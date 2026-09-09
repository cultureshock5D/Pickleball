import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/constants/supabase_config.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/booking_refund_model.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/models/user_profile.dart';

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
        'name': 'Court 1',
        'type': 'indoor',
        'status': 'active',
        'hourly_rate': 300.0,
        'is_active': true,
      };

      final court = CourtModel.fromJson(courtJson);
      expect(court.id, equals('court-101'));
      expect(court.name, equals('Court 1'));
      expect(court.type, equals('indoor'));
      expect(court.hourlyRate, equals(300.0));
      expect(court.isActive, isTrue);

      final serialized = court.toJson();
      expect(serialized['id'], equals('court-101'));
      expect(serialized['name'], equals('Court 1'));
      expect(serialized['status'], equals('active'));
      expect(serialized['hourly_rate'], equals(300.0));
    });

    test('BookingModel fromJson and toJson work correctly', () {
      final now = DateTime.now().toUtc();
      final bookingJson = {
        'id': 'BK-999',
        'user_id': 'user-123',
        'court_id': 'court-1',
        'start_time': now.toIso8601String(),
        'end_time': now.add(const Duration(hours: 1)).toIso8601String(),
        'duration_hours': 1,
        'total_price': 300.0,
        'status': 'pending',
        'guest_name': 'Taylor Swift',
        'guest_email': 'taylor@example.com',
        'guest_phone': '09123456789',
        'created_at': now.toIso8601String(),
        'courts': {'name': 'Court 1', 'type': 'indoor'},
      };

      final booking = BookingModel.fromJson(bookingJson);
      expect(booking.id, equals('BK-999'));
      expect(booking.userId, equals('user-123'));
      expect(booking.courtName, equals('Court 1'));
      expect(booking.totalAmount, equals(300.0));
      expect(booking.guestName, equals('Taylor Swift'));

      final serialized = booking.toJson();
      expect(serialized['user_id'], equals('user-123'));
      expect(serialized['court_id'], equals('court-1'));
      expect(serialized['status'], equals('pending'));
      expect(serialized['total_price'], equals(300.0));
    });

    test('BookingRefundModel fromJson and toJson work correctly', () {
      final now = DateTime.now().toUtc();
      final refundJson = {
        'id': 'ref-001',
        'booking_id': 'BK-999',
        'user_id': 'user-123',
        'amount': 300.0,
        'wallet_type': 'gcash',
        'account_name': 'Taylor Swift',
        'account_number': '09123456789',
        'reason': 'Change of schedule',
        'status': 'pending',
        'created_at': now.toIso8601String(),
      };

      final refund = BookingRefundModel.fromJson(refundJson);
      expect(refund.id, equals('ref-001'));
      expect(refund.bookingId, equals('BK-999'));
      expect(refund.walletType, equals('gcash'));
      expect(refund.amount, equals(300.0));
      expect(refund.accountName, equals('Taylor Swift'));

      final serialized = refund.toJson();
      expect(serialized['booking_id'], equals('BK-999'));
      expect(serialized['wallet_type'], equals('gcash'));
      expect(serialized['amount'], equals(300.0));
    });

    test('UserProfile model fromJson and copyWith work correctly', () {
      final userJson = {
        'id': 'usr-001',
        'full_name': 'Taylor Swift',
        'role': 'client',
        'created_at': DateTime.now().toIso8601String(),
      };

      final profile = UserProfile.fromJson(userJson);
      expect(profile.id, equals('usr-001'));
      expect(profile.fullName, equals('Taylor Swift'));
      expect(profile.role, equals('client'));

      final updated = profile.copyWith(fullName: 'Taylor Alison Swift');
      expect(updated.fullName, equals('Taylor Alison Swift'));
      expect(updated.id, equals('usr-001'));
    });
  });
}

