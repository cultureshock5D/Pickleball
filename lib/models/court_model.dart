class CourtModel {
  final String id;
  final String name;
  final String status;
  final double hourlyRate;
  final String? surfaceType;
  final String? courtType;
  final String? venueId;
  final String? venueName;

  const CourtModel({
    required this.id,
    required this.name,
    this.status = 'active',
    this.hourlyRate = 120.0,
    this.surfaceType = 'Pro-Cushion Hardcourt',
    this.courtType = 'Championship Indoor',
    this.venueId = 'venue-bcn-1',
    this.venueName = 'Barcelona Smash Club',
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    // Determine custom visual metadata based on court name if not present in DB schema
    final name = json['name'] as String? ?? 'Court';
    double rate = 120.0;
    String surface = 'Pro-Cushion Hardcourt';
    String type = 'Championship Indoor';
    String vName = json['venue_name'] as String? ?? 'Barcelona Smash Club';
    String vId = json['venue_id'] as String? ?? 'venue-bcn-1';

    if (name.toLowerCase().contains('arena') || name.toLowerCase().contains('2')) {
      rate = 150.0;
      surface = 'Ultra-Fast Acrylic';
      type = 'LED Glow Indoor';
    } else if (name.toLowerCase().contains('skyline') || name.toLowerCase().contains('3')) {
      rate = 100.0;
      surface = 'All-Weather Surface';
      type = 'Rooftop Covered';
      vName = 'Skyline Rooftop Club';
      vId = 'venue-sky-2';
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
      venueId: vId,
      venueName: vName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'venue_id': venueId,
      'venue_name': venueName,
    };
  }

  CourtModel copyWith({
    String? id,
    String? name,
    String? status,
    double? hourlyRate,
    String? surfaceType,
    String? courtType,
    String? venueId,
    String? venueName,
  }) {
    return CourtModel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      surfaceType: surfaceType ?? this.surfaceType,
      courtType: courtType ?? this.courtType,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
    );
  }
}
