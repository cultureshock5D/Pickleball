import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/pos_product_model.dart';
import 'package:pickleball_app/screens/pos/controllers/pos_cart_controller.dart';
import 'package:pickleball_app/screens/pos/widgets/pos_paymongo_modal.dart';
import 'package:pickleball_app/services/pos_service.dart';

void main() {
  group('POS PayMongo GCash / QR Ph Integration Tests', () {
    late PosCartController cartController;

    const testItem = PosProductModel(
      id: 'prod-pm-01',
      sku: 'COF-PM',
      name: 'PayMongo Coffee',
      price: 150.00,
      category: 'Coffee',
      department: 'Coffee',
      stockLevel: 10,
    );

    setUp(() {
      cartController = PosCartController(posService: PosService.instance);
      cartController.addItem(testItem);
      cartController.setPaymentMethod('GCash / QR Ph');
    });

    tearDown(() {
      cartController.dispose();
    });

    test('PosService creates PayMongo POS checkout session with fallback', () async {
      final res = await PosService.instance.createPayMongoCheckoutSession(
        totalAmount: cartController.taxBreakdown.netPayable,
        items: [
          {'name': testItem.name, 'price': testItem.price, 'quantity': 1}
        ],
        customerName: 'Test Cashier Player',
      );

      expect(res['sessionId'], isNotNull);
      expect(res['checkoutUrl'], isNotNull);
      expect((res['checkoutUrl'] as String).contains('paymongo.com'), isTrue);
    });

    testWidgets('PosPayMongoModal renders GCash/QR Ph title and payable amount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PosPayMongoModal.show(
                  context,
                  cartController: cartController,
                  cashierId: 'cashier-01',
                  cashierName: 'Test Cashier',
                ),
                child: const Text('Launch PayMongo Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch PayMongo Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('GCash / QR Ph Checkout'), findsOneWidget);
      expect(find.text('Powered by PayMongo Gateway'), findsOneWidget);
      expect(find.text('₱150.00'), findsOneWidget);
      expect(find.text('Cancel Payment'), findsOneWidget);
    });

    testWidgets('Cancelling PosPayMongoModal returns null without completing checkout', (tester) async {
      dynamic result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await PosPayMongoModal.show(
                    context,
                    cartController: cartController,
                    cashierId: 'cashier-01',
                    cashierName: 'Test Cashier',
                  );
                },
                child: const Text('Launch Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Cancel Payment
      await tester.tap(find.text('Cancel Payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Modal closed, result is null (no receipt issued, cart retained)
      expect(result, isNull);
      expect(cartController.isEmpty, isFalse);
      expect(cartController.itemCount, 1);
    });
  });
}
