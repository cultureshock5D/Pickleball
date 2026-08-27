import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../demo/demo_data.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';
import 'auth_service.dart';

class BookingService {
  BookingService._internal();
  static final BookingService instance = BookingService._internal();

  final AuthService _authService = AuthService.instance;

  // In-memory availability cache: key is "courtId_YYYY-MM-DD"
  final Map<String, List<BookingModel>> _courtAvailabilityCache = {};

  String _formatCacheKey(String courtId, DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${courtId}_${date.year}-$m-$d';
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

  /// Query active courts from public.courts
  Future<List<CourtModel>> fetchActiveCourts() async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final response = await _supabase!
            .from('courts')
            .select()
            .eq('status', 'active');

        final list = (response as List<dynamic>)
            .map((json) => CourtModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (list.isNotEmpty) return list;
        return DemoData.mockCourts;
      } catch (e) {
        debugPrint('Notice: Error fetching active courts from Supabase: $e');
        return DemoData.mockCourts;
      }
    }
    return DemoData.mockCourts;
  }

  /// Create a new booking in public.bookings
  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
  }) async {
    final isLive = _authService.isLiveUser;

    if (isLive && _supabase != null) {
      final user = _supabase!.auth.currentUser;
      if (user == null) {
        throw const AuthException('User must be authenticated to create a booking.');
      }

      try {
        final payload = {
          'customer_id': user.id,
          'court_id': courtId,
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

        final created = BookingModel.fromJson(response);
        invalidateAvailabilityCache(courtId: courtId, date: startTime);
        return created;
      } on PostgrestException catch (pe) {
        throw Exception(pe.message);
      } catch (e) {
        throw Exception('Failed to create reservation: $e');
      }
    } else {
      // Local demo booking insertion strictly for demo/preview sessions
      final courtName = DemoData.mockCourts
          .firstWhere(
            (c) => c.id == courtId,
            orElse: () => DemoData.mockCourts.first,
          )
          .name;

      final newBooking = BookingModel(
        id: 'BK-${(1000 + DemoData.demoBookings.length * 77)}',
        customerId: DemoData.demoUserId,
        courtId: courtId,
        courtName: courtName,
        startTime: startTime,
        endTime: endTime,
        status: 'pending',
        totalAmount: totalAmount,
        createdAt: DateTime.now(),
      );

      DemoData.addDemoBooking(newBooking);
      invalidateAvailabilityCache(courtId: courtId, date: startTime);
      return newBooking;
    }
  }

  /// Fetch user's bookings from public.bookings.
  /// For legitimate users, returns only their actual database bookings (empty list if none).
  /// Mock data is NEVER returned for real authenticated accounts.
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
        debugPrint('Notice: live user bookings query result: $e');
        return []; // Real users get an empty list, NEVER demo data!
      }
    }

    // Return demo mockup data ONLY for demo guest preview sessions
    if (_authService.isDemoMode) {
      return DemoData.demoBookings;
    }

    return [];
  }

  /// Cancel a booking by ID
  Future<bool> cancelBooking(String bookingId) async {
    final isLive = _authService.isLiveUser;

    if (isLive && _supabase != null) {
      final user = _supabase!.auth.currentUser;
      if (user == null) return false;

      try {
        await _supabase!
            .from('bookings')
            .update({'status': 'cancelled'})
            .eq('id', bookingId)
            .eq('customer_id', user.id);
        invalidateAvailabilityCache();
        return true;
      } catch (e) {
        debugPrint('Error cancelling booking in Supabase: $e');
        return false;
      }
    }

    // Demo/offline mode cancellation
    DemoData.cancelDemoBooking(bookingId);
    invalidateAvailabilityCache();
    return true;
  }

  /// Fetch bookings for a court on a given date to accurately determine booked vs available slots
  /// with in-memory caching for sub-millisecond tab/date transitions.
  Future<List<BookingModel>> fetchCourtBookingsForDate(
    String courtId,
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _formatCacheKey(courtId, date);

    if (!forceRefresh && _courtAvailabilityCache.containsKey(cacheKey)) {
      return _courtAvailabilityCache[cacheKey]!;
    }

    final isLive = _authService.isLiveUser;
    final startOfDay = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();

    List<BookingModel> result = [];

    if (isLive && _supabase != null) {
      try {
        final response = await _supabase!
            .from('bookings')
            .select('*, courts(name)')
            .eq('court_id', courtId)
            .neq('status', 'cancelled')
            .gte('start_time', startOfDay)
            .lte('start_time', endOfDay);

        result = (response as List<dynamic>)
            .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Notice: Error fetching court bookings for date from Supabase: $e');
      }
    } else {
      // Demo/fallback mode: Check demo bookings for this court and date
      result = DemoData.demoBookings.where((b) {
        if (b.courtId != courtId || b.status.toLowerCase() == 'cancelled') return false;
        final localDate = b.startTime.toLocal();
        return localDate.year == date.year &&
            localDate.month == date.month &&
            localDate.day == date.day;
      }).toList();
    }

    _courtAvailabilityCache[cacheKey] = result;
    return result;
  }
}
