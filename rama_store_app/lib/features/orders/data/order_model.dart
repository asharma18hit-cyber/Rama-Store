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

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'quantity': quantity,
      'price_at_purchase': priceAtPurchase,
    };
  }
}

class OrderModel {
  final int id;
  final String trackingNumber;
  final double totalAmount;
  final double taxAmount;
  final String? shippingAddress;
  final String orderStatus; // 'Confirmed', 'Packed', 'Dispatched', 'Delivered', 'Cancelled'
  final String paymentStatus; // 'Pending', 'Paid', 'Unpaid', 'Refund Pending', 'Refunded', 'Failed'
  final String paymentMethod; // 'COD', 'Card', 'UPI'
  final String createdAt;
  final String? cancellationReason;
  final String? cancellationReasonDetail;
  final String? cancelledAt;
  final String? paidAt;
  final String? refundStatus;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.trackingNumber,
    required this.totalAmount,
    required this.taxAmount,
    this.shippingAddress,
    required this.orderStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
    this.cancellationReason,
    this.cancellationReasonDetail,
    this.cancelledAt,
    this.paidAt,
    this.refundStatus,
    required this.items,
  });

  // Backward compatibility alias
  String get status => orderStatus;

  bool get isCancellable {
    final s = orderStatus.toLowerCase();
    return s != 'dispatched' && s != 'out for delivery' && s != 'delivered' && s != 'cancelled';
  }

  bool get isCod => paymentMethod.toUpperCase() == 'COD';

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';

  bool get isCancelled => orderStatus.toLowerCase() == 'cancelled';

  bool get canPayNow => !isPaid && !isCancelled && orderStatus.toLowerCase() != 'delivered';

  double get amountDue => (isPaid || isCancelled) ? 0.0 : totalAmount;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List? ?? [])
        .map((i) => OrderItem.fromJson(i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i)))
        .toList();

    final rawStatus = json['order_status'] ?? json['status'] ?? 'Confirmed';
    final rawPaymentStatus = json['payment_status'] ?? (json['payment_method']?.toString().toUpperCase() == 'COD' ? 'Pending' : 'Paid');
    final rawPaymentMethod = json['payment_method'] ?? 'Card';

    return OrderModel(
      id: json['id'] ?? 0,
      trackingNumber: json['tracking_number'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      shippingAddress: json['shipping_address'],
      orderStatus: rawStatus,
      paymentStatus: rawPaymentStatus,
      paymentMethod: rawPaymentMethod,
      createdAt: json['created_at'] ?? '',
      cancellationReason: json['cancellation_reason'],
      cancellationReasonDetail: json['cancellation_reason_detail'],
      cancelledAt: json['cancelled_at'],
      paidAt: json['paid_at'],
      refundStatus: json['refund_status'],
      items: list,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tracking_number': trackingNumber,
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'shipping_address': shippingAddress,
      'order_status': orderStatus,
      'status': orderStatus,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'created_at': createdAt,
      'cancellation_reason': cancellationReason,
      'cancellation_reason_detail': cancellationReasonDetail,
      'cancelled_at': cancelledAt,
      'paid_at': paidAt,
      'refund_status': refundStatus,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  OrderModel copyWith({
    int? id,
    String? trackingNumber,
    double? totalAmount,
    double? taxAmount,
    String? shippingAddress,
    String? orderStatus,
    String? paymentStatus,
    String? paymentMethod,
    String? createdAt,
    String? cancellationReason,
    String? cancellationReasonDetail,
    String? cancelledAt,
    String? paidAt,
    String? refundStatus,
    List<OrderItem>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationReasonDetail: cancellationReasonDetail ?? this.cancellationReasonDetail,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      paidAt: paidAt ?? this.paidAt,
      refundStatus: refundStatus ?? this.refundStatus,
      items: items ?? this.items,
    );
  }
}
