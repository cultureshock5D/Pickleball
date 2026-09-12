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
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.createdAt,
    this.updatedAt,
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
      'city': city,
      'address': address,
      'rating': rating,
      'review_count': reviewCount,
      'amenities': amenities,
      'court_count': courtCount,
      'price_starting_at': priceStartingAt,
      'tag': tag,
      'court_type': courtType,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Keyset cursor representing position in (created_at DESC, id DESC) sorted streams.
class KeysetCursor {
  final DateTime createdAt;
  final String id;

  const KeysetCursor({
    required this.createdAt,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toUtc().toIso8601String(),
        'id': id,
      };

  factory KeysetCursor.fromJson(Map<String, dynamic> json) => KeysetCursor(
        createdAt: DateTime.parse(json['createdAt'] as String),
        id: json['id'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeysetCursor &&
          other.createdAt.isAtSameMomentAs(createdAt) &&
          other.id == id;

  @override
  int get hashCode => Object.hash(createdAt, id);

  @override
  String toString() => 'KeysetCursor(createdAt: $createdAt, id: $id)';
}

/// Paginated result chunk holding loaded items, next keyset cursor, and exhaustion flag.
class PaginatedChunk<T> {
  final List<T> items;
  final KeysetCursor? nextCursor;
  final bool hasMore;

  const PaginatedChunk({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}

typedef PageChunk<T> = PaginatedChunk<T>;

