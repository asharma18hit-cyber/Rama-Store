import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import 'catalog_models.dart';

abstract class CatalogRepository {
  Future<ProductResponse> getProducts({
    int page = 1,
    int perPage = 8,
    String search = '',
    int? categoryId,
    double? maxPrice,
  });
  Future<List<Category>> getCategories();
  Future<Announcement> getAnnouncements();
}

class ApiCatalogRepository implements CatalogRepository {
  final ApiClient apiClient;
  final LocalStorageService storage;
  final bool useMocks;

  ApiCatalogRepository({
    required this.apiClient,
    required this.storage,
    this.useMocks = const bool.fromEnvironment('USE_MOCKS', defaultValue: false),
  });

  @override
  Future<ProductResponse> getProducts({
    int page = 1,
    int perPage = 8,
    String search = '',
    int? categoryId,
    double? maxPrice,
  }) async {
    if (useMocks) {
      return _getMockProducts(page: page, search: search, categoryId: categoryId);
    }

    try {
      final params = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      if (search.isNotEmpty) params['search'] = search;
      if (categoryId != null) params['category_id'] = categoryId;
      if (maxPrice != null) params['max_price'] = maxPrice;

      final res = await apiClient.get('/api/store/products', queryParameters: params);
      final responseObj = ProductResponse.fromJson(res);

      // Cache first page for offline store browsing
      if (page == 1 && search.isEmpty && categoryId == null) {
        await storage.setString(AppConstants.keyCachedProducts, jsonEncode(res));
      }

      return responseObj;
    } catch (_) {
      // Offline fallback from local cache
      final cachedJson = storage.getString(AppConstants.keyCachedProducts);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        return ProductResponse.fromJson(jsonDecode(cachedJson));
      }
      return _getMockProducts(page: page, search: search, categoryId: categoryId);
    }
  }

  @override
  Future<List<Category>> getCategories() async {
    if (useMocks) return _getMockCategories();

    try {
      final res = await apiClient.get('/api/categories');
      final list = (res as List).map((i) => Category.fromJson(i)).toList();
      return list;
    } catch (_) {
      return _getMockCategories();
    }
  }

  @override
  Future<Announcement> getAnnouncements() async {
    if (useMocks) {
      return Announcement(
        stockStatus: 'Fresh Inventory Active',
        loyaltyOffer: '10% Cash-Back Loyalty Points Credit',
        homeDelivery: 'Free Local Delivery on Orders > ₹500',
      );
    }
    try {
      final res = await apiClient.get('/api/announcements');
      return Announcement.fromJson(res);
    } catch (_) {
      return Announcement(
        stockStatus: 'Store Operational',
        loyaltyOffer: '10% Loyalty Cash-Back Active',
        homeDelivery: 'Free Delivery above ₹500',
      );
    }
  }

  List<Category> _getMockCategories() {
    return [
      Category(id: 1, name: 'Bakery'),
      Category(id: 2, name: 'Groceries'),
      Category(id: 3, name: 'Medicine'),
      Category(id: 4, name: 'Books'),
      Category(id: 5, name: 'Stationery'),
      Category(id: 6, name: 'Sports Gear'),
    ];
  }

  ProductResponse _getMockProducts({int page = 1, String search = '', int? categoryId}) {
    final allMocks = [
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
    ];

    var filtered = allMocks;
    if (search.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(search.toLowerCase())).toList();
    }
    if (categoryId != null) {
      filtered = filtered.where((p) => p.categoryId == categoryId).toList();
    }

    return ProductResponse(
      products: filtered,
      page: page,
      perPage: 8,
      totalCount: filtered.length,
      totalPages: 1,
    );
  }
}
