import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/availability_slot.dart';
import '../models/booking_model.dart';
import '../models/booking_refund_model.dart';
import '../models/court_model.dart';
import 'auth_service.dart';

class BookingService {
  BookingService._internal();
  static final BookingService instance = BookingService._internal();

  static const String appUrl = 'https://c-j-pickleball.vercel.app';
  static const double defaultHourlyRate = 300.0;
  static const double paddleRentalFee = 150.0; // Flat fee for 2x paddles + 3x balls
  static const double ballThrowerHourlyFee = 150.0; // Per hour

  final AuthService _authService = AuthService.instance;

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

        return (response as List<dynamic>)
            .map((json) => CourtModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error fetching active courts from Supabase: $e');
      }
    }
    return [];
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

    return [];
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

    if (_supabase == null) {
      throw const AuthException('Supabase connection required to create a booking.');
    }

    final user = _supabase!.auth.currentUser;
    final duration = endTime.difference(startTime).inHours;

    final isAvail = await checkSlotAvailability(
      courtId: courtId,
      startTime: startTime,
      endTime: endTime,
    );

    if (!isAvail) {
      throw Exception('Slot No Longer Available: Time interval already booked.');
    }

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
      if (user == null) return [];

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

        return (response as List<dynamic>)
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error fetching player bookings: $e');
      }
    }

    return [];
  }

  /// Cancel a booking enforcing the strict 24-hour advance rule
  Future<void> cancelBooking(BookingModel booking) async {
    if (_supabase == null) {
      throw const AuthException('Supabase connection required to cancel a booking.');
    }

    final user = _supabase!.auth.currentUser;
    if (user == null) {
      throw const AuthException('Authentication required.');
    }

    // Strict 24-hour advance cancellation rule
    if (!booking.isCancellable) {
      throw Exception(
        'Cancellations are only permitted 24+ hours in advance of match start time.',
      );
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
    if (_supabase == null) {
      throw const AuthException('Supabase connection required for refund request.');
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
    if (_supabase == null) return null;

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
}
