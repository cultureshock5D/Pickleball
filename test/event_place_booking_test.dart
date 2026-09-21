import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/event_space_model.dart';
import 'package:pickleball_app/screens/booking/court_reservation.dart';
import 'package:pickleball_app/screens/booking/event_place_booking_screen.dart';
import 'package:pickleball_app/widgets/event_booking_confirmation_modal.dart';

Widget _wrapWithApp(Widget child, {ThemeMode mode = ThemeMode.dark, Size? size}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: mode,
    home: MediaQuery(
      data: MediaQueryData(size: size ?? const Size(400, 850)),
      child: child,
    ),
  );
}

void main() {
  group('EventSpaceModel & Pricing Calculation Tests', () {
    final testSpace = MockData.eventSpaces.first;

    test('Custom hourly package calculates rate correctly', () {
      final price2Hours = testSpace.calculateBasePrice(
        package: EventPackageType.customHourly,
        customHours: 2,
      );
      expect(price2Hours, equals(testSpace.hourlyRate * 2));

      final price5Hours = testSpace.calculateBasePrice(
        package: EventPackageType.customHourly,
        customHours: 5,
      );
      expect(price5Hours, equals(testSpace.hourlyRate * 5));
    });

    test('Half-day and full-day packages use fixed package rates', () {
      final morningPrice = testSpace.calculateBasePrice(
        package: EventPackageType.halfDayMorning,
        customHours: 4,
      );
      expect(morningPrice, equals(testSpace.halfDayRate));

      final fullDayPrice = testSpace.calculateBasePrice(
        package: EventPackageType.fullDay,
        customHours: 8,
      );
      expect(fullDayPrice, equals(testSpace.fullDayRate));
    });

    test('EventAddon calculates cost correctly for perSession and perHour', () {
      const flatAddon = EventAddon(
        id: 'flat-1',
        name: 'PA Sound',
        description: 'Sound system',
        price: 1500.0,
        icon: Icons.speaker,
      );
      expect(flatAddon.calculateCost(4), equals(1500.0));

      const hourlyAddon = EventAddon(
        id: 'hourly-1',
        name: 'Ball Boy',
        description: 'Hourly assistant',
        price: 300.0,
        isPerSession: false,
        icon: Icons.person,
      );
      expect(hourlyAddon.calculateCost(3), equals(900.0));
    });

    test('EventBookingModel end time handles boundaries', () {
      final booking = EventBookingModel(
        id: 'EVT-TEST',
        spaceId: testSpace.id,
        spaceName: testSpace.name,
        eventType: 'Tournament',
        packageType: EventPackageType.halfDayMorning,
        date: DateTime(2026, 10, 15),
        startTime: const TimeOfDay(hour: 8, minute: 0),
        durationHours: 4,
        guestCount: 50,
        selectedAddons: const [],
        organizerName: 'Jordan Vance',
        organizerEmail: 'jordan@vance.com',
        organizerPhone: '+63 918 000 0000',
        specialInstructions: 'None',
        basePrice: 12000.0,
        addonsPrice: 0.0,
        securityDeposit: 2500.0,
        totalAmount: 14500.0,
        createdAt: DateTime.now(),
      );

      expect(booking.endTime.hour, equals(12));
      expect(booking.endTime.minute, equals(0));
    });
  });

  group('MockData Event Bookings In-Memory Store Tests', () {
    setUp(() {
      MockData.clearMockEventBookings();
    });

    test('Adding and retrieving mock event bookings', () {
      expect(MockData.getMockEventBookings(), isEmpty);

      final booking = EventBookingModel(
        id: 'EVT-101',
        spaceId: 'space-grand-pavilion',
        spaceName: 'Grand Championship Pavilion',
        eventType: 'Corporate Outing',
        packageType: EventPackageType.customHourly,
        date: DateTime.now().add(const Duration(days: 2)),
        startTime: const TimeOfDay(hour: 10, minute: 0),
        durationHours: 3,
        guestCount: 40,
        selectedAddons: const [],
        organizerName: 'Tech Corp',
        organizerEmail: 'events@techcorp.com',
        organizerPhone: '+63 917 111 2222',
        specialInstructions: 'Need projector',
        basePrice: 10500.0,
        addonsPrice: 0.0,
        securityDeposit: 2500.0,
        totalAmount: 13000.0,
        createdAt: DateTime.now(),
      );

      MockData.addMockEventBooking(booking);
      final list = MockData.getMockEventBookings();
      expect(list.length, equals(1));
      expect(list.first.id, equals('EVT-101'));
      expect(list.first.organizerName, equals('Tech Corp'));

      MockData.clearMockEventBookings();
      expect(MockData.getMockEventBookings(), isEmpty);
    });
  });

  group('EventPlaceBookingScreen Widget & Responsive Layout Tests', () {
    testWidgets('Renders compact mobile layout and switches event spaces', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapWithApp(
        const EventPlaceBookingScreen(),
        size: const Size(400, 850),
      ));
      await tester.pumpAndSettle();

      // Verify title & initial space
      expect(find.text('EVENTS PLACE RESERVATION'), findsOneWidget);
      expect(find.text("C&J's Events Place & Court Rental"), findsWidgets);

      // Verify venue selector
      expect(find.text('SELECT EVENT VENUE'), findsOneWidget);

      // Tap on second space: Grand Championship Pavilion & Arena
      final grandPavilion = find.text('Grand Championship Pavilion & Arena');
      expect(grandPavilion, findsOneWidget);
      await tester.tap(grandPavilion);
      await tester.pumpAndSettle();

      // Verify mobile bottom bar with Request Space button after selecting non-message-first space
      expect(find.text('Request Space'), findsOneWidget);
    });

    testWidgets('Renders two-column split layout on tablet / desktop width (>= 650)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapWithApp(
        const EventPlaceBookingScreen(),
        size: const Size(900, 900),
      ));
      await tester.pumpAndSettle();

      // Tablet split layout for default message-first space should display the inquiry button
      expect(find.text('Send Inquiry / Message Us First'), findsOneWidget);
      // Mobile bottom bar button should NOT be displayed
      expect(find.text('Message Us to Book'), findsNothing);
    });

    testWidgets('Validates form and displays inquiry confirmation modal on submission', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapWithApp(
        const EventPlaceBookingScreen(),
        size: const Size(400, 850),
      ));
      await tester.pumpAndSettle();

      // Default space is C&J's (message-first inquiry mode)
      final submitBtn = find.text('Message Us to Book');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Inquiry modal should appear
      expect(find.byType(EventBookingConfirmationModal), findsOneWidget);
      expect(find.text('INQUIRY SUBMITTED'), findsOneWidget);
      expect(find.text('Inquiry Received'), findsOneWidget);
      expect(find.text('₱0 (Inquiry Only)'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.text('Done & Return to Arena'));
      await tester.pumpAndSettle();

      expect(find.byType(EventBookingConfirmationModal), findsNothing);
    });
  });

  group('CourtReservationScreen Events Place Tab Integration Test', () {
    testWidgets('Top mode switcher contains Courts, Events Place, and My Bookings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapWithApp(
        const CourtReservationScreen(),
        size: const Size(400, 850),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pickleball'), findsOneWidget);
      expect(find.text('Basketball'), findsOneWidget);
      expect(find.text('Events Place'), findsOneWidget);

      // Tap on Events Place tab
      await tester.tap(find.text('Events Place'));
      await tester.pumpAndSettle();

      // Should render EventPlaceBookingScreen without stand-alone AppBar
      expect(find.byType(EventPlaceBookingScreen), findsOneWidget);
      expect(find.text('SELECT EVENT VENUE'), findsOneWidget);
    });
  });
}
