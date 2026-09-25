# Flutter (Dart) Translation: Cashier Operations Suite

Complete Dart and Flutter translation of the 5 cashier-facing pages and functions from Next.js 16 to Flutter (Dart 3.x + Riverpod 2.x + `supabase_flutter`).

---

## 1. Domain Models (`lib/data/models/`)

### A. BIR Tax Calculator & Models (`lib/core/utils/bir_tax_calculator.dart`)
```dart
import 'dart:math';

enum DiscountType {
  none,
  seniorCitizen,
  pwd,
  student,
  staff;

  String get dbValue {
    switch (this) {
      case DiscountType.seniorCitizen:
        return 'senior_citizen';
      case DiscountType.pwd:
        return 'pwd';
      case DiscountType.student:
        return 'student';
      case DiscountType.staff:
        return 'staff';
      case DiscountType.none:
        return 'none';
    }
  }

  static DiscountType fromDb(String? value) {
    switch (value) {
      case 'senior_citizen':
        return DiscountType.seniorCitizen;
      case 'pwd':
        return DiscountType.pwd;
      case 'student':
        return DiscountType.student;
      case 'staff':
        return DiscountType.staff;
      default:
        return DiscountType.none;
    }
  }
}

class BirTaxBreakdown {
  final double grossSubtotal;
  final double vatableSales;
  final double vatAmount;
  final double vatExemptSales;
  final double discountAmount;
  final double netPayable;

  const BirTaxBreakdown({
    required this.grossSubtotal,
    required this.vatableSales,
    required this.vatAmount,
    required this.vatExemptSales,
    required this.discountAmount,
    required this.netPayable,
  });

  factory BirTaxBreakdown.compute({
    required double gross,
    required DiscountType discountType,
  }) {
    double round2(double v) => (v * 100).roundToDouble() / 100;

    if (discountType == DiscountType.seniorCitizen || discountType == DiscountType.pwd) {
      // Philippine EOPT / RA 9994 / RA 10754:
      // 1. Remove 12% VAT to get VAT-Exempt Base
      final vatExemptBase = round2(gross / 1.12);
      // 2. Apply 20% discount to VAT-Exempt Base
      final discount = round2(vatExemptBase * 0.20);
      final net = round2(vatExemptBase - discount);

      return BirTaxBreakdown(
        grossSubtotal: gross,
        vatableSales: 0.0,
        vatAmount: 0.0,
        vatExemptSales: vatExemptBase,
        discountAmount: discount,
        netPayable: net,
      );
    } else if (discountType == DiscountType.student) {
      // 10% student discount without VAT exemption
      final discount = round2(gross * 0.10);
      final net = round2(gross - discount);
      final vatable = round2(net / 1.12);
      final vat = round2(net - vatable);

      return BirTaxBreakdown(
        grossSubtotal: gross,
        vatableSales: vatable,
        vatAmount: vat,
        vatExemptSales: 0.0,
        discountAmount: discount,
        netPayable: net,
      );
    } else if (discountType == DiscountType.staff) {
      // 15% staff discount without VAT exemption
      final discount = round2(gross * 0.15);
      final net = round2(gross - discount);
      final vatable = round2(net / 1.12);
      final vat = round2(net - vatable);

      return BirTaxBreakdown(
        grossSubtotal: gross,
        vatableSales: vatable,
        vatAmount: vat,
        vatExemptSales: 0.0,
        discountAmount: discount,
        netPayable: net,
      );
    } else {
      // Regular Non-Discounted Sale (12% VAT inclusive)
      final vatable = round2(gross / 1.12);
      final vat = round2(gross - vatable);

      return BirTaxBreakdown(
        grossSubtotal: gross,
        vatableSales: vatable,
        vatAmount: vat,
        vatExemptSales: 0.0,
        discountAmount: 0.0,
        netPayable: gross,
      );
    }
  }
}
```

### B. Product & Volume Model (`lib/data/models/pos_product_model.dart`)
```dart
class PosProductModel {
  final String id;
  final String? sku;
  final String name;
  final String category;
  final double price;
  final double costPrice;
  final double stockLevel;
  final double reorderThreshold;
  final String baseUnit;
  final double volume;
  final bool isActive;
  final DateTime updatedAt;

  PosProductModel({
    required this.id,
    this.sku,
    required this.name,
    required this.category,
    required this.price,
    this.costPrice = 0.0,
    this.stockLevel = 0.0,
    this.reorderThreshold = 10.0,
    this.baseUnit = 'pcs',
    this.volume = 0.0,
    this.isActive = true,
    required this.updatedAt,
  });

  bool get isVolumeAware => volume > 0 && baseUnit != 'pcs';
  bool get isOutOfStock => stockLevel <= 0;
  bool get isLowStock => stockLevel > 0 && stockLevel <= reorderThreshold;

  double get marginPercent {
    if (price <= 0) return 0.0;
    return (((price - costPrice) / price) * 100).roundToDouble();
  }

  String get stockDisplay {
    if (isVolumeAware) {
      final totalVolume = (stockLevel * volume).round();
      return '${stockLevel.toStringAsFixed(1)} units ($totalVolume $baseUnit)';
    }
    return '${stockLevel.toInt()} pcs';
  }

  factory PosProductModel.fromJson(Map<String, dynamic> json) {
    return PosProductModel(
      id: json['id'] as String,
      sku: json['sku'] as String?,
      name: json['name'] as String? ?? 'Unnamed Product',
      category: json['category'] as String? ?? 'General',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      stockLevel: (json['stock_level'] as num?)?.toDouble() ?? 0.0,
      reorderThreshold: (json['reorder_threshold'] as num?)?.toDouble() ?? 10.0,
      baseUnit: json['base_unit'] as String? ?? 'pcs',
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'name': name,
    'category': category,
    'price': price,
    'cost_price': costPrice,
    'stock_level': stockLevel,
    'reorder_threshold': reorderThreshold,
    'base_unit': baseUnit,
    'volume': volume,
    'is_active': isActive,
    'updated_at': updatedAt.toIso8601String(),
  };
}
```

### C. Cashier Duty Session Model (`lib/data/models/duty_session_model.dart`)
```dart
class DutySessionModel {
  final String id;
  final String cashierId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // 'on_duty' | 'off_duty'
  final double openingFloat;
  final double? closingCash;
  final String? notes;

  DutySessionModel({
    required this.id,
    required this.cashierId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.openingFloat = 0.0,
    this.closingCash,
    this.notes,
  });

  bool get isOnDuty => status == 'on_duty';

  factory DutySessionModel.fromJson(Map<String, dynamic> json) {
    return DutySessionModel(
      id: json['id'] as String,
      cashierId: json['cashier_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      status: json['status'] as String? ?? 'on_duty',
      openingFloat: (json['opening_float'] as num?)?.toDouble() ?? 0.0,
      closingCash: (json['closing_cash'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}
```

### D. Daily Expense & Disbursal Model (`lib/data/models/daily_expense_model.dart`)
```dart
class DailyExpenseModel {
  final String id;
  final String expenseDate; // YYYY-MM-DD
  final String category;
  final String title;
  final double amount;
  final String paymentMethod; // 'cash', 'gcash', 'card'
  final String? receiptReference;
  final String? notes;
  final String? recordedBy;
  final String? recorderName;
  final DateTime createdAt;

  DailyExpenseModel({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.title,
    required this.amount,
    required this.paymentMethod,
    this.receiptReference,
    this.notes,
    this.recordedBy,
    this.recorderName,
    required this.createdAt,
  });

  factory DailyExpenseModel.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['profiles'] != null) {
      if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
        name = json['profiles'][0]['full_name'] as String?;
      } else if (json['profiles'] is Map) {
        name = json['profiles']['full_name'] as String?;
      }
    }

    return DailyExpenseModel(
      id: json['id'] as String,
      expenseDate: json['expense_date'] as String,
      category: json['category'] as String? ?? 'other',
      title: json['title'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      receiptReference: json['receipt_reference'] as String?,
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by'] as String?,
      recorderName: name ?? 'Staff Cashier',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
```

### E. Court & Booking Schedule Model (`lib/data/models/schedule_booking_model.dart`)
```dart
class CourtModel {
  final String id;
  final String name;
  final String type;
  final double hourlyRate;
  final bool isActive;

  CourtModel({
    required this.id,
    required this.name,
    required this.type,
    required this.hourlyRate,
    required this.isActive,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'Standard',
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 300.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class ScheduleBookingModel {
  final String id;
  final String courtId;
  final String courtName;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double totalPrice;
  final double downPaymentAmount;
  final String status; // 'paid', 'checked_in', 'walk_in', 'pending_payment', 'cancelled'
  final String paymentMethod;
  final String guestName;
  final String? guestPhone;
  final String? guestEmail;
  final String? notes;

  ScheduleBookingModel({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalPrice,
    this.downPaymentAmount = 0.0,
    required this.status,
    required this.paymentMethod,
    required this.guestName,
    this.guestPhone,
    this.guestEmail,
    this.notes,
  });

  bool get isCheckedIn => status == 'checked_in';
  bool get isPaid => status == 'paid' || status == 'checked_in' || status == 'walk_in';
  double get remainingBalance => (totalPrice - downPaymentAmount).clamp(0.0, double.infinity);

  factory ScheduleBookingModel.fromJson(Map<String, dynamic> json) {
    String cName = 'Court';
    if (json['courts'] != null) {
      if (json['courts'] is List && (json['courts'] as List).isNotEmpty) {
        cName = json['courts'][0]['name'] as String? ?? 'Court';
      } else if (json['courts'] is Map) {
        cName = json['courts']['name'] as String? ?? 'Court';
      }
    }

    String gName = json['guest_name'] as String? ?? '';
    if (gName.isEmpty && json['profiles'] != null) {
      if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
        gName = json['profiles'][0]['full_name'] as String? ?? 'Registered Player';
      } else if (json['profiles'] is Map) {
        gName = json['profiles']['full_name'] as String? ?? 'Registered Player';
      }
    }
    if (gName.isEmpty) gName = 'Walk-in Client';

    return ScheduleBookingModel(
      id: json['id'] as String,
      courtId: json['court_id'] as String,
      courtName: cName,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 1.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      downPaymentAmount: (json['down_payment_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'paid',
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      guestName: gName,
      guestPhone: json['guest_phone'] as String?,
      guestEmail: json['guest_email'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
```

---

## 2. Repositories (`lib/data/repositories/`)

### A. Cashier Repositories Implementation
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/pos_product_model.dart';
import '../models/duty_session_model.dart';
import '../models/daily_expense_model.dart';
import '../models/schedule_booking_model.dart';
import '../../core/utils/bir_tax_calculator.dart';

class CashierRepository {
  final SupabaseClient _supabase;
  CashierRepository(this._supabase);

  // 1. PIN Verification
  Future<bool> verifyMasterPin(String inputPin) async {
    final res = await _supabase
        .from('system_settings')
        .select('value')
        .eq('key', 'pos_master_pin')
        .maybeSingle();
    final actualPin = res?['value'] ?? '8888';
    return inputPin.trim() == actualPin.trim();
  }

  // 2. Duty Session (Clock In / Clock Out)
  Future<DutySessionModel?> getActiveDutySession(String cashierId) async {
    final res = await _supabase
        .from('cashier_duty_sessions')
        .select('*')
        .eq('cashier_id', cashierId)
        .eq('status', 'on_duty')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return DutySessionModel.fromJson(res);
  }

  Future<DutySessionModel> clockIn({
    required String cashierId,
    required double openingFloat,
    String? notes,
  }) async {
    final res = await _supabase
        .from('cashier_duty_sessions')
        .insert({
          'cashier_id': cashierId,
          'status': 'on_duty',
          'opening_float': openingFloat,
          'notes': notes,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return DutySessionModel.fromJson(res);
  }

  Future<void> clockOut({
    required String sessionId,
    required double closingCash,
    String? notes,
  }) async {
    await _supabase
        .from('cashier_duty_sessions')
        .update({
          'status': 'off_duty',
          'closing_cash': closingCash,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
          if (notes != null) 'notes': notes,
        })
        .eq('id', sessionId);
  }

  // 3. Process POS Checkout
  Future<String> processCheckout({
    required String cashierId,
    required List<Map<String, dynamic>> items,
    required BirTaxBreakdown breakdown,
    required String paymentMethod,
    String? customerName,
    String? customerTin,
    DiscountType discountType = DiscountType.none,
    String? discountIdNumber,
  }) async {
    // Generate Invoice Number via RPC or Fallback
    String invoiceNumber;
    try {
      final rpcRes = await _supabase.rpc('generate_pos_invoice_number');
      invoiceNumber = rpcRes.toString();
    } catch (_) {
      final nowStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final randSuffix = (10000 + (DateTime.now().millisecond * 89) % 90000);
      invoiceNumber = 'SI-$nowStr-$randSuffix';
    }

    // Insert Transaction Record
    final txRes = await _supabase
        .from('pos_transactions')
        .insert({
          'invoice_number': invoiceNumber,
          'cashier_id': cashierId,
          'customer_name': customerName?.trim().isNotEmpty == true ? customerName : 'Retail Customer',
          'customer_tin': customerTin?.trim(),
          'discount_type': discountType.dbValue,
          'discount_id_number': discountIdNumber?.trim(),
          'gross_amount': breakdown.grossSubtotal,
          'discount_amount': breakdown.discountAmount,
          'vatable_sales': breakdown.vatableSales,
          'vat_amount': breakdown.vatAmount,
          'vat_exempt_sales': breakdown.vatExemptSales,
          'zero_rated_sales': 0.0,
          'total_amount': breakdown.netPayable,
          'payment_method': paymentMethod,
          'status': 'completed',
        })
        .select('id')
        .single();

    final txId = txRes['id'] as String;

    // Insert Transaction Line Items and Deduct Inventory
    for (final item in items) {
      final prodId = item['product_id'] as String;
      final qty = item['quantity'] as int;
      final price = (item['price'] as num).toDouble();
      final dispensedVol = (item['dispensed_volume'] as num?)?.toDouble() ?? 0.0;
      final volUnit = item['volume_unit'] as String? ?? 'pcs';

      await _supabase.from('pos_transaction_items').insert({
        'transaction_id': txId,
        'product_id': prodId,
        'quantity': qty,
        'price_at_time': price,
        'dispensed_volume': dispensedVol,
        'volume_unit': volUnit,
      });

      // Deduct stock in database
      await _supabase.rpc('decrement_pos_product_stock', params: {
        'p_product_id': prodId,
        'p_quantity': qty,
      }).catchError((_) async {
        // Fallback manual decrement
        final prod = await _supabase.from('pos_products').select('stock_level').eq('id', prodId).single();
        final currentStock = (prod['stock_level'] as num).toDouble();
        await _supabase.from('pos_products').update({
          'stock_level': (currentStock - qty).clamp(0.0, double.infinity),
        }).eq('id', prodId);
      });
    }

    return invoiceNumber;
  }

  // 4. Void Transaction with Master PIN
  Future<void> voidTransaction({
    required String transactionId,
    required String cashierId,
    required String pin,
    required String reason,
  }) async {
    final valid = await verifyMasterPin(pin);
    if (!valid) throw Exception('Invalid Master Supervisor PIN.');

    // 1. Mark transaction voided
    await _supabase.from('pos_transactions').update({
      'status': 'voided',
      'void_reason': reason,
      'voided_at': DateTime.now().toUtc().toIso8601String(),
      'voided_by': cashierId,
    }).eq('id', transactionId);

    // 2. Restore inventory quantities
    final items = await _supabase
        .from('pos_transaction_items')
        .select('product_id, quantity')
        .eq('transaction_id', transactionId);

    for (final item in items) {
      final prodId = item['product_id'] as String;
      final qty = item['quantity'] as int;

      final prod = await _supabase.from('pos_products').select('stock_level').eq('id', prodId).single();
      final currentStock = (prod['stock_level'] as num).toDouble();
      await _supabase.from('pos_products').update({
        'stock_level': currentStock + qty,
      }).eq('id', prodId);
    }
  }

  // 5. Update Inventory Product
  Future<void> updateInventoryProduct({
    required String productId,
    required double stockLevel,
    required double costPrice,
    required double price,
    required double volume,
    required String baseUnit,
    required double reorderThreshold,
  }) async {
    await _supabase.from('pos_products').update({
      'stock_level': stockLevel,
      'cost_price': costPrice,
      'price': price,
      'volume': volume,
      'base_unit': baseUnit,
      'reorder_threshold': reorderThreshold,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);
  }

  // 6. Add Daily Disbursal Expense
  Future<void> addDailyExpense({
    required String title,
    required String category,
    required double amount,
    required String paymentMethod,
    String? receiptRef,
    String? notes,
    required String recordedBy,
  }) async {
    final nowManila = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _supabase.from('daily_expenses').insert({
      'expense_date': nowManila,
      'title': title,
      'category': category,
      'amount': amount,
      'payment_method': paymentMethod,
      'receipt_reference': receiptRef,
      'notes': notes,
      'recorded_by': recordedBy,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // 7. Check-in Court Booking
  Future<void> checkInBooking(String bookingId) async {
    await _supabase.from('bookings').update({
      'status': 'checked_in',
    }).eq('id', bookingId);
  }

  // 8. Create Walk-in Booking
  Future<void> createWalkInBooking({
    required String courtId,
    required DateTime startTime,
    required int durationHours,
    required double totalPrice,
    required String guestName,
    String? guestPhone,
    required String paymentMethod,
    required String cashierId,
    double downPaymentAmount = 0.0,
  }) async {
    final endTime = startTime.add(Duration(hours: durationHours));
    await _supabase.from('bookings').insert({
      'court_id': courtId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'duration_hours': durationHours,
      'total_price': totalPrice,
      'down_payment_amount': downPaymentAmount,
      'status': 'walk_in',
      'payment_method': paymentMethod,
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'cashier_id': cashierId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
```

---

## 3. Riverpod State Providers (`lib/state/`)

### A. Cart State Notifier (`lib/state/pos_cart_provider.dart`)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/pos_product_model.dart';
import '../core/utils/bir_tax_calculator.dart';

class CartLineItem {
  final PosProductModel product;
  final int quantity;
  final double dispensedVolume;

  const CartLineItem({
    required this.product,
    required this.quantity,
    this.dispensedVolume = 0.0,
  });

  double get subtotal => product.price * quantity;

  CartLineItem copyWith({int? quantity, double? dispensedVolume}) {
    return CartLineItem(
      product: product,
      quantity: quantity ?? this.quantity,
      dispensedVolume: dispensedVolume ?? this.dispensedVolume,
    );
  }
}

class CartState {
  final Map<String, CartLineItem> items;
  final DiscountType discountType;
  final String customerName;
  final String customerTin;
  final String discountIdNumber;

  const CartState({
    this.items = const {},
    this.discountType = DiscountType.none,
    this.customerName = '',
    this.customerTin = '',
    this.discountIdNumber = '',
  });

  double get grossSubtotal => items.values.fold(0.0, (acc, item) => acc + item.subtotal);
  int get totalItemCount => items.values.fold(0, (acc, item) => acc + item.quantity);

  BirTaxBreakdown get taxBreakdown => BirTaxBreakdown.compute(
    gross: grossSubtotal,
    discountType: discountType,
  );

  bool get isDiscountValid {
    if (discountType == DiscountType.none) return true;
    return customerName.trim().isNotEmpty && discountIdNumber.trim().isNotEmpty;
  }

  CartState copyWith({
    Map<String, CartLineItem>? items,
    DiscountType? discountType,
    String? customerName,
    String? customerTin,
    String? discountIdNumber,
  }) {
    return CartState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      customerName: customerName ?? this.customerName,
      customerTin: customerTin ?? this.customerTin,
      discountIdNumber: discountIdNumber ?? this.discountIdNumber,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addProduct(PosProductModel product) {
    if (product.isOutOfStock) return;
    final current = state.items[product.id];
    final updated = Map<String, CartLineItem>.from(state.items);

    if (current != null) {
      updated[product.id] = current.copyWith(quantity: current.quantity + 1);
    } else {
      updated[product.id] = CartLineItem(product: product, quantity: 1);
    }
    state = state.copyWith(items: updated);
  }

  void decrementQuantity(String productId) {
    final current = state.items[productId];
    if (current == null) return;
    if (current.quantity > 1) {
      final updated = Map<String, CartLineItem>.from(state.items);
      updated[productId] = current.copyWith(quantity: current.quantity - 1);
      state = state.copyWith(items: updated);
    }
  }

  void removeItem(String productId) {
    final updated = Map<String, CartLineItem>.from(state.items);
    updated.remove(productId);
    state = state.copyWith(items: updated);
  }

  void clearCart() {
    state = state.copyWith(
      items: {},
      discountType: DiscountType.none,
      customerName: '',
      customerTin: '',
      discountIdNumber: '',
    );
  }

  void setDiscount({
    required DiscountType discountType,
    String? name,
    String? idNumber,
    String? tin,
  }) {
    state = state.copyWith(
      discountType: discountType,
      customerName: name ?? state.customerName,
      discountIdNumber: idNumber ?? state.discountIdNumber,
      customerTin: tin ?? state.customerTin,
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
```

### B. Daily Court Schedule Real-Time Stream Provider (`lib/state/schedule_provider.dart`)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../data/models/schedule_booking_model.dart';

final selectedScheduleDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dailyCourtsProvider = FutureProvider<List<CourtModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final res = await supabase.from('courts').select().eq('is_active', true).order('name');
  return (res as List).map((c) => CourtModel.fromJson(c)).toList();
});

final scheduleBookingsRealtimeProvider = StreamProvider.autoDispose<List<ScheduleBookingModel>>((ref) {
  final supabase = Supabase.instance.client;
  final date = ref.watch(selectedScheduleDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(date);

  final startOfDay = '${dateStr}T00:00:00.000+08:00';
  final endOfDay = '${dateStr}T23:59:59.999+08:00';

  // Subscribes to realtime changes and emits fresh list on any table mutation
  return supabase
      .from('bookings')
      .stream(primaryKey: ['id'])
      .order('start_time', ascending: true)
      .map((rows) {
        return rows
            .where((r) {
              final start = r['start_time'] as String;
              final end = r['end_time'] as String;
              return end.compareTo(startOfDay) >= 0 && start.compareTo(endOfDay) <= 0;
            })
            .map((r) => ScheduleBookingModel.fromJson(r))
            .toList();
      });
});
```

---

## 4. UI Screen Implementation Samples

### A. Navigation Shell (`lib/ui/shell/cashier_shell_screen.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../pos/pos_screen.dart';
import '../schedule/daily_schedule_screen.dart';
import '../inventory/inventory_screen.dart';
import '../expenses/expenses_screen.dart';
import '../reports/shift_reports_screen.dart';

class CashierShellScreen extends StatefulWidget {
  const CashierShellScreen({super.key});

  @override
  State<CashierShellScreen> createState() => _CashierShellScreenState();
}

class _CashierShellScreenState extends State<CashierShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    PosScreen(),
    DailyScheduleScreen(),
    InventoryScreen(),
    ExpensesScreen(),
    ShiftReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail for Tablet POV
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007D48),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'C&J',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('POS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(LucideIcons.store),
                selectedIcon: Icon(LucideIcons.store, color: Color(0xFF007D48)),
                label: Text('Register'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.calendarDays),
                selectedIcon: Icon(LucideIcons.calendarDays, color: Color(0xFF007D48)),
                label: Text('Courts'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.boxes),
                selectedIcon: Icon(LucideIcons.boxes, color: Color(0xFF007D48)),
                label: Text('Inventory'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.wallet),
                selectedIcon: Icon(LucideIcons.wallet, color: Color(0xFF007D48)),
                label: Text('Expenses'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.receipt),
                selectedIcon: Icon(LucideIcons.receipt, color: Color(0xFF007D48)),
                label: Text('Reports'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Active Screen Content
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
```

### B. 80mm ESC/POS Thermal Receipt Builder (`lib/core/utils/thermal_receipt_builder.dart`)
```dart
import 'package:intl/intl.dart';
import 'bir_tax_calculator.dart';
import '../../state/pos_cart_provider.dart';

class ThermalReceiptBuilder {
  static String format80mmText({
    required String invoiceNumber,
    required String cashierName,
    required DateTime timestamp,
    required List<CartLineItem> items,
    required BirTaxBreakdown breakdown,
    required String paymentMethod,
    String? customerName,
    String? customerTin,
    DiscountType discountType = DiscountType.none,
    String? discountIdNumber,
  }) {
    final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    final buffer = StringBuffer();

    void line(String text) => buffer.writeln(text);
    void divider() => line('------------------------------------------');
    void center(String text) {
      final pad = (42 - text.length) ~/ 2;
      line(' ' * (pad > 0 ? pad : 0) + text);
    }

    center("C&J'S EVENTS PLACE & SPORTS ARENA");
    center('25 Bologna Muzon, Taytay, Rizal, 1920');
    center('VAT Reg. TIN: 000-123-456-00000 • BIR EOPT');
    divider();
    line('Invoice No: $invoiceNumber');
    line('Date/Time:  $dateFormatted');
    line('Cashier:    $cashierName');
    divider();

    if (discountType != DiscountType.none) {
      line('Customer:   ${customerName ?? "Valued Guest"}');
      line('Privilege:  ${discountType.name.toUpperCase()}');
      line('ID No:      ${discountIdNumber ?? "N/A"}');
      divider();
    }

    line('ITEM                     QTY         TOTAL');
    for (final item in items) {
      final name = item.product.name.padRight(22).substring(0, 22);
      final qty = item.quantity.toString().padLeft(4);
      final total = '₱${item.subtotal.toStringAsFixed(2)}'.padLeft(14);
      line('$name $qty $total');
    }

    divider();
    line('Gross Sales:           ${("₱" + breakdown.grossSubtotal.toStringAsFixed(2)).padLeft(19)}');
    if (breakdown.discountAmount > 0) {
      line('Statutory Discount:   -${("₱" + breakdown.discountAmount.toStringAsFixed(2)).padLeft(19)}');
    }
    line('Vatable Sales:         ${("₱" + breakdown.vatableSales.toStringAsFixed(2)).padLeft(19)}');
    line('12% VAT:               ${("₱" + breakdown.vatAmount.toStringAsFixed(2)).padLeft(19)}');
    line('VAT-Exempt Sales:      ${("₱" + breakdown.vatExemptSales.toStringAsFixed(2)).padLeft(19)}');
    divider();
    line('TOTAL DUE:             ${("₱" + breakdown.netPayable.toStringAsFixed(2)).padLeft(19)}');
    line('Payment Mode:          ${paymentMethod.padLeft(19)}');
    divider();
    center('*$invoiceNumber*');
    center('THANK YOU FOR PLAYING AT C&J!');
    center('Non-refundable after 24 hours');

    return buffer.toString();
  }
}
```
