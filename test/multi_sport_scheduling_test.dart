import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/core/utils/validators.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/event_space_model.dart';
import 'package:pickleball_app/screens/booking/court_reservation.dart';
import 'package:pickleball_app/screens/booking/event_place_booking_screen.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.dark,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    MockData.resetToDefault();
  });

  tearDown(() {
    MockData.resetToDefault();
  });

  // =========================================================================
  // Group 1: Multi-Sport Facility Catalog & Court Partitioning
  // =========================================================================
  group('1. Requirement R2: Multi-Sport Facility Catalog & Court Partitioning', () {
    test('Partitions pickleball courts from full active court catalog', () {
      final allCourts = MockData.courts;
      final pickleballCourts = allCourts.where((c) => c.isPickleball).toList();

      expect(pickleballCourts, isNotEmpty);
      expect(pickleballCourts.length, greaterThanOrEqualTo(4));

      for (final court in pickleballCourts) {
        expect(court.isPickleball, isTrue);
        expect(court.isBasketball, isFalse);
        expect(court.isAvailableForBooking, isTrue);
      }

      // Verify specific known pickleball courts
      final court1 = pickleballCourts.firstWhere((c) => c.id == 'court-1-indoor-cushion');
      expect(court1.name, contains('Court 1'));
      expect(court1.isIndoor, isTrue);
      expect(court1.surfaceDescription, equals('Pro Cushion Surface'));
      expect(court1.courtBadge, equals('Indoor Championship'));

      final court3 = pickleballCourts.firstWhere((c) => c.id == 'court-3-outdoor-lighted');
      expect(court3.isOutdoor, isTrue);
      expect(court3.courtBadge, equals('Outdoor Lighted'));
    });

    test('Partitions basketball half courts with correct surface and badges', () {
      const allCourts = MockData.defaultBasketballCourts;
      final basketballCourts = allCourts.where((c) => c.isBasketball).toList();

      expect(basketballCourts.length, equals(2));

      final hoop1 = basketballCourts.firstWhere((c) => c.id == 'court-bb-1-half-poly');
      expect(hoop1.name, contains('Hoops 1'));
      expect(hoop1.isBasketball, isTrue);
      expect(hoop1.isPickleball, isFalse);
      expect(hoop1.surfaceDescription, equals('Polyurethane Half Court'));
      expect(hoop1.courtBadge, equals('FIBA Half Court'));
      expect(hoop1.hourlyRate, equals(350.0));

      final hoop2 = basketballCourts.firstWhere((c) => c.id == 'court-bb-2-half-spec');
      expect(hoop2.name, contains('Hoops 2'));
      expect(hoop2.hourlyRate, equals(400.0));
      expect(hoop2.isBasketball, isTrue);
    });

    test('Events Place catalog provides Grand Pavilion and Skyline View Deck spaces', () {
      const spaces = MockData.eventSpaces;
      expect(spaces.length, greaterThanOrEqualTo(2));

      final pavilion = spaces.firstWhere((s) => s.id == 'space-grand-pavilion');
      expect(pavilion.name, equals('Grand Championship Pavilion & Arena'));
      expect(pavilion.capacityMin, equals(20));
      expect(pavilion.capacityMax, equals(150));
      expect(pavilion.hourlyRate, equals(3500.0));
      expect(pavilion.halfDayRate, equals(12000.0));
      expect(pavilion.fullDayRate, equals(22000.0));
      expect(pavilion.tags, contains('TOURNAMENTS'));
      expect(pavilion.amenities, contains('Exclusive Dual-Court Access'));

      final terrace = spaces.firstWhere((s) => s.id == 'space-skyline-terrace');
      expect(terrace.name, equals('The Skyline View Deck & Terrace'));
      expect(terrace.hourlyRate, equals(2200.0));
      expect(terrace.tags, contains('VIEW DECK'));
    });

    test('Event package types expose valid duration hours and timeframes', () {
      expect(EventPackageType.customHourly.defaultDurationHours, equals(2));
      expect(EventPackageType.customHourly.label, equals('Custom Hourly'));

      expect(EventPackageType.halfDayMorning.defaultDurationHours, equals(4));
      expect(EventPackageType.halfDayMorning.timeFrame, contains('8:00 AM'));

      expect(EventPackageType.halfDayAfternoon.defaultDurationHours, equals(4));
      expect(EventPackageType.halfDayAfternoon.timeFrame, contains('1:00 PM'));

      expect(EventPackageType.halfDayEvening.defaultDurationHours, equals(4));
      expect(EventPackageType.halfDayEvening.timeFrame, contains('6:00 PM'));

      expect(EventPackageType.fullDay.defaultDurationHours, equals(8));
      expect(EventPackageType.fullDay.label, equals('Full-Day Championship'));
    });
  });

  // =========================================================================
  // Group 2: Discrete 16-Hour Slot Grid & Operating Boundaries (06:00 - 22:00)
  // =========================================================================
  group('2. Requirement R2: Discrete 16-Hour Slot Grid & Operating Boundaries (06:00 - 22:00)', () {
    test('generateDaySlots produces exactly 16 discrete hourly slots (06:00 to 22:00)', () async {
      final service = BookingService.instance;
      // Use a future date so past-slot flagging does not mark any as past
      final futureDate = DateTime.now().add(const Duration(days: 7));
      final date = DateTime(futureDate.year, futureDate.month, futureDate.day);

      final slots = await service.generateDaySlots(
        courtId: 'court-1-indoor-cushion',
        date: date,
      );

      // 6:00 AM through 9:00 PM start times = exactly 16 slots (last slot 21:00-22:00)
      expect(slots.length, equals(16));

      // First slot is 6:00 AM
      expect(slots.first.hour24, equals(6));
      expect(slots.first.startTime.hour, equals(6));
      expect(slots.first.timeLabel, equals('6:00 AM'));
      expect(slots.first.timeRangeLabel, equals('6:00 AM - 7:00 AM'));
      expect(slots.first.isPast, isFalse);

      // Last slot is 9:00 PM (ends 10:00 PM)
      expect(slots.last.hour24, equals(21));
      expect(slots.last.startTime.hour, equals(21));
      expect(slots.last.timeLabel, equals('9:00 PM'));
      expect(slots.last.timeRangeLabel, equals('9:00 PM - 10:00 PM'));
      expect(slots.last.isPast, isFalse);
    });

    test('generateDaySlots enforces boundary when duration is 2 or 3 hours', () async {
      final service = BookingService.instance;
      final futureDate = DateTime.now().add(const Duration(days: 10));
      final date = DateTime(futureDate.year, futureDate.month, futureDate.day);

      // 2-hour duration: last start hour is 22 - 2 = 20 (8:00 PM, ending 10:00 PM)
      // Slots: 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 = 15 slots
      final slots2h = await service.generateDaySlots(
        courtId: 'court-2-indoor-tour',
        date: date,
        durationHours: 2,
        hourlyRate: 350.0,
      );
      expect(slots2h.length, equals(15));
      expect(slots2h.last.hour24, equals(20));
      expect(slots2h.last.price, equals(700.0));

      // 3-hour duration: last start hour is 22 - 3 = 19 (7:00 PM, ending 10:00 PM)
      // Slots: 6 through 19 = 14 slots
      final slots3h = await service.generateDaySlots(
        courtId: 'court-2-indoor-tour',
        date: date,
        durationHours: 3,
        hourlyRate: 350.0,
      );
      expect(slots3h.length, equals(14));
      expect(slots3h.last.hour24, equals(19));
      expect(slots3h.last.price, equals(1050.0));
    });

    test('generateDaySlots correctly marks existing seed bookings as unavailable', () async {
      final service = BookingService.instance;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final slots = await service.generateDaySlots(
        courtId: 'court-1-indoor-cushion',
        date: today,
      );

      expect(slots.length, equals(16));

      // Court 1 has seed booking at 2:00 PM (hour 14) confirmed/paid
      final slot14 = slots.firstWhere((s) => s.hour24 == 14);
      expect(slot14.available, isFalse);
    });

    test('Cancelled and expired bookings release slots back to available', () async {
      final service = BookingService.instance;
      final futureDate = DateTime.now().add(const Duration(days: 3));
      final date = DateTime(futureDate.year, futureDate.month, futureDate.day);
      const courtId = 'court-3-outdoor-lighted';

      // 1. Initially 10:00 AM is available
      var slots = await service.generateDaySlots(courtId: courtId, date: date);
      expect(slots.firstWhere((s) => s.hour24 == 10).available, isTrue);

      // 2. Book 10:00 AM - 11:00 AM
      final booking = await service.createBooking(
        courtId: courtId,
        startTime: date.add(const Duration(hours: 10)),
        endTime: date.add(const Duration(hours: 11)),
        totalAmount: 280.0,
      );

      // 3. 10:00 AM is now occupied
      slots = await service.generateDaySlots(courtId: courtId, date: date);
      expect(slots.firstWhere((s) => s.hour24 == 10).available, isFalse);

      // 4. Cancel booking
      await service.cancelBooking(booking);

      // 5. 10:00 AM is released back to available
      slots = await service.generateDaySlots(courtId: courtId, date: date);
      expect(slots.firstWhere((s) => s.hour24 == 10).available, isTrue);
    });
  });

  // =========================================================================
  // Group 3: Mathematical Half-Open [start, end) Interval Collision Detection
  // =========================================================================
  group('3. Requirement R2: Mathematical Half-Open [start, end) Interval Collision Detection', () {
    final baseDate = DateTime(2026, 9, 23);

    test('Back-to-back adjacent intervals do NOT overlap (newStart == existingEnd)', () {
      final existingStart = baseDate.add(const Duration(hours: 8));
      final existingEnd = baseDate.add(const Duration(hours: 9));
      final newStart = baseDate.add(const Duration(hours: 9));
      final newEnd = baseDate.add(const Duration(hours: 10));

      final overlap = Validators.hasTimeOverlap(
        newStart: newStart,
        newEnd: newEnd,
        existingStart: existingStart,
        existingEnd: existingEnd,
      );

      expect(overlap, isFalse);
    });

    test('Back-to-back adjacent intervals do NOT overlap (newEnd == existingStart)', () {
      final newStart = baseDate.add(const Duration(hours: 7));
      final newEnd = baseDate.add(const Duration(hours: 8));
      final existingStart = baseDate.add(const Duration(hours: 8));
      final existingEnd = baseDate.add(const Duration(hours: 9));

      final overlap = Validators.hasTimeOverlap(
        newStart: newStart,
        newEnd: newEnd,
        existingStart: existingStart,
        existingEnd: existingEnd,
      );

      expect(overlap, isFalse);
    });

    test('Exact duplicate intervals trigger collision', () {
      final start = baseDate.add(const Duration(hours: 10));
      final end = baseDate.add(const Duration(hours: 11));

      final overlap = Validators.hasTimeOverlap(
        newStart: start,
        newEnd: end,
        existingStart: start,
        existingEnd: end,
      );

      expect(overlap, isTrue);
    });

    test('Partial forward and backward overlaps trigger collision', () {
      // Existing: [8:00, 10:00)
      final existingStart = baseDate.add(const Duration(hours: 8));
      final existingEnd = baseDate.add(const Duration(hours: 10));

      // Proposed forward overlap: [9:00, 11:00)
      final forwardStart = baseDate.add(const Duration(hours: 9));
      final forwardEnd = baseDate.add(const Duration(hours: 11));
      expect(
        Validators.hasTimeOverlap(
          newStart: forwardStart,
          newEnd: forwardEnd,
          existingStart: existingStart,
          existingEnd: existingEnd,
        ),
        isTrue,
      );

      // Proposed backward overlap: [7:00, 9:00)
      final backwardStart = baseDate.add(const Duration(hours: 7));
      final backwardEnd = baseDate.add(const Duration(hours: 9));
      expect(
        Validators.hasTimeOverlap(
          newStart: backwardStart,
          newEnd: backwardEnd,
          existingStart: existingStart,
          existingEnd: existingEnd,
        ),
        isTrue,
      );
    });

    test('Interval subset and superset inclusions trigger collision', () {
      // Superset: [7:00, 12:00), Subset: [8:00, 10:00)
      final superStart = baseDate.add(const Duration(hours: 7));
      final superEnd = baseDate.add(const Duration(hours: 12));
      final subStart = baseDate.add(const Duration(hours: 8));
      final subEnd = baseDate.add(const Duration(hours: 10));

      // Proposing subset inside existing superset
      expect(
        Validators.hasTimeOverlap(
          newStart: subStart,
          newEnd: subEnd,
          existingStart: superStart,
          existingEnd: superEnd,
        ),
        isTrue,
      );

      // Proposing superset enclosing existing subset
      expect(
        Validators.hasTimeOverlap(
          newStart: superStart,
          newEnd: superEnd,
          existingStart: subStart,
          existingEnd: subEnd,
        ),
        isTrue,
      );
    });

    test('Disjoint separated intervals do NOT overlap', () {
      final morningStart = baseDate.add(const Duration(hours: 8));
      final morningEnd = baseDate.add(const Duration(hours: 9));
      final afternoonStart = baseDate.add(const Duration(hours: 15));
      final afternoonEnd = baseDate.add(const Duration(hours: 16));

      expect(
        Validators.hasTimeOverlap(
          newStart: afternoonStart,
          newEnd: afternoonEnd,
          existingStart: morningStart,
          existingEnd: morningEnd,
        ),
        isFalse,
      );
    });

    test('formatTimeSlotRange formats standardized interval string', () {
      final start = DateTime(2026, 9, 23, 8);
      final end = DateTime(2026, 9, 23, 9);
      final formatted = Validators.formatTimeSlotRange(start, end);
      expect(formatted, equals('FROM 8:00 AM TO 9:00 AM'));
    });

    test('checkSlotAvailability enforces strict availability in BookingService', () async {
      final service = BookingService.instance;
      final targetDate = DateTime(2026, 11, 15);
      const courtId = 'court-1-indoor-cushion';

      // 1. Clean slot is available
      final avail1 = await service.checkSlotAvailability(
        courtId: courtId,
        startTime: targetDate.add(const Duration(hours: 14)),
        endTime: targetDate.add(const Duration(hours: 15)),
      );
      expect(avail1, isTrue);

      // 2. Book 14:00 - 15:00 and mark paid
      final b = await service.createBooking(
        courtId: courtId,
        startTime: targetDate.add(const Duration(hours: 14)),
        endTime: targetDate.add(const Duration(hours: 15)),
        totalAmount: 300.0,
      );
      await service.markBookingAsPaid(b.id);

      // 3. Same slot is now unavailable
      final avail2 = await service.checkSlotAvailability(
        courtId: courtId,
        startTime: targetDate.add(const Duration(hours: 14)),
        endTime: targetDate.add(const Duration(hours: 15)),
      );
      expect(avail2, isFalse);

      // 4. Adjacent back-to-back slot [15:00, 16:00) remains available
      final availAdjacent = await service.checkSlotAvailability(
        courtId: courtId,
        startTime: targetDate.add(const Duration(hours: 15)),
        endTime: targetDate.add(const Duration(hours: 16)),
      );
      expect(availAdjacent, isTrue);
    });
  });

  // =========================================================================
  // Group 4: Equipment & Service Add-On Pricing Engine
  // =========================================================================
  group('4. Requirement R2: Equipment & Service Add-On Pricing Engine', () {
    test('Calculates base court rental without add-ons across durations', () {
      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 300.0,
          durationHours: 1,
          paddleRental: false,
          ballThrowerRental: false,
        ),
        equals(300.0),
      );

      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 350.0,
          durationHours: 2,
          paddleRental: false,
          ballThrowerRental: false,
        ),
        equals(700.0),
      );

      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 400.0,
          durationHours: 4,
          paddleRental: false,
          ballThrowerRental: false,
        ),
        equals(1600.0),
      );
    });

    test('Paddle rental adds fixed flat fee (₱150) regardless of duration', () {
      // 1-Hour: 300 base + 150 paddle flat = 450
      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 300.0,
          durationHours: 1,
          paddleRental: true,
          ballThrowerRental: false,
        ),
        equals(450.0),
      );

      // 3-Hour: (300 * 3) base + 150 paddle flat = 1050
      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 300.0,
          durationHours: 3,
          paddleRental: true,
          ballThrowerRental: false,
        ),
        equals(1050.0),
      );
    });

    test('Ball thrower adds hourly fee (₱150/hr) scaled by duration', () {
      // 1-Hour: 300 base + (150 * 1) = 450
      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 300.0,
          durationHours: 1,
          paddleRental: false,
          ballThrowerRental: true,
        ),
        equals(450.0),
      );

      // 2-Hour: (300 * 2) base + (150 * 2) = 600 + 300 = 900
      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 300.0,
          durationHours: 2,
          paddleRental: false,
          ballThrowerRental: true,
        ),
        equals(900.0),
      );

      // 3-Hour: (300 * 3) base + (150 * 3) = 900 + 450 = 1350
      expect(
        BookingService.calculateTotalPrice(
          hourlyRate: 300.0,
          durationHours: 3,
          paddleRental: false,
          ballThrowerRental: true,
        ),
        equals(1350.0),
      );
    });

    test('Combines both paddle rental and ball thrower accurately', () {
      // 2-Hour Tour Spec (350/hr):
      // Court: 350 * 2 = 700
      // Paddle: 150 flat
      // Ball thrower: 150 * 2 = 300
      // Total: 700 + 150 + 300 = 1150
      final total = BookingService.calculateTotalPrice(
        hourlyRate: 350.0,
        durationHours: 2,
        paddleRental: true,
        ballThrowerRental: true,
      );
      expect(total, equals(1150.0));
    });
  });

  // =========================================================================
  // Group 5: Zero-Auth Multi-Calendar Deep Link & RFC 5545 Export Engine
  // =========================================================================
  group('5. Requirement R2: Zero-Auth Multi-Calendar Deep Link & RFC 5545 Export Engine', () {
    final start = DateTime.utc(2026, 9, 25, 8);
    final end = DateTime.utc(2026, 9, 25, 10);

    test('formatUtcDateTime formats exact RFC 5545 UTC timestamp (YYYYMMDDTHHmmSSZ)', () {
      final formatted = CalendarLinkService.formatUtcDateTime(start);
      expect(formatted, equals('20260925T080000Z'));
    });

    test('buildGoogleCalendarUri constructs zero-auth deep link with query parameters', () {
      final uri = CalendarLinkService.buildGoogleCalendarUri(
        title: 'Pickleball @ C&J Arena - Court 1',
        startTime: start,
        endTime: end,
        details: 'Booking Ref: BK-1001\nTotal: ₱750.00',
        location: 'C&J Sports Arena, BGC, Taguig',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('calendar.google.com'));
      expect(uri.path, equals('/calendar/render'));
      expect(uri.queryParameters['action'], equals('TEMPLATE'));
      expect(uri.queryParameters['text'], equals('Pickleball @ C&J Arena - Court 1'));
      expect(uri.queryParameters['dates'], equals('20260925T080000Z/20260925T100000Z'));
      expect(uri.queryParameters['details'], contains('BK-1001'));
      expect(uri.queryParameters['location'], equals('C&J Sports Arena, BGC, Taguig'));
    });

    test('buildOutlookCalendarUrl constructs valid Outlook Live deep link', () {
      final url = CalendarLinkService.buildOutlookCalendarUrl(
        title: 'Basketball Half Court Match',
        startTime: start,
        endTime: end,
        details: 'Hoops 1 - FIBA Spec',
        location: 'C&J Arena Court B',
      );

      final uri = Uri.parse(url);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('outlook.live.com'));
      expect(uri.queryParameters['rru'], equals('addevent'));
      expect(uri.queryParameters['subject'], equals('Basketball Half Court Match'));
      expect(uri.queryParameters['body'], equals('Hoops 1 - FIBA Spec'));
      expect(uri.queryParameters['startdt'], equals(start.toIso8601String()));
      expect(uri.queryParameters['enddt'], equals(end.toIso8601String()));
    });

    test('buildIcsCalendarData produces compliant RFC 5545 calendar schema', () {
      final ics = CalendarLinkService.buildIcsCalendarData(
        title: 'Championship Pickleball Singles',
        startTime: start,
        endTime: end,
        details: 'Court 1 Pro Cushion',
        location: 'C&J Sports Hub',
        uid: 'booking-ics-uid-42',
      );

      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('VERSION:2.0\r\n'));
      expect(ics, contains('PRODID:-//Pickleball App//EN\r\n'));
      expect(ics, contains('BEGIN:VEVENT\r\n'));
      expect(ics, contains('UID:booking-ics-uid-42\r\n'));
      expect(ics, contains('DTSTART:20260925T080000Z\r\n'));
      expect(ics, contains('DTEND:20260925T100000Z\r\n'));
      expect(ics, contains('SUMMARY:Championship Pickleball Singles\r\n'));
      expect(ics, contains('STATUS:CONFIRMED\r\n'));
      expect(ics, endsWith('END:VCALENDAR'));
    });

    test('buildAppleCalendarUrl creates encoded data URI for iCal import', () {
      final url = CalendarLinkService.buildAppleCalendarUrl(
        title: 'Court 2 Match',
        startTime: start,
        endTime: end,
      );

      expect(url, startsWith('data:text/calendar;charset=utf8,'));
      final decoded = Uri.decodeComponent(url.replaceFirst('data:text/calendar;charset=utf8,', ''));
      expect(decoded, contains('BEGIN:VCALENDAR'));
      expect(decoded, contains('SUMMARY:Court 2 Match'));
    });

    test('Sanitizes adversarial Trojan Source and Unicode control characters', () {
      // Unicode directional overrides and zero-width chars: \u202E (RLO), \u200E (LRM)
      const dirtyTitle = 'Pickleball\u202Ereversed\u200E Match';
      final sanitized = Validators.sanitizeText(dirtyTitle);

      expect(sanitized.contains('\u202E'), isFalse);
      expect(sanitized.contains('\u200E'), isFalse);

      final uri = CalendarLinkService.buildGoogleCalendarUri(
        title: dirtyTitle,
        startTime: start,
        endTime: end,
      );
      expect(uri.queryParameters['text']!.contains('\u202E'), isFalse);
    });
  });

  // =========================================================================
  // Group 6: Dynamic Gate Pass QR Code & Check-In Lifecycle (CheckInQrModal)
  // =========================================================================
  group('6. Requirement R2: Dynamic Gate Pass QR Code & Check-In Lifecycle', () {
    testWidgets('Renders dynamic rolling TOTP token and laser sweep animation', (tester) async {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'bk-gatepass-778899',
        courtId: 'court-1-indoor-cushion',
        courtName: 'Court 1 — Indoor (Pro Cushion)',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        totalPrice: 300.0,
        status: 'confirmed',
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          CheckInQrModal(booking: booking),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header title
      expect(find.text('Smart Court Gate QR Pass'), findsOneWidget);

      // Verify rolling token pattern: PKL-[ID]-[HEX_SEED]
      final tokenFinder = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^PKL-.*-[A-F0-9]+$').hasMatch(w.data ?? ''),
      );
      expect(tokenFinder, findsOneWidget);

      // Verify initial upcoming status badge
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);

      // Laser sweep animation container is present
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('Cycles through check-in state lifecycle on simulate tap', (tester) async {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'bk-lifecycle-test',
        courtId: 'court-1-indoor-cushion',
        courtName: 'Court 1',
        startTime: now.subtract(const Duration(minutes: 10)),
        endTime: now.add(const Duration(minutes: 50)),
        totalPrice: 300.0,
        status: 'confirmed',
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          CheckInQrModal(booking: booking),
        ),
      );
      await tester.pump();

      // State 1: Upcoming
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);

      // Tap Simulate Gate Scan button to transition to checked_in
      final simulateBtn = find.text('Simulate Gate Scan (Check-In)');
      expect(simulateBtn, findsOneWidget);
      await tester.tap(simulateBtn);
      await tester.pump();

      // State 2: Checked In (Session Active)
      expect(find.text('CHECKED IN • SESSION ACTIVE'), findsOneWidget);

      // Tap again to transition to completed
      final checkOutBtn = find.text('Simulate Gate Scan (Check-Out)');
      expect(checkOutBtn, findsOneWidget);
      await tester.tap(checkOutBtn);
      await tester.pump();

      // State 3: Completed (Session Concluded)
      expect(find.text('CHECKED OUT • CONCLUDED'), findsOneWidget);
      expect(find.text('Court Session Concluded'), findsOneWidget);

      // Tap reset cycles back to upcoming
      final resetBtn = find.text('Reset Gate Status');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pump();
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);
    });

    testWidgets('CheckInQrModal satisfies 48x48dp minimum touch target', (tester) async {
      final booking = MockData.mockBookings.first;

      await tester.pumpWidget(
        _wrapWithTheme(
          CheckInQrModal(booking: booking),
        ),
      );
      await tester.pump();

      // Gate scan toggle button touch target satisfies 48x48dp minimum
      final scanBtn = find.byType(ElevatedButton);
      expect(scanBtn, findsOneWidget);
      final btnSize = tester.getSize(scanBtn);
      expect(btnSize.height, greaterThanOrEqualTo(48.0));
      expect(btnSize.width, greaterThanOrEqualTo(48.0));
    });
  });

  // =========================================================================
  // Group 7: Interactive Court Reservation UI Flow (CourtReservationScreen)
  // =========================================================================
  group('7. Requirement R2: Interactive Court Reservation UI Flow', () {
    testWidgets('Renders CourtReservationScreen with 3 sub-tabs and switches between sports', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pinnedFutureDate = DateTime.now().add(const Duration(days: 7));

      await tester.pumpWidget(
        _wrapWithTheme(
          CourtReservationScreen(initialDate: pinnedFutureDate),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 3 sub-tabs are displayed
      expect(find.text('Pickleball'), findsOneWidget);
      expect(find.text('Basketball'), findsOneWidget);
      expect(find.text('Events Place'), findsOneWidget);

      // Default tab: Pickleball courts are rendered
      expect(find.textContaining('Court 1'), findsWidgets);

      // 2. Switch to Basketball sub-tab
      await tester.tap(find.text('Basketball'));
      await tester.pumpAndSettle();

      // Basketball courts rendered
      expect(find.textContaining('Hoops 1'), findsWidgets);

      // 3. Switch to Events Place sub-tab
      await tester.tap(find.text('Events Place'));
      await tester.pumpAndSettle();

      // Events Place screen rendered
      expect(find.byType(EventPlaceBookingScreen), findsOneWidget);
      expect(find.textContaining('Grand Championship Pavilion'), findsWidgets);
    });

    testWidgets('Tapping add-on checkboxes dynamically updates total price', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pinnedFutureDate = DateTime.now().add(const Duration(days: 7));

      await tester.pumpWidget(
        _wrapWithTheme(
          CourtReservationScreen(initialDate: pinnedFutureDate),
        ),
      );
      await tester.pumpAndSettle();

      // Default: 1 slot selected (8:00 AM), Court 1 rate is ₱300
      expect(find.text('Reserve Court • ₱300'), findsOneWidget);

      // Find paddle rental switch
      final paddleAddon = find.textContaining('Pro Carbon Paddle Bundle');
      expect(paddleAddon, findsOneWidget);
      await tester.tap(paddleAddon);
      await tester.pumpAndSettle();

      // Total updates to 300 + 150 = ₱450
      expect(find.text('Reserve Court • ₱450'), findsOneWidget);

      // Find ball thrower add-on switch
      final ballThrowerAddon = find.textContaining('Ball Thrower Machine');
      expect(ballThrowerAddon, findsOneWidget);
      await tester.tap(ballThrowerAddon);
      await tester.pumpAndSettle();

      // Total updates to 450 + 150 = ₱600
      expect(find.text('Reserve Court • ₱600'), findsOneWidget);
    });

    testWidgets('Court selection changes active court and surface specifications', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pinnedFutureDate = DateTime.now().add(const Duration(days: 7));

      await tester.pumpWidget(
        _wrapWithTheme(
          CourtReservationScreen(initialDate: pinnedFutureDate),
        ),
      );
      await tester.pumpAndSettle();

      // Court 1 surface: Pro Cushion is present in court header or card
      expect(find.textContaining('Pro Cushion'), findsWidgets);

      // Tap Court 2 pill if available
      final court2Pill = find.text('Court 2');
      if (court2Pill.evaluate().isNotEmpty) {
        await tester.tap(court2Pill);
        await tester.pumpAndSettle();
        // Court 2 rate is 350
        expect(find.text('Reserve Court • ₱350'), findsOneWidget);
      }
    });
  });
}
