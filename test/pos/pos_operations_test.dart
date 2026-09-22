import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/daily_expense_model.dart';
import 'package:pickleball_app/screens/pos/pos_screen.dart';
import 'package:pickleball_app/screens/pos/widgets/inventory_table_view.dart';
import 'package:pickleball_app/screens/pos/widgets/daily_expenses_margins_view.dart';
import 'package:pickleball_app/screens/pos/widgets/shift_reports_view.dart';
import 'package:pickleball_app/services/pos_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PosService Operations Tests', () {
    final posService = PosService.instance;

    test('fetchInventoryProducts returns products with valid fields', () async {
      final products = await posService.fetchInventoryProducts();
      expect(products, isNotEmpty);
      final first = products.first;
      expect(first.name, isNotEmpty);
      expect(first.price, greaterThan(0));
      expect(first.category, isNotEmpty);
    });

    test('updateProductStock modifies stock level', () async {
      final products = await posService.fetchInventoryProducts();
      final target = products.first;
      final originalStock = target.stockLevel;
      final newStock = originalStock + 5;

      final success = await posService.updateProductStock(target.id, newStock);
      expect(success, isTrue);

      final updatedProducts = await posService.fetchInventoryProducts();
      final updated = updatedProducts.firstWhere((p) => p.id == target.id);
      expect(updated.stockLevel, equals(newStock));
    });

    test('fetchDailyExpenses returns expense records', () async {
      final expenses = await posService.fetchDailyExpenses();
      expect(expenses, isNotEmpty);
      expect(expenses.first.title, isNotEmpty);
      expect(expenses.first.amount, greaterThan(0));
    });

    test('createDailyExpense adds new expense to list', () async {
      final newExpense = DailyExpenseModel(
        id: 'test-exp-01',
        expenseDate: DateTime.now(),
        category: 'supplies',
        title: 'Test Coffee Filters',
        amount: 350.00,
        createdAt: DateTime.now(),
      );

      final created = await posService.createDailyExpense(newExpense);
      expect(created, isNotNull);
      expect(created!.title, equals('Test Coffee Filters'));
      expect(created.amount, equals(350.00));

      final all = await posService.fetchDailyExpenses();
      expect(all.any((e) => e.title == 'Test Coffee Filters'), isTrue);
    });

    test('fetchDutySessions returns duty sessions with on-duty status', () async {
      final sessions = await posService.fetchDutySessions();
      expect(sessions, isNotEmpty);
      expect(sessions.any((s) => s.isOnDuty), isTrue);
      expect(sessions.first.openingFloat, greaterThan(0));
    });

    test('computeDailyMargins calculates financial KPIs correctly', () async {
      final margins = await posService.computeDailyMargins();
      expect(margins.containsKey('grossRevenue'), isTrue);
      expect(margins.containsKey('cogs'), isTrue);
      expect(margins.containsKey('grossProfit'), isTrue);
      expect(margins.containsKey('grossMarginPercent'), isTrue);
      expect(margins.containsKey('totalOperatingExpenses'), isTrue);
      expect(margins.containsKey('netProfit'), isTrue);
      expect(margins.containsKey('netMarginPercent'), isTrue);
      expect(margins.containsKey('transactionCount'), isTrue);
      expect(margins.containsKey('itemsSold'), isTrue);
    });
  });

  group('POS Operations Widgets Smoke Tests', () {
    testWidgets('InventoryTableView renders without error', (tester) async {
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inventory & Stock Control'), findsOneWidget);
      expect(find.text('TOTAL SKUS'), findsOneWidget);
      expect(find.text('PRODUCT NAME'), findsOneWidget);
    });

    testWidgets('DailyExpensesMarginsView renders without error', (tester) async {
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Expenses & Margins'), findsOneWidget);
      expect(find.text('GROSS SALES'), findsOneWidget);
      expect(find.text('Record Expense'), findsOneWidget);
    });

    testWidgets('ShiftReportsView renders without error', (tester) async {
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shift & Drawer Reports (Z-Reading)'), findsOneWidget);
      expect(find.text('CASH DRAWER & TENDER BREAKDOWN'), findsOneWidget);
      expect(find.text('BIR STATUTORY TAX & VOID AUDIT'), findsOneWidget);
    });

    testWidgets('PosScreen allows navigation to Inventory, Expenses, and Shift Reports', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PosScreen(
            cashierId: 'cashier-001',
            cashierName: 'Maria Santos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Inventory Table
      expect(find.text('Inventory Table'), findsOneWidget);
      await tester.tap(find.text('Inventory Table'));
      await tester.pumpAndSettle();
      expect(find.text('Inventory & Stock Control'), findsOneWidget);

      // Open Daily Expenses & Margins
      expect(find.text('Daily Expenses & Margins'), findsOneWidget);
      await tester.tap(find.text('Daily Expenses & Margins'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Expenses & Margins'), findsWidgets);

      // Open Shift Reports
      expect(find.text('Shift Reports'), findsOneWidget);
      await tester.tap(find.text('Shift Reports'));
      await tester.pumpAndSettle();
      expect(find.text('Shift & Drawer Reports (Z-Reading)'), findsOneWidget);

      // Return to Register
      expect(find.text('C&J POS REGISTER'), findsOneWidget);
      await tester.tap(find.text('C&J POS REGISTER'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsWidgets);
    });
  });
}
