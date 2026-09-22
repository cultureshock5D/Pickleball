import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/screens/pos/pos_auth_screen.dart';
import 'package:pickleball_app/screens/pos/pos_screen.dart';
import 'package:pickleball_app/screens/pos/widgets/supervisor_pin_modal.dart';

void main() {
  group('POS Widget Rendering & Smoke Tests', () {
    testWidgets('PosAuthScreen renders staff login title and email/password fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PosAuthScreen(),
        ),
      );

      expect(find.text('C&J ARENA POS TERMINAL'), findsOneWidget);
      expect(find.text('Cashier & Pro Shop Staff Register Only'), findsOneWidget);
      expect(find.text('Sign In to POS Register'), findsOneWidget);
      expect(find.text('Switch to Player Court Reservations'), findsOneWidget);
      expect(find.text('Demo Cashier'), findsNothing);
      expect(find.text('Demo Admin'), findsNothing);
    });

    testWidgets('SupervisorPinModal displays keypad and PIN dots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SupervisorPinModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Supervisor Authorization'), findsOneWidget);
      expect(find.text('Enter 4-digit Master PIN to proceed'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('PosScreen renders top bar, catalog tabs, and cart panel in tablet layout', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('C&J POS REGISTER'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('CASHIER'), findsOneWidget);
      expect(find.text('Coffee'), findsWidgets);
      expect(find.text('Drinks'), findsWidgets);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Active Order (0 items)'), findsOneWidget);
      expect(find.text('GCash / QR Ph'), findsNothing);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Credit / Debit Card'), findsNothing);
    });

    testWidgets('PosScreen blocks unauthorized non-cashier player account', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PosScreen(
            cashierId: 'player-test-01',
            cashierName: 'Regular Player',
            cashierRole: 'client',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Cashier & Pro Shop Staff register only.'), findsOneWidget);
    });

    testWidgets('PosScreen renders mobile logout button in header bar and sidebar drawer', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
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
      await tester.pumpAndSettle();

      // Verify compact header contains direct Sign Out icon button
      final headerLogoutBtn = find.byTooltip('Sign Out / Close Register');
      expect(headerLogoutBtn, findsOneWidget);

      // Tap header logout button and verify confirmation dialog appears
      await tester.tap(headerLogoutBtn);
      await tester.pumpAndSettle();

      expect(find.text('Close Cashier Register?'), findsOneWidget);
      expect(find.text('You will be signed out of the POS terminal.'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Close Cashier Register?'), findsNothing);

      // Open mobile drawer
      final menuBtn = find.byTooltip('Navigation Menu');
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Drawer contains "Sign Out / Close Register"
      expect(find.text('Sign Out / Close Register'), findsOneWidget);
    });

    testWidgets('PosScreen horizontal phone layout hides active orders and allows opening operations drawer', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
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
      await tester.pumpAndSettle();

      // Active orders pane is hidden while ordering on horizontal phone
      expect(find.text('Active Order (0 items)'), findsNothing);
      expect(find.text('View Cart'), findsOneWidget);

      // Operations menu button is available on horizontal
      final menuBtn = find.byTooltip('Navigation Menu');
      expect(menuBtn, findsOneWidget);

      // Tap menu button - operations drawer pops up!
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      expect(find.text('OPERATIONS MENU'), findsOneWidget);
      expect(find.text('OPERATIONS'), findsOneWidget);
      expect(find.text('C&J POS REGISTER'), findsOneWidget);
      expect(find.text('Inventory Table'), findsOneWidget);
      expect(find.text('Shift Reports'), findsOneWidget);

      // Close drawer using its top close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('OPERATIONS MENU'), findsNothing);

      // Tap View Cart to open modal cart
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();

      // Active orders now pops up in modal bottom sheet
      expect(find.text('Active Order (0 items)'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap close button in cart modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Active Order (0 items)'), findsNothing);
    });

    testWidgets('PosScreen tablet dual-pane layout supports toggling cart pane', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
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
      await tester.pumpAndSettle();

      // Dual pane layout initially visible
      expect(find.text('Active Order (0 items)'), findsOneWidget);
      expect(find.text('Hide Cart'), findsOneWidget);

      // Tap Hide Cart to collapse order pane
      await tester.tap(find.text('Hide Cart'));
      await tester.pumpAndSettle();

      expect(find.text('Active Order (0 items)'), findsNothing);
      expect(find.text('Show Cart'), findsOneWidget);
      expect(find.text('View Cart'), findsOneWidget);

      // Tap Show Cart to restore dual pane
      await tester.tap(find.text('Show Cart'));
      await tester.pumpAndSettle();

      expect(find.text('Active Order (0 items)'), findsOneWidget);
      expect(find.text('Hide Cart'), findsOneWidget);
    });
  });
}


