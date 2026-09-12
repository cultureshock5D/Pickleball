import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/paymongo_webhook_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockData.resetToDefault();
    BookingService.instance.invalidateAvailabilityCache();
  });

  tearDown(() {
    BookingService.instance.disposeRealtimeSubscription();
  });

  group('BookingRealtimeEventType & BookingRealtimeEvent Contracts', () {
    test('BookingRealtimeEventType contains inserted, updated, and deleted', () {
      expect(BookingRealtimeEventType.values, hasLength(3));
      expect(
        BookingRealtimeEventType.values,
        containsAll([
          BookingRealtimeEventType.inserted,
          BookingRealtimeEventType.updated,
          BookingRealtimeEventType.deleted,
        ]),
      );
    });

    test('BookingRealtimeEvent auto-derives courtId and startTime from booking', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'bk-event-test-01',
        courtId: 'court-1-indoor-cushion',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        totalPrice: 300.0,
      );

      final event = BookingRealtimeEvent(
        type: BookingRealtimeEventType.inserted,
        booking: booking,
      );

      expect(event.type, equals(BookingRealtimeEventType.inserted));
      expect(event.booking, equals(booking));
      expect(event.courtId, equals('court-1-indoor-cushion'));
      expect(event.startTime, equals(now));
    });

    test('BookingRealtimeEvent allows overriding courtId and startTime', () {
      final baseTime = DateTime(2026, 9, 11, 10);
      final overrideTime = DateTime(2026, 9, 11, 14);
      final booking = BookingModel(
        id: 'bk-event-test-02',
        courtId: 'court-1-indoor-cushion',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 1)),
        totalPrice: 300.0,
      );

      final event = BookingRealtimeEvent(
        type: BookingRealtimeEventType.updated,
        booking: booking,
        courtId: 'court-2-indoor-tour',
        startTime: overrideTime,
      );

      expect(event.type, equals(BookingRealtimeEventType.updated));
      expect(event.booking, equals(booking));
      expect(event.courtId, equals('court-2-indoor-tour'));
      expect(event.startTime, equals(overrideTime));
    });

    test('BookingRealtimeEvent instantiates cleanly without a BookingModel', () {
      final eventTime = DateTime(2026, 9, 12, 9);
      final event = BookingRealtimeEvent(
        type: BookingRealtimeEventType.deleted,
        courtId: 'court-3-outdoor-lighted',
        startTime: eventTime,
      );

      expect(event.type, equals(BookingRealtimeEventType.deleted));
      expect(event.booking, isNull);
      expect(event.courtId, equals('court-3-outdoor-lighted'));
      expect(event.startTime, equals(eventTime));
    });

    test('BookingRealtimeEvent toString includes event metadata', () {
      final time = DateTime(2026, 9, 15, 16);
      final event = BookingRealtimeEvent(
        type: BookingRealtimeEventType.inserted,
        courtId: 'court-4-outdoor-acrylic',
        startTime: time,
      );

      final str = event.toString();
      expect(str, contains('BookingRealtimeEvent'));
      expect(str, contains('inserted'));
      expect(str, contains('court-4-outdoor-acrylic'));
      expect(str, contains(time.toString()));
    });
  });

  group('BookingService Realtime Subscription & Stream Lifecycle', () {
    test('initRealtimeSubscription executes safely when Supabase is unconfigured', () {
      expect(
        () => BookingService.instance.initRealtimeSubscription(),
        returnsNormally,
      );
    });

    test('initRealtimeSubscription is idempotent on repeated invocations', () {
      expect(
        () => BookingService.instance.initRealtimeSubscription(),
        returnsNormally,
      );
      expect(
        () => BookingService.instance.initRealtimeSubscription(),
        returnsNormally,
      );
    });

    test('bookingRealtimeEvents exposes a functional broadcast stream', () {
      final stream = BookingService.instance.bookingRealtimeEvents;
      expect(stream.isBroadcast, isTrue);
    });

    test('Multiple listeners concurrently receive broadcast events', () async {
      final eventsSub1 = <BookingRealtimeEvent>[];
      final eventsSub2 = <BookingRealtimeEvent>[];

      final sub1 = BookingService.instance.bookingRealtimeEvents.listen(eventsSub1.add);
      final sub2 = BookingService.instance.bookingRealtimeEvents.listen(eventsSub2.add);

      final testTime = DateTime(2026, 9, 18, 11);
      final testEvent = BookingRealtimeEvent(
        type: BookingRealtimeEventType.inserted,
        courtId: 'court-1-indoor-cushion',
        startTime: testTime,
      );

      BookingService.instance.broadcastMockBookingEvent(testEvent);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(eventsSub1, hasLength(1));
      expect(eventsSub2, hasLength(1));
      expect(eventsSub1.first.courtId, equals('court-1-indoor-cushion'));
      expect(eventsSub2.first.courtId, equals('court-1-indoor-cushion'));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('disposeRealtimeSubscription cleans up stream and allows safe re-initialization', () async {
      final receivedBefore = <BookingRealtimeEvent>[];
      final subBefore = BookingService.instance.bookingRealtimeEvents.listen(receivedBefore.add);

      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.inserted,
          courtId: 'court-1-indoor-cushion',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedBefore, hasLength(1));

      await subBefore.cancel();
      BookingService.instance.disposeRealtimeSubscription();

      // Accessing bookingRealtimeEvents after disposal safely re-allocates controller
      final receivedAfter = <BookingRealtimeEvent>[];
      final subAfter = BookingService.instance.bookingRealtimeEvents.listen(receivedAfter.add);

      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
          courtId: 'court-2-indoor-tour',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedAfter, hasLength(1));
      expect(receivedAfter.first.courtId, equals('court-2-indoor-tour'));
      expect(receivedAfter.first.type, equals(BookingRealtimeEventType.updated));

      await subAfter.cancel();
    });
  });

  group('Automatic Availability Cache Invalidation', () {
    test('broadcastMockBookingEvent invalidates targeted court and date cache', () async {
      final testDate = DateTime(2026, 9, 20);
      const courtId = 'court-1-indoor-cushion';

      // 1. Populate cache via fetchCourtBookingsForDate
      final initialBookings = await BookingService.instance.fetchCourtBookingsForDate(
        courtId,
        testDate,
      );
      expect(initialBookings, isNotNull);

      // Verify cached availability exists
      expect(
        BookingService.instance.getCachedAvailability(courtId, testDate),
        isNotNull,
      );

      // 2. Broadcast realtime insert event for this court & date
      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.inserted,
          courtId: courtId,
          startTime: DateTime(2026, 9, 20, 15),
        ),
      );

      // Verify targeted cache entry was invalidated
      expect(
        BookingService.instance.getCachedAvailability(courtId, testDate),
        isNull,
      );
    });

    test('Cache invalidation preserves unrelated courts and dates', () async {
      final testDate1 = DateTime(2026, 9, 22);
      final testDate2 = DateTime(2026, 9, 23);
      const court1 = 'court-1-indoor-cushion';
      const court2 = 'court-2-indoor-tour';

      // Populate cache for court 1 on date 1 and court 2 on date 2
      await BookingService.instance.fetchCourtBookingsForDate(court1, testDate1);
      await BookingService.instance.fetchCourtBookingsForDate(court2, testDate2);

      expect(BookingService.instance.getCachedAvailability(court1, testDate1), isNotNull);
      expect(BookingService.instance.getCachedAvailability(court2, testDate2), isNotNull);

      // Invalidate only court 1 on date 1 via dispatchRealtimeEvent
      BookingService.instance.dispatchRealtimeEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
          courtId: court1,
          startTime: DateTime(2026, 9, 22, 10),
        ),
      );

      // court 1 on date 1 is invalidated
      expect(BookingService.instance.getCachedAvailability(court1, testDate1), isNull);

      // court 2 on date 2 is preserved
      expect(BookingService.instance.getCachedAvailability(court2, testDate2), isNotNull);
    });

    test('Global cache invalidation clears all cached entries when courtId or startTime is null', () async {
      final testDate1 = DateTime(2026, 9, 25);
      final testDate2 = DateTime(2026, 9, 26);
      const court1 = 'court-1-indoor-cushion';
      const court2 = 'court-2-indoor-tour';

      await BookingService.instance.fetchCourtBookingsForDate(court1, testDate1);
      await BookingService.instance.fetchCourtBookingsForDate(court2, testDate2);

      expect(BookingService.instance.getCachedAvailability(court1, testDate1), isNotNull);
      expect(BookingService.instance.getCachedAvailability(court2, testDate2), isNotNull);

      // Broadcast event with null courtId/startTime triggers full cache wipe
      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
        ),
      );

      expect(BookingService.instance.getCachedAvailability(court1, testDate1), isNull);
      expect(BookingService.instance.getCachedAvailability(court2, testDate2), isNull);
    });

    test('Deleted event invalidates targeted availability cache', () async {
      final testDate = DateTime(2026, 9, 28);
      const courtId = 'court-3-outdoor-lighted';

      await BookingService.instance.fetchCourtBookingsForDate(courtId, testDate);
      expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNotNull);

      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.deleted,
          courtId: courtId,
          startTime: DateTime(2026, 9, 28, 18),
        ),
      );

      expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNull);
    });
  });

  group('Offline & Mock Realtime Dispatch Verification', () {
    test('broadcastMockBookingEvent delivers event to UI subscribers in offline mode', () async {
      final events = <BookingRealtimeEvent>[];
      final subscription = BookingService.instance.bookingRealtimeEvents.listen(events.add);

      final startTime = DateTime(2026, 10, 1, 8);
      final mockBooking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: startTime,
        endTime: startTime.add(const Duration(hours: 1)),
        totalAmount: 300.0,
      );

      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.inserted,
          booking: mockBooking,
          courtId: 'court-1-indoor-cushion',
          startTime: startTime,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(events, hasLength(1));
      expect(events.first.type, equals(BookingRealtimeEventType.inserted));
      expect(events.first.courtId, equals('court-1-indoor-cushion'));
      expect(events.first.startTime, equals(startTime));
      expect(events.first.booking?.id, equals(mockBooking.id));

      await subscription.cancel();
    });

    test('dispatchRealtimeEvent delivers updated event and invalidates cache', () async {
      final events = <BookingRealtimeEvent>[];
      final subscription = BookingService.instance.bookingRealtimeEvents.listen(events.add);

      final date = DateTime(2026, 10, 5);
      const courtId = 'court-4-outdoor-acrylic';

      await BookingService.instance.fetchCourtBookingsForDate(courtId, date);
      expect(BookingService.instance.getCachedAvailability(courtId, date), isNotNull);

      final eventTime = DateTime(2026, 10, 5, 17);
      BookingService.instance.dispatchRealtimeEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
          courtId: courtId,
          startTime: eventTime,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(events, hasLength(1));
      expect(events.first.type, equals(BookingRealtimeEventType.updated));
      expect(events.first.courtId, equals(courtId));
      expect(BookingService.instance.getCachedAvailability(courtId, date), isNull);

      await subscription.cancel();
    });
  });
}
