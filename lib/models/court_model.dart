class CourtModel {
  final String id;
  final String name;
  final String status;
  final double hourlyRate;
  final double peakHourlyRate;
  final int peakStartHour;
  final int peakEndHour;
  final String? surfaceType;
  final String? courtType;
  final String? venueId;
  final String? venueName;

  const CourtModel({
    required this.id,
    required this.name,
    this.status = 'active',
    this.hourlyRate = 120.0,
    this.peakHourlyRate = 180.0,
    this.peakStartHour = 17,
    this.peakEndHour = 22,
    this.surfaceType,
    this.courtType,
    this.venueId,
    this.venueName,
  });

  bool isPeakHour(int hour) {
    return hour >= peakStartHour && hour < peakEndHour;
  }

  double rateForHour(int hour) {
    return isPeakHour(hour) ? peakHourlyRate : hourlyRate;
  }

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    // Determine custom visual metadata based on court name if not present in DB schema
    final name = json['name'] as String? ?? 'Court';
    double rate = 120.0;
    double peakRate = 180.0;
    String surface = 'Pro-Cushion Hardcourt';
    String type = 'Championship Indoor';
    String vName = json['venue_name'] as String? ?? 'Barcelona Smash Club';
    String vId = json['venue_id'] as String? ?? 'venue-bcn-1';

    if (name.toLowerCase().contains('arena') || name.toLowerCase().contains('2')) {
      rate = 150.0;
      peakRate = 220.0;
      surface = 'Ultra-Fast Acrylic';
      type = 'LED Glow Indoor';
    } else if (name.toLowerCase().contains('skyline') || name.toLowerCase().contains('3')) {
      rate = 100.0;
      peakRate = 150.0;
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
      peakHourlyRate: (json['peak_hourly_rate'] != null)
          ? (json['peak_hourly_rate'] as num).toDouble()
          : peakRate,
      peakStartHour: json['peak_start_hour'] as int? ?? 17,
      peakEndHour: json['peak_end_hour'] as int? ?? 22,
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
    double? peakHourlyRate,
    int? peakStartHour,
    int? peakEndHour,
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
      peakHourlyRate: peakHourlyRate ?? this.peakHourlyRate,
      peakStartHour: peakStartHour ?? this.peakStartHour,
      peakEndHour: peakEndHour ?? this.peakEndHour,
      surfaceType: surfaceType ?? this.surfaceType,
      courtType: courtType ?? this.courtType,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
    );
  }
}
