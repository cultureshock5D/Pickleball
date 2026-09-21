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
  });
}

