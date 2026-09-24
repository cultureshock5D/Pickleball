import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/screens/home/landing_home_screen.dart';
import 'package:pickleball_app/screens/pos/pos_screen.dart';
import 'package:pickleball_app/screens/pos/widgets/daily_expenses_margins_view.dart';
import 'package:pickleball_app/screens/pos/widgets/inventory_table_view.dart';
import 'package:pickleball_app/screens/pos/widgets/recent_invoices_drawer.dart';
import 'package:pickleball_app/screens/pos/widgets/shift_reports_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Stress-Test: RecentInvoicesDrawer Viewports and Text Scaling', () {
    final viewports = [200.0, 250.0, 280.0, 320.0, 360.0, 460.0];
    final textScales = [1.0, 1.5, 2.0];

    for (final width in viewports) {
      for (final scale in textScales) {
        testWidgets('Width: ${width}dp, TextScale: ${scale}x', (WidgetTester tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          List<FlutterErrorDetails> errors = [];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            oldHandler?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SizedBox(
                    width: width,
                    child: const RecentInvoicesDrawer(
                      currentCashierId: 'cashier-001',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          FlutterError.onError = oldHandler;

          final overflowErrors = errors.where((e) => e.toString().contains('RenderFlex overflowed')).toList();
          if (overflowErrors.isNotEmpty) {
            final lines = overflowErrors.map((e) {
              final str = e.toString();
              final match = RegExp(r'A RenderFlex overflowed by (\d+ pixels) on the right.*?Row:(.*?):(\d+):(\d+)', dotAll: true).firstMatch(str);
              if (match != null) {
                return 'Overflowed by ${match.group(1)} at line ${match.group(3)}';
              }
              final simpleMatch = RegExp(r'A RenderFlex overflowed by (\d+ pixels)').firstMatch(str);
              return 'Overflowed by ${simpleMatch?.group(1) ?? "unknown amount"}';
            }).toSet().toList();
            debugPrint('STRESS-RESULT: [FAIL] Width ${width}dp @ ${scale}x scale -> ${lines.join(", ")}');
          } else {
            debugPrint('STRESS-RESULT: [PASS] Width ${width}dp @ ${scale}x scale');
          }

          expect(
            overflowErrors,
            isEmpty,
            reason: 'RenderFlex overflow occurred on width: ${width}dp, textScale: ${scale}x',
          );
        });
      }
    }
  });

  group('Adversarial A11y & Touch Target Test: LandingHomeScreen Hero Chevrons', () {
    testWidgets('Previous and Next slide chevrons have >=48x48dp hit-testable bounds and function without distortion', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LandingHomeScreen(
            onBookCourtPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevFinder = find.bySemanticsLabel('Previous slide');
      final nextFinder = find.bySemanticsLabel('Next slide');

      expect(prevFinder, findsOneWidget, reason: 'Previous slide button should exist with semantics label');
      expect(nextFinder, findsOneWidget, reason: 'Next slide button should exist with semantics label');

      final prevSize = tester.getSize(prevFinder);
      final nextSize = tester.getSize(nextFinder);

      expect(
        prevSize.width,
        greaterThanOrEqualTo(48.0),
        reason: 'Previous slide width must be >= 48dp, but was ${prevSize.width}',
      );
      expect(
        prevSize.height,
        greaterThanOrEqualTo(48.0),
        reason: 'Previous slide height must be >= 48dp, but was ${prevSize.height}',
      );

      expect(
        nextSize.width,
        greaterThanOrEqualTo(48.0),
        reason: 'Next slide width must be >= 48dp, but was ${nextSize.width}',
      );
      expect(
        nextSize.height,
        greaterThanOrEqualTo(48.0),
        reason: 'Next slide height must be >= 48dp, but was ${nextSize.height}',
      );

      // Verify tapping at the hit-test bounds doesn't throw and triggers smooth transition
      await tester.tap(prevFinder);
      await tester.pumpAndSettle();

      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
    });
  });

  group('Adversarial Navigation Menu Tooltip Consistency Across POS Views', () {
    testWidgets('DailyExpensesMarginsView provides tooltip "Navigation Menu"', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DailyExpensesMarginsView(
            onBackToRegister: () {},
            onToggleMenu: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });

    testWidgets('InventoryTableView provides tooltip "Navigation Menu"', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryTableView(
            onBackToRegister: () {},
            onToggleMenu: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });

    testWidgets('ShiftReportsView provides tooltip "Navigation Menu"', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ShiftReportsView(
            onBackToRegister: () {},
            onToggleMenu: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });

    testWidgets('PosScreen provides tooltip "Navigation Menu"', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PosScreen(
            cashierId: 'cashier-test-01',
            cashierName: 'Maria Santos',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });
  });
}
