import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

class CatalogState {
  final List<Product> products;
  final List<Category> categories;
  final Announcement? announcement;
  final bool isLoading;
  final bool isMoreLoading;
  final String? errorMessage;
  final int currentPage;
  final int totalPages;
  final int? selectedCategoryId;
  final String searchQuery;
  final bool isOffline;

  CatalogState({
    this.products = const [],
    this.categories = const [],
    this.announcement,
    this.isLoading = false,
    this.isMoreLoading = false,
    this.errorMessage,
    this.currentPage = 1,
    this.totalPages = 1,
    this.selectedCategoryId,
    this.searchQuery = '',
    this.isOffline = false,
  });

  CatalogState copyWith({
    List<Product>? products,
    List<Category>? categories,
    Announcement? announcement,
    bool? isLoading,
    bool? isMoreLoading,
    String? errorMessage,
    int? currentPage,
    int? totalPages,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    bool? isOffline,
  }) {
    return CatalogState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      announcement: announcement ?? this.announcement,
      isLoading: isLoading ?? this.isLoading,
      isMoreLoading: isMoreLoading ?? this.isMoreLoading,
      errorMessage: errorMessage,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  final CatalogRepository repository;

  CatalogNotifier(this.repository) : super(CatalogState()) {
    initCatalog();
  }

  Future<void> initCatalog() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final categories = await repository.getCategories();
      final announcement = await repository.getAnnouncements();
      final res = await repository.getProducts(page: 1);

      state = state.copyWith(
        categories: categories,
        announcement: announcement,
        products: res.products,
        currentPage: res.page,
        totalPages: res.totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString(), isOffline: true);
    }
  }

  Future<void> setCategory(int? categoryId) async {
    if (state.selectedCategoryId == categoryId) return;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
      isLoading: true,
      currentPage: 1,
    );
    await _fetchProducts();
  }

  Future<void> setSearchQuery(String query) async {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, isLoading: true, currentPage: 1);
    await _fetchProducts();
  }

  Future<void> loadMore() async {
    if (state.isMoreLoading || state.currentPage >= state.totalPages) return;
    state = state.copyWith(isMoreLoading: true);
    try {
      final nextPage = state.currentPage + 1;
      final res = await repository.getProducts(
        page: nextPage,
        search: state.searchQuery,
        categoryId: state.selectedCategoryId,
      );
      state = state.copyWith(
        products: [...state.products, ...res.products],
        currentPage: res.page,
        totalPages: res.totalPages,
        isMoreLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isMoreLoading: false);
    }
  }

  void addProduct(Product product) {
    state = state.copyWith(
      products: [product, ...state.products],
    );
  }

  void updateProductStatus(int productId, String newStatus) {
    final updatedList = state.products.map((p) {
      if (p.id == productId) {
        return Product(
          id: p.id,
          sku: p.sku,
          name: p.name,
          categoryId: p.categoryId,
          categoryName: p.categoryName,
          sellingPrice: p.sellingPrice,
          stock: p.stock,
          status: newStatus,
          imageUrl: p.imageUrl,
        );
      }
      return p;
    }).toList();

    state = state.copyWith(products: updatedList);
  }

  void addCategory(Category category) {
    state = state.copyWith(
      categories: [...state.categories, category],
    );
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await repository.getProducts(
        page: 1,
        search: state.searchQuery,
        categoryId: state.selectedCategoryId,
      );
      state = state.copyWith(
        products: res.products,
        currentPage: res.page,
        totalPages: res.totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
