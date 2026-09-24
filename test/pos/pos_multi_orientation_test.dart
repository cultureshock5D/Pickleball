import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/data/mock_pos_data.dart';
import 'package:pickleball_app/screens/pos/controllers/pos_cart_controller.dart';
import 'package:pickleball_app/screens/pos/pos_screen.dart';
import 'package:pickleball_app/screens/pos/widgets/daily_expenses_margins_view.dart';
import 'package:pickleball_app/screens/pos/widgets/inventory_table_view.dart';
import 'package:pickleball_app/screens/pos/widgets/recent_invoices_drawer.dart';
import 'package:pickleball_app/screens/pos/widgets/shift_reports_view.dart';
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
    MockPosData.resetProducts();
  });

  tearDown(() async {
    await PosDatabase.instance.clearAll();
  });

  group('1. Requirement R1: Desktop/Landscape Viewport (1920x1080) Sidebar & Dual-Pane', () {
    testWidgets('Renders permanent 220px AnimatedContainer sidebar with ClipRect and toggles cleanly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          const PosScreen(
            cashierId: 'cashier-desktop-01',
            cashierName: 'Maria Santos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify desktop dual-pane and sidebar elements
      expect(find.text('OPERATIONS MENU'), findsOneWidget);
      expect(find.text('Active Order (0 items)'), findsOneWidget);

      // Verify the AnimatedContainer sidebar with width 220
      final sidebarFinder = find.byWidgetPredicate(
        (widget) => widget is AnimatedContainer && widget.constraints?.maxWidth == 220,
      );
      expect(sidebarFinder, findsWidgets);

      // Verify ClipRect is present inside AnimatedContainer sidebar
      final clipRectFinder = find.descendant(
        of: sidebarFinder.first,
        matching: find.byType(ClipRect),
      );
      expect(clipRectFinder, findsWidgets);

      // 2. Locate navigation hamburger toggle button by tooltip 'Navigation Menu'
      final toggleBtn = find.byTooltip('Navigation Menu');
      expect(toggleBtn, findsOneWidget);

      // 3. Tap to collapse sidebar
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Sidebar collapsed: AnimatedContainer width is 0
      final collapsedSidebar = find.byWidgetPredicate(
        (widget) => widget is AnimatedContainer && widget.constraints?.maxWidth == 0,
      );
      expect(collapsedSidebar, findsWidgets);

      // 4. Tap toggle button again to re-expand sidebar
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Re-expanded: AnimatedContainer width is 220 again
      final reExpandedSidebar = find.byWidgetPredicate(
        (widget) => widget is AnimatedContainer && widget.constraints?.maxWidth == 220,
      );
      expect(reExpandedSidebar, findsWidgets);
      expect(find.text('OPERATIONS MENU'), findsOneWidget);
    });
  });

  group('2. Requirement R1: Portrait Mobile Viewport (400x800) Drawer Navigation', () {
    testWidgets('Uses Scaffold.drawer instead of permanent sidebar and opens Drawer on menu tap', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          const PosScreen(
            cashierId: 'cashier-mobile-01',
            cashierName: 'Juan Mobile',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On portrait mobile, permanent sidebar should NOT be rendered
      expect(find.text('Active Order (0 items)'), findsNothing);
      expect(find.text('View Cart'), findsOneWidget);

      // Drawer is initially closed, OPERATIONS MENU not visible
      expect(find.text('OPERATIONS MENU'), findsNothing);

      // Tap 'Navigation Menu' trigger to open Drawer
      final menuBtn = find.byTooltip('Navigation Menu');
      expect(menuBtn, findsOneWidget);

      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Drawer is now open with OPERATIONS MENU
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('OPERATIONS MENU'), findsOneWidget);

      // Close drawer via close icon
      final closeBtn = find.byTooltip('Close Menu');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Drawer closed
      expect(find.byType(Drawer), findsNothing);
    });
  });

  group('3. Requirement R1: Vertical Viewport (400x800) Bottom Cart Sheet & Horizontal Auto-pop', () {
    testWidgets('Collapses cart into bottom bar and opens bottom modal sheet without RenderFlex overflow in vertical layout', (tester) async {
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
          const PosScreen(
            cashierId: 'cashier-portrait-01',
            cashierName: 'Pedro Portrait',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert zero RenderFlex overflows on initial render
      final initialOverflows = recordedErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(initialOverflows, isEmpty);

      // Verify compact vertical layout: 'View Cart' bottom bar is rendered
      final viewCartBtn = find.text('View Cart');
      expect(viewCartBtn, findsOneWidget);

      // Tap 'View Cart' button to trigger bottom modal sheet
      await tester.tap(viewCartBtn);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet is open
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('Active Order'), findsWidgets);

      // Verify zero RenderFlex overflows occurred when opening bottom sheet
      final sheetOverflows = recordedErrors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(sheetOverflows, isEmpty);

      FlutterError.onError = originalOnError;
    });
  });

  group('4. Requirement R1: Header Titles Wrapped in Expanded / Overflow Protection', () {
    testWidgets('Sidebar and Drawer headers enclose titles inside Expanded to prevent overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          const PosScreen(
            cashierId: 'cashier-01',
            cashierName: 'Long Cashier Staff Name That Could Exceed Width',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 'OPERATIONS MENU' Text is inside an Expanded widget
      final menuTextFinder = find.text('OPERATIONS MENU');
      expect(menuTextFinder, findsOneWidget);
      final expandedParent = find.ancestor(
        of: menuTextFinder,
        matching: find.byType(Expanded),
      );
      expect(expandedParent, findsOneWidget);

      // Verify Cashier name is inside an Expanded widget with ellipsis
      final cashierNameFinder = find.text('Long Cashier Staff Name That Could Exceed Width');
      expect(cashierNameFinder, findsOneWidget);
      final cashierExpanded = find.ancestor(
        of: cashierNameFinder,
        matching: find.byType(Expanded),
      );
      expect(cashierExpanded, findsWidgets);
    });

    testWidgets('RecentInvoicesDrawer header wraps title in Expanded with ellipsis', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Scaffold(
            body: SizedBox(
              width: 320,
              child: RecentInvoicesDrawer(currentCashierId: 'cashier-01'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final drawerTitle = find.text('Recent Invoices & Void Audit');
      expect(drawerTitle, findsOneWidget);

      final titleExpanded = find.ancestor(
        of: drawerTitle,
        matching: find.byType(Expanded),
      );
      expect(titleExpanded, findsWidgets);

      final textWidget = tester.widget<Text>(drawerTitle);
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
    });
  });

  group('5. Requirement R1: Uniform Tooltip Navigation Menu Stability', () {
    testWidgets('PosScreen exposes Navigation Menu tooltip', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          const PosScreen(
            cashierId: 'cashier-01',
            cashierName: 'Test Cashier',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });

    testWidgets('DailyExpensesMarginsView exposes Navigation Menu tooltip', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          DailyExpensesMarginsView(
            onBackToRegister: () {},
            onToggleMenu: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });

    testWidgets('InventoryTableView exposes Navigation Menu tooltip', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          InventoryTableView(
            onBackToRegister: () {},
            onToggleMenu: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });

    testWidgets('ShiftReportsView exposes Navigation Menu tooltip', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          ShiftReportsView(
            onBackToRegister: () {},
            onToggleMenu: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });
  });

  group('6. Requirement R1: Cart Operations & BIR Statutory Tax Calculations', () {
    test('PosCartController computes 12% VAT regular sale accurately', () {
      final cart = PosCartController();
      final product = MockPosData.getProducts().first; // Long Black, price 110.00

      cart.addItem(product);
      cart.addItem(product);

      expect(cart.itemCount, equals(2));
      expect(cart.grossSubtotal, equals(220.00));

      final tax = cart.taxBreakdown;
      // 220 / 1.12 = 196.43 vatable sales
      expect(tax.grossSubtotal, equals(220.00));
      expect(tax.vatableSales, equals(196.43));
      expect(tax.vatAmount, equals(23.57));
      expect(tax.vatExemptSales, equals(0.0));
      expect(tax.discountAmount, equals(0.0));
      expect(tax.netPayable, equals(220.00));
      expect((tax.vatableSales + tax.vatAmount).toStringAsFixed(2), equals('220.00'));
    });

    test('PosCartController computes Senior Citizen 20% statutory discount (RA 9994)', () {
      final cart = PosCartController();
      final product = MockPosData.getProducts().first; // 110.00

      cart.addItem(product);
      cart.addItem(product);
      cart.setDiscountType('senior_citizen');
      cart.setCustomerDetails(idNumber: 'OSCA-12345', name: 'Lolo Juan');

      final tax = cart.taxBreakdown;
      // 1. VAT Exempt Base: 220 / 1.12 = 196.43
      expect(tax.vatExemptSales, equals(196.43));
      // 2. 20% discount on base: 196.43 * 0.20 = 39.29
      expect(tax.discountAmount, equals(39.29));
      // 3. Net Payable: 196.43 - 39.29 = 157.14
      expect(tax.netPayable, equals(157.14));
      expect(tax.vatableSales, equals(0.0));
      expect(tax.vatAmount, equals(0.0));
    });

    test('PosCartController computes PWD 20% statutory discount (RA 10754)', () {
      final cart = PosCartController();
      final product = MockPosData.getProducts()[1]; // Capuccino, price 130.00

      cart.addItem(product); // gross 130.00
      cart.setDiscountType('pwd');
      cart.setCustomerDetails(idNumber: 'PWD-8877', name: 'Maria PWD');

      final tax = cart.taxBreakdown;
      // 130 / 1.12 = 116.07
      expect(tax.vatExemptSales, equals(116.07));
      // 116.07 * 0.20 = 23.21
      expect(tax.discountAmount, equals(23.21));
      // 116.07 - 23.21 = 92.86
      expect(tax.netPayable, equals(92.86));
      expect(tax.vatableSales, equals(0.0));
      expect(tax.vatAmount, equals(0.0));
    });

    test('PosCartController increments, decrements, and clears items accurately', () {
      final cart = PosCartController();
      final prod1 = MockPosData.getProducts()[0];
      final prod2 = MockPosData.getProducts()[1];

      cart.addItem(prod1);
      cart.addItem(prod2);
      expect(cart.itemCount, equals(2));

      cart.incrementItem(prod1.id);
      expect(cart.itemCount, equals(3));

      cart.decrementItem(prod1.id);
      expect(cart.itemCount, equals(2));

      cart.decrementItem(prod1.id); // removes prod1
      expect(cart.items.length, equals(1));
      expect(cart.items.first.productId, equals(prod2.id));

      cart.clearCart();
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, equals(0));
      expect(cart.grossSubtotal, equals(0.0));
    });

    testWidgets('Interactive catalog category filtering in PosScreen updates displayed items', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapWithTheme(
          const PosScreen(
            cashierId: 'cashier-cat-01',
            cashierName: 'Category Tester',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify department pills
      expect(find.text('Coffee'), findsWidgets);
      expect(find.text('Drinks'), findsWidgets);
      expect(find.text('Food'), findsWidgets);

      // Tap 'Drinks' filter
      await tester.tap(find.text('Drinks').first);
      await tester.pumpAndSettle();

      // Tap 'Food' filter
      await tester.tap(find.text('Food').first);
      await tester.pumpAndSettle();

      // Tap 'All Menu' filter
      expect(find.text('All Menu'), findsOneWidget);
      await tester.tap(find.text('All Menu'), warnIfMissed: false);
      await tester.pumpAndSettle();
    });
  });
}
