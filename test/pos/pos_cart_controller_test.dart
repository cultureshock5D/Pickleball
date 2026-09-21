import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/pos_product_model.dart';
import 'package:pickleball_app/screens/pos/controllers/pos_cart_controller.dart';
import 'package:pickleball_app/services/pos_service.dart';

void main() {
  group('PosCartController State & Workflow Tests', () {
    late PosCartController controller;

    const productA = PosProductModel(
      id: 'test-prod-01',
      sku: 'COF-01',
      name: 'Test Coffee',
      price: 120.00,
      category: 'Coffee',
      department: 'Coffee',
      stockLevel: 10,
    );

    const productOutOfStock = PosProductModel(
      id: 'test-prod-oos',
      sku: 'OOS-01',
      name: 'Out of Stock Item',
      price: 200.00,
      category: 'Coffee',
      department: 'Coffee',
    );

    setUp(() {
      controller = PosCartController(posService: PosService.instance);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial cart is empty', () {
      expect(controller.isEmpty, isTrue);
      expect(controller.itemCount, 0);
      expect(controller.grossSubtotal, 0.0);
      expect(controller.taxBreakdown.netPayable, 0.0);
    });

    test('Adding item increments count and computes subtotal', () {
      final success = controller.addItem(productA);
      expect(success, isTrue);
      expect(controller.itemCount, 1);
      expect(controller.grossSubtotal, 120.00);
      expect(controller.quantityForProduct(productA.id), 1);

      // Incrementing
      controller.incrementItem(productA.id);
      expect(controller.itemCount, 2);
      expect(controller.grossSubtotal, 240.00);
      expect(controller.quantityForProduct(productA.id), 2);
    });

    test('Out of stock product cannot be added', () {
      final success = controller.addItem(productOutOfStock);
      expect(success, isFalse);
      expect(controller.isEmpty, isTrue);
    });

    test('Decrementing or removing item at quantity 1 removes item directly without PIN', () {
      controller.addItem(productA);
      expect(controller.itemCount, 1);

      // Decrementing when quantity == 1 directly removes item without PIN
      final cleanDecrement = controller.decrementItem(productA.id);
      expect(cleanDecrement, isTrue);
      expect(controller.isEmpty, isTrue);

      // removeItem also removes directly without PIN
      controller.addItem(productA);
      expect(controller.itemCount, 1);
      controller.removeItem(productA.id);
      expect(controller.isEmpty, isTrue);
    });

    test('Clear cart with PIN resets all items and compliance state', () {
      controller.addItem(productA);
      controller.setDiscountType('senior_citizen');
      controller.setCustomerDetails(name: 'Maria Santos', idNumber: 'OSCA-1234');

      expect(controller.isEmpty, isFalse);

      controller.clearCartWithPin();

      expect(controller.isEmpty, isTrue);
      expect(controller.discountType, 'none');
      expect(controller.customerName, '');
      expect(controller.discountIdNumber, '');
    });

    test('Validation fails if cart is empty', () {
      final err = controller.validateForCheckout();
      expect(err, isNotNull);
      expect(err!.contains('empty'), isTrue);
    });

    test('Validation enforces mandatory name and ID for statutory discount', () {
      controller.addItem(productA);
      controller.setDiscountType('senior_citizen');

      // Missing name and ID
      var err = controller.validateForCheckout();
      expect(err, isNotNull);
      expect(err!.contains('Cardholder Name'), isTrue);

      // Add name only
      controller.setCustomerDetails(name: 'Juan Dela Cruz');
      err = controller.validateForCheckout();
      expect(err, isNotNull);
      expect(err!.contains('Discount ID Number'), isTrue);

      // Add ID
      controller.setCustomerDetails(idNumber: 'OSCA-987654');
      err = controller.validateForCheckout();
      // Cash payment requires tender
      expect(err, isNotNull);
      expect(err!.contains('Tender amount'), isTrue);

      // Provide tender
      controller.setTenderAmount(200.00);
      expect(controller.validateForCheckout(), isNull);
    });

    test('Cash change computation computes correctly', () {
      controller.addItem(productA); // 120.00
      controller.setPaymentMethod('Cash');
      controller.setTenderAmount(200.00);

      expect(controller.changeDue, 80.00);
    });

    test('Successful checkout creates transaction and resets cart', () async {
      controller.addItem(productA);
      controller.setPaymentMethod('GCash / QR Ph');

      final tx = await controller.checkout(
        cashierId: 'cashier-test-01',
        cashierName: 'Maria Cashier',
      );

      expect(tx, isNotNull);
      expect(tx!.cashierId, 'cashier-test-01');
      expect(tx.grossAmount, 120.00);
      expect(controller.isEmpty, isTrue);
    });
  });
}
