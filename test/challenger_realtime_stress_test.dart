import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/screens/auth/login_screen.dart';
import 'package:pickleball_app/screens/booking/court_reservation.dart';
import 'package:pickleball_app/screens/home/main_navigation_screen.dart';
import 'package:pickleball_app/services/auth_service.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/paymongo_webhook_service.dart';
import 'package:pickleball_app/widgets/auth_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockData.resetToDefault();
    BookingService.instance.invalidateAvailabilityCache();
  });

  tearDown(() async {
    await AuthService.instance.signOut();
    BookingService.instance.disposeRealtimeSubscription();
  });

  group('Stress 1: High-Frequency & Concurrent Realtime Event Emissions', () {
    test('Broadcasts 150 high-frequency events concurrently across 5 active listeners without drops', () async {
      const listenerCount = 5;
      const eventCount = 150;
      final listenerReceived = List.generate(listenerCount, (_) => <BookingRealtimeEvent>[]);
      final subscriptions = <StreamSubscription<BookingRealtimeEvent>>[];

      for (int i = 0; i < listenerCount; i++) {
        final index = i;
        subscriptions.add(
          BookingService.instance.bookingRealtimeEvents.listen((event) {
            listenerReceived[index].add(event);
          }),
        );
      }

      final baseTime = DateTime(2026, 10, 1, 8);

      // Concurrently emit 150 events
      await Future.wait(
        List.generate(eventCount, (i) async {
          final event = BookingRealtimeEvent(
            type: (i % 3 == 0)
                ? BookingRealtimeEventType.inserted
                : (i % 3 == 1)
                    ? BookingRealtimeEventType.updated
                    : BookingRealtimeEventType.deleted,
            courtId: 'court-${(i % 4) + 1}',
            startTime: baseTime.add(Duration(hours: i % 12)),
          );
          BookingService.instance.broadcastMockBookingEvent(event);
        }),
      );

      // Yield for microtasks and stream delivery
      await Future<void>.delayed(const Duration(milliseconds: 50));

      for (int i = 0; i < listenerCount; i++) {
        expect(
          listenerReceived[i].length,
          equals(eventCount),
          reason: 'Listener $i should have received all $eventCount events',
        );
      }

      for (final sub in subscriptions) {
        await sub.cancel();
      }
    });

    test('Handles interleaved dynamic listener subscriptions and unsubscriptions during active broadcast', () async {
      final sub1Events = <BookingRealtimeEvent>[];
      final sub2Events = <BookingRealtimeEvent>[];
      final sub3Events = <BookingRealtimeEvent>[];

      final sub1 = BookingService.instance.bookingRealtimeEvents.listen(sub1Events.add);

      // Emit first 20 events
      for (int i = 0; i < 20; i++) {
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.inserted,
            courtId: 'court-1-indoor-cushion',
          ),
        );
      }

      // Add sub2 mid-stream
      final sub2 = BookingService.instance.bookingRealtimeEvents.listen(sub2Events.add);

      for (int i = 0; i < 20; i++) {
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.updated,
            courtId: 'court-2-indoor-tour',
          ),
        );
      }

      // Cancel sub1 mid-stream and add sub3
      await sub1.cancel();
      final sub3 = BookingService.instance.bookingRealtimeEvents.listen(sub3Events.add);

      for (int i = 0; i < 20; i++) {
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.deleted,
            courtId: 'court-3-outdoor-lighted',
          ),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(sub1Events.length, equals(40)); // Received first 2 batches of 20
      expect(sub2Events.length, equals(40)); // Received 2nd and 3rd batches of 20
      expect(sub3Events.length, equals(20)); // Received only 3rd batch of 20

      await sub2.cancel();
      await sub3.cancel();
    });

    test('Rapid consecutive initRealtimeSubscription and disposeRealtimeSubscription cycles are safe', () {
      for (int i = 0; i < 10; i++) {
        BookingService.instance.initRealtimeSubscription();
        BookingService.instance.disposeRealtimeSubscription();
      }
      expect(BookingService.instance.bookingRealtimeEvents.isBroadcast, isTrue);
    });
  });

  group('Stress 2: Cache Invalidation Rigor Under Rapid Consecutive Updates', () {
    test('Rapid interleaving inserts, updates, and deletes maintain exact cache invalidation states', () async {
      const courtId = 'court-1-indoor-cushion';
      final testDate = DateTime(2026, 11, 15);

      for (int cycle = 0; cycle < 10; cycle++) {
        // 1. Warm cache
        final cached = await BookingService.instance.fetchCourtBookingsForDate(courtId, testDate);
        expect(cached, isNotNull);
        expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNotNull);

        // 2. Invalidate via rapid insert event
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.inserted,
            courtId: courtId,
            startTime: testDate.add(const Duration(hours: 10)),
          ),
        );
        expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNull);

        // 3. Re-warm cache
        await BookingService.instance.fetchCourtBookingsForDate(courtId, testDate);
        expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNotNull);

        // 4. Invalidate via rapid update event
        BookingService.instance.dispatchRealtimeEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.updated,
            courtId: courtId,
            startTime: testDate.add(const Duration(hours: 11)),
          ),
        );
        expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNull);

        // 5. Re-warm cache
        await BookingService.instance.fetchCourtBookingsForDate(courtId, testDate);
        expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNotNull);

        // 6. Invalidate via rapid delete event
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.deleted,
            courtId: courtId,
            startTime: testDate.add(const Duration(hours: 12)),
          ),
        );
        expect(BookingService.instance.getCachedAvailability(courtId, testDate), isNull);
      }
    });

    test('Null courtId or startTime systematically triggers global cache wipe across all populated entries', () async {
      final dates = [
        DateTime(2026, 12),
        DateTime(2026, 12, 2),
        DateTime(2026, 12, 3),
      ];
      final courts = [
        'court-1-indoor-cushion',
        'court-2-indoor-tour',
        'court-3-outdoor-lighted',
      ];

      // Populate multiple entries
      for (final c in courts) {
        for (final d in dates) {
          await BookingService.instance.fetchCourtBookingsForDate(c, d);
          expect(BookingService.instance.getCachedAvailability(c, d), isNotNull);
        }
      }

      // Invalidate globally with null metadata
      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(type: BookingRealtimeEventType.updated),
      );

      // Verify all entries wiped
      for (final c in courts) {
        for (final d in dates) {
          expect(BookingService.instance.getCachedAvailability(c, d), isNull);
        }
      }
    });
  });

  group('Stress 3: Court & Date Isolation Verification', () {
    test('Cross-court isolation: Events for Court A strictly leave Court B, C, D caches untouched', () async {
      final date = DateTime(2026, 10, 20);
      const courtA = 'court-1-indoor-cushion';
      const courtB = 'court-2-indoor-tour';
      const courtC = 'court-3-outdoor-lighted';
      const courtD = 'court-4-outdoor-acrylic';

      await BookingService.instance.fetchCourtBookingsForDate(courtA, date);
      await BookingService.instance.fetchCourtBookingsForDate(courtB, date);
      await BookingService.instance.fetchCourtBookingsForDate(courtC, date);
      await BookingService.instance.fetchCourtBookingsForDate(courtD, date);

      expect(BookingService.instance.getCachedAvailability(courtA, date), isNotNull);
      expect(BookingService.instance.getCachedAvailability(courtB, date), isNotNull);
      expect(BookingService.instance.getCachedAvailability(courtC, date), isNotNull);
      expect(BookingService.instance.getCachedAvailability(courtD, date), isNotNull);

      // Fire event specifically targeting Court A
      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.inserted,
          courtId: courtA,
          startTime: DateTime(2026, 10, 20, 14),
        ),
      );

      // Court A cache is invalidated
      expect(BookingService.instance.getCachedAvailability(courtA, date), isNull);

      // Courts B, C, and D remain cached and untouched
      expect(BookingService.instance.getCachedAvailability(courtB, date), isNotNull);
      expect(BookingService.instance.getCachedAvailability(courtC, date), isNotNull);
      expect(BookingService.instance.getCachedAvailability(courtD, date), isNotNull);
    });

    test('Cross-date isolation: Events for Date 1 strictly leave Date 2, 3 caches on same court untouched', () async {
      const court = 'court-1-indoor-cushion';
      final date1 = DateTime(2026, 10, 25);
      final date2 = DateTime(2026, 10, 26);
      final date3 = DateTime(2026, 10, 27);

      await BookingService.instance.fetchCourtBookingsForDate(court, date1);
      await BookingService.instance.fetchCourtBookingsForDate(court, date2);
      await BookingService.instance.fetchCourtBookingsForDate(court, date3);

      expect(BookingService.instance.getCachedAvailability(court, date1), isNotNull);
      expect(BookingService.instance.getCachedAvailability(court, date2), isNotNull);
      expect(BookingService.instance.getCachedAvailability(court, date3), isNotNull);

      // Fire event targeting Date 2 only
      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
          courtId: court,
          startTime: DateTime(2026, 10, 26, 9),
        ),
      );

      // Date 2 is invalidated
      expect(BookingService.instance.getCachedAvailability(court, date2), isNull);

      // Dates 1 and 3 remain cached and untouched
      expect(BookingService.instance.getCachedAvailability(court, date1), isNotNull);
      expect(BookingService.instance.getCachedAvailability(court, date3), isNotNull);
    });
  });

  group('Stress 4: Offline Resilience Across Screens & Services', () {
    test('BookingService operations succeed without network or credentials', () async {
      expect(BookingService.instance.isSupabaseReady, isFalse);

      // 1. Fetch active courts
      final courts = await BookingService.instance.fetchActiveCourts();
      expect(courts, isNotEmpty);

      // 2. Fetch court bookings
      final bookings = await BookingService.instance.fetchCourtBookingsForDate(
        courts.first.id,
        DateTime.now(),
      );
      expect(bookings, isNotNull);

      // 3. Create booking offline
      final futureDate = DateTime.now().add(const Duration(days: 20));
      final created = await BookingService.instance.createBooking(
        courtId: courts.first.id,
        startTime: futureDate,
        endTime: futureDate.add(const Duration(hours: 1)),
        totalAmount: 300.0,
      );
      expect(created.id, isNotEmpty);
      expect(created.status, equals('confirmed'));

      // 4. Mark as paid offline
      final paid = await BookingService.instance.markBookingAsPaid(created.id);
      expect(paid.status, equals('paid'));

      // 5. Fetch customer bookings offline
      final custBookings = await BookingService.instance.fetchCustomerBookings();
      expect(custBookings, isNotEmpty);
    });

    test('AuthService operations succeed without network or credentials', () async {
      expect(AuthService.instance.isSupabaseReady, isFalse);

      final guestRes = AuthService.instance.signInAsGuest(
        email: 'stress.player@pickleball.dev',
        fullName: 'Stress Player',
      );
      expect(guestRes.session, isNotNull);
      expect(AuthService.instance.isAuthenticated, isTrue);

      final profile = await AuthService.instance.fetchUserProfile();
      expect(profile?.email, equals('stress.player@pickleball.dev'));

      final updated = await AuthService.instance.updateUserProfile(
        fullName: 'Stress Champion',
      );
      expect(updated.fullName, equals('Stress Champion'));

      await AuthService.instance.signOut();
      expect(AuthService.instance.isAuthenticated, isFalse);
    });

    testWidgets('AuthGate renders LoginScreen when unauthenticated and MainNavigationScreen when guest-signed in', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Unauthenticated state renders LoginScreen
      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      // 2. Sign in as guest
      AuthService.instance.signInAsGuest();
      await tester.pumpAndSettle();

      // Renders MainNavigationScreen seamlessly
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('CourtReservationScreen mounts, loads mock data, and handles events without throwing offline', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.instance.signInAsGuest();

      await tester.pumpWidget(
        const MaterialApp(home: CourtReservationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MATCH TIME'), findsOneWidget);

      // Emit high-frequency event while screen is live
      BookingService.instance.broadcastMockBookingEvent(
        BookingRealtimeEvent(
          type: BookingRealtimeEventType.updated,
          courtId: 'court-1-indoor-cushion',
          startTime: DateTime.now(),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Screen remains completely functional and intact
      expect(find.text('SCHEDULE MATCH TIME'), findsOneWidget);
    });
  });
}
