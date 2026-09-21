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

  factory PosProductModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as String? ?? 'General';
    final dept = json['department'] as String? ?? resolveDepartment(cat);

    return PosProductModel(
      id: json['id'] as String,
      sku: json['sku'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      category: cat,
      department: dept,
      stockLevel: json['stock_level'] as int? ?? 0,
      reorderThreshold: json['reorder_threshold'] as int? ?? 10,
      isActive: json['is_active'] as bool? ?? true,
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
    );
  }
}
