import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import 'catalog_models.dart';

abstract class CatalogRepository {
  Future<ProductResponse> getProducts({
    int page = 1,
    int perPage = 20,
    String search = '',
    int? categoryId,
    double? maxPrice,
  });
  Future<List<Category>> getCategories();
  Future<Announcement> getAnnouncements();
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(int productId);
  Future<void> updateProduct(Product product);
  Future<void> saveCategory(Category category);
}

class ApiCatalogRepository implements CatalogRepository {
  final ApiClient apiClient;
  final LocalStorageService storage;
  final bool useMocks;

  static const String keyPersistentProducts = 'persistent_store_products_v3';
  static const String keyPersistentCategories = 'persistent_store_categories_v3';

  ApiCatalogRepository({
    required this.apiClient,
    required this.storage,
    this.useMocks = const bool.fromEnvironment('USE_MOCKS', defaultValue: false),
  });

  List<Product> _getInitialDefaultProducts() {
    return [
      Product(
        id: 101,
        sku: 'BK-001',
        name: 'The Art of Clean Code',
        categoryId: 4,
        categoryName: 'Books',
        sellingPrice: 499.0,
        stock: 12,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400',
      ),
      Product(
        id: 102,
        sku: 'BAK-001',
        name: 'Artisanal Butter Croissant',
        categoryId: 1,
        categoryName: 'Bakery',
        sellingPrice: 120.0,
        stock: 25,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=400',
      ),
      Product(
        id: 103,
        sku: 'GRO-001',
        name: 'Organic Honey & Whole Wheat',
        categoryId: 2,
        categoryName: 'Groceries',
        sellingPrice: 250.0,
        stock: 40,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400',
      ),
      Product(
        id: 104,
        sku: 'MED-001',
        name: 'First Aid Medical Kit Premium',
        categoryId: 3,
        categoryName: 'Medicine',
        sellingPrice: 799.0,
        stock: 15,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=400',
      ),
      Product(
        id: 105,
        sku: 'SPO-001',
        name: 'Pro Graphite Badminton Racket',
        categoryId: 6,
        categoryName: 'Sports Gear',
        sellingPrice: 1499.0,
        stock: 8,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=400',
      ),
      Product(
        id: 106,
        sku: 'STA-001',
        name: 'Executive Leather Notebook',
        categoryId: 5,
        categoryName: 'Stationery',
        sellingPrice: 349.0,
        stock: 30,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=400',
      ),
      Product(
        id: 107,
        sku: 'TECH-001',
        name: 'Noise-Cancelling Wireless Earbuds',
        categoryId: 7,
        categoryName: 'Tech & Electronics',
        sellingPrice: 2499.0,
        stock: 18,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400',
      ),
    ];
  }

  List<Product> _loadStoredProducts() {
    final raw = storage.getString(keyPersistentProducts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    final defaults = _getInitialDefaultProducts();
    _saveStoredProducts(defaults);
    return defaults;
  }

  Future<void> _saveStoredProducts(List<Product> products) async {
    final jsonList = products.map((p) => p.toJson()).toList();
    await storage.setString(keyPersistentProducts, jsonEncode(jsonList));
  }

  @override
  Future<ProductResponse> getProducts({
    int page = 1,
    int perPage = 20,
    String search = '',
    int? categoryId,
    double? maxPrice,
  }) async {
    // 1. Load from Persistent Storage
    final allProducts = _loadStoredProducts();

    var filtered = List<Product>.from(allProducts);

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.sku.toLowerCase().contains(q) ||
        (p.categoryName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    if (categoryId != null) {
      filtered = filtered.where((p) => p.categoryId == categoryId).toList();
    }

    if (maxPrice != null) {
      filtered = filtered.where((p) => p.sellingPrice <= maxPrice).toList();
    }

    return ProductResponse(
      products: filtered,
      page: page,
      perPage: perPage,
      totalCount: filtered.length,
      totalPages: 1,
    );
  }

  @override
  Future<void> saveProduct(Product product) async {
    final products = _loadStoredProducts();
    products.removeWhere((p) => p.id == product.id || p.sku == product.sku);
    products.insert(0, product);
    await _saveStoredProducts(products);

    // Also sync to backend API if available
    try {
      await apiClient.post('/api/admin/products', data: product.toJson());
    } catch (_) {}
  }

  @override
  Future<void> deleteProduct(int productId) async {
    final products = _loadStoredProducts();
    products.removeWhere((p) => p.id == productId);
    await _saveStoredProducts(products);

    try {
      await apiClient.delete('/api/admin/products/$productId');
    } catch (_) {}
  }

  @override
  Future<void> updateProduct(Product product) async {
    final products = _loadStoredProducts();
    final idx = products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      products[idx] = product;
    } else {
      products.add(product);
    }
    await _saveStoredProducts(products);

    try {
      await apiClient.put('/api/admin/products/${product.id}', data: product.toJson());
    } catch (_) {}
  }

  @override
  Future<List<Category>> getCategories() async {
    final raw = storage.getString(keyPersistentCategories);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((i) => Category.fromJson(i)).toList();
      } catch (_) {}
    }

    final defaultCats = [
      Category(id: 1, name: 'Bakery'),
      Category(id: 2, name: 'Groceries'),
      Category(id: 3, name: 'Medicine'),
      Category(id: 4, name: 'Books'),
      Category(id: 5, name: 'Stationery'),
      Category(id: 6, name: 'Sports Gear'),
      Category(id: 7, name: 'Tech & Electronics'),
    ];

    await saveCategoriesList(defaultCats);
    return defaultCats;
  }

  Future<void> saveCategoriesList(List<Category> categories) async {
    final jsonList = categories.map((c) => c.toJson()).toList();
    await storage.setString(keyPersistentCategories, jsonEncode(jsonList));
  }

  @override
  Future<void> saveCategory(Category category) async {
    final current = await getCategories();
    current.removeWhere((c) => c.id == category.id || c.name.toLowerCase() == category.name.toLowerCase());
    current.add(category);
    await saveCategoriesList(current);
  }

  @override
  Future<Announcement> getAnnouncements() async {
    return Announcement(
      stockStatus: 'Store Operational',
      loyaltyOffer: '10% Loyalty Cash-Back Active',
      homeDelivery: 'Free Delivery above ₹500',
    );
  }
}
