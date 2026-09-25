import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/utils/bir_tax_breakdown.dart';
import '../../../models/pos_cart_item_model.dart';
import '../../../models/pos_product_model.dart';
import '../../../models/pos_transaction_model.dart';
import '../../../services/pos_service.dart';

class PosCartController extends ChangeNotifier {
  final PosService _posService;

  PosCartController({PosService? posService})
      : _posService = posService ?? PosService.instance;

  final List<PosCartItemModel> _items = [];

  String _discountType = 'none'; // 'none', 'senior_citizen', 'pwd'
  String _customerName = '';
  String _discountIdNumber = '';
  String _customerTin = '';

  String _paymentMethod = 'Cash'; // 'Cash', 'GCash / QR Ph', 'Credit / Debit Card'
  double _tenderAmount = 0.0;
  bool _isProcessing = false;
  String? _checkoutError;

  List<PosCartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  String get discountType => _discountType;
  String get customerName => _customerName;
  String get discountIdNumber => _discountIdNumber;
  String get customerTin => _customerTin;

  String get paymentMethod => _paymentMethod;
  double get tenderAmount => _tenderAmount;
  bool get isProcessing => _isProcessing;
  String? get checkoutError => _checkoutError;

  /// Total gross sum of all items in cart
  double get grossSubtotal {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Current statutory tax breakdown
  BirTaxBreakdown get taxBreakdown {
    return BirTaxBreakdown.compute(
      gross: grossSubtotal,
      discountType: _discountType,
    );
  }

  /// Change due when paying cash
  double get changeDue {
    if (_paymentMethod != 'Cash') return 0.0;
    final diff = ((_tenderAmount - taxBreakdown.netPayable) * 100).round() / 100.0;
    return max(0.0, diff);
  }

  /// Quantity of a product currently in the cart
  int quantityForProduct(String productId) {
    final index = _items.indexWhere((i) => i.productId == productId);
    return index != -1 ? _items[index].quantity : 0;
  }

  /// Add a product to the cart
  bool addItem(PosProductModel product) {
    if (product.isOutOfStock) return false;

    final index = _items.indexWhere((i) => i.productId == product.id);
    if (index != -1) {
      final current = _items[index];
      if (current.quantity < product.stockLevel) {
        _items[index] = current.copyWith(quantity: current.quantity + 1);
        notifyListeners();
        return true;
      }
      return false; // Reached stock limit
    } else {
      _items.add(PosCartItemModel(product: product, quantity: 1));
      notifyListeners();
      return true;
    }
  }

  /// Increment quantity of an item
  bool incrementItem(String productId) {
    final index = _items.indexWhere((i) => i.productId == productId);
    if (index == -1) return false;

    final current = _items[index];
    if (current.quantity < current.product.stockLevel) {
      _items[index] = current.copyWith(quantity: current.quantity + 1);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Decrement quantity of an item.
  /// If quantity > 1, decrements by 1.
  /// If quantity == 1, directly removes the item from active cart without requesting a master code.
  bool decrementItem(String productId) {
    final index = _items.indexWhere((i) => i.productId == productId);
    if (index == -1) return false;

    final current = _items[index];
    if (current.quantity > 1) {
      _items[index] = current.copyWith(quantity: current.quantity - 1);
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
    return true;
  }

  /// Remove item from active cart without requiring supervisor PIN / master code
  void removeItem(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  /// Backward compatible alias for removeItem
  void removeItemWithPin(String productId) {
    removeItem(productId);
  }

  /// Clear entire active cart without requiring supervisor PIN
  void clearCart() {
    _items.clear();
    _discountType = 'none';
    _customerName = '';
    _discountIdNumber = '';
    _customerTin = '';
    _tenderAmount = 0.0;
    _checkoutError = null;
    notifyListeners();
  }

  /// Backward compatible alias for clearCart
  void clearCartWithPin() {
    clearCart();
  }

  /// Set discount type
  void setDiscountType(String type) {
    if (_discountType != type) {
      _discountType = type;
      notifyListeners();
    }
  }

  /// Set customer compliance fields
  void setCustomerDetails({
    String? name,
    String? idNumber,
    String? tin,
  }) {
    if (name != null) _customerName = name;
    if (idNumber != null) _discountIdNumber = idNumber;
    if (tin != null) _customerTin = tin;
    notifyListeners();
  }

  /// Set payment method
  void setPaymentMethod(String method) {
    if (_paymentMethod != method) {
      _paymentMethod = method;
      notifyListeners();
    }
  }

  /// Set cash tender amount
  void setTenderAmount(double amount) {
    _tenderAmount = max(0.0, amount);
    notifyListeners();
  }

  /// Validate current cart state before proceeding to payment
  String? validateForCheckout({bool checkTender = true}) {
    if (_items.isEmpty) {
      return 'Cart is empty. Please add items to proceed.';
    }

    if (_discountType == 'senior_citizen' ||
        _discountType == 'pwd' ||
        _discountType == 'student' ||
        _discountType == 'staff') {
      if (_customerName.trim().isEmpty) {
        return 'Customer / Cardholder Name is mandatory for discounts.';
      }
      if (_discountIdNumber.trim().isEmpty) {
        return 'Discount ID Number is mandatory.';
      }
    }

    if (checkTender && _paymentMethod == 'Cash') {
      if (_tenderAmount < (taxBreakdown.netPayable - 0.001)) {
        return 'Tender amount is less than total net payable (₱${taxBreakdown.netPayable.toStringAsFixed(2)}).';
      }
    }

    return null;
  }

  /// Complete checkout and record transaction
  Future<PosTransactionModel?> checkout({
    required String cashierId,
    String? cashierName,
  }) async {
    final validationError = validateForCheckout();
    if (validationError != null) {
      _checkoutError = validationError;
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    _checkoutError = null;
    notifyListeners();

    try {
      final lineItems = _items.map((i) => i.toJson()).toList();

      final tx = await _posService.createTransaction(
        cashierId: cashierId,
        cashierName: cashierName,
        customerName: _customerName.trim().isEmpty ? null : _customerName.trim(),
        customerTin: _customerTin.trim().isEmpty ? null : _customerTin.trim(),
        discountType: _discountType,
        discountIdNumber: _discountIdNumber.trim().isEmpty ? null : _discountIdNumber.trim(),
        taxBreakdown: taxBreakdown,
        paymentMethod: _paymentMethod,
        items: lineItems,
      );

      // Reset cart on successful checkout
      _items.clear();
      _discountType = 'none';
      _customerName = '';
      _discountIdNumber = '';
      _customerTin = '';
      _tenderAmount = 0.0;

      return tx;
    } catch (e) {
      _checkoutError = 'Checkout failed: $e';
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
