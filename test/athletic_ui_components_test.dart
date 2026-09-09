import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/theme/app_colors.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/screens/home/landing_home_screen.dart';
import 'package:pickleball_app/widgets/brand_logo_painter.dart';
import 'package:pickleball_app/widgets/court_visualizer.dart';
import 'package:pickleball_app/widgets/perforated_ticket_divider.dart';
import 'package:pickleball_app/widgets/refund_request_modal.dart';
import 'package:pickleball_app/widgets/status_badge.dart';
import 'package:pickleball_app/widgets/tap_collapse.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Athletic UI/UX Components Tests (UI-Context)', () {
    testWidgets('BrandLogoWidget renders custom painted court monogram', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandLogoWidget(size: 48),
            ),
          ),
        ),
      );

      expect(find.byType(BrandLogoWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BrandLogoWidget),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('StatusBadge renders variant labels and colors correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(label: 'Confirmed', variant: BadgeVariant.success),
                StatusBadge(label: 'Cancelled', variant: BadgeVariant.alert),
                StatusBadge(label: 'Member Pass', variant: BadgeVariant.dark),
                StatusBadge(label: 'Indoor Spec'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('MEMBER PASS'), findsOneWidget);
      expect(find.text('INDOOR SPEC'), findsOneWidget);
    });

    testWidgets('TapCollapse responds to press gestures', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TapCollapse(
                onTap: () => tapped = true,
                child: const Text('Press Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Press Me'), findsOneWidget);

      await tester.tap(find.text('Press Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('RefundRequestModal displays 24-hour policy verification and wallet options', (WidgetTester tester) async {
      final eligibleBooking = BookingModel(
        id: 'BK-REFUND-001',
        userId: 'user-1',
        courtId: 'court-1',
        courtName: 'Court 1 — Indoor (Pro Cushion)',
        startTime: DateTime.now().add(const Duration(hours: 48)),
        endTime: DateTime.now().add(const Duration(hours: 50)),
        status: 'paid',
        totalPrice: 600.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefundRequestModal(booking: eligibleBooking),
          ),
        ),
      );

      expect(find.text('REQUEST REFUND'), findsOneWidget);
      expect(find.textContaining('Court 1 — Indoor'), findsOneWidget);
      expect(find.textContaining('Eligible for 100% full refund'), findsOneWidget);
      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Bank Transfer'), findsOneWidget);
      expect(find.text('CONFIRM CANCELLATION & SUBMIT REFUND'), findsOneWidget);
    });

    test('AppColors token values adhere to design specification', () {
      expect(AppColors.ink, const Color(0xFF111111));
      expect(AppColors.canvas, const Color(0xFFFFFFFF));
      expect(AppColors.courtSuccess, const Color(0xFF007D48));
      expect(AppColors.saleRed, const Color(0xFFD30005));
      expect(AppColors.warningAmber, const Color(0xFFE65100));
    });

    testWidgets('PerforatedTicketDivider renders custom paint with radius cutouts', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerforatedTicketDivider(cutoutRadius: 14.0),
          ),
        ),
      );

      expect(find.byType(PerforatedTicketDivider), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PerforatedTicketDivider),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('CourtVisualizerWidget renders USAP blueprint and zone switcher', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CourtVisualizerWidget(courtName: 'C&J Test Court'),
            ),
          ),
        ),
      );

      expect(find.text('TECHNICAL BLUEPRINT'), findsOneWidget);
      expect(find.text("20' × 44' USAP COURT ARCHITECTURE"), findsOneWidget);
      expect(find.text('C&J Test Court'), findsOneWidget);
      expect(find.text('The Kitchen (NVZ)'), findsOneWidget);
      expect(find.text('Right Service Court'), findsOneWidget);
      expect(find.text('Left Service Court'), findsOneWidget);
      expect(find.text('Championship Net'), findsOneWidget);
      expect(find.text('Baseline & 8mm Cushion'), findsOneWidget);

      // Switch to Right Service Court
      await tester.tap(find.text('Right Service Court'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Right Service Court (Even / Server 1)'), findsOneWidget);
    });

    testWidgets('LandingHomeScreen renders hero banner, featured courts and FAQs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool bookPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LandingHomeScreen(
            onBookCourtPressed: () => bookPressed = true,
          ),
        ),
      );

      expect(find.text('C&J CHAMPIONSHIP ARENA'), findsOneWidget);
      expect(find.text('SERVE WITH FORCE.\nOWN THE COURT.'), findsOneWidget);
      expect(find.text('FEATURED TOURNAMENT COURTS'), findsOneWidget);
      expect(find.text('Court 1 — Pro Cushion'), findsOneWidget);
      expect(find.text('Court 2 — Tournament Spec'), findsOneWidget);
      expect(find.text('PRO SHOP ADD-ONS'), findsOneWidget);
      expect(find.text('THE KITCHEN HAS RULES. PLAY BY THEM.'), findsOneWidget);
      expect(find.text('POLICIES & VENUE GUIDELINES'), findsOneWidget);

      // Tap Book Court
      await tester.tap(find.text('Book Court — ₱300/hr'));
      await tester.pumpAndSettle();
      expect(bookPressed, isTrue);
    });
  });
}
