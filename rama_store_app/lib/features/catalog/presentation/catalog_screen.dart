import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../main.dart';
import '../data/catalog_models.dart';
import 'product_card.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer(milliseconds: 300);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(catalogNotifierProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogNotifierProvider);
    final visibleProducts = catalogState.products
        .where((p) => p.status == 'published' || p.status.isEmpty)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'ELITE COLLECTION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF3525CD), letterSpacing: 0.8),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF3525CD)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filter Active: Filter by Category, Material & Price Range'),
                  backgroundColor: Color(0xFF3525CD),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded, color: Color(0xFF3525CD)),
            onPressed: () => context.push('/wishlist'),
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(isOffline: catalogState.isOffline),

          // Store Inventory Status Banner Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: const Color(0xFFEFF4FF),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3525CD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('VERIFIED INVENTORY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                const Text('Precision Curated Fashion & Daily Essentials', style: TextStyle(fontSize: 11, color: Color(0xFF464555))),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _debouncer.run(() {
                  ref.read(catalogNotifierProvider.notifier).setSearchQuery(val.trim());
                });
              },
              style: const TextStyle(color: Color(0xFF0B1C30)),
              decoration: InputDecoration(
                hintText: 'Search products by title, author, brand...',
                hintStyle: const TextStyle(color: Color(0xFF777587), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC7C4D8), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC7C4D8), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3525CD), width: 1.5),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF777587)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF777587)),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(catalogNotifierProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Category Chips Row
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip(
                  label: 'All Items',
                  isSelected: catalogState.selectedCategoryId == null,
                  onTap: () => ref.read(catalogNotifierProvider.notifier).setCategory(null),
                ),
                ...catalogState.categories.map((cat) => _buildCategoryChip(
                      label: cat.name,
                      isSelected: catalogState.selectedCategoryId == cat.id,
                      onTap: () => ref.read(catalogNotifierProvider.notifier).setCategory(cat.id),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Grid View of Products
          Expanded(
            child: catalogState.isLoading
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) => ProductCardShimmer(),
                  )
                : visibleProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off_rounded, size: 64, color: Color(0xFF777587)),
                            SizedBox(height: 12),
                            Text('No matching products found', style: TextStyle(color: Color(0xFF464555), fontSize: 14)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(catalogNotifierProvider.notifier).initCatalog(),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width >= 1024
                                ? 4
                                : (MediaQuery.of(context).size.width >= 600 ? 3 : 2),
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: visibleProducts.length + (catalogState.isMoreLoading ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (index >= visibleProducts.length) {
                              return ProductCardShimmer();
                            }
                            final product = visibleProducts[index];
                            return ProductCard(product: product);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF3525CD),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFF3525CD) : const Color(0xFFC7C4D8),
          width: 1,
        ),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF464555),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}
