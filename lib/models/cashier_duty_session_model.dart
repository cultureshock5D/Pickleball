class CashierDutySessionModel {
  final String id;
  final String cashierId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final double openingFloat;
  final double? closingCash;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CashierDutySessionModel({
    required this.id,
    required this.cashierId,
    required this.startedAt,
    this.endedAt,
    this.status = 'on_duty',
    this.openingFloat = 0.0,
    this.closingCash,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isOnDuty => status == 'on_duty';

  Duration get sessionDuration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  factory CashierDutySessionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return CashierDutySessionModel(
      id: json['id'] as String? ?? '',
      cashierId: json['cashier_id'] as String? ?? '',
      startedAt: parseDate(json['started_at']),
      endedAt: json['ended_at'] != null ? parseDate(json['ended_at']) : null,
      status: json['status'] as String? ?? 'on_duty',
      openingFloat: (json['opening_float'] as num?)?.toDouble() ?? 0.0,
      closingCash: (json['closing_cash'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'cashier_id': cashierId,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      'status': status,
      'opening_float': openingFloat,
      if (closingCash != null) 'closing_cash': closingCash,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  CashierDutySessionModel copyWith({
    String? id,
    String? cashierId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? status,
    double? openingFloat,
    double? closingCash,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashierDutySessionModel(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      openingFloat: openingFloat ?? this.openingFloat,
      closingCash: closingCash ?? this.closingCash,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
