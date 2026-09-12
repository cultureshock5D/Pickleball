// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/network/network_resilience.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/data/repositories/booking_repository.dart';
import 'package:pickleball_app/models/booking_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockData.resetToDefault();
  });

  group('Challenger Empirical Verification 1: Keyset 0-Duplicate Pagination Over 100+ Items', () {
    late MockBookingRepository repository;

    setUp(() {
      repository = MockBookingRepository();
    });

    test('Keyset traversal over 150 synthetic items with prime pageSize produces 0 duplicates', () async {
      const totalItems = 150;
      const pageSize = 17; // prime number to stress chunk boundary alignment

      final generated = repository.generateMockBookings(totalItems);
      expect(generated.length, totalItems);

      final encounteredIds = <String>{};
      final encounteredRecords = <BookingModel>[];
      KeysetCursor? cursor;
      int chunkCount = 0;
      bool hasMore = true;

      while (hasMore) {
        final chunk = await repository.fetchPaginatedCustomerBookings(
          cursor: cursor,
          pageSize: pageSize,
        );
        chunkCount++;

        expect(chunk.items.length, lessThanOrEqualTo(pageSize));

        for (final item in chunk.items) {
          final isUnique = encounteredIds.add(item.id);
          expect(isUnique, isTrue, reason: 'Duplicate record encountered in keyset pagination: ${item.id}');
          encounteredRecords.add(item);
        }

        hasMore = chunk.hasMore;
        cursor = chunk.nextCursor;

        if (hasMore) {
          expect(cursor, isNotNull, reason: 'nextCursor must not be null when hasMore is true');
          expect(cursor!.id, equals(chunk.items.last.id));
        } else {
          expect(cursor, isNull, reason: 'nextCursor must be null when hasMore is false');
        }

        if (chunkCount > 30) {
          fail('Keyset pagination infinite loop detected: exceeded 30 chunk iterations');
        }
      }

      // Verify that all 150 generated items were visited
      for (final gen in generated) {
        expect(encounteredIds.contains(gen.id), isTrue,
            reason: 'Generated item was skipped during keyset pagination: ${gen.id}');
      }

      // Verify strict descending order: created_at DESC, then id DESC
      for (int i = 0; i < encounteredRecords.length - 1; i++) {
        final current = encounteredRecords[i];
        final next = encounteredRecords[i + 1];

        final currentDate = current.createdAt ?? current.startTime;
        final nextDate = next.createdAt ?? next.startTime;

        if (currentDate.isAtSameMomentAs(nextDate)) {
          expect(current.id.compareTo(next.id), greaterThan(0),
              reason: 'Tie-breaker failed: ${current.id} should be > ${next.id} for identical timestamps');
        } else {
          expect(currentDate.isAfter(nextDate), isTrue,
              reason: 'Timestamp order violation: $currentDate should be after $nextDate');
        }
      }
    });

    test('Tie-breaker stress: 30 records with identical microsecond created_at sort strictly by id DESC', () async {
      repository.clearGeneratedBookings();
      MockData.clearMockBookings();

      final sharedInstant = DateTime.utc(2026, 9, 12, 14, 0, 0, 123456);
      final rawIds = List.generate(30, (i) => 'mock-tie-${(i + 1).toString().padLeft(3, '0')}');

      // Shuffle raw IDs to ensure insertion order does not accidentally provide sorting
      final shuffledIds = List<String>.from(rawIds)..shuffle(Random(123));

      for (final id in shuffledIds) {
        MockData.addMockBooking(
          BookingModel(
            id: id,
            courtId: 'court-1-indoor-cushion',
            userId: 'tie-user',
            startTime: DateTime.utc(2026, 9, 15, 10),
            endTime: DateTime.utc(2026, 9, 15, 11),
            totalPrice: 300.0,
            status: 'confirmed',
            createdAt: sharedInstant,
          ),
        );
      }

      final collectedIds = <String>[];
      KeysetCursor? cursor;
      bool hasMore = true;

      while (hasMore) {
        final chunk = await repository.fetchPaginatedCustomerBookings(
          userId: 'tie-user',
          cursor: cursor,
          pageSize: 7,
        );
        for (final item in chunk.items) {
          collectedIds.add(item.id);
        }
        hasMore = chunk.hasMore;
        cursor = chunk.nextCursor;
      }

      expect(collectedIds.length, 30);
      final expectedSortedIds = List<String>.from(rawIds)..sort((a, b) => b.compareTo(a));
      expect(collectedIds, equals(expectedSortedIds),
          reason: 'Tie-breaker must sort deterministically by id DESC across chunk boundaries');
    });

    test('Zero duplicate invariant when new records arrive concurrently during pagination', () async {
      repository.clearGeneratedBookings();
      MockData.clearMockBookings();

      final baseTime = DateTime.utc(2026, 9, 10, 12);
      for (int i = 0; i < 40; i++) {
        final createdAt = baseTime.subtract(Duration(hours: i));
        MockData.addMockBooking(
          BookingModel(
            id: 'orig-${i.toString().padLeft(3, '0')}',
            courtId: 'court-1-indoor-cushion',
            userId: 'concurrent-user',
            startTime: DateTime.utc(2026, 9, 20, 10),
            endTime: DateTime.utc(2026, 9, 20, 11),
            totalPrice: 300.0,
            status: 'confirmed',
            createdAt: createdAt,
          ),
        );
      }

      // Fetch Chunk 1 (15 items)
      final chunk1 = await repository.fetchPaginatedCustomerBookings(
        userId: 'concurrent-user',
        pageSize: 15,
      );
      expect(chunk1.items.length, 15);
      final chunk1Ids = chunk1.items.map((b) => b.id).toSet();

      // Concurrent event: 5 newer records inserted at the head
      final newerTime = baseTime.add(const Duration(hours: 5));
      for (int n = 0; n < 5; n++) {
        MockData.addMockBooking(
          BookingModel(
            id: 'newly-inserted-$n',
            courtId: 'court-1-indoor-cushion',
            userId: 'concurrent-user',
            startTime: DateTime.utc(2026, 9, 25, 10),
            endTime: DateTime.utc(2026, 9, 25, 11),
            totalPrice: 300.0,
            status: 'confirmed',
            createdAt: newerTime.add(Duration(minutes: n)),
          ),
        );
      }

      // Fetch Chunk 2 using chunk 1 cursor
      final chunk2 = await repository.fetchPaginatedCustomerBookings(
        userId: 'concurrent-user',
        cursor: chunk1.nextCursor,
        pageSize: 15,
      );

      final chunk2Ids = chunk2.items.map((b) => b.id).toSet();

      // Verify no overlap between chunk 1 and chunk 2
      expect(chunk1Ids.intersection(chunk2Ids), isEmpty,
          reason: 'Concurrent writes at head must not cause duplicate items across pagination chunks');
    });
  });

  group('Challenger Empirical Verification 2: NetworkResilience 8s Clamped Ceiling & Backoff', () {
    test('executeWithRetry clamps explicit timeout ceiling to clampedTimeout (8s)', () async {
      expect(NetworkResilience.clampedTimeout, equals(const Duration(seconds: 8)));

      // If caller passes a timeout > 8s, effective timeout must be clamped to 8s
      final sw = Stopwatch()..start();
      try {
        await NetworkResilience.executeWithRetry(
          action: () async {
            await Future.delayed(const Duration(seconds: 10));
            return 'should_never_complete';
          },
          timeout: const Duration(seconds: 60), // Exceeds 8s clamp ceiling!
          maxRetries: 0,
        );
        fail('Should have timed out at 8s clamp ceiling');
      } on TimeoutException {
        sw.stop();
        // Clamped at 8s, must abort between 7.5s and 9.5s, NOT 60s
        expect(sw.elapsedMilliseconds, lessThan(10000));
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(7500));
      }
    });

    test('Smaller timeout values (< 8s) are respected without expansion', () async {
      final sw = Stopwatch()..start();
      try {
        await NetworkResilience.executeWithRetry(
          action: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            return 'ok';
          },
          timeout: const Duration(milliseconds: 50),
          maxRetries: 0,
        );
        fail('Should have timed out at 50ms');
      } on TimeoutException {
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(400));
      }
    });

    test('Jittered exponential backoff retries transient failures with non-negative delays', () async {
      int attempts = 0;
      final retryDelays = <Duration>[];

      await expectLater(
        () => NetworkResilience.executeWithRetry(
          action: () async {
            attempts++;
            throw const SocketException('Transient gateway error');
          },
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 80),
          maxRetries: 3,
          onRetry: (attempt, error, delay) {
            retryDelays.add(delay);
          },
        ),
        throwsA(isA<SocketException>()),
      );

      // Verify attempts: 1 initial + 3 retries = 4
      expect(attempts, 4);
      expect(retryDelays.length, 3);

      for (final delay in retryDelays) {
        expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
        expect(delay.inMilliseconds, lessThanOrEqualTo(80));
      }
    });

    test('Non-transient errors terminate immediately on attempt 1 without retry', () async {
      int attempts = 0;

      await expectLater(
        () => NetworkResilience.executeWithRetry(
          action: () async {
            attempts++;
            throw const FormatException('Corrupt JSON payload');
          },
          maxRetries: 3,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(attempts, 1, reason: 'Non-transient errors must fail immediately');
    });
  });

  group('Challenger Empirical Verification 3: Slot Availability Interval Overlap Logic [start, end)', () {
    late MockBookingRepository repository;

    setUp(() {
      repository = MockBookingRepository();
      MockData.clearMockBookings();
      repository.clearGeneratedBookings();
    });

    test('Half-open interval overlap: rejects [start, end) collisions and permits adjacent intervals', () async {
      const courtId = 'court-overlap-test';
      final base = DateTime.utc(2026, 9, 20, 14, 0); // 14:00
      final baseEnd = DateTime.utc(2026, 9, 20, 16, 0); // 16:00

      // Seed an active booking for [14:00, 16:00)
      MockData.addMockBooking(
        BookingModel(
          id: 'existing-booking-1',
          courtId: courtId,
          startTime: base,
          endTime: baseEnd,
          totalPrice: 600.0,
          status: 'confirmed',
          createdAt: DateTime.utc(2026, 9, 10),
        ),
      );

      // --- Overlap scenarios (must return false: unavailable) ---

      // 1. Exact match [14:00, 16:00)
      final exactOverlap = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: base,
        endTime: baseEnd,
      );
      expect(exactOverlap, isFalse, reason: 'Exact matching interval must be rejected');

      // 2. Strict sub-interval [14:30, 15:30)
      final subIntervalOverlap = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: base.add(const Duration(minutes: 30)),
        endTime: baseEnd.subtract(const Duration(minutes: 30)),
      );
      expect(subIntervalOverlap, isFalse, reason: 'Interior sub-interval must be rejected');

      // 3. Strict super-interval [13:00, 17:00)
      final superIntervalOverlap = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: base.subtract(const Duration(hours: 1)),
        endTime: baseEnd.add(const Duration(hours: 1)),
      );
      expect(superIntervalOverlap, isFalse, reason: 'Encompassing super-interval must be rejected');

      // 4. Overlapping start [13:30, 14:30)
      final leftOverlap = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: base.subtract(const Duration(minutes: 30)),
        endTime: base.add(const Duration(minutes: 30)),
      );
      expect(leftOverlap, isFalse, reason: 'Left-overlapping interval must be rejected');

      // 5. Overlapping end [15:30, 16:30)
      final rightOverlap = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: baseEnd.subtract(const Duration(minutes: 30)),
        endTime: baseEnd.add(const Duration(minutes: 30)),
      );
      expect(rightOverlap, isFalse, reason: 'Right-overlapping interval must be rejected');

      // --- Adjacent non-overlapping scenarios (must return true: available) ---

      // 6. Left-adjacent [12:00, 14:00) where candidate end == existing start
      final leftAdjacent = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: base.subtract(const Duration(hours: 2)),
        endTime: base,
      );
      expect(leftAdjacent, isTrue,
          reason: 'Left-adjacent interval [12:00, 14:00) sharing endpoint 14:00 must be permitted');

      // 7. Right-adjacent [16:00, 18:00) where candidate start == existing end
      final rightAdjacent = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: baseEnd,
        endTime: baseEnd.add(const Duration(hours: 2)),
      );
      expect(rightAdjacent, isTrue,
          reason: 'Right-adjacent interval [16:00, 18:00) sharing endpoint 16:00 must be permitted');
    });

    test('Slot availability honors booking statuses (cancelled allows, active blocks)', () async {
      const courtId = 'court-status-test';
      final slotStart = DateTime.utc(2026, 9, 21, 10, 0);
      final slotEnd = DateTime.utc(2026, 9, 21, 12, 0);

      // Cancelled booking should NOT block the slot
      MockData.addMockBooking(
        BookingModel(
          id: 'booking-cancelled',
          courtId: courtId,
          startTime: slotStart,
          endTime: slotEnd,
          totalPrice: 600.0,
          status: 'cancelled',
          createdAt: DateTime.utc(2026, 9, 10),
        ),
      );

      final availableAfterCancel = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: slotStart,
        endTime: slotEnd,
      );
      expect(availableAfterCancel, isTrue, reason: 'Cancelled booking must not block slot');

      // Cancelled refund pending should NOT block the slot
      MockData.clearMockBookings();
      MockData.addMockBooking(
        BookingModel(
          id: 'booking-refund-pending',
          courtId: courtId,
          startTime: slotStart,
          endTime: slotEnd,
          totalPrice: 600.0,
          status: 'cancelled_refund_pending',
          createdAt: DateTime.utc(2026, 9, 10),
        ),
      );

      final availableAfterRefund = await repository.checkSlotAvailability(
        courtId: courtId,
        startTime: slotStart,
        endTime: slotEnd,
      );
      expect(availableAfterRefund, isTrue, reason: 'cancelled_refund_pending booking must not block slot');

      // Each active status MUST block the slot
      for (final activeStatus in ['confirmed', 'pending', 'paid', 'pending_payment']) {
        MockData.clearMockBookings();
        MockData.addMockBooking(
          BookingModel(
            id: 'booking-$activeStatus',
            courtId: courtId,
            startTime: slotStart,
            endTime: slotEnd,
            totalPrice: 600.0,
            status: activeStatus,
            createdAt: DateTime.utc(2026, 9, 10),
          ),
        );

        final availableActive = await repository.checkSlotAvailability(
          courtId: courtId,
          startTime: slotStart,
          endTime: slotEnd,
        );
        expect(availableActive, isFalse,
            reason: 'Booking with status $activeStatus must block slot availability');
      }
    });

    test('Conflict detection checks synthetically generated bookings in MockBookingRepository', () async {
      // Generate deterministic bookings in repository
      final generated = repository.generateMockBookings(20);
      final sample = generated.first;

      // Overlapping slot with the generated booking on the same court
      final isAvailableOverlap = await repository.checkSlotAvailability(
        courtId: sample.courtId,
        startTime: sample.startTime,
        endTime: sample.endTime,
      );

      // If sample status is confirmed/pending/etc., it must NOT be available
      if (sample.status == 'confirmed' ||
          sample.status == 'pending' ||
          sample.status == 'paid' ||
          sample.status == 'pending_payment') {
        expect(isAvailableOverlap, isFalse,
            reason: 'Synthetic booking with status ${sample.status} must block slot availability');
      }

      // Non-overlapping slot far in the future on the same court must be available
      final farFuture = DateTime.now().add(const Duration(days: 365));
      final isAvailableFree = await repository.checkSlotAvailability(
        courtId: sample.courtId,
        startTime: farFuture,
        endTime: farFuture.add(const Duration(hours: 1)),
      );
      expect(isAvailableFree, isTrue,
          reason: 'Far future slot without any bookings must be available');
    });
  });
}
