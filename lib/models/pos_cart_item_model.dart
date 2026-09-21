import 'pos_product_model.dart';

class PosCartItemModel {
  final PosProductModel product;
  final int quantity;

  const PosCartItemModel({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;
  String get productId => product.id;
  String get productName => product.name;
  double get unitPrice => product.price;

  PosCartItemModel copyWith({
    PosProductModel? product,
    int? quantity,
  }) {
    return PosCartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'product_name': product.name,
      'quantity': quantity,
      'price_at_time': product.price,
      'subtotal': subtotal,
    };
  }
}
