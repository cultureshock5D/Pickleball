import 'dart:convert';
import 'court_model.dart';
import 'booking_refund_model.dart';

class BookingModel {
  final String id;
  final String courtId;
  final String? userId;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final DateTime startTime;
  final DateTime endTime;
  final int durationHours;
  final double totalPrice;
  final String currency;
  final String status; // pending_payment | paid | checked_in | walk_in | cancelled | cancelled_refund_pending | expired
  final String paymentMethod; // paymongo | cash | counter_qr | other
  final String? paymongoCheckoutSessionId;
  final DateTime? expiresAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final CourtModel? court;
  final BookingRefundModel? refund;
  final String? courtName;

  const BookingModel({
    required this.id,
    required this.courtId,
    this.userId,
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    required this.startTime,
    required this.endTime,
    this.durationHours = 1,
    required this.totalPrice,
    this.currency = 'PHP',
    this.status = 'pending_payment',
    this.paymentMethod = 'paymongo',
    this.paymongoCheckoutSessionId,
    this.expiresAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.court,
    this.refund,
    this.courtName,
  });

  /// Alias for backward compatibility
  double get totalAmount => totalPrice;

  /// Alias for backward compatibility
  String get customerId => userId ?? '';

  bool get isPaid =>
      status == 'paid' ||
      status == 'confirmed' ||
      status == 'checked_in' ||
      status == 'walk_in';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCancelled =>
      status == 'cancelled' || status == 'cancelled_refund_pending';
  bool get isRefundPending => status == 'cancelled_refund_pending';
  bool get isPendingPayment =>
      status == 'pending_payment' || status == 'pending';
  bool get isMaintenance => status == 'maintenance';

  /// Check if 5-minute checkout hold is expired
  bool get isHoldExpired {
    if (status == 'expired') return true;
    if ((status == 'pending_payment' || status == 'pending') && expiresAt != null) {
      return expiresAt!.isBefore(DateTime.now());
    }
    return false;
  }

  /// Strict 24-hour advance cancellation rule:
  /// Client can only cancel if start_time - now >= 24 hours AND booking is paid/confirmed
  bool get isCancellable {
    if (!isPaid) return false;
    final hoursUntil = startTime.difference(DateTime.now()).inHours;
    return hoursUntil >= 24;
  }

  /// Generate official QR code payload for court gate check-in
  String get qrPayload {
    return jsonEncode({
      'bookingId': id,
      'system': 'C&J Court',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Display court name
  String get displayCourtName => court?.name ?? courtName ?? 'Pickleball Court';

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    CourtModel? parsedCourt;
    String? courtNameStr;

    if (json['courts'] != null && json['courts'] is Map) {
      parsedCourt =
          CourtModel.fromJson(json['courts'] as Map<String, dynamic>);
      courtNameStr = parsedCourt.name;
    } else if (json['court_name'] != null) {
      courtNameStr = json['court_name'] as String?;
    }

    BookingRefundModel? parsedRefund;
    if (json['booking_refunds'] != null) {
      if (json['booking_refunds'] is List &&
          (json['booking_refunds'] as List).isNotEmpty) {
        parsedRefund = BookingRefundModel.fromJson(
            (json['booking_refunds'] as List).first as Map<String, dynamic>);
      } else if (json['booking_refunds'] is Map) {
        parsedRefund = BookingRefundModel.fromJson(
            json['booking_refunds'] as Map<String, dynamic>);
      }
    }

    final sTime = DateTime.parse(json['start_time'] as String).toLocal();
    final eTime = DateTime.parse(json['end_time'] as String).toLocal();
    final diffHours = eTime.difference(sTime).inHours;

    final priceVal = json['total_price'] ?? json['total_amount'] ?? 0.0;

    return BookingModel(
      id: json['id'] as String,
      courtId: json['court_id'] as String,
      userId: json['user_id'] as String? ?? json['customer_id'] as String?,
      guestName: json['guest_name'] as String? ?? '',
      guestEmail: json['guest_email'] as String? ?? '',
      guestPhone: json['guest_phone'] as String? ?? '',
      startTime: sTime,
      endTime: eTime,
      durationHours: (json['duration_hours'] as int?) ?? (diffHours > 0 ? diffHours : 1),
      totalPrice: (priceVal as num).toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      status: json['status'] as String? ?? 'pending_payment',
      paymentMethod: json['payment_method'] as String? ?? 'paymongo',
      paymongoCheckoutSessionId:
          json['paymongo_checkout_session_id'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)?.toLocal()
          : null,
      court: parsedCourt,
      refund: parsedRefund,
      courtName: courtNameStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'court_id': courtId,
      if (userId != null) 'user_id': userId,
      'guest_name': guestName,
      'guest_email': guestEmail,
      'guest_phone': guestPhone,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'duration_hours': durationHours,
      'total_price': totalPrice,
      'currency': currency,
      'status': status,
      'payment_method': paymentMethod,
      if (paymongoCheckoutSessionId != null)
        'paymongo_checkout_session_id': paymongoCheckoutSessionId,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  BookingModel copyWith({
    String? id,
    String? courtId,
    String? userId,
    String? guestName,
    String? guestEmail,
    String? guestPhone,
    DateTime? startTime,
    DateTime? endTime,
    int? durationHours,
    double? totalPrice,
    String? currency,
    String? status,
    String? paymentMethod,
    String? paymongoCheckoutSessionId,
    DateTime? expiresAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    CourtModel? court,
    BookingRefundModel? refund,
    String? courtName,
  }) {
    return BookingModel(
      id: id ?? this.id,
      courtId: courtId ?? this.courtId,
      userId: userId ?? this.userId,
      guestName: guestName ?? this.guestName,
      guestEmail: guestEmail ?? this.guestEmail,
      guestPhone: guestPhone ?? this.guestPhone,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationHours: durationHours ?? this.durationHours,
      totalPrice: totalPrice ?? this.totalPrice,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymongoCheckoutSessionId:
          paymongoCheckoutSessionId ?? this.paymongoCheckoutSessionId,
      expiresAt: expiresAt ?? this.expiresAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      court: court ?? this.court,
      refund: refund ?? this.refund,
      courtName: courtName ?? this.courtName,
    );
  }
}
