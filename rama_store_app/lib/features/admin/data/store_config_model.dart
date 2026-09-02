class StoreCoupon {
  final String code;
  final String description;
  final String discountType; // 'flat' or 'percent'
  final double discountValue;
  final double minOrderAmount;
  final bool isActive;

  const StoreCoupon({
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    this.isActive = true,
  });

  double calculateDiscount(double subtotal) {
    if (!isActive || subtotal < minOrderAmount) return 0.0;
    if (discountType == 'percent') {
      return (subtotal * (discountValue / 100.0));
    }
    return discountValue.clamp(0.0, subtotal);
  }

  StoreCoupon copyWith({
    String? code,
    String? description,
    String? discountType,
    double? discountValue,
    double? minOrderAmount,
    bool? isActive,
  }) {
    return StoreCoupon(
      code: code ?? this.code,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'description': description,
    'discountType': discountType,
    'discountValue': discountValue,
    'minOrderAmount': minOrderAmount,
    'isActive': isActive,
  };

  factory StoreCoupon.fromJson(Map<String, dynamic> json) => StoreCoupon(
    code: json['code'] ?? '',
    description: json['description'] ?? '',
    discountType: json['discountType'] ?? 'flat',
    discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
    minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
    isActive: json['isActive'] ?? true,
  );
}

class StoreConfig {
  final double freeDeliveryThreshold;
  final double standardDeliveryFee;
  final double flashSaleDiscountPercent;
  final String announcementText;
  final bool isStoreOpen;
  final List<StoreCoupon> coupons;

  const StoreConfig({
    this.freeDeliveryThreshold = 500.0,
    this.standardDeliveryFee = 40.0,
    this.flashSaleDiscountPercent = 0.0,
    this.announcementText = '✨ Mega Store Sale: Free Doorstep Delivery on orders above ₹500!',
    this.isStoreOpen = true,
    this.coupons = const [
      StoreCoupon(
        code: 'RAMA50',
        description: '₹50 Flat Discount on orders above ₹299',
        discountType: 'flat',
        discountValue: 50.0,
        minOrderAmount: 299.0,
        isActive: true,
      ),
      StoreCoupon(
        code: 'FESTIVE10',
        description: '10% Instant Savings on orders above ₹499',
        discountType: 'percent',
        discountValue: 10.0,
        minOrderAmount: 499.0,
        isActive: true,
      ),
      StoreCoupon(
        code: 'WELCOME100',
        description: '₹100 Mega Discount on orders above ₹799',
        discountType: 'flat',
        discountValue: 100.0,
        minOrderAmount: 799.0,
        isActive: true,
      ),
    ],
  });

  StoreConfig copyWith({
    double? freeDeliveryThreshold,
    double? standardDeliveryFee,
    double? flashSaleDiscountPercent,
    String? announcementText,
    bool? isStoreOpen,
    List<StoreCoupon>? coupons,
  }) {
    return StoreConfig(
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      standardDeliveryFee: standardDeliveryFee ?? this.standardDeliveryFee,
      flashSaleDiscountPercent: flashSaleDiscountPercent ?? this.flashSaleDiscountPercent,
      announcementText: announcementText ?? this.announcementText,
      isStoreOpen: isStoreOpen ?? this.isStoreOpen,
      coupons: coupons ?? this.coupons,
    );
  }
}
