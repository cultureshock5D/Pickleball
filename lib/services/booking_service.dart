import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';

class BookingService {
  BookingService._internal();
  static final BookingService instance = BookingService._internal();

  final List<BookingModel> _localBookings = [
    BookingModel(
      id: 'BK-9024',
      customerId: 'demo-user-12345',
      courtId: 'a1111111-1111-1111-1111-111111111111',
      courtName: 'Court 1 - Center Championship',
      startTime: DateTime.now().add(const Duration(hours: 3)),
      endTime: DateTime.now().add(const Duration(hours: 4, minutes: 30)),
      status: 'confirmed',
      totalAmount: 67.50,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    BookingModel(
      id: 'BK-8911',
      customerId: 'demo-user-12345',
      courtId: 'b2222222-2222-2222-2222-222222222222',
      courtName: 'Court 2 - Neon Arena (LED)',
      startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      endTime: DateTime.now().add(const Duration(days: 1, hours: 3, minutes: 30)),
      status: 'pending',
      totalAmount: 82.50,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BookingModel(
      id: 'BK-7840',
      customerId: 'demo-user-12345',
      courtId: 'c3333333-3333-3333-3333-333333333333',
      courtName: 'Court 3 - Skyline Rooftop',
      startTime: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      endTime: DateTime.now().subtract(const Duration(days: 3, hours: 2, minutes: 30)),
      status: 'completed',
      totalAmount: 60.00,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  bool get isSupabaseReady {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

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
        return _defaultCourts;
      } catch (e) {
        debugPrint('Error fetching active courts: $e');
        return _defaultCourts;
      }
    }
    return _defaultCourts;
  }

  /// Create a new booking in public.bookings
  Future<BookingModel> createBooking({
    required String courtId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalAmount,
  }) async {
    if (isSupabaseReady && _supabase != null) {
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
      // Local demo booking insertion
      final courtName = _defaultCourts
          .firstWhere(
            (c) => c.id == courtId,
            orElse: () => _defaultCourts.first,
          )
          .name;

      final newBooking = BookingModel(
        id: 'BK-${(1000 + _localBookings.length * 77)}',
        customerId: 'demo-user-12345',
        courtId: courtId,
        courtName: courtName,
        startTime: startTime,
        endTime: endTime,
        status: 'pending',
        totalAmount: totalAmount,
        createdAt: DateTime.now(),
      );

      _localBookings.insert(0, newBooking);
      return newBooking;
    }
  }

  /// Fetch user's bookings from public.bookings
  Future<List<BookingModel>> fetchCustomerBookings() async {
    if (isSupabaseReady && _supabase != null) {
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
        debugPrint('Error fetching user bookings: $e');
        return _localBookings;
      }
    }
    return List.unmodifiable(_localBookings);
  }

  static const List<CourtModel> _defaultCourts = [
    CourtModel(
      id: 'a1111111-1111-1111-1111-111111111111',
      name: 'Court 1 - Center Championship',
      status: 'active',
      hourlyRate: 45.0,
      surfaceType: 'Pro-Cushion Hardcourt',
      courtType: 'Championship Indoor',
    ),
    CourtModel(
      id: 'b2222222-2222-2222-2222-222222222222',
      name: 'Court 2 - Neon Arena (LED)',
      status: 'active',
      hourlyRate: 55.0,
      surfaceType: 'Ultra-Fast Acrylic',
      courtType: 'LED Glow Indoor',
    ),
    CourtModel(
      id: 'c3333333-3333-3333-3333-333333333333',
      name: 'Court 3 - Skyline Rooftop',
      status: 'active',
      hourlyRate: 40.0,
      surfaceType: 'All-Weather Surface',
      courtType: 'Rooftop Covered',
    ),
  ];
}
