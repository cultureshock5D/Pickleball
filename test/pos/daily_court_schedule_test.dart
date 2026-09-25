import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/screens/pos/widgets/daily_court_schedule_view.dart';
import 'package:pickleball_app/services/pos_database.dart';

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

  setUp(() async {
    await PosDatabase.instance.initialize(forceMemory: true);
    await PosDatabase.instance.clearAll();
    MockData.resetToDefault();
  });

  tearDown(() async {
    await PosDatabase.instance.clearAll();
  });

  group('DailyCourtScheduleView Widget & Multi-Orientation Tests', () {
    testWidgets('Renders court schedule header, courts, and Navigation Menu tooltip', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          DailyCourtScheduleView(
            onBackToRegister: () {},
            onToggleMenu: () {},
            cashierId: 'cashier-sched-01',
            cashierName: 'Maria Santos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and menu button
      expect(find.text('Court Schedule & Walk-in Terminal'), findsOneWidget);
      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);

      // Verify date navigation buttons
      expect(find.byTooltip('Previous Day'), findsOneWidget);
      expect(find.byTooltip('Next Day'), findsOneWidget);
      expect(find.textContaining('Today'), findsWidgets);

      // Verify quick action button
      expect(find.text('+ Walk-In Booking'), findsOneWidget);

      // Verify court headers render
      expect(find.textContaining('Court 1'), findsWidgets);
      expect(find.textContaining('Court 2'), findsWidgets);
      expect(find.textContaining('Hoops 1'), findsWidgets);
      expect(find.textContaining('Events Place'), findsWidgets);
    });

    testWidgets('Allows date switching with Previous and Next day buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          DailyCourtScheduleView(
            onBackToRegister: () {},
            cashierId: 'cashier-sched-02',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Previous Day
      await tester.tap(find.byTooltip('Previous Day'));
      await tester.pumpAndSettle();

      // When moved to yesterday, "Today" quick button appears
      expect(find.text('Today'), findsOneWidget);

      // Tap "Today" to return to current date
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Tap Next Day
      await tester.tap(find.byTooltip('Next Day'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('Opens Walk-In Booking modal and allows creation flow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          DailyCourtScheduleView(
            onBackToRegister: () {},
            cashierId: 'cashier-sched-03',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap + Walk-In Booking button
      await tester.tap(find.text('+ Walk-In Booking'));
      await tester.pumpAndSettle();

      // Verify modal dialog opened
      expect(find.text('Cashier Walk-in Reservation'), findsOneWidget);
      expect(find.text('Court Selection'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('Guest Player Name *'), findsOneWidget);

      // Enter Guest Name
      await tester.enterText(find.byType(TextFormField).first, 'Coach Brandon');
      await tester.pumpAndSettle();

      // Tap Confirm Walk-In button
      await tester.tap(find.text('Confirm Walk-In'));
      await tester.pumpAndSettle();

      // Modal closed and booking created
      expect(find.text('Cashier Walk-in Reservation'), findsNothing);
    });

    testWidgets('Adapts to portrait mobile (400x800) with zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recordedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        recordedErrors.add(details);
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        _wrapWithTheme(
          DailyCourtScheduleView(
            onBackToRegister: () {},
            cashierId: 'cashier-sched-mobile',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero RenderFlex overflows
      final overflows = recordedErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(overflows, isEmpty);

      // Verify compact buttons render properly
      expect(find.text('POS'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Walk-In'), findsOneWidget);
      expect(find.byTooltip('Navigation Menu'), findsOneWidget);

      FlutterError.onError = originalOnError;
    });

    testWidgets('Adapts to compact landscape (720x380) with zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(720, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recordedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        recordedErrors.add(details);
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        _wrapWithTheme(
          DailyCourtScheduleView(
            onBackToRegister: () {},
            cashierId: 'cashier-sched-landscape',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final overflows = recordedErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(overflows, isEmpty);

      FlutterError.onError = originalOnError;
    });
  });
}
