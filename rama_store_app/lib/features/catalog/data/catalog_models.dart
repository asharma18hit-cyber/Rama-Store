class Category {
  final int id;
  final String name;
  final int? parentId;

  Category({
    required this.id,
    required this.name,
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      parentId: json['parent_id'],
    );
  }
}

class Product {
  final int id;
  final String sku;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final double sellingPrice;
  final int stock;
  final String status;
  final String? imageUrl;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.sellingPrice,
    required this.stock,
    required this.status,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] ?? 0,
      status: json['status'] ?? 'published',
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category_id': categoryId,
        'category_name': categoryName,
        'selling_price': sellingPrice,
        'stock': stock,
        'status': status,
        'image_url': imageUrl,
      };

  String get displayBadge {
    if (sellingPrice > 800) return 'Popular';
    if (stock < 5 && stock > 0) return 'Bestseller';
    if (id % 2 == 0) return 'New Arrival';
    return 'Must Have';
  }

  bool get isInStock => stock > 0;
}

class ProductResponse {
  final List<Product> products;
  final int page;
  final int perPage;
  final int totalCount;
  final int totalPages;

  ProductResponse({
    required this.products,
    required this.page,
    required this.perPage,
    required this.totalCount,
    required this.totalPages,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['products'] as List? ?? [])
        .map((item) => Product.fromJson(item))
        .toList();
    return ProductResponse(
      products: list,
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 8,
      totalCount: json['total_count'] ?? list.length,
      totalPages: json['total_pages'] ?? 1,
    );
  }
}

class Announcement {
  final String stockStatus;
  final String loyaltyOffer;
  final String homeDelivery;

  Announcement({
    required this.stockStatus,
    required this.loyaltyOffer,
    required this.homeDelivery,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      stockStatus: json['stock_status'] ?? '',
      loyaltyOffer: json['loyalty_offer'] ?? '',
      homeDelivery: json['home_delivery'] ?? '',
    );
  }
}
