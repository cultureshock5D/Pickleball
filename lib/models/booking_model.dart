class BookingModel {
  final String id;
  final String customerId;
  final String courtId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double totalAmount;
  final DateTime? createdAt;
  final String? courtName;

  const BookingModel({
    required this.id,
    required this.customerId,
    required this.courtId,
    required this.startTime,
    required this.endTime,
    this.status = 'pending',
    required this.totalAmount,
    this.createdAt,
    this.courtName,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    String? courtName;
    if (json['courts'] != null && json['courts'] is Map) {
      courtName = json['courts']['name'] as String?;
    }

    return BookingModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      courtId: json['court_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      status: json['status'] as String? ?? 'pending',
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      courtName: courtName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'court_id': courtId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'status': status,
      'total_amount': totalAmount,
    };
  }
}
