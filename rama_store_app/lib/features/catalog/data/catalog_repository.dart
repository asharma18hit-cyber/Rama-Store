import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        name: 'Organic Honey 500g',
        categoryId: 2,
        categoryName: 'Grocery',
        sellingPrice: 350.0,
        stock: 40,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1587049352847-4a222e784d38?w=400',
      ),
      Product(
        id: 104,
        sku: 'MED-001',
        name: 'Multivitamin Supplements 60s',
        categoryId: 3,
        categoryName: 'Medicine',
        sellingPrice: 650.0,
        stock: 18,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400',
      ),
      Product(
        id: 105,
        sku: 'SPT-001',
        name: 'Pro Badminton Racket',
        categoryId: 5,
        categoryName: 'Sports',
        sellingPrice: 1499.0,
        stock: 8,
        status: 'published',
        imageUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=400',
      ),
    ];
  }

  List<Category> _getInitialDefaultCategories() {
    return [
      Category(id: 1, name: 'Bakery'),
      Category(id: 2, name: 'Grocery'),
      Category(id: 3, name: 'Medicine'),
      Category(id: 4, name: 'Books'),
      Category(id: 5, name: 'Sports'),
    ];
  }

  List<Product> _loadStoredProducts() {
    final raw = storage.getString(keyPersistentProducts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    final initial = _getInitialDefaultProducts();
    _saveStoredProducts(initial);
    return initial;
  }

  Future<void> _saveStoredProducts(List<Product> products) async {
    final raw = jsonEncode(products.map((p) => p.toJson()).toList());
    await storage.setString(keyPersistentProducts, raw);
  }

  List<Category> _loadStoredCategories() {
    final raw = storage.getString(keyPersistentCategories);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    final initial = _getInitialDefaultCategories();
    _saveStoredCategories(initial);
    return initial;
  }

  Future<void> _saveStoredCategories(List<Category> categories) async {
    final raw = jsonEncode(categories.map((c) => c.toJson()).toList());
    await storage.setString(keyPersistentCategories, raw);
  }

  @override
  Future<ProductResponse> getProducts({
    int page = 1,
    int perPage = 20,
    String search = '',
    int? categoryId,
    double? maxPrice,
  }) async {
    // 1. Try Cloud Firestore first
    try {
      final snap = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'published')
          .get();

      if (snap.docs.isNotEmpty) {
        final fsProducts = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = data['id'] ?? doc.id;
          return Product.fromJson(data);
        }).toList();

        var filtered = List<Product>.from(fsProducts);
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
    } catch (_) {}

    // 2. Fallback to Local Storage
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
  Future<List<Category>> getCategories() async {
    // 1. Try Cloud Firestore first
    try {
      final snap = await _firestore.collection('categories').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = data['id'] ?? doc.id;
          return Category.fromJson(data);
        }).toList();
      }
    } catch (_) {}

    return _loadStoredCategories();
  }

  @override
  Future<Announcement> getAnnouncements() async {
    return Announcement(
      stockStatus: 'Fresh bakery items updated daily',
      loyaltyOffer: 'Get 10% Instant Loyalty Cash-Back on all grocery & bakery orders over ₹500!',
      homeDelivery: 'Free 2-hour express delivery for gold members',
    );
  }

  @override
  Future<void> saveProduct(Product product) async {
    final products = _loadStoredProducts();
    products.removeWhere((p) => p.id == product.id || p.sku == product.sku);
    products.insert(0, product);
    await _saveStoredProducts(products);

    // Sync to Cloud Firestore
    try {
      await _firestore.collection('products').doc(product.id.toString()).set(
        product.toJson(),
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteProduct(int productId) async {
    final products = _loadStoredProducts();
    products.removeWhere((p) => p.id == productId);
    await _saveStoredProducts(products);

    try {
      await _firestore.collection('products').doc(productId.toString()).delete();
    } catch (_) {}
  }

  @override
  Future<void> updateProduct(Product product) async {
    await saveProduct(product);
  }

  @override
  Future<void> saveCategory(Category category) async {
    final categories = _loadStoredCategories();
    categories.removeWhere((c) => c.id == category.id);
    categories.insert(0, category);
    await _saveStoredCategories(categories);

    try {
      await _firestore.collection('categories').doc(category.id.toString()).set(
        category.toJson(),
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
