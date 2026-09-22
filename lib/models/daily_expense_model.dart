class DailyExpenseModel {
  final String id;
  final DateTime expenseDate;
  final String category;
  final String title;
  final double amount;
  final String paymentMethod;
  final String? receiptReference;
  final String? notes;
  final String? recordedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DailyExpenseModel({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.title,
    required this.amount,
    this.paymentMethod = 'cash',
    this.receiptReference,
    this.notes,
    this.recordedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory DailyExpenseModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return DailyExpenseModel(
      id: json['id'] as String? ?? '',
      expenseDate: parseDate(json['expense_date']),
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      receiptReference: json['receipt_reference'] as String?,
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'expense_date': "${expenseDate.year.toString().padLeft(4, '0')}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}",
      'category': category,
      'title': title,
      'amount': amount,
      'payment_method': paymentMethod,
      if (receiptReference != null) 'receipt_reference': receiptReference,
      if (notes != null) 'notes': notes,
      if (recordedBy != null) 'recorded_by': recordedBy,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  DailyExpenseModel copyWith({
    String? id,
    DateTime? expenseDate,
    String? category,
    String? title,
    double? amount,
    String? paymentMethod,
    String? receiptReference,
    String? notes,
    String? recordedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyExpenseModel(
      id: id ?? this.id,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptReference: receiptReference ?? this.receiptReference,
      notes: notes ?? this.notes,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
