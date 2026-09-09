import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/repositories/booking_repository.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/services/booking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;

  setUp(() {
    repository = SupabaseBookingRepository();
  });

  group('BookingRepository Unit Tests', () {
    test('calculateTotalPrice computes court subtotal, paddle fee and ball thrower fee', () {
      // 1 hour, standard rate, no add-ons
      final total1 = repository.calculateTotalPrice(
        hourlyRate: 300.0,
        durationHours: 1,
        paddleRental: false,
        ballThrowerRental: false,
      );
      expect(total1, 300.0);

      // 2 hours + paddle bundle (+₱150)
      final total2 = repository.calculateTotalPrice(
        hourlyRate: 300.0,
        durationHours: 2,
        paddleRental: true,
        ballThrowerRental: false,
      );
      expect(total2, 600.0 + 150.0); // ₱750

      // 2 hours + paddle bundle (+₱150) + ball thrower (+₱150/hr * 2 = ₱300)
      final total3 = repository.calculateTotalPrice(
        hourlyRate: 300.0,
        durationHours: 2,
        paddleRental: true,
        ballThrowerRental: true,
      );
      expect(total3, 600.0 + 150.0 + 300.0); // ₱1050
    });

    test('Court pricing constants match C&J UI-Context rules', () {
      expect(BookingService.defaultHourlyRate, 300.0);
      expect(BookingService.paddleRentalFee, 150.0);
      expect(BookingService.ballThrowerHourlyFee, 150.0);
    });

    test('CourtModel serialization and helper properties', () {
      const court = CourtModel(
        id: 'court-cushion-1',
        name: 'Court 1 — Indoor (Pro Cushion)',
      );

      expect(court.isIndoor, isTrue);
      expect(court.isOutdoor, isFalse);
      expect(court.isAvailableForBooking, isTrue);
      expect(court.surfaceDescription, 'Pro Cushion Surface');
      expect(court.courtBadge, 'Indoor Championship');

      final json = court.toJson();
      final fromJson = CourtModel.fromJson(json);
      expect(fromJson.id, court.id);
      expect(fromJson.hourlyRate, 300.0);
      expect(fromJson.name, court.name);
    });
  });
}
