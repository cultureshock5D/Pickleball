import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';
import '../models/venue_model.dart';
import 'auth_service.dart';

class BookingService {
  BookingService._internal();
  static final BookingService instance = BookingService._internal();

  final AuthService _authService = AuthService.instance;

  // In-memory availability cache: key is "courtId_YYYY-MM-DD"
  // Limited to _maxCacheEntries to prevent memory growth across long sessions
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

  /// Query all available venues with fast memory fallback
  Future<List<VenueModel>> fetchVenues() async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final response = await _supabase!.from('venues').select();
        final list = (response as List<dynamic>)
            .map((json) => VenueModel.fromJson(json as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('Notice: Supabase venues table fallback to MockData: $e');
      }
    }
    return MockData.venues;
  }

  /// Query active courts from public.courts
  Future<List<CourtModel>> fetchActiveCourts({String? venueId}) async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final dynamic response;
        if (venueId != null && venueId.isNotEmpty) {
          response = await _supabase!
              .from('courts')
              .select('*, venues(name)')
              .eq('status', 'active')
              .eq('venue_id', venueId);
        } else {
          response = await _supabase!
              .from('courts')
              .select('*, venues(name)')
              .eq('status', 'active');
        }

        final list = (response as List<dynamic>)
            .map((json) => CourtModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('Notice: Error fetching active courts from Supabase: $e');
      }
    }

    if (venueId != null && venueId.isNotEmpty) {
      return MockData.courts.where((c) => c.venueId == venueId).toList();
    }

    return MockData.courts;
  }

  /// Check real-time availability for a specific court and time window
  Future<bool> checkSlotAvailability({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // Invalidate cache for fresh live check
    invalidateAvailabilityCache(courtId: courtId, date: startTime);
    final existingBookings = await fetchCourtBookingsForDate(courtId, startTime);

    for (final b in existingBookings) {
      if (b.status.toLowerCase() == 'cancelled') continue;
      // Overlap condition: proposed start < existing end AND proposed end > existing start
      if (startTime.isBefore(b.endTime) && endTime.isAfter(b.startTime)) {
        return false;
      }
    }
    return true;
  }

  /// Create a new booking in public.bookings
  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
  }) async {
    final cleanCourtId = courtId.trim();
    if (cleanCourtId.isEmpty) {
      throw ArgumentError('Court ID must not be empty.');
    }
    if (!startTime.isBefore(endTime)) {
      throw ArgumentError('Booking start time must be before end time.');
    }
    if (totalAmount.isNaN || totalAmount.isInfinite || totalAmount < 0) {
      throw ArgumentError('Total amount must be a non-negative finite number.');
    }

    // Perform real-time first-come first-paid availability verification
    final isAvailable = await checkSlotAvailability(
      courtId: cleanCourtId,
      startTime: startTime,
      endTime: endTime,
    );

    if (!isAvailable) {
      throw Exception(
        'Slot No Longer Available: This court slot was just booked by another player who completed payment first. Please re-select a time.',
      );
    }

    final isLive = _authService.isLiveUser;

    if (isLive && _supabase != null) {
      final user = _supabase!.auth.currentUser;
      if (user == null) {
        throw const AuthException('User must be authenticated to create a booking.');
      }

      try {
        final payload = {
          'customer_id': user.id,
          'court_id': cleanCourtId,
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'status': 'pending',
          'total_amount': totalAmount,
        };

        final response = await _supabase!
            .from('bookings')
            .insert(payload)
            .select('*, courts(name)')
            .single();

        invalidateAvailabilityCache(courtId: courtId, date: startTime);
        return BookingModel.fromJson(response);
      } catch (e) {
        debugPrint('Error creating booking via Supabase: $e');
        rethrow;
      }
    } else {
      // Mock fallback: simulate ultra-fast latency (<200ms)
      await Future.delayed(const Duration(milliseconds: 150));
      final court = MockData.courts.firstWhere(
        (c) => c.id == courtId,
        orElse: () => MockData.courts.first,
      );

      final newBooking = BookingModel(
        id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        customerId: MockData.demoUserId,
        courtId: courtId,
        courtName: court.name,
        startTime: startTime,
        endTime: endTime,
        status: 'confirmed',
        totalAmount: totalAmount,
        createdAt: DateTime.now(),
      );

      MockData.addBooking(newBooking);
      invalidateAvailabilityCache(courtId: courtId, date: startTime);
      return newBooking;
    }
  }

  /// Fetch user bookings
  Future<List<BookingModel>> fetchCustomerBookings() async {
    final isLive = _authService.isLiveUser;

    if (isLive && _supabase != null) {
      final user = _supabase!.auth.currentUser;
      if (user == null) return [];

      try {
        final response = await _supabase!
            .from('bookings')
            .select('*, courts(name)')
            .eq('customer_id', user.id)
            .order('start_time', ascending: false);

        return (response as List<dynamic>)
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Notice: Error fetching customer bookings: $e');
        return MockData.bookings;
      }
    }

    return MockData.bookings;
  }

  /// Fetch bookings for a court on a given date
  Future<List<BookingModel>> fetchCourtBookingsForDate(
    String courtId,
    DateTime date,
  ) async {
    final key = _formatCacheKey(courtId, date);
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    if (isSupabaseReady && _supabase != null) {
      try {
        final response = await _supabase!
            .from('bookings')
            .select('*, courts(name)')
            .eq('court_id', courtId)
            .neq('status', 'cancelled')
            .gte('start_time', startOfDay.toUtc().toIso8601String())
            .lte('start_time', endOfDay.toUtc().toIso8601String());

        final bookings = (response as List<dynamic>)
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _putInCache(key, bookings);
        return bookings;
      } catch (e) {
        debugPrint('Notice: Error fetching court bookings: $e');
      }
    }

    // Mock fallback: check mock bookings
    final list = MockData.bookings.where((b) {
      return b.courtId == courtId &&
          b.status != 'cancelled' &&
          b.startTime.year == date.year &&
          b.startTime.month == date.month &&
          b.startTime.day == date.day;
    }).toList();

    _putInCache(key, list);
    return list;
  }

  /// Cancel a booking
  Future<void> cancelBooking(String bookingId) async {
    final isLive = _authService.isLiveUser;

    if (isLive && _supabase != null) {
      try {
        await _supabase!
            .from('bookings')
            .update({'status': 'cancelled'})
            .eq('id', bookingId);
        invalidateAvailabilityCache();
      } catch (e) {
        debugPrint('Error cancelling booking: $e');
        rethrow;
      }
    } else {
      MockData.cancelBooking(bookingId);
      invalidateAvailabilityCache();
    }
  }
}
