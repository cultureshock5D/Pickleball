class CourtModel {
  final String id;
  final String name;
  final String status;
  final double hourlyRate;
  final String? surfaceType;
  final String? courtType;

  const CourtModel({
    required this.id,
    required this.name,
    this.status = 'active',
    this.hourlyRate = 45.0,
    this.surfaceType = 'Pro-Cushion Hardcourt',
    this.courtType = 'Championship Indoor',
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    // Determine custom visual metadata based on court name if not present in DB schema
    final name = json['name'] as String? ?? 'Court';
    double rate = 45.0;
    String surface = 'Pro-Cushion Hardcourt';
    String type = 'Championship Indoor';

    if (name.toLowerCase().contains('arena') || name.toLowerCase().contains('2')) {
      rate = 55.0;
      surface = 'Ultra-Fast Acrylic';
      type = 'LED Glow Indoor';
    } else if (name.toLowerCase().contains('skyline') || name.toLowerCase().contains('3')) {
      rate = 40.0;
      surface = 'All-Weather Surface';
      type = 'Rooftop Covered';
    }

    return CourtModel(
      id: json['id'] as String,
      name: name,
      status: json['status'] as String? ?? 'active',
      hourlyRate: (json['hourly_rate'] != null)
          ? (json['hourly_rate'] as num).toDouble()
          : rate,
      surfaceType: json['surface_type'] as String? ?? surface,
      courtType: json['court_type'] as String? ?? type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
    };
  }
}
