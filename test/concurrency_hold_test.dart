import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    MockData.resetToDefault();
  });

  group('Postgres GiST 23P01 Concurrency & Slot Hold Tests', () {
    test('createBookingHold creates valid pending_payment hold with expiration window', () async {
      final now = DateTime.now();
      final startTime = now.add(const Duration(days: 3, hours: 2));
      final endTime = startTime.add(const Duration(hours: 1));

      final hold = await BookingService.instance.createBookingHold(
        courtId: 'court-1-indoor-cushion',
        startTime: startTime,
        endTime: endTime,
        totalAmount: 300.0,
        guestName: 'Hold Tester',
        guestEmail: 'hold@pickleball.dev',
      );

      expect(hold.id, startsWith('mock-hold-'));
      expect(hold.status, equals('pending_payment'));
      expect(hold.isPendingPayment, isTrue);
      expect(hold.courtId, equals('court-1-indoor-cushion'));
      expect(hold.totalPrice, equals(300.0));
      expect(hold.expiresAt, isNotNull);
      expect(hold.expiresAt!.isAfter(DateTime.now()), isTrue);
      expect(
        hold.expiresAt!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(8, 11),
      );
    });

    test('Concurrent overlapping hold on same court is rejected with 23P01', () async {
      final now = DateTime.now();
      final startTime1 = now.add(const Duration(days: 4, hours: 14));
      final endTime1 = startTime1.add(const Duration(hours: 2)); // 14:00 - 16:00

      // First hold succeeds
      final firstHold = await BookingService.instance.createBookingHold(
        courtId: 'court-2-indoor-tour',
        startTime: startTime1,
        endTime: endTime1,
        totalAmount: 700.0,
        guestName: 'Player One',
      );
      expect(firstHold.status, equals('pending_payment'));

      // Second overlapping hold (15:00 - 17:00) must be rejected with 23P01
      final startTime2 = startTime1.add(const Duration(hours: 1)); // 15:00
      final endTime2 = startTime2.add(const Duration(hours: 2)); // 17:00

      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-2-indoor-tour',
          startTime: startTime2,
          endTime: endTime2,
          totalAmount: 700.0,
          guestName: 'Player Two',
        ),
        throwsA(
          predicate((e) =>
              e is PostgrestException &&
              e.code == '23P01' &&
              e.message.contains('Slot is no longer available')),
        ),
      );
    });

    test('Non-overlapping back-to-back slots succeed without conflict', () async {
      final now = DateTime.now();
      final start1 = now.add(const Duration(days: 5, hours: 9));
      final end1 = start1.add(const Duration(hours: 1)); // 09:00 - 10:00
      final start2 = end1; // 10:00
      final end2 = start2.add(const Duration(hours: 1)); // 10:00 - 11:00

      final hold1 = await BookingService.instance.createBookingHold(
        courtId: 'court-3-outdoor-lighted',
        startTime: start1,
        endTime: end1,
        totalAmount: 280.0,
      );
      expect(hold1.status, equals('pending_payment'));

      final hold2 = await BookingService.instance.createBookingHold(
        courtId: 'court-3-outdoor-lighted',
        startTime: start2,
        endTime: end2,
        totalAmount: 280.0,
      );
      expect(hold2.status, equals('pending_payment'));

      // Left-adjacent [t0, start1) where end == start1 succeeds
      final start0 = start1.subtract(const Duration(hours: 1));
      final hold0 = await BookingService.instance.createBookingHold(
        courtId: 'court-3-outdoor-lighted',
        startTime: start0,
        endTime: start1,
        totalAmount: 280.0,
      );
      expect(hold0.status, equals('pending_payment'));
    });

    test('Boundary collision by even 1 millisecond throws 23P01', () async {
      final now = DateTime.now();
      final t1 = now.add(const Duration(days: 8, hours: 14));
      final t2 = t1.add(const Duration(hours: 2)); // 14:00 - 16:00

      await BookingService.instance.createBookingHold(
        courtId: 'court-2-indoor-tour',
        startTime: t1,
        endTime: t2,
        totalAmount: 700.0,
      );

      // Micro-overlap at start: 13:00 to 14:00:00.001 (1ms overlap with t1)
      final microOverlapStart = t1.subtract(const Duration(hours: 1));
      final microOverlapEnd = t1.add(const Duration(milliseconds: 1));

      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-2-indoor-tour',
          startTime: microOverlapStart,
          endTime: microOverlapEnd,
          totalAmount: 350.0,
        ),
        throwsA(
          predicate((e) =>
              e is PostgrestException &&
              e.code == '23P01' &&
              e.message.contains('Slot is no longer available')),
        ),
      );

      // Micro-overlap at end: 15:59:59.999 to 17:00 (1ms overlap before t2)
      final microEndStart = t2.subtract(const Duration(milliseconds: 1));
      final microEndEnd = t2.add(const Duration(hours: 1));

      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-2-indoor-tour',
          startTime: microEndStart,
          endTime: microEndEnd,
          totalAmount: 350.0,
        ),
        throwsA(
          predicate((e) =>
              e is PostgrestException &&
              e.code == '23P01' &&
              e.message.contains('Slot is no longer available')),
        ),
      );
    });

    test('Subset and superset intervals strictly rejected with 23P01', () async {
      final now = DateTime.now();
      final baseStart = now.add(const Duration(days: 9, hours: 10));
      final baseEnd = baseStart.add(const Duration(hours: 4)); // 10:00 - 14:00

      await BookingService.instance.createBookingHold(
        courtId: 'court-3-outdoor-lighted',
        startTime: baseStart,
        endTime: baseEnd,
        totalAmount: 1120.0,
      );

      // Superset: 09:00 - 15:00
      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-3-outdoor-lighted',
          startTime: baseStart.subtract(const Duration(hours: 1)),
          endTime: baseEnd.add(const Duration(hours: 1)),
          totalAmount: 1680.0,
        ),
        throwsA(predicate((e) => e is PostgrestException && e.code == '23P01')),
      );

      // Strict subset: 11:00 - 13:00
      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-3-outdoor-lighted',
          startTime: baseStart.add(const Duration(hours: 1)),
          endTime: baseEnd.subtract(const Duration(hours: 1)),
          totalAmount: 560.0,
        ),
        throwsA(predicate((e) => e is PostgrestException && e.code == '23P01')),
      );
    });

    test('Cancelled refund pending status allows slot re-reservation', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final slotStart = now.add(const Duration(days: 10, hours: 16));
      final slotEnd = slotStart.add(const Duration(hours: 1));

      // Add a booking with status 'cancelled_refund_pending'
      MockData.addMockBooking(
        BookingModel(
          id: 'refund-pending-slot',
          courtId: 'court-1-indoor-cushion',
          startTime: slotStart,
          endTime: slotEnd,
          totalPrice: 300.0,
          status: 'cancelled_refund_pending',
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
      );

      // Subsequent player can hold this exact slot because cancelled_refund_pending is excluded
      final newHold = await BookingService.instance.createBookingHold(
        courtId: 'court-1-indoor-cushion',
        startTime: slotStart,
        endTime: slotEnd,
        totalAmount: 300.0,
      );

      expect(newHold.status, equals('pending_payment'));
    });

    test('Simultaneous reservations for same time on DIFFERENT courts succeed', () async {
      final now = DateTime.now();
      final startTime = now.add(const Duration(days: 6, hours: 10));
      final endTime = startTime.add(const Duration(hours: 1));

      final holdCourt1 = await BookingService.instance.createBookingHold(
        courtId: 'court-1-indoor-cushion',
        startTime: startTime,
        endTime: endTime,
        totalAmount: 300.0,
      );
      final holdCourt2 = await BookingService.instance.createBookingHold(
        courtId: 'court-2-indoor-tour',
        startTime: startTime,
        endTime: endTime,
        totalAmount: 350.0,
      );

      expect(holdCourt1.status, equals('pending_payment'));
      expect(holdCourt2.status, equals('pending_payment'));
      expect(holdCourt1.courtId, isNot(equals(holdCourt2.courtId)));
    });

    test('Lazy expiration sweeps dangling holds and allows slot to be booked', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetSlotStart = now.add(const Duration(days: 2, hours: 16));
      final targetSlotEnd = targetSlotStart.add(const Duration(hours: 1));

      // Inject an expired hold (expires_at is 15 minutes in the past)
      final expiredHold = BookingModel(
        id: 'expired-hold-abc',
        courtId: 'court-1-indoor-cushion',
        startTime: targetSlotStart,
        endTime: targetSlotEnd,
        totalPrice: 300.0,
        expiresAt: now.subtract(const Duration(minutes: 15)),
        createdAt: now.subtract(const Duration(minutes: 30)),
      );
      MockData.addMockBooking(expiredHold);

      // Verify the slot is currently occupied by the expired hold
      final existing = MockData.mockBookings.firstWhere((b) => b.id == 'expired-hold-abc');
      expect(existing.status, equals('pending_payment'));

      // New player attempts to hold the same slot
      final newHold = await BookingService.instance.createBookingHold(
        courtId: 'court-1-indoor-cushion',
        startTime: targetSlotStart,
        endTime: targetSlotEnd,
        totalAmount: 300.0,
        guestName: 'New Challenger',
      );

      expect(newHold.status, equals('pending_payment'));
      expect(newHold.id, isNot(equals('expired-hold-abc')));

      // Confirm the old hold was lazily transitioned to 'expired'
      final sweptOldHold = MockData.mockBookings.firstWhere((b) => b.id == 'expired-hold-abc');
      expect(sweptOldHold.status, equals('expired'));
    });

    test('Cancelled booking does not block subsequent slot reservation', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final start = now.add(const Duration(days: 3, hours: 11));
      final end = start.add(const Duration(hours: 1));

      // Inject cancelled booking
      final cancelledBooking = BookingModel(
        id: 'cancelled-bk-xyz',
        courtId: 'court-4-outdoor-acrylic',
        startTime: start,
        endTime: end,
        totalPrice: 320.0,
        status: 'cancelled',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      MockData.addMockBooking(cancelledBooking);

      // Subsequent hold on exact same slot succeeds because cancelled slots are excluded
      final hold = await BookingService.instance.createBookingHold(
        courtId: 'court-4-outdoor-acrylic',
        startTime: start,
        endTime: end,
        totalAmount: 320.0,
      );

      expect(hold.status, equals('pending_payment'));
    });

    test('Active confirmed booking rejects hold attempt with 23P01', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final start = now.add(const Duration(days: 7, hours: 8));
      final end = start.add(const Duration(hours: 1));

      final confirmed = BookingModel(
        id: 'confirmed-bk-123',
        courtId: 'court-1-indoor-cushion',
        startTime: start,
        endTime: end,
        totalPrice: 300.0,
        status: 'confirmed',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      MockData.addMockBooking(confirmed);

      // Attempting to hold overlapping interval fails with 23P01
      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-1-indoor-cushion',
          startTime: start,
          endTime: end,
          totalAmount: 300.0,
        ),
        throwsA(
          predicate((e) => e is PostgrestException && e.code == '23P01'),
        ),
      );
    });

    test('Input parameter validation guards', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(days: 1, hours: 10));
      final end = start.add(const Duration(hours: 1));

      // Empty courtId
      expect(
        () => BookingService.instance.createBookingHold(
          courtId: '   ',
          startTime: start,
          endTime: end,
          totalAmount: 300.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // startTime >= endTime
      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-1-indoor-cushion',
          startTime: end,
          endTime: start,
          totalAmount: 300.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative amount
      expect(
        () => BookingService.instance.createBookingHold(
          courtId: 'court-1-indoor-cushion',
          startTime: start,
          endTime: end,
          totalAmount: -50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
