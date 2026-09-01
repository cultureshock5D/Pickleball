class VenueModel {
  final String id;
  final String name;
  final String city;
  final String address;
  final double rating;
  final int reviewCount;
  final List<String> amenities;
  final int courtCount;
  final double priceStartingAt;
  final String tag;
  final String courtType; // e.g. 'Indoor & Outdoor', 'Championship Indoor'

  const VenueModel({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.rating = 4.9,
    this.reviewCount = 120,
    this.amenities = const [],
    this.courtCount = 4,
    this.priceStartingAt = 120.0,
    this.tag = 'POPULAR',
    this.courtType = 'Championship Indoor',
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Club Venue',
      city: json['city'] as String? ?? 'Barcelona',
      address: json['address'] as String? ?? 'Diagonal Mar, Barcelona',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: json['review_count'] as int? ?? 120,
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Pro Cushioning', 'LED Glow Lighting', 'Lounge'],
      courtCount: json['court_count'] as int? ?? 4,
      priceStartingAt: (json['price_starting_at'] as num?)?.toDouble() ?? 120.0,
      tag: json['tag'] as String? ?? 'PREMIUM',
      courtType: json['court_type'] as String? ?? 'Championship Indoor',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'address': address,
      'rating': rating,
      'review_count': reviewCount,
      'amenities': amenities,
      'court_count': courtCount,
      'price_starting_at': priceStartingAt,
      'tag': tag,
      'court_type': courtType,
    };
  }

  VenueModel copyWith({
    String? id,
    String? name,
    String? city,
    String? address,
    double? rating,
    int? reviewCount,
    List<String>? amenities,
    int? courtCount,
    double? priceStartingAt,
    String? tag,
    String? courtType,
  }) {
    return VenueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      amenities: amenities ?? this.amenities,
      courtCount: courtCount ?? this.courtCount,
      priceStartingAt: priceStartingAt ?? this.priceStartingAt,
      tag: tag ?? this.tag,
      courtType: courtType ?? this.courtType,
    );
  }
}
