class DeliveryAddress {
  final String id;
  final String label; // e.g. Home, Work, Other
  final String fullAddress;
  final String city;
  final String postalCode;
  final bool isDefault;

  DeliveryAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.city,
    required this.postalCode,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullAddress': fullAddress,
        'city': city,
        'postalCode': postalCode,
        'isDefault': isDefault,
      };

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) => DeliveryAddress(
        id: json['id'] as String,
        label: json['label'] as String,
        fullAddress: json['fullAddress'] as String,
        city: json['city'] as String,
        postalCode: json['postalCode'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
