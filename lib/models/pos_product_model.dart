class PosProductModel {
  final String id;
  final String? sku;
  final String name;
  final double price;
  final double costPrice;
  final String category;
  final String department;
  final int stockLevel;
  final int reorderThreshold;
  final bool isActive;
  final String? imagePath;

  const PosProductModel({
    required this.id,
    this.sku,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.category,
    required this.department,
    this.stockLevel = 0,
    this.reorderThreshold = 10,
    this.isActive = true,
    this.imagePath,
  });

  bool get isOutOfStock => stockLevel <= 0;

  static String resolveDepartment(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('coffee') || lower.contains('espresso') || lower.contains('brew')) {
      return 'Coffee';
    }
    if (lower.contains('drink') ||
        lower.contains('tea') ||
        lower.contains('shake') ||
        lower.contains('hydration') ||
        lower.contains('beverage') ||
        lower.contains('water')) {
      return 'Drinks';
    }
    if (lower.contains('food') ||
        lower.contains('silog') ||
        lower.contains('meal') ||
        lower.contains('snack') ||
        lower.contains('dimsum') ||
        lower.contains('noodle') ||
        lower.contains('pasta') ||
        lower.contains('rice')) {
      return 'Food';
    }
    return 'Supplies';
  }

  String get effectiveImagePath =>
      (imagePath != null && imagePath!.isNotEmpty) ? imagePath! : resolveImagePath(name, category);

  /// Automatically matches product to authentic image asset inside cashier_pos/
  static String resolveImagePath(String name, String category) {
    final lowerName = name.toLowerCase().trim();
    final lowerCat = category.toLowerCase().trim();

    // Coffee & Barista Drinks
    if (lowerName.contains('americano') || lowerName.contains('long black')) return 'cashier_pos/long-black.jpg';
    if (lowerName.contains('capuccino') || lowerName.contains('cappuccino') || lowerName.contains('flat white')) {
      return 'cashier_pos/cappuccino.jpg';
    }
    if (lowerName.contains('spanish latte') || lowerName.contains('vanilla')) return 'cashier_pos/spanish-latte.jpg';
    if (lowerName.contains('seasalt latte')) return 'cashier_pos/seasalt-latte.jpg';
    if (lowerName.contains('caramel macchiato')) return 'cashier_pos/caramel-macchiato.jpg';
    if (lowerName.contains('brown sugar')) return 'cashier_pos/brown-sugar-latte.jpg';
    if (lowerName.contains('mocha')) return 'cashier_pos/mocha-latte.jpg';
    if (lowerName.contains('choco hazelnut') || lowerName.contains('hazelnut')) return 'cashier_pos/choco-hazelnut.jpg';
    if (lowerName.contains('butterscotch') || lowerName.contains('salted caramel')) {
      return 'cashier_pos/seasalt-butterscotch.jpg';
    }

    // Pickleball Equipment & Pro Shop
    if (lowerName.contains('paddle') || lowerCat.contains('paddle') || lowerCat.contains('equipment') || lowerCat.contains('pro shop')) {
      return 'cashier_pos/gear-paddle.jpg';
    }
    if (lowerName.contains('thrower') || lowerName.contains('machine')) {
      return 'cashier_pos/gear-ball-thrower.png';
    }
    if (lowerName.contains('ball') || lowerCat.contains('gear') || lowerCat.contains('accessory')) {
      return 'cashier_pos/gear-balls.jpg';
    }

    // Court & Facility Services
    if (lowerName.contains('court') || lowerCat.contains('court')) return 'cashier_pos/service-court.jpg';
    if (lowerName.contains('event') || lowerName.contains('hall') || lowerName.contains('pavilion') || lowerCat.contains('event')) {
      return 'cashier_pos/service-events.jpg';
    }
    if (lowerName.contains('deck') || lowerName.contains('lounge') || lowerName.contains('viewdeck')) {
      return 'cashier_pos/service-viewdeck.jpg';
    }

    // Category fallbacks
    if (lowerCat.contains('coffee') || lowerCat.contains('espresso') || lowerCat.contains('brew')) {
      return 'cashier_pos/cappuccino.jpg';
    }

    // Default brand logo
    return 'cashier_pos/cj-logo.png';
  }

  factory PosProductModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as String? ?? 'General';
    final dept = json['department'] as String? ?? resolveDepartment(cat);
    final name = json['name'] as String? ?? 'Item';

    return PosProductModel(
      id: json['id'] as String,
      sku: json['sku'] as String?,
      name: name,
      price: (json['price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      category: cat,
      department: dept,
      stockLevel: json['stock_level'] as int? ?? 0,
      reorderThreshold: json['reorder_threshold'] as int? ?? 10,
      isActive: json['is_active'] as bool? ?? true,
      imagePath: json['image_path'] as String? ?? resolveImagePath(name, cat),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sku != null) 'sku': sku,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'category': category,
      'department': department,
      'stock_level': stockLevel,
      'reorder_threshold': reorderThreshold,
      'is_active': isActive,
      if (imagePath != null) 'image_path': imagePath,
    };
  }

  PosProductModel copyWith({
    String? id,
    String? sku,
    String? name,
    double? price,
    double? costPrice,
    String? category,
    String? department,
    int? stockLevel,
    int? reorderThreshold,
    bool? isActive,
    String? imagePath,
  }) {
    return PosProductModel(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      category: category ?? this.category,
      department: department ?? this.department,
      stockLevel: stockLevel ?? this.stockLevel,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
