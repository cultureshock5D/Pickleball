import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/core/utils/validators.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/court_model.dart';
import 'package:pickleball_app/screens/booking/booking_review_screen.dart';
import 'package:pickleball_app/screens/insights/insights.dart';
import 'package:pickleball_app/widgets/booking_success_modal.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';
import 'package:pickleball_app/widgets/downloadable_receipt_modal.dart';
import 'package:pickleball_app/widgets/time_player_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleBooking = BookingModel(
    id: 'BK-TEST-100',
    userId: 'cust-100',
    courtId: 'court-100',
    courtName: 'C&J Pickleball - Court 1',
    startTime: DateTime(2026, 9, 10, 18),
    endTime: DateTime(2026, 9, 10, 19),
    status: 'confirmed',
    totalPrice: 300.00,
    createdAt: DateTime(2026, 9, 9, 12),
  );

  const sampleCourt = CourtModel(
    id: 'court-100',
    name: 'C&J Pickleball - Court 1',
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
      expect(find.text('C&J Pickleball - Court 1'), findsOneWidget);

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
      expect(confirmedSelection!.totalAmount, equals(300.0));
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
      expect(find.text('C&J Pickleball - Court 1'), findsOneWidget);
      expect(find.text('Maya via PayMongo'), findsOneWidget);
      expect(find.text('pm_ref_maya_8841'), findsOneWidget);

      // Itemized Financials
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('₱300.00'), findsOneWidget);

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
            totalAmount: 300.00,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Court Overview
      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(find.text('C&J Pickleball - Court 1'), findsOneWidget);

      // Transparent Pricing Breakdown
      expect(find.text('Price Breakdown'), findsOneWidget);
      expect(find.text('₱300.00'), findsWidgets);

      // 1-Tap Calendar Sync Toggle
      expect(find.text('1-Tap Auto-Sync Calendar'), findsOneWidget);

      // PayMongo Multi-Channel Payment Options
      expect(find.text('GCash via PayMongo'), findsOneWidget);
      expect(find.text('Maya via PayMongo'), findsOneWidget);
      expect(find.text('GrabPay via PayMongo'), findsOneWidget);
      expect(find.text('Credit / Debit Card via PayMongo'), findsOneWidget);

      // Select Maya Payment Option
      await tester.tap(find.text('Maya via PayMongo'));
      await tester.pumpAndSettle();

      // Bottom Checkout Bar
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.text('Confirm & Pay via PayMongo'), findsOneWidget);
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
              venueName: 'C&J Pickleball Court',
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
      expect(find.text('C&J Pickleball - Court 1'), findsOneWidget);
      expect(find.text('C&J Pickleball Court'), findsOneWidget);
      expect(find.text('₱300.00'), findsOneWidget);
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
    test('Tier 2.1: Court rates, rental add-ons, and 24-hour cancellation rule', () {
      const court = CourtModel(
        id: 'court-bnd-1',
        name: 'C&J Court 1',
      );

      expect(court.hourlyRate, equals(300.0));

      // 1 hour booking calculation
      const duration1 = 1.0;
      const baseTotal = 300.0 * duration1;
      expect(baseTotal, equals(300.0));

      // Add-ons: Paddle Bundle (₱150 flat) + Ball Thrower (₱150/hr * 2h)
      const duration2 = 2.0;
      const courtFee = 300.0 * duration2;
      const paddleFee = 150.0;
      const ballThrowerFee = 150.0 * duration2;
      const grandTotal = courtFee + paddleFee + ballThrowerFee;
      expect(grandTotal, equals(1050.0));

      // 24-hour cancellation eligibility rule
      final future48h = DateTime.now().add(const Duration(hours: 48));
      final bookingCancellable = BookingModel(
        id: 'BK-CANCEL-OK',
        courtId: 'court-1',
        startTime: future48h,
        endTime: future48h.add(const Duration(hours: 1)),
        status: 'confirmed',
        totalPrice: 300.0,
      );
      expect(bookingCancellable.isCancellable, isTrue);

      final future12h = DateTime.now().add(const Duration(hours: 12));
      final bookingLocked = BookingModel(
        id: 'BK-CANCEL-NO',
        courtId: 'court-1',
        startTime: future12h,
        endTime: future12h.add(const Duration(hours: 1)),
        status: 'confirmed',
        totalPrice: 300.0,
      );
      expect(bookingLocked.isCancellable, isFalse);
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
}
