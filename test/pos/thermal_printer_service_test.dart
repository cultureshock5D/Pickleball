import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/pos_transaction_model.dart';
import 'package:pickleball_app/screens/pos/widgets/pos_printer_debug_modal.dart';
import 'package:pickleball_app/screens/pos/widgets/thermal_receipt_modal.dart';
import 'package:pickleball_app/services/thermal_printer_service.dart';

void main() {
  group('ThermalPrinterService Tests', () {
    test('generateTestReceiptBytes generates valid ESC/POS byte sequence', () {
      final bytes = ThermalPrinterService.generateTestReceiptBytes();

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(200));

      // ESC @ (Initialize)
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);

      // Verify receipt contains brand name and test markers
      final text = String.fromCharCodes(bytes);
      expect(text.contains('C&J SPORTS ARENA POS'), isTrue);
      expect(text.contains('JP58H-0A4B (58mm)'), isTrue);
      expect(text.contains('TEST PRINT SUCCESSFUL'), isTrue);
      expect(text.endsWith('\n\n\n\n'), isTrue);
    });

    test('PrinterResult model constructor holds correct state', () {
      const successResult = PrinterResult(
        success: true,
        message: 'Printed to JP58H-0A4B',
        deviceName: 'JP58H-0A4B',
      );

      expect(successResult.success, isTrue);
      expect(successResult.message, 'Printed to JP58H-0A4B');
      expect(successResult.deviceName, 'JP58H-0A4B');

      const errorResult = PrinterResult(
        success: false,
        message: 'Port COM4 busy',
      );

      expect(errorResult.success, isFalse);
      expect(errorResult.deviceName, isNull);
    });

    test('print58mmReceipt clamps non-byte characters without throwing', () async {
      // Contains out-of-range integer (0x20B1 = 8369 for peso symbol)
      final badBytes = [0x1B, 0x40, 0x20B1, 65, 66, 67];
      final result = await ThermalPrinterService.print58mmReceipt(badBytes);
      // Ensure it does not crash or throw RangeError
      expect(result, isNotNull);
    });

    test('ThermalReceiptModal formats 80mm plain text receipt with all item names and prices', () {
      final sampleTx = PosTransactionModel(
        id: 'tx-test-01',
        invoiceNumber: 'INV-2026-00001',
        cashierId: 'c1',
        cashierName: 'Jane Doe',
        paymentMethod: 'cash',
        grossAmount: 300.0,
        discountAmount: 0.0,
        vatableSales: 267.86,
        vatAmount: 32.14,
        vatExemptSales: 0.0,
        totalAmount: 300.0,
        createdAt: DateTime(2026, 9, 21, 14, 30),
        items: const [
          PosTransactionItemModel(
            id: 'item-1',
            transactionId: 'tx-test-01',
            productId: 'prod-1',
            productName: 'Long Black',
            quantity: 1,
            priceAtTime: 120.0,
          ),
          PosTransactionItemModel(
            id: 'item-2',
            transactionId: 'tx-test-01',
            productId: 'prod-2',
            productName: 'Pancit Canton Sweet & Spicy',
            quantity: 2,
            priceAtTime: 65.0,
          ),
          PosTransactionItemModel(
            id: 'item-3',
            transactionId: 'tx-test-01',
            productId: 'prod-3',
            productName: '   ',
            quantity: 1,
            priceAtTime: 50.0,
          ),
        ],
      );

      final text = ThermalReceiptModal.generatePlainTextReceipt(sampleTx);

      expect(text.contains('ITEM                     QTY         TOTAL'), isTrue);
      // Item 1: standard name
      expect(text.contains('Long Black'), isTrue);
      expect(text.contains('₱120.00'), isTrue);
      // Item 2: long name wrapping
      expect(text.contains('Pancit Canton Sweet & Spicy'), isTrue);
      expect(text.contains('₱130.00'), isTrue);
      // Item 3: whitespace fallback to 'Item'
      expect(text.contains('Item'), isTrue);
      // Total amount
      expect(text.contains('TOTAL DUE:'), isTrue);
      expect(text.contains('₱300.00'), isTrue);
    });

    test('ThermalReceiptModal formats 58mm ESC/POS bytes without omitting item names', () {
      final sampleTx = PosTransactionModel(
        id: 'tx-test-02',
        invoiceNumber: 'INV-2026-00002',
        cashierId: 'c1',
        cashierName: 'Jane Doe',
        paymentMethod: 'cash',
        grossAmount: 300.0,
        discountAmount: 0.0,
        vatableSales: 267.86,
        vatAmount: 32.14,
        vatExemptSales: 0.0,
        totalAmount: 300.0,
        createdAt: DateTime(2026, 9, 21, 14, 30),
        items: const [
          PosTransactionItemModel(
            id: 'item-1',
            transactionId: 'tx-test-02',
            productId: 'prod-1',
            productName: 'Long Black',
            quantity: 1,
            priceAtTime: 120.0,
          ),
          PosTransactionItemModel(
            id: 'item-2',
            transactionId: 'tx-test-02',
            productId: 'prod-2',
            productName: 'Pancit Canton Sweet & Spicy',
            quantity: 2,
            priceAtTime: 65.0,
          ),
        ],
      );

      final bytes = ThermalReceiptModal.generatePos58Bytes(sampleTx);
      final rawText = String.fromCharCodes(bytes);

      expect(bytes.first, 0x1B); // ESC @
      expect(rawText.contains('C&J EVENTS & SPORTS ARENA'), isTrue);
      expect(rawText.contains('Long Black'), isTrue);
      expect(rawText.contains('P120.00'), isTrue);
      expect(rawText.contains('Pancit Canton Sweet & Spicy'), isTrue);
      expect(rawText.contains('P130.00'), isTrue);
      expect(rawText.contains('TOTAL DUE:'), isTrue);
      expect(rawText.contains('P300.00'), isTrue);
    });
  });

  group('PosPrinterDebugModal Widget Tests', () {
    testWidgets('Renders diagnostics modal with status and buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosPrinterDebugModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thermal Printer Diagnostics'), findsOneWidget);
      expect(find.text('XP-58H / JP58H • 58mm Driverless ESC/POS'), findsOneWidget);
      expect(find.text('100% DRIVERLESS'), findsOneWidget);
      expect(find.text('Connect / Select Port'), findsOneWidget);
      expect(find.text('Print Test'), findsOneWidget);
      expect(find.text('Realtime Diagnostic Log:'), findsOneWidget);
    });
  });

  group('ThermalReceiptModal Widget Tests', () {
    setUp(() {
      ThermalPrinterService.testPrintHandler = (bytes) async {
        return const PrinterResult(
          success: true,
          message: 'Printed to JP58H-0A4B (Test Mock)',
          deviceName: 'JP58H-0A4B',
        );
      };
    });

    tearDown(() {
      ThermalPrinterService.testPrintHandler = null;
    });

    final testTx = PosTransactionModel(
      id: 'tx-test-auto',
      invoiceNumber: 'INV-2026-00099',
      cashierId: 'c1',
      cashierName: 'Cashier Staff',
      paymentMethod: 'cash',
      grossAmount: 110.0,
      discountAmount: 0.0,
      vatableSales: 98.21,
      vatAmount: 11.79,
      vatExemptSales: 0.0,
      totalAmount: 110.0,
      createdAt: DateTime(2026, 9, 21, 15),
      items: const [
        PosTransactionItemModel(
          id: 'item-1',
          transactionId: 'tx-test-auto',
          productId: 'prod-1',
          productName: 'Long Black',
          quantity: 1,
          priceAtTime: 110.0,
        ),
      ],
    );

    testWidgets('Renders receipt modal, auto-prints on open, and keeps Print Again button visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThermalReceiptModal(
              transaction: testTx,
            ),
          ),
        ),
      );

      // Initial render triggers post-frame auto-print callback
      await tester.pump();
      await tester.pumpAndSettle();

      // Modal is STILL open and keeps Print Again button visible
      expect(find.text('Print Again'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Copy ESC/POS'), findsOneWidget);
      expect(find.text('Print 80mm'), findsOneWidget);
      expect(find.text('Long Black'), findsWidgets);
    });

    testWidgets('Renders with autoPrint false and displays Print Receipt initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThermalReceiptModal(
              transaction: testTx,
              autoPrint: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Print Receipt'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
