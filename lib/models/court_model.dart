class CourtModel {
  final String id;
  final String name;
  final String type; // 'indoor' | 'outdoor'
  final String status; // 'active' | 'maintenance' | 'inactive'
  final double hourlyRate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CourtModel({
    required this.id,
    required this.name,
    this.type = 'indoor',
    this.status = 'active',
    this.hourlyRate = 300.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Whether this court is indoor
  bool get isIndoor => type.toLowerCase() == 'indoor';

  /// Whether this court is outdoor
  bool get isOutdoor => type.toLowerCase() == 'outdoor';

  /// Whether this court is available for reservations
  bool get isAvailableForBooking => status.toLowerCase() == 'active';

  /// Returns surface/feature description badge based on type/name
  String get surfaceDescription {
    if (name.contains('Pro Cushion')) return 'Pro Cushion Surface';
    if (isIndoor) return 'Pro Cushion Hardcourt';
    return 'All-Weather Acrylic';
  }

  /// Returns lighting / court badge
  String get courtBadge {
    if (isIndoor) return 'Indoor Championship';
    return 'Outdoor Lighted';
  }

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    final statusVal = (json['status'] as String?)?.toLowerCase() ?? 'active';
    final generatedActive = json['is_active'] as bool? ?? (statusVal == 'active');

    return CourtModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Court',
      type: json['type'] as String? ?? 'indoor',
      status: statusVal,
      hourlyRate: (json['hourly_rate'] != null)
          ? (json['hourly_rate'] as num).toDouble()
          : 300.0,
      isActive: generatedActive,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'hourly_rate': hourlyRate,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  CourtModel copyWith({
    String? id,
    String? name,
    String? type,
    String? status,
    double? hourlyRate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourtModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
