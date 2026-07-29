import '../../catalog/data/catalog_models.dart';

class CartItem {
  final Product product;
  final int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get lineTotal => product.sellingPrice * quantity;

  Map<String, dynamic> toJson() => {
        'id': product.id,
        'qty': quantity,
        'product': product.toJson(),
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] ?? json),
      quantity: json['qty'] ?? json['quantity'] ?? 1,
    );
  }
}
