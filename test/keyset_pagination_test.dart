import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/booking_service.dart';

void main() {
  setUp(() {
    MockData.resetToDefault();
  });

  group('KeysetCursor Unit Tests', () {
    test('KeysetCursor JSON serialization and deserialization roundtrip', () {
      final now = DateTime.utc(2026, 9, 12, 14, 30, 45);
      const id = 'booking-cursor-xyz';
      final cursor = KeysetCursor(createdAt: now, id: id);

      final json = cursor.toJson();
      expect(json['createdAt'], equals(now.toIso8601String()));
      expect(json['id'], equals(id));

      final restored = KeysetCursor.fromJson(json);
      expect(restored.createdAt, equals(now));
      expect(restored.id, equals(id));
      expect(restored, equals(cursor));
      expect(restored.hashCode, equals(cursor.hashCode));
      expect(restored.toString(), contains(id));
    });

    test('KeysetCursor equality handles equivalent moments and IDs', () {
      final dt1 = DateTime.parse('2026-09-12T10:00:00.000Z');
      final dt2 = DateTime.parse('2026-09-12T10:00:00.000Z');
      final cursor1 = KeysetCursor(createdAt: dt1, id: 'cursor-1');
      final cursor2 = KeysetCursor(createdAt: dt2, id: 'cursor-1');
      final cursor3 = KeysetCursor(createdAt: dt1, id: 'cursor-2');

      expect(cursor1 == cursor2, isTrue);
      expect(cursor1.hashCode == cursor2.hashCode, isTrue);
      expect(cursor1 == cursor3, isFalse);
    });

    test('KeysetCursor deserialization rejects malformed input and preserves microsecond precision', () {
      // Malformed / invalid inputs
      expect(() => KeysetCursor.fromJson({'id': 'only-id'}), throwsA(isA<TypeError>()));
      expect(() => KeysetCursor.fromJson({'createdAt': '2026-09-12T10:00:00Z'}), throwsA(isA<TypeError>()));
      expect(
        () => KeysetCursor.fromJson({'createdAt': 'invalid-timestamp', 'id': 'cursor-id'}),
        throwsA(isA<FormatException>()),
      );

      // Microsecond precision preservation
      final microInstant = DateTime.parse('2026-09-12T15:45:30.123456Z');
      final microCursor = KeysetCursor(createdAt: microInstant, id: 'micro-cursor');
      final roundtrip = KeysetCursor.fromJson(microCursor.toJson());
      expect(roundtrip.createdAt.isAtSameMomentAs(microInstant), isTrue);
      expect(roundtrip.id, equals('micro-cursor'));
    });

    test('Explicit null cursor begins pagination from the newest item', () async {
      MockData.clearMockBookings();
      final now = DateTime.utc(2026, 9, 12, 10);
      for (int i = 0; i < 5; i++) {
        MockData.addMockBooking(
          BookingModel(
            id: 'booking-null-test-$i',
            courtId: 'court-1-indoor-cushion',
            userId: 'user-null-cursor',
            startTime: now.add(Duration(days: i + 1)),
            endTime: now.add(Duration(days: i + 1, hours: 1)),
            totalPrice: 200.0,
            status: 'confirmed',
            createdAt: now.add(Duration(hours: i)),
          ),
        );
      }

      final chunk = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-null-cursor',
        pageSize: 2,
      );
      expect(chunk.items.length, equals(2));
      expect(chunk.items.first.id, equals('booking-null-test-4'));
      expect(chunk.hasMore, isTrue);
      expect(chunk.nextCursor, isNotNull);
    });

    test('Cursor pointing past the oldest element returns empty chunk with hasMore=false', () async {
      MockData.clearMockBookings();
      final now = DateTime.utc(2026, 9, 12, 10);
      MockData.addMockBooking(
        BookingModel(
          id: 'booking-single',
          courtId: 'court-1-indoor-cushion',
          userId: 'user-past-oldest',
          startTime: now.add(const Duration(days: 1)),
          endTime: now.add(const Duration(days: 1, hours: 1)),
          totalPrice: 200.0,
          status: 'confirmed',
          createdAt: now,
        ),
      );

      final pastCursor = KeysetCursor(
        createdAt: now.subtract(const Duration(days: 365)),
        id: 'past-id',
      );

      final chunk = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-past-oldest',
        cursor: pastCursor,
      );

      expect(chunk.items, isEmpty);
      expect(chunk.hasMore, isFalse);
      expect(chunk.nextCursor, isNull);
    });

    test('Cursor pointing to non-existent ID at valid timestamp seamlessly resumes', () async {
      MockData.clearMockBookings();
      final now = DateTime.utc(2026, 9, 12, 10);
      final ids = ['item-04', 'item-03', 'item-02', 'item-01'];
      for (final id in ids) {
        MockData.addMockBooking(
          BookingModel(
            id: id,
            courtId: 'court-1-indoor-cushion',
            userId: 'user-missing-cursor',
            startTime: now.add(const Duration(days: 1)),
            endTime: now.add(const Duration(days: 1, hours: 1)),
            totalPrice: 200.0,
            status: 'confirmed',
            createdAt: now,
          ),
        );
      }

      final nonExistentCursor = KeysetCursor(createdAt: now, id: 'item-025');
      final chunk = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-missing-cursor',
        cursor: nonExistentCursor,
      );

      expect(chunk.items.map((b) => b.id).toList(), equals(['item-02', 'item-01']));
      expect(chunk.hasMore, isFalse);
    });
  });

  group('Keyset Pagination Invariant: Zero Duplicates Under Concurrent Writes', () {
    test('Zero duplicate items when new records are prepended during active scrolling', () async {
      MockData.clearMockBookings();

      final baseTime = DateTime.utc(2026, 9, 10, 8);
      const totalInitial = 25;

      // Seed 25 bookings with strictly descending created_at timestamps
      for (int i = 0; i < totalInitial; i++) {
        final itemCreatedAt = baseTime.subtract(Duration(minutes: i * 10));
        MockData.addMockBooking(
          BookingModel(
            id: 'item-${i.toString().padLeft(3, '0')}',
            courtId: 'court-1-indoor-cushion',
            userId: 'user-scroll-tester',
            startTime: DateTime.utc(2026, 9, 15, 8).add(Duration(hours: i)),
            endTime: DateTime.utc(2026, 9, 15, 9).add(Duration(hours: i)),
            totalPrice: 300.0,
            status: 'confirmed',
            createdAt: itemCreatedAt,
            updatedAt: itemCreatedAt,
          ),
        );
      }

      // Step 1: Client loads Page 1 (pageSize = 10)
      final page1 = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-scroll-tester',
      );

      expect(page1.items.length, equals(10));
      expect(page1.hasMore, isTrue);
      expect(page1.nextCursor, isNotNull);
      final page1Ids = page1.items.map((b) => b.id).toSet();
      expect(page1Ids.length, equals(10));

      // Step 2: Concurrent write occurs! 3 brand new records arrive at the top (newer createdAt)
      final writeTime = baseTime.add(const Duration(hours: 1));
      for (int w = 0; w < 3; w++) {
        final newCreatedAt = writeTime.add(Duration(minutes: w * 5));
        MockData.addMockBooking(
          BookingModel(
            id: 'concurrent-write-$w',
            courtId: 'court-1-indoor-cushion',
            userId: 'user-scroll-tester',
            startTime: DateTime.utc(2026, 9, 20, 10).add(Duration(hours: w)),
            endTime: DateTime.utc(2026, 9, 20, 11).add(Duration(hours: w)),
            totalPrice: 300.0,
            status: 'confirmed',
            createdAt: newCreatedAt,
            updatedAt: newCreatedAt,
          ),
        );
      }

      // Step 3: Client loads Page 2 using Page 1's nextCursor
      final page2 = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-scroll-tester',
        cursor: page1.nextCursor,
      );

      expect(page2.items.length, equals(10));
      expect(page2.hasMore, isTrue);
      expect(page2.nextCursor, isNotNull);

      // INVARIANT ASSERTION 1: Intersection between page 1 and page 2 is EMPTY
      final page2Ids = page2.items.map((b) => b.id).toSet();
      final intersection1and2 = page1Ids.intersection(page2Ids);
      expect(
        intersection1and2,
        isEmpty,
        reason: 'Keyset pagination must have 0 duplicates across pages despite concurrent inserts',
      );

      // Step 4: Client loads Page 3 using Page 2's nextCursor
      final page3 = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-scroll-tester',
        cursor: page2.nextCursor,
      );

      expect(page3.items.length, equals(5)); // 25 - 20 = 5 remaining items
      expect(page3.hasMore, isFalse);
      expect(page3.nextCursor, isNull);

      // INVARIANT ASSERTION 2: Total unique items across pages equals exactly 25 original items
      final allScrolledIds = <String>{...page1Ids, ...page2Ids, ...page3.items.map((b) => b.id)};
      expect(allScrolledIds.length, equals(25));
      for (int i = 0; i < totalInitial; i++) {
        expect(allScrolledIds.contains('item-${i.toString().padLeft(3, '0')}'), isTrue);
      }
    });

    test('Tie-breaking by ID works correctly when created_at timestamps are identical', () async {
      MockData.clearMockBookings();

      final sharedTimestamp = DateTime.utc(2026, 9, 12, 12);
      final idSuffixes = ['e', 'd', 'c', 'b', 'a']; // 'item-e', 'item-d', etc.

      for (final suffix in idSuffixes) {
        MockData.addMockBooking(
          BookingModel(
            id: 'item-$suffix',
            courtId: 'court-1-indoor-cushion',
            userId: 'user-tie-break',
            startTime: DateTime.utc(2026, 9, 16, 10),
            endTime: DateTime.utc(2026, 9, 16, 11),
            totalPrice: 300.0,
            status: 'confirmed',
            createdAt: sharedTimestamp,
            updatedAt: sharedTimestamp,
          ),
        );
      }

      // Chunk 1: Page size 2
      final chunk1 = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-tie-break',
        pageSize: 2,
      );
      expect(chunk1.items.map((b) => b.id).toList(), equals(['item-e', 'item-d']));
      expect(chunk1.hasMore, isTrue);

      // Chunk 2: Page size 2 with cursor
      final chunk2 = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-tie-break',
        cursor: chunk1.nextCursor,
        pageSize: 2,
      );
      expect(chunk2.items.map((b) => b.id).toList(), equals(['item-c', 'item-b']));
      expect(chunk2.hasMore, isTrue);

      // Chunk 3: Page size 2 with cursor (final 1 item)
      final chunk3 = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'user-tie-break',
        cursor: chunk2.nextCursor,
        pageSize: 2,
      );
      expect(chunk3.items.map((b) => b.id).toList(), equals(['item-a']));
      expect(chunk3.hasMore, isFalse);
      expect(chunk3.nextCursor, isNull);
    });
  });

  group('Keyset Pagination for Venues and Courts', () {
    test('fetchPaginatedVenues returns deterministic chunks', () async {
      final chunk = await BookingService.instance.fetchPaginatedVenues(pageSize: 1);
      expect(chunk.items.length, equals(1));
      expect(chunk.hasMore, isTrue);
      expect(chunk.nextCursor, isNotNull);

      final nextChunk = await BookingService.instance.fetchPaginatedVenues(
        cursor: chunk.nextCursor,
        pageSize: 5,
      );
      expect(nextChunk.items.length, equals(1));
      expect(nextChunk.hasMore, isFalse);
      expect(nextChunk.nextCursor, isNull);

      expect(chunk.items.first.id, isNot(equals(nextChunk.items.first.id)));
    });

    test('fetchPaginatedCourts respects activeOnly filter and cursor advancement', () async {
      final allCourtsChunk = await BookingService.instance.fetchPaginatedCourts(
        pageSize: 2,
      );

      expect(allCourtsChunk.items.length, equals(2));
      expect(allCourtsChunk.hasMore, isTrue);
      expect(allCourtsChunk.nextCursor, isNotNull);

      final page2 = await BookingService.instance.fetchPaginatedCourts(
        cursor: allCourtsChunk.nextCursor,
      );

      expect(page2.items.length, equals(2));
      expect(page2.hasMore, isFalse);

      final combined = [...allCourtsChunk.items, ...page2.items];
      final uniqueIds = combined.map((c) => c.id).toSet();
      expect(uniqueIds.length, equals(4));
    });

    test('Empty results handle pagination gracefully', () async {
      final chunk = await BookingService.instance.fetchPaginatedCustomerBookings(
        userId: 'non-existent-user-id-999',
      );

      expect(chunk.items, isEmpty);
      expect(chunk.hasMore, isFalse);
      expect(chunk.nextCursor, isNull);
    });
  });
}

