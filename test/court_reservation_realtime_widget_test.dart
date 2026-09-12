import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/screens/booking/court_reservation.dart';
import 'package:pickleball_app/services/auth_service.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/widgets/tap_collapse.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockData.resetToDefault();
    BookingService.instance.invalidateAvailabilityCache();
    AuthService.instance.signInAsGuest();
  });

  tearDown(() async {
    await AuthService.instance.signOut();
    BookingService.instance.disposeRealtimeSubscription();
  });

  group('CourtReservationScreen Realtime Reactive Slots Integration', () {
    testWidgets(
      'Automatically marks available slot as booked upon receiving realtime insert event without manual refresh',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Render CourtReservationScreen
        await tester.pumpWidget(
          const MaterialApp(
            home: CourtReservationScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial UI elements loaded cleanly
        expect(find.text('SCHEDULE MATCH TIME'), findsOneWidget);
        expect(find.byTooltip('Next Day'), findsOneWidget);

        // 2. Advance to tomorrow so all daytime slots are open and not in the past
        await tester.tap(find.byTooltip('Next Day'));
        await tester.pumpAndSettle();

        final tomorrow = DateTime.now().add(const Duration(days: 1));
        const targetCourtId = 'court-1-indoor-cushion';

        // 3. Verify the 3:00 PM slot is initially available and enabled
        final availableSlotFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '3:00 PM' &&
              w.properties.enabled == true,
        );
        expect(availableSlotFinder, findsOneWidget);

        final bookedSlotFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '3:00 PM, Booked' &&
              w.properties.enabled == false,
        );
        expect(bookedSlotFinder, findsNothing);

        // 4. Simulate a concurrent booking from another client/session
        final slotStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15);
        final slotEnd = slotStart.add(const Duration(hours: 1));

        final concurrentBooking = MockData.createMockBooking(
          courtId: targetCourtId,
          startTime: slotStart,
          endTime: slotEnd,
          totalAmount: 300.0,
          guestName: 'Court Rival',
        );

        // 5. Emit realtime booking event to the BookingService broadcast stream
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.inserted,
            booking: concurrentBooking,
            courtId: targetCourtId,
            startTime: slotStart,
          ),
        );

        // 6. Pump the reactive frame update without manual navigation or pull-to-refresh
        await tester.pump();
        await tester.pumpAndSettle();

        // 7. Verify the 3:00 PM slot automatically transitioned to booked and disabled
        expect(availableSlotFinder, findsNothing);
        expect(bookedSlotFinder, findsOneWidget);

        // Verify strike-through text decoration is applied to 3:00 PM
        final textFinder = find.descendant(
          of: bookedSlotFinder,
          matching: find.byType(Text),
        );
        expect(textFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.style?.decoration, equals(TextDecoration.lineThrough));

        // Verify slot interaction is disabled (TapCollapse onTap is null)
        final tapCollapseFinder = find.descendant(
          of: bookedSlotFinder,
          matching: find.byType(TapCollapse),
        );
        expect(tapCollapseFinder, findsOneWidget);
        final tapCollapseWidget = tester.widget<TapCollapse>(tapCollapseFinder);
        expect(tapCollapseWidget.onTap, isNull);
      },
    );

    testWidgets(
      'Automatically frees slot when a realtime cancellation/delete event is broadcast',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: CourtReservationScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to tomorrow
        await tester.tap(find.byTooltip('Next Day'));
        await tester.pumpAndSettle();

        final tomorrow = DateTime.now().add(const Duration(days: 1));
        const targetCourtId = 'court-1-indoor-cushion';
        final slotStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16); // 4:00 PM
        final slotEnd = slotStart.add(const Duration(hours: 1));

        // Create booking to occupy 4:00 PM
        final booking = MockData.createMockBooking(
          courtId: targetCourtId,
          startTime: slotStart,
          endTime: slotEnd,
          totalAmount: 300.0,
        );

        // Emit insert event to lock the slot
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.inserted,
            booking: booking,
            courtId: targetCourtId,
            startTime: slotStart,
          ),
        );
        await tester.pumpAndSettle();

        final booked4pm = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '4:00 PM, Booked' &&
              w.properties.enabled == false,
        );
        expect(booked4pm, findsOneWidget);

        // Now simulate realtime cancellation / deletion of this booking
        MockData.cancelMockBooking(booking.id);
        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.deleted,
            booking: booking.copyWith(status: 'cancelled'),
            courtId: targetCourtId,
            startTime: slotStart,
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Verify slot is now open and selectable again
        final open4pm = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '4:00 PM' &&
              w.properties.enabled == true,
        );
        expect(open4pm, findsOneWidget);
        expect(booked4pm, findsNothing);

        final text4pmFinder = find.descendant(of: open4pm, matching: find.byType(Text));
        expect(tester.widget<Text>(text4pmFinder).style?.decoration, isNull);

        final tap4pmFinder = find.descendant(of: open4pm, matching: find.byType(TapCollapse));
        expect(tester.widget<TapCollapse>(tap4pmFinder).onTap, isNotNull);
      },
    );

    testWidgets(
      'Realtime events for other courts do not alter current court availability',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: CourtReservationScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Next Day'));
        await tester.pumpAndSettle();

        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final slotStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17); // 5:00 PM

        // 5:00 PM on Court 1 is open
        final open5pmCourt1 = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '5:00 PM' &&
              w.properties.enabled == true,
        );
        expect(open5pmCourt1, findsOneWidget);

        // Emit an event for Court 2 (unrelated court)
        final otherCourtBooking = MockData.createMockBooking(
          courtId: 'court-2-indoor-tour',
          startTime: slotStart,
          endTime: slotStart.add(const Duration(hours: 1)),
          totalAmount: 350.0,
        );

        BookingService.instance.broadcastMockBookingEvent(
          BookingRealtimeEvent(
            type: BookingRealtimeEventType.inserted,
            booking: otherCourtBooking,
            courtId: 'court-2-indoor-tour',
            startTime: slotStart,
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // 5:00 PM on Court 1 remains available and untouched
        expect(open5pmCourt1, findsOneWidget);
      },
    );
  });
}
