import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/services/booking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scheduling and Availability Tests', () {
    test('MockData standard durations are strictly 1-hour whole intervals', () {
      expect(MockData.standardDurations, equals([1.0, 2.0, 3.0, 4.0]));
      for (final duration in MockData.standardDurations) {
        expect(duration % 1.0, equals(0.0));
      }
    });

    test('BookingService checkSlotAvailability detects available and taken slots', () async {
      final bookingService = BookingService.instance;
      bookingService.invalidateAvailabilityCache();

      const courtId = 'test-court-999';
      final testDate = DateTime.now().add(const Duration(days: 10));
      final startTime = DateTime(testDate.year, testDate.month, testDate.day, 10);
      final endTime = startTime.add(const Duration(hours: 1));

      // Slot should initially be available
      final isAvailableBefore = await bookingService.checkSlotAvailability(
        courtId: courtId,
        startTime: startTime,
        endTime: endTime,
      );
      expect(isAvailableBefore, isTrue);

      // Create booking for this slot
      await bookingService.createBooking(
        courtId: courtId,
        startTime: startTime,
        endTime: endTime,
        totalAmount: 120.0,
      );

      // Slot should now NOT be available
      final isAvailableAfter = await bookingService.checkSlotAvailability(
        courtId: courtId,
        startTime: startTime,
        endTime: endTime,
      );
      expect(isAvailableAfter, isFalse);
    });

    test('BookingService throws Exception when trying to book an already booked slot', () async {
      final bookingService = BookingService.instance;
      bookingService.invalidateAvailabilityCache();

      const courtId = 'test-court-888';
      final testDate = DateTime.now().add(const Duration(days: 12));
      final startTime = DateTime(testDate.year, testDate.month, testDate.day, 14);
      final endTime = startTime.add(const Duration(hours: 2));

      // First user books first
      await bookingService.createBooking(
        courtId: courtId,
        startTime: startTime,
        endTime: endTime,
        totalAmount: 240.0,
      );

      // Second user attempts to book the overlapping slot -> Should fail
      expect(
        () async => await bookingService.createBooking(
          courtId: courtId,
          startTime: startTime,
          endTime: endTime,
          totalAmount: 240.0,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Slot No Longer Available'),
          ),
        ),
      );
    });
  });
}
