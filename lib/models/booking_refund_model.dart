class BookingRefundModel {
  final String id;
  final String bookingId;
  final double amount;
  final String walletType; // gcash | maya | bank_transfer | counter_cash
  final String accountName;
  final String accountNumber;
  final String? reason;
  final String status; // none | pending | approved | rejected | completed | voided_no_refund
  final String? reference;
  final String? processedBy;
  final DateTime? processedAt;
  final String? adminNotes;

  const BookingRefundModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.walletType,
    required this.accountName,
    required this.accountNumber,
    this.reason,
    this.status = 'pending',
    this.reference,
    this.processedBy,
    this.processedAt,
    this.adminNotes,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved (Processing)';
      case 'completed':
        return 'Refund Completed';
      case 'rejected':
        return 'Refund Rejected';
      case 'voided_no_refund':
        return 'Voided (No Refund)';
      default:
        return status.toUpperCase();
    }
  }

  factory BookingRefundModel.fromJson(Map<String, dynamic> json) {
    return BookingRefundModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      walletType: json['wallet_type'] as String? ?? 'gcash',
      accountName: json['account_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      reference: json['reference'] as String?,
      processedBy: json['processed_by'] as String?,
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'] as String)?.toLocal()
          : null,
      adminNotes: json['admin_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'amount': amount,
      'wallet_type': walletType,
      'account_name': accountName,
      'account_number': accountNumber,
      if (reason != null) 'reason': reason,
      'status': status,
      if (reference != null) 'reference': reference,
      if (processedBy != null) 'processed_by': processedBy,
      if (processedAt != null) 'processed_at': processedAt!.toUtc().toIso8601String(),
      if (adminNotes != null) 'admin_notes': adminNotes,
    };
  }

  BookingRefundModel copyWith({
    String? id,
    String? bookingId,
    double? amount,
    String? walletType,
    String? accountName,
    String? accountNumber,
    String? reason,
    String? status,
    String? reference,
    String? processedBy,
    DateTime? processedAt,
    String? adminNotes,
  }) {
    return BookingRefundModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      amount: amount ?? this.amount,
      walletType: walletType ?? this.walletType,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      reference: reference ?? this.reference,
      processedBy: processedBy ?? this.processedBy,
      processedAt: processedAt ?? this.processedAt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }
}
