import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/theme/app_colors.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/widgets/brand_logo_painter.dart';
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
    });
  });
}
