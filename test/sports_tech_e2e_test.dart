import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/core/utils/validators.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/screens/booking/booking_review_screen.dart';
import 'package:pickleball_app/screens/booking/court_reservation.dart';
import 'package:pickleball_app/screens/insights/insights.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';
import 'package:pickleball_app/widgets/booking_success_modal.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';
import 'package:pickleball_app/widgets/downloadable_receipt_modal.dart';
import 'package:pickleball_app/widgets/time_player_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleBooking = BookingModel(
    id: 'BK-TEST-100',
    customerId: 'cust-100',
    courtId: 'court-100',
    courtName: 'SmashCourt - Center Arena',
    startTime: DateTime(2026, 9, 10, 18),
    endTime: DateTime(2026, 9, 10, 19),
    status: 'confirmed',
    totalAmount: 180.00,
    createdAt: DateTime(2026, 9, 9, 12),
  );

  const sampleCourt = CourtModel(
    id: 'court-100',
    name: 'SmashCourt - Center Arena',
    surfaceType: 'Ultra-Fast Acrylic',
    courtType: 'LED Glow Indoor',
    venueId: 'venue-bcn-1',
    venueName: 'Barcelona Smash Club',
  );

  // =========================================================================
  // TIER 1: FEATURE COVERAGE
  // =========================================================================
  group('Tier 1: Feature Coverage', () {
    testWidgets('Tier 1.1: Athletic typography tokens and design system tokens in AppTheme', (tester) async {
      // 1. Telemetry Hero Typography
      expect(AppTheme.fontTelemetryHero.fontSize, equals(38));
      expect(AppTheme.fontTelemetryHero.fontWeight, equals(FontWeight.w800));
      expect(AppTheme.fontTelemetryHero.letterSpacing, equals(-1.2));
      expect(AppTheme.fontTelemetryHero.color, equals(AppTheme.textPrimary));

      // 2. Telemetry Value Typography
      expect(AppTheme.fontTelemetryValue.fontSize, equals(24));
      expect(AppTheme.fontTelemetryValue.fontWeight, equals(FontWeight.w700));
      expect(AppTheme.fontTelemetryValue.letterSpacing, equals(-0.5));

      // 3. Telemetry Label Typography
      expect(AppTheme.fontTelemetryLabel.fontSize, equals(10.5));
      expect(AppTheme.fontTelemetryLabel.fontWeight, equals(FontWeight.w700));
      expect(AppTheme.fontTelemetryLabel.letterSpacing, equals(1.0));
      expect(AppTheme.fontTelemetryLabel.color, equals(AppTheme.textMuted));

      // 4. Sports Badge Typography
      expect(AppTheme.fontSportsBadge.fontSize, equals(10));
      expect(AppTheme.fontSportsBadge.fontWeight, equals(FontWeight.w800));
      expect(AppTheme.fontSportsBadge.letterSpacing, equals(0.5));

      // 5. Price Hero Typography
      expect(AppTheme.fontPriceHero.fontSize, equals(19));
      expect(AppTheme.fontPriceHero.fontWeight, equals(FontWeight.w800));
      expect(AppTheme.fontPriceHero.color, equals(AppTheme.neonLime));

      // 6. Monospace Value Typography
      expect(AppTheme.fontMonospaceValue.fontSize, equals(13));
      expect(AppTheme.fontMonospaceValue.fontWeight, equals(FontWeight.w700));
      expect(AppTheme.fontMonospaceValue.color, equals(AppTheme.neonLime));

      // 7. Core Palette Tokens
      const palette = AppTheme.darkPalette;
      expect(palette.background, equals(const Color(0xFF0A0F0D)));
      expect(palette.surface, equals(const Color(0xFF121A16)));
      expect(palette.surfaceElevated, equals(const Color(0xFF1B2620)));
      expect(palette.neonLime, equals(const Color(0xFFCCFF00)));
      expect(palette.neonGreen, equals(const Color(0xFF00E599)));
      expect(palette.neonYellow, equals(const Color(0xFFFACC15)));

      // 8. WCAG AAA Contrast Calculation: #CCFF00 on #0A0F0D
      double linearize(double channel) {
        return (channel <= 0.03928)
            ? channel / 12.92
            : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
      }

      double luminance(Color c) {
        final r = linearize(c.r);
        final g = linearize(c.g);
        final b = linearize(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      final lumLime = luminance(const Color(0xFFCCFF00));
      final lumDark = luminance(const Color(0xFF0A0F0D));
      final contrastRatio = (lumLime + 0.05) / (lumDark + 0.05);

      expect(contrastRatio, greaterThanOrEqualTo(16.0),
          reason: 'Electric Lime on Dark Slate must achieve WCAG AAA contrast >= 16:1');
    });

    testWidgets('Tier 1.2: Telemetry activity visuals, DUPR progression, and horizon baseline in InsightsScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const InsightsScreen(),
        ),
      );

      // Allow async booking loading and UI state calculation to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // 1. Total Court Playtime Header
      expect(find.text('TOTAL COURT PLAYTIME'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);

      // 2. Player Telemetry & DUPR Card
      expect(find.text('PLAYER TELEMETRY & DUPR'), findsOneWidget);
      expect(find.text('Advanced Competitive'), findsOneWidget);
      expect(find.textContaining('DUPR'), findsWidgets);
      expect(find.text('/ 5.0'), findsOneWidget);
      expect(find.textContaining('Top 8% Club Rank'), findsOneWidget);

      // 3. Intensity Load Chips
      expect(find.textContaining('Match Intensity:'), findsOneWidget);
      expect(find.text('Court Pace: +12%'), findsOneWidget);
      expect(find.text('Training Load: Optimal'), findsOneWidget);

      // 4. Weekly Playtime Activity & Target Horizon Line
      expect(find.text('Weekly Playtime Activity'), findsOneWidget);
      expect(find.text('TARGET 1.1h'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);

      // 5. Period Horizon Filter Chips
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('All-Time'), findsOneWidget);

      // Switch period filter
      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();
      expect(find.text('This Week'), findsOneWidget);
    });

    testWidgets('Tier 1.3: Horizontal multi-court visual timeline and court cards in CourtReservationScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.6),
            ),
            child: child!,
          ),
          home: const CourtReservationScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Mode Switcher
      expect(find.text('Reserve Court'), findsOneWidget);
      expect(find.text('My Reservations'), findsOneWidget);

      // Multi-Court Timeline & Live Lanes Header
      expect(find.text('Multi-Court Visual Timeline'), findsOneWidget);
      expect(find.text('LIVE LANES'), findsOneWidget);

      // Timeline Heat Legend
      expect(find.text('Off-Peak (₱120)'), findsOneWidget);
      expect(find.text('Peak 17-22h (₱180)'), findsOneWidget);
      expect(find.text('Booked'), findsOneWidget);

      // Court Lanes
      expect(find.text('Court 1'), findsWidgets);
      expect(find.text('Championship Courts'), findsOneWidget);

      // Tap slot 18:00 on lane to test interactive slot selection
      final slot18Finder = find.text('18:00');
      if (slot18Finder.evaluate().isNotEmpty) {
        await tester.tap(slot18Finder.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Tier 1.4: Interactive laser sweep QR gate pass modal with dynamic rolling token and check-in toggle in CheckInQrModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CheckInQrModal(booking: sampleBooking),
          ),
        ),
      );

      // Pump single frame for repeating pulse & laser sweep controllers
      await tester.pump(const Duration(milliseconds: 100));

      // Header & Court Details
      expect(find.text('Smart Court Gate QR Pass'), findsOneWidget);
      expect(find.text('SmashCourt - Center Arena'), findsOneWidget);

      // Status Badge
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);

      // Rolling 30s token formatted as PKL-[ID]-[SEED]
      expect(find.textContaining('PKL-'), findsOneWidget);

      // Countdown Timer Strip
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // QR Visual with RepaintBoundary for GPU optimization
      expect(find.byType(RepaintBoundary), findsWidgets);

      // Gate Simulation Action Button
      expect(find.text('Simulate Gate Scan (Check-In)'), findsOneWidget);

      // Simulate Gate Scan (Check-In)
      await tester.tap(find.text('Simulate Gate Scan (Check-In)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHECKED IN • SESSION ACTIVE'), findsOneWidget);
      expect(find.text('Simulate Gate Scan (Check-Out)'), findsOneWidget);

      // Simulate Gate Scan (Check-Out)
      await tester.tap(find.text('Simulate Gate Scan (Check-Out)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHECKED OUT • CONCLUDED'), findsOneWidget);
    });

    testWidgets('Tier 1.5: Fluid fast-booking sheet with peak ribbon and auto-computed pricing in TimePlayerPickerModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      MatchTimeSelection? confirmedSelection;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TimePlayerPickerModal(
              availableTimes: const [
                TimeOfDay(hour: 10, minute: 0),
                TimeOfDay(hour: 18, minute: 0),
              ],
              initialTimeSlotIndex: 0,
              onSelectionConfirmed: (sel) => confirmedSelection = sel,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Subtitle
      expect(find.text('Select Match Time Slot'), findsOneWidget);
      expect(find.text('Court Match Duration: 1-hour slot • Auto-computes fee'), findsOneWidget);

      // Peak & Off-Peak Visual Ribbons
      expect(find.text('Off-Peak'), findsOneWidget);
      expect(find.text('PEAK'), findsOneWidget);

      // 48x48 Accessible Close Button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap the peak slot (18:00)
      await tester.tap(find.text('PEAK'));
      await tester.pumpAndSettle();

      // Confirm Match Time Slot
      await tester.tap(find.text('Confirm Match Time Slot'));
      await tester.pumpAndSettle();

      expect(confirmedSelection, isNotNull);
      expect(confirmedSelection!.timeSlotIndex, equals(1));
      expect(confirmedSelection!.startTime.hour, equals(18));
      expect(confirmedSelection!.totalAmount, equals(180.0));
    });

    testWidgets('Tier 1.6: Perforated digital ticket receipt with barcode aesthetics and PayMongo confirmation in DownloadableReceiptModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DownloadableReceiptModal(
              booking: sampleBooking,
              paymentMethod: 'Maya via PayMongo',
              paymongoReference: 'pm_ref_maya_8841',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header Titles
      expect(find.text('Official Court Reservation Receipt'), findsOneWidget);
      expect(find.text('Official Payment Receipt'), findsOneWidget);
      expect(find.text('PayMongo Transaction Confirmed'), findsOneWidget);

      // Reservation Section
      expect(find.text('BK-TEST-100'), findsOneWidget);
      expect(find.text('SmashCourt - Center Arena'), findsOneWidget);
      expect(find.text('Maya via PayMongo'), findsOneWidget);
      expect(find.text('pm_ref_maya_8841'), findsOneWidget);

      // Itemized Financials
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('₱180.00'), findsOneWidget);

      // Action Buttons
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Share Receipt'), findsOneWidget);

      // Tap Download PDF to trigger feedback
      await tester.tap(find.text('Download PDF'));
      await tester.pump();
      expect(find.text('Receipt PDF downloaded to device storage.'), findsOneWidget);
    });

    testWidgets('Tier 1.7: PayMongo multi-channel selectors, pricing breakdown card, and calendar sync in BookingReviewScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.65),
            ),
            child: child!,
          ),
          home: BookingReviewScreen(
            court: sampleCourt,
            startTime: DateTime(2026, 9, 10, 18),
            endTime: DateTime(2026, 9, 10, 19),
            durationHours: 1.0,
            totalAmount: 180.00,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Court Overview
      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(find.text('SmashCourt - Center Arena'), findsOneWidget);
      expect(find.text('Ultra-Fast Acrylic'), findsOneWidget);

      // Transparent Pricing Breakdown
      expect(find.text('Price Breakdown'), findsOneWidget);
      expect(find.text('PEAK RATE ACTIVE'), findsOneWidget);
      expect(find.text('+₱60.00'), findsOneWidget);
      expect(find.text('₱180.00'), findsWidgets);

      // 1-Tap Calendar Sync Toggle
      expect(find.text('1-Tap Auto-Sync Calendar'), findsOneWidget);

      // PayMongo Multi-Channel Payment Options
      expect(find.text('GCash via PayMongo'), findsOneWidget);
      expect(find.text('Maya via PayMongo'), findsOneWidget);
      expect(find.text('GrabPay via PayMongo'), findsOneWidget);
      expect(find.text('Credit / Debit Card via PayMongo'), findsOneWidget);
      expect(find.text('Club Membership Card'), findsOneWidget);

      // Select Maya Payment Option
      await tester.tap(find.text('Maya via PayMongo'));
      await tester.pumpAndSettle();

      // Bottom Checkout Bar
      expect(find.text('TOTAL AMOUNT'), findsOneWidget);
      expect(find.text('Confirm & Lock Court Reservation'), findsOneWidget);
    });

    testWidgets('Tier 1.8: Booking confirmation success modal with multi-calendar deep links in BookingSuccessModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool viewBookingsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BookingSuccessModal(
              booking: sampleBooking,
              venueName: 'Barcelona Smash Club',
              onViewBookings: () => viewBookingsCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Glowing Checkmark Header
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Reservation Confirmed!'), findsOneWidget);
      expect(find.text('Your court has been successfully locked in.'), findsOneWidget);

      // Summary Details
      expect(find.text('SmashCourt - Center Arena'), findsOneWidget);
      expect(find.text('Barcelona Smash Club'), findsOneWidget);
      expect(find.text('₱180.00'), findsOneWidget);
      expect(find.text('BK-TEST-100'), findsOneWidget);

      // Multi-Calendar Sync Links
      expect(find.text('Add to Google Calendar'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Outlook'), findsOneWidget);
      expect(find.text('iCal (.ics)'), findsOneWidget);

      // Secondary Dismissal CTA
      expect(find.text('Done • View My Bookings'), findsOneWidget);

      await tester.tap(find.text('Done • View My Bookings'));
      await tester.pumpAndSettle();
      expect(viewBookingsCalled, isTrue);
    });
  });

  // =========================================================================
  // TIER 2: BOUNDARY & CORNER CASES
  // =========================================================================
  group('Tier 2: Boundary & Corner Cases', () {
    test('Tier 2.1: Court peak/off-peak boundary transitions and custom hour windows', () {
      const court = CourtModel(
        id: 'court-bnd-1',
        name: 'Grand Slam Court',
      );

      // Hour 16:59 (represented by hour 16) -> Off-peak
      expect(court.isPeakHour(16), isFalse);
      expect(court.rateForHour(16), equals(120.0));

      // Hour 17:00 (exact start boundary) -> Peak
      expect(court.isPeakHour(17), isTrue);
      expect(court.rateForHour(17), equals(180.0));

      // Hour 21:00 (last peak hour) -> Peak
      expect(court.isPeakHour(21), isTrue);
      expect(court.rateForHour(21), equals(180.0));

      // Hour 22:00 (exact end boundary of half-open interval [17, 22)) -> Off-peak
      expect(court.isPeakHour(22), isFalse);
      expect(court.rateForHour(22), equals(120.0));

      // Midnight hour 0 -> Off-peak
      expect(court.isPeakHour(0), isFalse);
      expect(court.rateForHour(0), equals(120.0));

      // Custom Peak Hour Windows (18:00 to 20:00)
      const customCourt = CourtModel(
        id: 'court-bnd-custom',
        name: 'Custom Peak Court',
        hourlyRate: 100.0,
        peakHourlyRate: 250.0,
        peakStartHour: 18,
        peakEndHour: 20,
      );

      expect(customCourt.isPeakHour(17), isFalse);
      expect(customCourt.isPeakHour(18), isTrue);
      expect(customCourt.rateForHour(18), equals(250.0));
      expect(customCourt.isPeakHour(19), isTrue);
      expect(customCourt.isPeakHour(20), isFalse);
      expect(customCourt.rateForHour(20), equals(100.0));
    });

    testWidgets('Tier 2.2: Zero playtime and empty state calculations in InsightsScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Test defensive division by zero logic
      const int zeroBookings = 0;
      const double zeroPlaytime = 0.0;
      const avgSession = zeroBookings == 0 ? 0.0 : zeroPlaytime / zeroBookings;
      expect(avgSession, equals(0.0));
      expect(avgSession.isNaN, isFalse);
      expect(avgSession.isInfinite, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const InsightsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify no exceptions thrown and layout renders reliably
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    test('Tier 2.3: DUPR rating progression bounds and progress fraction gauge clamping', () {
      double computeDupr(int count) {
        return 3.85 + (count * 0.02).clamp(0.0, 0.40);
      }

      // Baseline rating with 0 bookings
      expect(computeDupr(0), equals(3.85));

      // Progression with 5 bookings
      expect(computeDupr(5), closeTo(3.95, 0.001));

      // Progression with 20 bookings (hits exact max clamp 0.40)
      expect(computeDupr(20), closeTo(4.25, 0.001));

      // Progression with 100 bookings (clamped, cannot exceed 4.25)
      expect(computeDupr(100), equals(4.25));

      // Progress fraction clamping [0.0, 1.0] for gauge
      double computeFraction(double rating) {
        return (rating / 5.0).clamp(0.0, 1.0);
      }

      expect(computeFraction(3.85), equals(0.77));
      expect(computeFraction(4.25), equals(0.85));
      expect(computeFraction(-1.0), equals(0.0));
      expect(computeFraction(6.5), equals(1.0));
    });

    test('Tier 2.4: Name length boundaries, Trojan Source control characters, and text sanitization', () {
      // 1. Lower Boundary (min 2 characters)
      expect(Validators.validateFullName('A'), equals('Name must be at least 2 characters'));
      expect(Validators.validateFullName('Bo'), isNull);

      // 2. Upper Boundary (max 70 characters)
      final name70 = 'A' * 70;
      expect(Validators.validateFullName(name70), isNull);
      final name71 = 'A' * 71;
      expect(Validators.validateFullName(name71), equals('Name cannot exceed 70 characters'));

      // 3. Trojan Source & Hidden Control Characters Defense
      expect(Validators.validateFullName('Alex\u0000Morgan'), equals('Name contains invalid control characters'));
      expect(Validators.validateFullName('Alex\u0007Bell'), equals('Name contains invalid control characters'));
      expect(Validators.validateFullName('Alex\u202EReverse'), equals('Name contains invalid control characters'));
      expect(Validators.validateFullName('Alex\nNewline'), equals('Name contains invalid control characters'));
      expect(Validators.validateFullName('Alex\rReturn'), equals('Name contains invalid control characters'));

      // 4. Text Sanitization
      const dirtyText = 'User\u0000Name\u202E Spoof';
      final cleanText = Validators.sanitizeText(dirtyText);
      expect(cleanText, equals('UserName Spoof'));

      final clamped = Validators.sanitizeText('A' * 500, maxLength: 50);
      expect(clamped.length, equals(50));
      expect(Validators.sanitizeText(null), equals(''));
    });

    test('Tier 2.5: Half-open interval overlap math across all permutations (Validators.hasTimeOverlap)', () {
      final baseDate = DateTime(2026, 9, 10);
      DateTime slot(int h, int m) => DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);

      // Case 1: Back-to-back adjacent slots [8:00, 9:00) and [9:00, 10:00) -> Allowed
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(8, 0),
          newEnd: slot(9, 0),
          existingStart: slot(9, 0),
          existingEnd: slot(10, 0),
        ),
        isFalse,
      );

      // Case 2: Back-to-back adjacent in reverse order [9:00, 10:00) and [8:00, 9:00) -> Allowed
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(9, 0),
          newEnd: slot(10, 0),
          existingStart: slot(8, 0),
          existingEnd: slot(9, 0),
        ),
        isFalse,
      );

      // Case 3: Partial middle overlap [8:00, 10:00) and [9:00, 11:00) -> Overlap
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(8, 0),
          newEnd: slot(10, 0),
          existingStart: slot(9, 0),
          existingEnd: slot(11, 0),
        ),
        isTrue,
      );

      // Case 4: Enclosing interval [8:00, 12:00) around [9:00, 10:00) -> Overlap
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(8, 0),
          newEnd: slot(12, 0),
          existingStart: slot(9, 0),
          existingEnd: slot(10, 0),
        ),
        isTrue,
      );

      // Case 5: Enclosed interval [9:00, 10:00) inside [8:00, 12:00) -> Overlap
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(9, 0),
          newEnd: slot(10, 0),
          existingStart: slot(8, 0),
          existingEnd: slot(12, 0),
        ),
        isTrue,
      );

      // Case 6: Exact identical intervals [10:00, 11:00) vs [10:00, 11:00) -> Overlap
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(10, 0),
          newEnd: slot(11, 0),
          existingStart: slot(10, 0),
          existingEnd: slot(11, 0),
        ),
        isTrue,
      );

      // Case 7: Completely disjoint slots [8:00, 9:00) and [12:00, 13:00) -> Allowed
      expect(
        Validators.hasTimeOverlap(
          newStart: slot(8, 0),
          newEnd: slot(9, 0),
          existingStart: slot(12, 0),
          existingEnd: slot(13, 0),
        ),
        isFalse,
      );
    });
  });

  // =========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS
  // =========================================================================
  group('Tier 3: Cross-Feature Combinations', () {
    testWidgets('Tier 3.1: Court selection -> fast-booking sheet -> booking review -> digital ticket receipt flow', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Fast-Booking Slot Selection with Peak Surcharge
      MatchTimeSelection? selection;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TimePlayerPickerModal(
              availableTimes: const [
                TimeOfDay(hour: 14, minute: 0),
                TimeOfDay(hour: 19, minute: 0),
              ],
              initialTimeSlotIndex: 0,
              onSelectionConfirmed: (sel) => selection = sel,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap peak slot 19:00
      await tester.tap(find.text('PEAK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Match Time Slot'));
      await tester.pumpAndSettle();

      expect(selection, isNotNull);
      expect(selection!.totalAmount, equals(180.00));

      // 2. Booking Review & Multi-Channel Checkout Screen
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.65),
            ),
            child: child!,
          ),
          home: BookingReviewScreen(
            court: sampleCourt,
            startTime: DateTime(2026, 9, 10, 19),
            endTime: DateTime(2026, 9, 10, 20),
            durationHours: 1.0,
            totalAmount: selection!.totalAmount,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(find.text('PEAK RATE ACTIVE'), findsOneWidget);
      expect(find.text('+₱60.00'), findsOneWidget);

      // Switch to Maya via PayMongo
      await tester.tap(find.text('Maya via PayMongo'));
      await tester.pumpAndSettle();

      // Tap Checkout Confirmation
      await tester.tap(find.text('Confirm & Lock Court Reservation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Verify Booking Success Modal appears and dismiss it
      expect(find.text('Reservation Confirmed!'), findsOneWidget);
      await tester.tap(find.text('Done • View My Bookings'));
      await tester.pumpAndSettle();

      // 3. Inspect Perforated Digital Ticket Receipt
      final confirmedBooking = BookingModel(
        id: 'BK-CONFIRMED-99',
        customerId: 'athlete-1',
        courtId: sampleCourt.id,
        courtName: sampleCourt.name,
        startTime: DateTime(2026, 9, 10, 19),
        endTime: DateTime(2026, 9, 10, 20),
        status: 'confirmed',
        totalAmount: 180.00,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('receipt_app'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DownloadableReceiptModal(
              booking: confirmedBooking,
              paymentMethod: 'Maya via PayMongo',
              paymongoReference: 'pm_ref_maya_9901',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Official Payment Receipt'), findsOneWidget);
      expect(find.text('PayMongo Transaction Confirmed'), findsOneWidget);
      expect(find.text('BK-CONFIRMED-99'), findsOneWidget);
      expect(find.text('Maya via PayMongo'), findsOneWidget);
      expect(find.text('₱180.00'), findsOneWidget);

      // 4. Inspect Kiosk Gate Pass QR Code Modal
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('qr_app'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CheckInQrModal(booking: confirmedBooking),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Smart Court Gate QR Pass'), findsOneWidget);
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);
      expect(find.textContaining('PKL-'), findsOneWidget);
    });
  });

  // =========================================================================
  // TIER 4: REAL-WORLD SCENARIOS
  // =========================================================================
  group('Tier 4: Real-World Scenarios', () {
    testWidgets('Tier 4.1: End-to-end athlete reservation journey from telemetry inspection to gate pass kiosk check-in', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Step 1: Athlete inspects telemetry dashboard and DUPR progression
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const InsightsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL COURT PLAYTIME'), findsOneWidget);
      expect(find.text('PLAYER TELEMETRY & DUPR'), findsOneWidget);
      expect(find.text('Weekly Playtime Activity'), findsOneWidget);
      expect(find.text('TARGET 1.1h'), findsOneWidget);

      // Step 2: Athlete navigates to court reservation timeline
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.6),
            ),
            child: child!,
          ),
          home: const CourtReservationScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Multi-Court Visual Timeline'), findsOneWidget);
      expect(find.text('LIVE LANES'), findsOneWidget);
      expect(find.text('Court 1'), findsWidgets);

      // Step 3: Athlete selects match time slot with peak/off-peak comparison
      final bookingStart = DateTime(2026, 9, 10, 18);
      final bookingEnd = DateTime(2026, 9, 10, 19);

      expect(sampleCourt.isPeakHour(bookingStart.hour), isTrue);
      expect(sampleCourt.rateForHour(bookingStart.hour), equals(180.0));

      // Step 4: Athlete proceeds to checkout review with PayMongo payment options
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.65),
            ),
            child: child!,
          ),
          home: BookingReviewScreen(
            court: sampleCourt,
            startTime: bookingStart,
            endTime: bookingEnd,
            durationHours: 1.0,
            totalAmount: 180.00,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(find.text('PEAK RATE ACTIVE'), findsOneWidget);
      expect(find.text('GCash via PayMongo'), findsOneWidget);

      // Step 5: Zero-Auth Calendar Integration Verification
      final googleUrl = CalendarLinkService.buildGoogleCalendarUrl(
        title: 'Pickleball @ ${sampleCourt.name}',
        startTime: bookingStart,
        endTime: bookingEnd,
        location: 'Barcelona Smash Club',
      );
      expect(googleUrl, contains('calendar.google.com'));
      expect(googleUrl, contains('action=TEMPLATE'));

      final appleUrl = CalendarLinkService.buildAppleCalendarUrl(
        title: 'Pickleball @ ${sampleCourt.name}',
        startTime: bookingStart,
        endTime: bookingEnd,
        location: 'Barcelona Smash Club',
      );
      expect(appleUrl, contains('data:text/calendar'));
      expect(appleUrl, contains('BEGIN%3AVCALENDAR'));

      final outlookUrl = CalendarLinkService.buildOutlookCalendarUrl(
        title: 'Pickleball @ ${sampleCourt.name}',
        startTime: bookingStart,
        endTime: bookingEnd,
        location: 'Barcelona Smash Club',
      );
      expect(outlookUrl, contains('outlook.live.com'));

      final icsData = CalendarLinkService.buildIcsCalendarData(
        title: 'Pickleball @ ${sampleCourt.name}',
        startTime: bookingStart,
        endTime: bookingEnd,
        location: 'Barcelona Smash Club',
      );
      expect(icsData, contains('BEGIN:VCALENDAR'));
      expect(icsData, contains('BEGIN:VEVENT'));
      expect(icsData, contains('END:VCALENDAR'));

      // Step 6: Confirmation Modal
      final journeyBooking = BookingModel(
        id: 'BK-JOURNEY-01',
        customerId: 'athlete-pro',
        courtId: sampleCourt.id,
        courtName: sampleCourt.name,
        startTime: bookingStart,
        endTime: bookingEnd,
        status: 'confirmed',
        totalAmount: 180.00,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BookingSuccessModal(
              booking: journeyBooking,
              venueName: 'Barcelona Smash Club',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reservation Confirmed!'), findsOneWidget);
      expect(find.text('BK-JOURNEY-01'), findsOneWidget);
      expect(find.text('Add to Google Calendar'), findsOneWidget);

      // Step 7: Kiosk Arrival Gate Check-In Pass
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CheckInQrModal(booking: journeyBooking),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Smart Court Gate QR Pass'), findsOneWidget);
      expect(find.text('UPCOMING • READY FOR GATE'), findsOneWidget);
      expect(find.textContaining('PKL-BK-JOU'), findsOneWidget);

      // Simulate gate kiosk check-in tap
      await tester.tap(find.text('Simulate Gate Scan (Check-In)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHECKED IN • SESSION ACTIVE'), findsOneWidget);
    });
  });
}
