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

        return BookingModel.fromJson(response);
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
}
