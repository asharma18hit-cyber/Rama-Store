class OrderItem {
  final int productId;
  final String name;
  final int quantity;
  final double priceAtPurchase;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.priceAtPurchase,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? 'Product',
      quantity: json['quantity'] ?? 1,
      priceAtPurchase: (json['price_at_purchase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final int id;
  final String trackingNumber;
  final double totalAmount;
  final double taxAmount;
  final String? shippingAddress;
  final String status; // 'Pending', 'Paid', 'Shipped', 'Delivered', 'Cancelled'
  final String createdAt;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.trackingNumber,
    required this.totalAmount,
    required this.taxAmount,
    this.shippingAddress,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List? ?? []).map((i) => OrderItem.fromJson(i)).toList();
    return OrderModel(
      id: json['id'] ?? 0,
      trackingNumber: json['tracking_number'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      shippingAddress: json['shipping_address'],
      status: json['status'] ?? 'Pending',
      createdAt: json['created_at'] ?? '',
      items: list,
    );
  }
}
