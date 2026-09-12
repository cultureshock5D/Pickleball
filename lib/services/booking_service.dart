import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/availability_slot.dart';
import '../models/booking_model.dart';
import '../models/booking_refund_model.dart';
import '../models/court_model.dart';
import '../data/mock_data.dart';
import '../core/constants/paymongo_config.dart';
import 'auth_service.dart';

enum BookingRealtimeEventType { inserted, updated, deleted }

class BookingRealtimeEvent {
  final BookingRealtimeEventType type;
  final BookingModel? booking;
  final String? courtId;
  final DateTime? startTime;

  BookingRealtimeEvent({
    required this.type,
    this.booking,
    String? courtId,
    DateTime? startTime,
  })  : courtId = courtId ?? booking?.courtId,
        startTime = startTime ?? booking?.startTime;

  @override
  String toString() =>
      'BookingRealtimeEvent(type: $type, courtId: $courtId, startTime: $startTime, booking: ${booking?.id})';
}

class BookingService {
  BookingService._internal();
  static final BookingService instance = BookingService._internal();

  static String get appUrl {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet('NEXT_PUBLIC_APP_URL') ?? dotenv.maybeGet('APP_URL');
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (_) {}
    return 'https://c-j-pickleball.vercel.app';
  }
  static const double defaultHourlyRate = 300.0;
  static const double paddleRentalFee = 150.0; // Flat fee for 2x paddles + 3x balls
  static const double ballThrowerHourlyFee = 150.0; // Per hour

  final AuthService _authService = AuthService.instance;

  // Realtime subscription and event stream
  RealtimeChannel? _bookingsChannel;
  StreamController<BookingRealtimeEvent>? _bookingEventsController;
  bool _hasSubscribedBefore = false;

  /// Expose broadcast stream of realtime booking events
  Stream<BookingRealtimeEvent> get bookingRealtimeEvents {
    _ensureBookingEventsController();
    return _bookingEventsController!.stream;
  }

  void _ensureBookingEventsController() {
    if (_bookingEventsController == null || _bookingEventsController!.isClosed) {
      _bookingEventsController =
          StreamController<BookingRealtimeEvent>.broadcast();
    }
  }

  /// Initialize Supabase Realtime channel on public:bookings table
  void initRealtimeSubscription() {
    _ensureBookingEventsController();

    if (!isSupabaseReady || _supabase == null) {
      debugPrint('Supabase is not ready. Realtime subscription deferred.');
      return;
    }

    if (_bookingsChannel != null) {
      return;
    }

    try {
      _bookingsChannel = _supabase!.channel('public:bookings')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (PostgresChangePayload payload) {
            _handleRealtimePayload(payload);
          },
        )
        ..subscribe((RealtimeSubscribeStatus status, Object? error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint(
              'Supabase Realtime channel public:bookings subscribed successfully.',
            );
            if (_hasSubscribedBefore) {
              // Reconnection catch-up: invalidate cache and notify UI listeners
              invalidateAvailabilityCache();
              _bookingEventsController?.add(
                BookingRealtimeEvent(
                  type: BookingRealtimeEventType.updated,
                ),
              );
            }
            _hasSubscribedBefore = true;
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('Supabase Realtime channel error: $error');
          }
        });
    } catch (e) {
      debugPrint('Error initializing Supabase Realtime channel: $e');
    }
  }

  void _handleRealtimePayload(PostgresChangePayload payload) {
    BookingRealtimeEventType eventType;
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        eventType = BookingRealtimeEventType.inserted;
        break;
      case PostgresChangeEvent.delete:
        eventType = BookingRealtimeEventType.deleted;
        break;
      case PostgresChangeEvent.update:
      case PostgresChangeEvent.all:
      default:
        eventType = BookingRealtimeEventType.updated;
        break;
    }

    final record =
        payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
    BookingModel? booking;
    if (record.isNotEmpty) {
      try {
        booking = BookingModel.fromJson(record);
      } catch (e) {
        debugPrint('Note: unable to parse BookingModel from realtime payload: $e');
      }
    }

    final rawCourtId = payload.newRecord['court_id'] ??
        payload.newRecord['courtId'] ??
        payload.oldRecord['court_id'] ??
        payload.oldRecord['courtId'];
    final courtId = rawCourtId?.toString() ?? booking?.courtId;

    DateTime? startTime = booking?.startTime;
    if (startTime == null) {
      final rawStartTime = payload.newRecord['start_time'] ??
          payload.newRecord['startTime'] ??
          payload.oldRecord['start_time'] ??
          payload.oldRecord['startTime'];
      if (rawStartTime != null) {
        startTime = DateTime.tryParse(rawStartTime.toString());
      }
    }

    // Invalidate cache for newly affected court & date
    if (courtId != null && startTime != null) {
      invalidateAvailabilityCache(courtId: courtId, date: startTime);
    } else {
      invalidateAvailabilityCache();
    }

    // Also invalidate old court/date if this was an update and changed slot
    final oldCourtId =
        (payload.oldRecord['court_id'] ?? payload.oldRecord['courtId'])?.toString();
    final rawOldStart =
        payload.oldRecord['start_time'] ?? payload.oldRecord['startTime'];
    final oldStartTime =
        rawOldStart != null ? DateTime.tryParse(rawOldStart.toString()) : null;
    if (oldCourtId != null &&
        oldStartTime != null &&
        (oldCourtId != courtId || oldStartTime != startTime)) {
      invalidateAvailabilityCache(courtId: oldCourtId, date: oldStartTime);
    }

    final event = BookingRealtimeEvent(
      type: eventType,
      booking: booking,
      courtId: courtId,
      startTime: startTime,
    );

    _ensureBookingEventsController();
    _bookingEventsController?.add(event);
  }

  /// Broadcast a mock or simulator event to all UI listeners and invalidate cache
  void broadcastMockBookingEvent(BookingRealtimeEvent event) {
    if (event.courtId != null && event.startTime != null) {
      invalidateAvailabilityCache(courtId: event.courtId, date: event.startTime);
    } else {
      invalidateAvailabilityCache();
    }
    _ensureBookingEventsController();
    _bookingEventsController?.add(event);
  }

  /// Tear down and close Realtime subscriptions and streams
  void disposeRealtimeSubscription() {
    if (_bookingsChannel != null && _supabase != null) {
      try {
        _supabase!.removeChannel(_bookingsChannel!);
      } catch (e) {
        debugPrint('Error removing realtime channel: $e');
      }
      _bookingsChannel = null;
    }
    if (_bookingEventsController != null && !_bookingEventsController!.isClosed) {
      _bookingEventsController!.close();
      _bookingEventsController = null;
    }
    _hasSubscribedBefore = false;
  }

  User? get currentUser => _authService.currentUser;

  // In-memory availability cache: key is "courtId_YYYY-MM-DD"
  static const int _maxCacheEntries = 60;
  final Map<String, List<BookingModel>> _courtAvailabilityCache = {};

  String _formatCacheKey(String courtId, DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${courtId}_${date.year}-$m-$d';
  }

  void _putInCache(String key, List<BookingModel> items) {
    if (_courtAvailabilityCache.length >= _maxCacheEntries) {
      _courtAvailabilityCache.remove(_courtAvailabilityCache.keys.first);
    }
    _courtAvailabilityCache[key] = items;
  }

  /// Instant synchronous cache lookup for zero-latency UI updates
  List<BookingModel>? getCachedAvailability(String courtId, DateTime date) {
    return _courtAvailabilityCache[_formatCacheKey(courtId, date)];
  }

  /// Invalidate cache for a specific date or clear all
  void invalidateAvailabilityCache({String? courtId, DateTime? date}) {
    if (courtId != null && date != null) {
      _courtAvailabilityCache.remove(_formatCacheKey(courtId, date));
    } else {
      _courtAvailabilityCache.clear();
    }
  }

  bool get isSupabaseReady => _authService.isSupabaseReady;

  SupabaseClient? get _supabase {
    try {
      return isSupabaseReady ? Supabase.instance.client : null;
    } catch (_) {
      return null;
    }
  }

  /// Calculate total price for a booking based on C&J Pickleball pricing rules
  static double calculateTotalPrice({
    required double hourlyRate,
    required int durationHours,
    required bool paddleRental,
    required bool ballThrowerRental,
  }) {
    final courtSubtotal = hourlyRate * durationHours;
    final paddleFee = paddleRental ? paddleRentalFee : 0.0;
    final ballThrowerFee =
        ballThrowerRental ? (ballThrowerHourlyFee * durationHours) : 0.0;
    return courtSubtotal + paddleFee + ballThrowerFee;
  }

  /// Query active courts from public.courts table (where status != 'inactive')
  Future<List<CourtModel>> fetchActiveCourts() async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final response = await _supabase!
            .from('courts')
            .select()
            .neq('status', 'inactive')
            .order('name');

        final courts = (response as List<dynamic>)
            .map((json) => CourtModel.fromJson(json as Map<String, dynamic>))
            .toList();
        if (courts.isNotEmpty) {
          return courts;
        }
      } catch (e) {
        debugPrint('Error fetching active courts from Supabase: $e');
      }
    }
    return MockData.getMockActiveCourts();
  }

  /// Fetch bookings for a court on a given date range to check availability
  Future<List<BookingModel>> fetchCourtBookingsForDate(
    String courtId,
    DateTime date,
  ) async {
    final key = _formatCacheKey(courtId, date);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    if (isSupabaseReady && _supabase != null) {
      try {
        dynamic response;
        try {
          // Primary query: v_court_availability view (publicly readable court schedules)
          response = await _supabase!
              .from('v_court_availability')
              .select()
              .eq('court_id', courtId)
              .gte('end_time', dayStart.toUtc().toIso8601String())
              .lte('start_time', dayEnd.toUtc().toIso8601String());
        } catch (_) {
          // Fallback to bookings table
          response = await _supabase!
              .from('bookings')
              .select('*, courts(name, type, hourly_rate)')
              .eq('court_id', courtId)
              .inFilter('status', [
                'paid',
                'confirmed',
                'checked_in',
                'walk_in',
                'pending_payment',
                'pending',
              ])
              .gte('end_time', dayStart.toUtc().toIso8601String())
              .lte('start_time', dayEnd.toUtc().toIso8601String());
        }

        final allBookings = (response as List<dynamic>)
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .where((b) {
          // Discard expired pending holds
          if ((b.status == 'pending_payment' || b.status == 'pending') &&
              b.isHoldExpired) {
            return false;
          }
          return true;
        }).toList();

        // Also query court maintenance schedules from project.sql
        try {
          final maintenanceRes = await _supabase!
              .from('court_maintenance_schedules')
              .select()
              .eq('court_id', courtId)
              .gte('end_time', dayStart.toUtc().toIso8601String())
              .lte('start_time', dayEnd.toUtc().toIso8601String());

          for (final m in (maintenanceRes as List<dynamic>)) {
            final mJson = m as Map<String, dynamic>;
            final sTime =
                DateTime.parse(mJson['start_time'] as String).toLocal();
            final eTime =
                DateTime.parse(mJson['end_time'] as String).toLocal();
            allBookings.add(BookingModel(
              id: mJson['id'] as String? ?? 'maint',
              courtId: mJson['court_id'] as String? ?? courtId,
              startTime: sTime,
              endTime: eTime,
              status: 'maintenance',
              totalPrice: 0.0,
              notes: mJson['title'] as String? ?? 'Court Maintenance',
            ));
          }
        } catch (me) {
          debugPrint('Notice: court_maintenance_schedules query: $me');
        }

        _putInCache(key, allBookings);
        return allBookings;
      } catch (e) {
        debugPrint('Error fetching court bookings: $e');
      }
    }

    final fallbackBookings = MockData.getBookingsForCourtAndDate(courtId, date);
    _putInCache(key, fallbackBookings);
    return fallbackBookings;
  }

  /// Generate 16 hourly slots (6:00 AM – 10:00 PM, hours 6 to 21) for a court on date
  Future<List<AvailabilitySlot>> generateDaySlots({
    required String courtId,
    required DateTime date,
    int durationHours = 1,
    double hourlyRate = defaultHourlyRate,
  }) async {
    final bookings = await fetchCourtBookingsForDate(courtId, date);
    final occupiedHours = <int>{};

    for (final b in bookings) {
      final s = b.startTime;
      final e = b.endTime;

      // Extract occupied hours
      for (int h = s.hour; h < e.hour; h++) {
        occupiedHours.add(h);
      }
    }

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final slots = <AvailabilitySlot>[];

    // Operating hours: 6:00 AM to 10:00 PM (hours 6–21)
    // Last start hour is 22 - durationHours
    for (int hour = 6; hour <= 22 - durationHours; hour++) {
      bool available = true;

      // Check contiguous block
      for (int sub = hour; sub < hour + durationHours; sub++) {
        if (occupiedHours.contains(sub)) {
          available = false;
          break;
        }
      }

      final isPast = isToday && hour <= now.hour;
      if (isPast) {
        available = false;
      }

      slots.add(AvailabilitySlot(
        hour24: hour,
        available: available,
        price: hourlyRate * durationHours,
        isPast: isPast,
      ));
    }

    return slots;
  }

  /// Check whether a proposed time slot is strictly available
  Future<bool> checkSlotAvailability({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    invalidateAvailabilityCache(courtId: courtId, date: startTime);
    final existingBookings = await fetchCourtBookingsForDate(courtId, startTime);

    for (final b in existingBookings) {
      if (b.status == 'cancelled' || b.status == 'expired') continue;
      if (b.status == 'pending_payment' && b.isHoldExpired) continue;

      // Overlap condition: proposed start < existing end AND proposed end > existing start
      if (startTime.isBefore(b.endTime) && endTime.isAfter(b.startTime)) {
        return false;
      }
    }
    return true;
  }

  /// Create PayMongo Checkout Session directly via PayMongo Live REST API
  /// Returns checkout URL, session ID, and status
  Future<Map<String, dynamic>> createPayMongoCheckoutSession({
    required String courtId,
    required String courtName,
    required double hourlyRate,
    required int durationHours,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    bool paddleRental = false,
    bool ballThrowerRental = false,
    List<String>? selectedPaymentMethods,
  }) async {
    final secretKey = PayMongoConfig.secretKey;
    if (secretKey.isEmpty) {
      throw Exception('PayMongo live secret key not configured.');
    }

    final lineItems = <Map<String, dynamic>>[];

    // 1. Court line item (centavos)
    final courtAmountCentavos = (hourlyRate * durationHours * 100).round();
    lineItems.add({
      'currency': 'PHP',
      'amount': courtAmountCentavos,
      'name': '$courtName ($durationHours hr)',
      'quantity': 1,
    });

    // 2. Paddle Rental
    if (paddleRental) {
      lineItems.add({
        'currency': 'PHP',
        'amount': (paddleRentalFee * 100).round(),
        'name': 'Paddle Rental (2x Paddles, 3x Balls)',
        'quantity': 1,
      });
    }

    // 3. Ball Thrower
    if (ballThrowerRental) {
      lineItems.add({
        'currency': 'PHP',
        'amount': (ballThrowerHourlyFee * durationHours * 100).round(),
        'name': 'Ball Thrower Machine ($durationHours hr)',
        'quantity': 1,
      });
    }

    final defaultPaymentMethods = [
      'gcash',
      'paymaya',
      'grab_pay',
      'card',
      'dob',
      'billease',
    ];

    final paymentMethodTypes = (selectedPaymentMethods != null && selectedPaymentMethods.isNotEmpty)
        ? selectedPaymentMethods
        : defaultPaymentMethods;

    final body = jsonEncode({
      'data': {
        'attributes': {
          'send_email_receipt': true,
          'show_description': true,
          'show_line_items': true,
          'line_items': lineItems,
          'payment_method_types': paymentMethodTypes,
          'description': 'C&J Pickleball Court Booking - $courtName',
          'billing': {
            'name': guestName.trim().isNotEmpty ? guestName.trim() : 'Guest Player',
            if (guestEmail.trim().isNotEmpty) 'email': guestEmail.trim().toLowerCase(),
            if (guestPhone.trim().isNotEmpty) 'phone': guestPhone.trim(),
          },
          'success_url': '$appUrl/booking/success',
          'cancel_url': '$appUrl/booking/cancelled',
        }
      }
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.paymongo.com/v1/checkout_sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': PayMongoConfig.basicAuthHeader,
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        final attributes = data['attributes'] as Map<String, dynamic>;
        final sessionId = data['id'] as String;
        final checkoutUrl = attributes['checkout_url'] as String;

        return {
          'sessionId': sessionId,
          'checkoutUrl': checkoutUrl,
          'status': attributes['status'] as String? ?? 'active',
        };
      } else {
        String errorMessage = 'Failed to create PayMongo checkout (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err['errors'] != null && err['errors'] is List && (err['errors'] as List).isNotEmpty) {
            errorMessage = err['errors'][0]['detail'] ?? errorMessage;
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Direct PayMongo API notice (e.g. browser CORS on Web): $e');
      // Fallback: Attempt Next.js server-side proxy
      try {
        final proxyRes = await http.post(
          Uri.parse('$appUrl/api/checkout/paymongo'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'courtId': courtId,
            'courtName': courtName,
            'hourlyRate': hourlyRate,
            'durationHours': durationHours,
            'guestName': guestName.trim(),
            'guestEmail': guestEmail.trim().toLowerCase(),
            'guestPhone': guestPhone.trim(),
            'paddleRental': paddleRental,
            'ballThrowerRental': ballThrowerRental,
          }),
        );

        if (proxyRes.statusCode == 200 || proxyRes.statusCode == 201) {
          final data = jsonDecode(proxyRes.body) as Map<String, dynamic>;
          final checkoutUrl = data['checkoutUrl'] as String? ?? data['url'] as String?;
          final sessionId = data['sessionId'] as String? ?? data['id'] as String? ?? 'cs_${DateTime.now().millisecondsSinceEpoch}';
          if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
            return {
              'sessionId': sessionId,
              'checkoutUrl': checkoutUrl,
              'status': 'active',
            };
          }
        }
      } catch (proxyErr) {
        debugPrint('Proxy endpoint notice: $proxyErr');
      }

      rethrow;
    }
  }

  /// Direct PayMongo REST API query to inspect checkout session payment status
  Future<Map<String, dynamic>> getPayMongoSessionStatus(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.paymongo.com/v1/checkout_sessions/$sessionId'),
        headers: {
          'Authorization': PayMongoConfig.basicAuthHeader,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        final attributes = data['attributes'] as Map<String, dynamic>;
        final status = attributes['status'] as String? ?? '';
        final payments = attributes['payments'] as List<dynamic>? ?? [];
        final isPaid = status == 'paid' ||
            payments.any((p) {
              final pStatus = p['attributes']?['status'] as String?;
              return pStatus == 'paid';
            });

        return {
          'sessionId': sessionId,
          'status': status,
          'isPaid': isPaid,
          'payments': payments,
        };
      }
    } catch (e) {
      debugPrint('PayMongo session status check notice: $e');
    }

    return {
      'sessionId': sessionId,
      'status': 'pending',
      'isPaid': false,
      'payments': [],
    };
  }

  /// Create PayMongo Checkout Session via Next.js API
  /// Returns checkout URL, booking ID, and expiration timestamp
  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String courtId,
    required DateTime date,
    required int hour24,
    required int durationHours,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    bool paddleRental = false,
    bool ballThrowerRental = false,
  }) async {
    final session = _supabase?.auth.currentSession;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final body = jsonEncode({
      'courtId': courtId,
      'date': formattedDate,
      'hour24': hour24,
      'durationHours': durationHours,
      'guestName': guestName.trim(),
      'guestEmail': guestEmail.trim().toLowerCase(),
      'guestPhone': guestPhone.trim(),
      'paddleRental': paddleRental,
      'ballThrowerRental': ballThrowerRental,
    });

    try {
      final response = await http.post(
        Uri.parse('$appUrl/api/checkout/paymongo'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        invalidateAvailabilityCache(courtId: courtId, date: date);
        return data;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Checkout initiation failed (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Next.js PayMongo Checkout Error: $e');
      rethrow;
    }
  }

  /// Fallback direct booking creation when authenticated
  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
    String? paymongoCheckoutSessionId,
    String? notes,
  }) async {
    if (courtId.trim().isEmpty) {
      throw ArgumentError.value(courtId, 'courtId', 'Court ID cannot be empty');
    }
    if (!startTime.isBefore(endTime)) {
      throw ArgumentError('startTime must be before endTime');
    }
    if (totalAmount < 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', 'Total amount must be non-negative');
    }

    final isAvail = await checkSlotAvailability(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
    );

    if (!isAvail) {
      throw Exception('Slot No Longer Available: Time interval already booked.');
    }

    if (!isSupabaseReady || _supabase == null) {
      final user = _authService.currentUser;
      final mockBooking = MockData.createMockBooking(
        courtId: courtId,
        startTime: startTime,
        endTime: endTime,
        totalAmount: totalAmount,
        userId: user?.id,
        guestName: guestName.isNotEmpty
            ? guestName
            : (user?.userMetadata?['full_name'] ?? 'Guest'),
        guestEmail: guestEmail.isNotEmpty
            ? guestEmail
            : (user?.email ?? 'player@pickleball.dev'),
        guestPhone: guestPhone,
        paymongoCheckoutSessionId: paymongoCheckoutSessionId,
        notes: notes,
        status: (paymongoCheckoutSessionId != null &&
                paymongoCheckoutSessionId.isNotEmpty)
            ? 'pending_payment'
            : 'confirmed',
      );
      invalidateAvailabilityCache(courtId: courtId, date: startTime);
      broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.inserted,
          booking: mockBooking,
        ),
      );
      return mockBooking;
    }

    final user = _supabase!.auth.currentUser;
    final duration = endTime.difference(startTime).inHours;

    try {
      final payload = {
        'court_id': courtId,
        if (user != null) 'user_id': user.id,
        if (user != null) 'customer_id': user.id,
        'guest_name': guestName.isNotEmpty
            ? guestName
            : (user?.userMetadata?['full_name'] ?? 'Guest'),
        'guest_email':
            guestEmail.isNotEmpty ? guestEmail : (user?.email ?? ''),
        'guest_phone': guestPhone,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'duration_hours': duration > 0 ? duration : 1,
        'total_price': totalAmount,
        'total_amount': totalAmount,
        'currency': 'PHP',
        'status': 'pending_payment',
        'payment_method': 'paymongo',
        if (paymongoCheckoutSessionId != null && paymongoCheckoutSessionId.isNotEmpty)
          'paymongo_checkout_session_id': paymongoCheckoutSessionId,
        if (notes != null) 'notes': notes,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _supabase!
          .from('bookings')
          .insert(payload)
          .select('*, courts(name, type, hourly_rate)')
          .single();

      invalidateAvailabilityCache(courtId: courtId, date: startTime);
      return BookingModel.fromJson(response);
    } on PostgrestException catch (pe) {
      debugPrint('PostgrestException creating booking: ${pe.message} (${pe.code})');
      if (pe.code == '42501') {
        throw const AuthException(
          'Booking authorization restricted. Please ensure you are logged in.',
        );
      }
      throw Exception('Booking failed: ${pe.message}');
    } catch (e) {
      debugPrint('Error creating booking via Supabase: $e');
      rethrow;
    }
  }

  /// Fetch player bookings for the authenticated user
  Future<List<BookingModel>> fetchCustomerBookings() async {
    if (isSupabaseReady && _supabase != null) {
      final user = _supabase!.auth.currentUser;
      if (user == null) {
        return MockData.getMockUserBookings();
      }

      try {
        final email = user.email?.trim().toLowerCase() ?? '';
        final orFilter = email.isNotEmpty
            ? 'user_id.eq.${user.id},customer_id.eq.${user.id},guest_email.eq.$email'
            : 'user_id.eq.${user.id},customer_id.eq.${user.id}';

        final response = await _supabase!
            .from('bookings')
            .select('*, courts(name, type, hourly_rate), booking_refunds(*)')
            .or(orFilter)
            .order('start_time', ascending: false);

        final bookings = (response as List<dynamic>)
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .toList();
        if (bookings.isNotEmpty) {
          return bookings;
        }
      } catch (e) {
        debugPrint('Error fetching player bookings: $e');
      }
      return MockData.getMockUserBookings(user.id, user.email);
    }

    final user = _authService.currentUser;
    return MockData.getMockUserBookings(user?.id, user?.email);
  }

  /// Cancel a booking enforcing the strict 24-hour advance rule
  Future<void> cancelBooking(BookingModel booking) async {
    // Strict 24-hour advance cancellation rule
    if (!booking.isCancellable) {
      throw Exception(
        'Cancellations are only permitted 24+ hours in advance of match start time.',
      );
    }

    if (!isSupabaseReady || _supabase == null) {
      final cancelled = MockData.cancelMockBooking(booking.id);
      invalidateAvailabilityCache(
        courtId: booking.courtId,
        date: booking.startTime,
      );
      broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
          booking: cancelled ?? booking.copyWith(status: 'cancelled'),
          courtId: booking.courtId,
          startTime: booking.startTime,
        ),
      );
      return;
    }

    final user = _supabase!.auth.currentUser;
    if (user == null) {
      throw const AuthException('Authentication required.');
    }

    final nextStatus = booking.paymentMethod == 'cash'
        ? 'cancelled'
        : 'cancelled_refund_pending';

    try {
      await _supabase!
          .from('bookings')
          .update({
            'status': nextStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', booking.id)
          .eq('user_id', user.id);

      MockData.cancelMockBooking(booking.id);
      invalidateAvailabilityCache(
        courtId: booking.courtId,
        date: booking.startTime,
      );
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      rethrow;
    }
  }

  /// Request a refund for a booking with e-wallet details
  Future<BookingRefundModel> requestRefund({
    required String bookingId,
    required double amount,
    required String walletType, // gcash | maya | bank_transfer | counter_cash
    required String accountName,
    required String accountNumber,
    String? reason,
  }) async {
    if (!isSupabaseReady || _supabase == null) {
      final refund = BookingRefundModel(
        id: 'mock-ref-${DateTime.now().millisecondsSinceEpoch}',
        bookingId: bookingId,
        amount: amount,
        walletType: walletType,
        accountName: accountName.trim(),
        accountNumber: accountNumber.trim(),
        reason: reason?.trim(),
        createdAt: DateTime.now(),
      );
      MockData.cancelMockBooking(bookingId);
      invalidateAvailabilityCache();
      return refund;
    }

    try {
      final refundPayload = {
        'booking_id': bookingId,
        'amount': amount,
        'wallet_type': walletType,
        'account_name': accountName.trim(),
        'account_number': accountNumber.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _supabase!
          .from('booking_refunds')
          .insert(refundPayload)
          .select()
          .single();

      await _supabase!.from('bookings').update({
        'status': 'cancelled_refund_pending',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);

      MockData.cancelMockBooking(bookingId);
      invalidateAvailabilityCache();
      return BookingRefundModel.fromJson(response);
    } catch (e) {
      debugPrint('Error requesting refund: $e');
      rethrow;
    }
  }

  /// Poll for booking payment completion
  Future<BookingModel?> pollBookingPaidStatus(
    String bookingId, {
    int maxAttempts = 15,
    Duration interval = const Duration(seconds: 2),
  }) async {
    if (_supabase == null) {
      final mock = MockData.mockBookings.firstWhere(
        (b) => b.id == bookingId,
        orElse: () => BookingModel(
          id: bookingId,
          courtId: '',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          totalPrice: 300.0,
        ),
      );
      if (mock.isPaid) return mock;
      return null;
    }

    for (int i = 0; i < maxAttempts; i++) {
      try {
        final data = await _supabase!
            .from('bookings')
            .select('*, courts(name, type, hourly_rate)')
            .eq('id', bookingId)
            .single();

        final booking = BookingModel.fromJson(data);
        if (booking.isPaid || booking.isCheckedIn) {
          return booking;
        }
      } catch (e) {
        debugPrint('Poll attempt $i note: $e');
      }
      await Future.delayed(interval);
    }
    return null;
  }

  /// Mark a booking as paid in Supabase
  Future<BookingModel> markBookingAsPaid(
    String bookingId, {
    String? paymongoSessionId,
  }) async {
    if (_supabase != null) {
      try {
        final updatePayload = {
          'status': 'paid',
          if (paymongoSessionId != null && paymongoSessionId.isNotEmpty)
            'paymongo_checkout_session_id': paymongoSessionId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        final response = await _supabase!
            .from('bookings')
            .update(updatePayload)
            .eq('id', bookingId)
            .select('*, courts(name, type, hourly_rate)')
            .single();

        MockData.markMockBookingAsPaid(
          bookingId,
          paymongoSessionId: paymongoSessionId,
        );
        invalidateAvailabilityCache();
        final paidBooking = BookingModel.fromJson(response);
        broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.updated,
            booking: paidBooking,
          ),
        );
        return paidBooking;
      } catch (e) {
        debugPrint('Error marking booking as paid in Supabase: $e');
      }
    }

    final updatedMock = MockData.markMockBookingAsPaid(
      bookingId,
      paymongoSessionId: paymongoSessionId,
    );
    invalidateAvailabilityCache();
    final fallbackBooking = updatedMock ??
        BookingModel(
          id: bookingId,
          courtId: '',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          status: 'paid',
          totalPrice: 300.0,
        );
    broadcastMockBookingEvent(
      BookingRealtimeEvent(
        type: BookingRealtimeEventType.updated,
        booking: fallbackBooking,
      ),
    );
    return fallbackBooking;
  }
}
