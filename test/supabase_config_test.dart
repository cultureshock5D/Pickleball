import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/constants/supabase_config.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/models/user_profile.dart';
import 'package:pickleball_app/services/auth_service.dart';
import 'package:pickleball_app/services/booking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseConfig Tests', () {
    test('Supabase URL getter returns string', () {
      expect(SupabaseConfig.url, isA<String>());
    });

    test('Supabase anon key getter returns string', () {
      expect(SupabaseConfig.anonKey, isA<String>());
    });

    test('Supabase isConfigured returns boolean status', () {
      expect(SupabaseConfig.isConfigured, isA<bool>());
    });
  });

  group('Model Serialization Tests', () {
    test('CourtModel fromJson and toJson work correctly', () {
      final courtJson = {
        'id': 'court-101',
        'name': 'Court 1 - Center Championship',
        'status': 'active',
        'hourly_rate': 45.0,
        'surface_type': 'Pro-Cushion Hardcourt',
        'court_type': 'Championship Indoor',
      };

      final court = CourtModel.fromJson(courtJson);
      expect(court.id, equals('court-101'));
      expect(court.name, equals('Court 1 - Center Championship'));
      expect(court.hourlyRate, equals(45.0));

      final serialized = court.toJson();
      expect(serialized['id'], equals('court-101'));
      expect(serialized['name'], equals('Court 1 - Center Championship'));
      expect(serialized['status'], equals('active'));
    });

    test('BookingModel fromJson and toJson work correctly', () {
      final now = DateTime.now().toUtc();
      final bookingJson = {
        'id': 'BK-999',
        'customer_id': 'user-123',
        'court_id': 'court-1',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(hours: 1)).toIso8601String(),
        'status': 'pending',
        'total_amount': 67.5,
        'created_at': now.toIso8601String(),
        'courts': {'name': 'Center Championship'},
      };

      final booking = BookingModel.fromJson(bookingJson);
      expect(booking.id, equals('BK-999'));
      expect(booking.courtName, equals('Center Championship'));
      expect(booking.totalAmount, equals(67.5));

      final serialized = booking.toJson();
      expect(serialized['customer_id'], equals('user-123'));
      expect(serialized['court_id'], equals('court-1'));
      expect(serialized['status'], equals('pending'));
      expect(serialized['total_amount'], equals(67.5));
    });

    test('UserProfile model fromJson and copyWith work correctly', () {
      final userJson = {
        'id': 'usr-001',
        'full_name': 'Taylor Swift',
        'role': 'customer',
        'created_at': DateTime.now().toIso8601String(),
      };

      final profile = UserProfile.fromJson(userJson);
      expect(profile.id, equals('usr-001'));
      expect(profile.fullName, equals('Taylor Swift'));
      expect(profile.role, equals('customer'));

      final updated = profile.copyWith(fullName: 'Taylor Alison Swift');
      expect(updated.fullName, equals('Taylor Alison Swift'));
      expect(updated.id, equals('usr-001'));
    });
  });

  group('Service Layer Tests', () {
    test('AuthService demo login flow functions smoothly', () async {
      final authService = AuthService.instance;
      expect(authService, isNotNull);

      // Sign in with demo credentials
      final res = await authService.signIn(
        email: 'customer@pickleball.com',
        password: 'password123',
      );
      expect(res, isNotNull);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.email, equals('customer@pickleball.com'));

      // Sign out
      await authService.signOut();
      expect(authService.isAuthenticated, isFalse);
    });

    test('BookingService fetches active courts list', () async {
      final bookingService = BookingService.instance;
      final courts = await bookingService.fetchActiveCourts();
      expect(courts, isNotEmpty);
      expect(courts.length, greaterThanOrEqualTo(1));
      expect(courts.first.name, equals('SmashCourt - Court 1'));
    });

    test('Legitimate user with zero bookings receives empty list rather than demo data', () async {
      final bookingService = BookingService.instance;
      final authService = AuthService.instance;
      
      // Ensure we are not logged in as demo guest
      await authService.signOut();
      expect(authService.isDemoMode, isFalse);

      final bookings = await bookingService.fetchCustomerBookings();
      expect(bookings, isEmpty);
    });
  });
}
