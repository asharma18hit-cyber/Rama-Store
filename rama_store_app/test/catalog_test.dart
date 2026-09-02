import 'package:flutter_test/flutter_test.dart';
import 'package:rama_store_app/features/catalog/data/catalog_models.dart';
import 'package:rama_store_app/features/catalog/data/catalog_repository.dart';
import 'package:rama_store_app/features/catalog/presentation/catalog_notifier.dart';

class MockCatalogRepository implements CatalogRepository {
  final List<Product> mockProducts = [
    Product(id: 1, sku: 'BK-001', name: 'The Art of Clean Code', sellingPrice: 500.0, stock: 10, status: 'published', categoryId: 4, categoryName: 'Books'),
    Product(id: 2, sku: 'BK-002', name: 'Sourdough Artisan Bread', sellingPrice: 150.0, stock: 25, status: 'published', categoryId: 1, categoryName: 'Bakery'),
    Product(id: 3, sku: 'BK-003', name: 'Organic Almond Milk', sellingPrice: 280.0, stock: 15, status: 'published', categoryId: 2, categoryName: 'Groceries'),
  ];

  final List<Category> mockCategories = [
    Category(id: 1, name: 'Bakery'),
    Category(id: 2, name: 'Groceries'),
    Category(id: 4, name: 'Books'),
  ];

  @override
  Future<ProductResponse> getProducts({int page = 1, int perPage = 10, String search = '', int? categoryId, double? maxPrice}) async {
    final filtered = mockProducts.where((p) {
      if (search.isNotEmpty && !p.name.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      if (categoryId != null && p.categoryId != categoryId) {
        return false;
      }
      return true;
    }).toList();

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
    return mockCategories;
  }

  @override
  Future<Announcement> getAnnouncements() async {
    return Announcement(
      stockStatus: 'In Stock',
      loyaltyOffer: '10% Cash-Back Rewards Active',
      homeDelivery: 'Free Delivery Available',
    );
  }

  @override
  Future<void> saveProduct(Product product) async {
    mockProducts.removeWhere((p) => p.id == product.id);
    mockProducts.insert(0, product);
  }

  @override
  Future<void> deleteProduct(int productId) async {
    mockProducts.removeWhere((p) => p.id == productId);
  }

  @override
  Future<void> updateProduct(Product product) async {
    final idx = mockProducts.indexWhere((p) => p.id == product.id);
    if (idx != -1) mockProducts[idx] = product;
  }

  @override
  Future<void> saveCategory(Category category) async {
    mockCategories.add(category);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogNotifier Unit Tests', () {
    late CatalogNotifier catalogNotifier;

    setUp(() {
      catalogNotifier = CatalogNotifier(MockCatalogRepository());
    });

    test('Initializing catalog loads products and categories', () async {
      await catalogNotifier.initCatalog();
      expect(catalogNotifier.state.products.length, 3);
      expect(catalogNotifier.state.categories.length, 3);
      expect(catalogNotifier.state.announcement?.loyaltyOffer, '10% Cash-Back Rewards Active');
    });

    test('Filtering by category updates state products', () async {
      await catalogNotifier.initCatalog();
      await catalogNotifier.setCategory(1); // Bakery
      expect(catalogNotifier.state.products.length, 1);
      expect(catalogNotifier.state.products.first.name, 'Sourdough Artisan Bread');
    });

    test('Search query filters matching products', () async {
      await catalogNotifier.initCatalog();
      await catalogNotifier.setSearchQuery('Clean Code');
      expect(catalogNotifier.state.products.length, 1);
      expect(catalogNotifier.state.products.first.sku, 'BK-001');
    });
  });
}
