import 'dart:math';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isValidUuid(String? str) {
  if (str == null || str.trim().isEmpty) return false;
  return _uuidPattern.hasMatch(str.trim());
}

String generateUuidV4() {
  final rnd = Random();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

class PosTransactionItemModel {
  final String id;
  final String transactionId;
  final String productId;
  final String productName;
  final int quantity;
  final double priceAtTime;

  const PosTransactionItemModel({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.priceAtTime,
  });

  double get subtotal => quantity * priceAtTime;

  factory PosTransactionItemModel.fromJson(Map<String, dynamic> json) {
    String resolvedName = 'Item';
    final rawName = json['product_name'] as String?;
    if (rawName != null && rawName.trim().isNotEmpty) {
      resolvedName = rawName.trim();
    } else if (json['pos_products'] != null && json['pos_products'] is Map) {
      final pName = json['pos_products']['name'] as String?;
      if (pName != null && pName.trim().isNotEmpty) {
        resolvedName = pName.trim();
      }
    }

    return PosTransactionItemModel(
      id: json['id'] as String? ?? '',
      transactionId: json['transaction_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: resolvedName,
      quantity: json['quantity'] as int? ?? 1,
      priceAtTime: (json['price_at_time'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (transactionId.isNotEmpty) 'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price_at_time': priceAtTime,
    };
  }
}

class PosTransactionModel {
  final String id;
  final String invoiceNumber;
  final String cashierId;
  final String? cashierName;
  final String? customerName;
  final String? customerTin;
  final String discountType;
  final String? discountIdNumber;
  final double grossAmount;
  final double discountAmount;
  final double vatableSales;
  final double vatAmount;
  final double vatExemptSales;
  final double zeroRatedSales;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String? voidReason;
  final DateTime? voidedAt;
  final String? voidedBy;
  final DateTime createdAt;
  final List<PosTransactionItemModel> items;

  const PosTransactionModel({
    required this.id,
    required this.invoiceNumber,
    required this.cashierId,
    this.cashierName,
    this.customerName,
    this.customerTin,
    this.discountType = 'none',
    this.discountIdNumber,
    required this.grossAmount,
    required this.discountAmount,
    required this.vatableSales,
    required this.vatAmount,
    required this.vatExemptSales,
    this.zeroRatedSales = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.status = 'completed',
    this.voidReason,
    this.voidedAt,
    this.voidedBy,
    required this.createdAt,
    this.items = const [],
  });

  bool get isVoided => status == 'voided';
  bool get isCompleted => status == 'completed';
  bool get hasDiscount => discountType != 'none' && discountAmount > 0;

  factory PosTransactionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['pos_transaction_items'] as List<dynamic>? ??
        json['items'] as List<dynamic>? ??
        [];

    final parsedItems = rawItems
        .map((e) => PosTransactionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PosTransactionModel(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String? ?? 'SI-UNKNOWN',
      cashierId: json['cashier_id'] as String? ?? '',
      cashierName: json['cashier_name'] as String? ??
          (json['profiles'] != null && json['profiles'] is Map
              ? json['profiles']['full_name'] as String?
              : null),
      customerName: json['customer_name'] as String?,
      customerTin: json['customer_tin'] as String?,
      discountType: json['discount_type'] as String? ?? 'none',
      discountIdNumber: json['discount_id_number'] as String?,
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      vatableSales: (json['vatable_sales'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
      vatExemptSales: (json['vat_exempt_sales'] as num?)?.toDouble() ?? 0.0,
      zeroRatedSales: (json['zero_rated_sales'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      status: json['status'] as String? ?? 'completed',
      voidReason: json['void_reason'] as String?,
      voidedAt: json['voided_at'] != null
          ? DateTime.tryParse(json['voided_at'] as String)?.toLocal()
          : null,
      voidedBy: json['voided_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'cashier_id': cashierId,
      if (customerName != null) 'customer_name': customerName,
      if (customerTin != null) 'customer_tin': customerTin,
      'discount_type': discountType,
      if (discountIdNumber != null) 'discount_id_number': discountIdNumber,
      'gross_amount': grossAmount,
      'discount_amount': discountAmount,
      'vatable_sales': vatableSales,
      'vat_amount': vatAmount,
      'vat_exempt_sales': vatExemptSales,
      'zero_rated_sales': zeroRatedSales,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'status': status,
      if (voidReason != null) 'void_reason': voidReason,
      if (voidedAt != null) 'voided_at': voidedAt!.toUtc().toIso8601String(),
      if (voidedBy != null) 'voided_by': voidedBy,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  PosTransactionModel copyWith({
    String? status,
    String? voidReason,
    DateTime? voidedAt,
    String? voidedBy,
    List<PosTransactionItemModel>? items,
  }) {
    return PosTransactionModel(
      id: id,
      invoiceNumber: invoiceNumber,
      cashierId: cashierId,
      cashierName: cashierName,
      customerName: customerName,
      customerTin: customerTin,
      discountType: discountType,
      discountIdNumber: discountIdNumber,
      grossAmount: grossAmount,
      discountAmount: discountAmount,
      vatableSales: vatableSales,
      vatAmount: vatAmount,
      vatExemptSales: vatExemptSales,
      zeroRatedSales: zeroRatedSales,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }
}
