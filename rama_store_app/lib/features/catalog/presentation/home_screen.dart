import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../../main.dart';
import '../data/catalog_models.dart';
import 'catalog_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(catalogNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('RAMA STORE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/catalog'),
          ),
          IconButton(
            icon: const Icon(Icons.loyalty),
            color: AppColors.accentAmber,
            onPressed: () => context.push('/loyalty'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(catalogNotifierProvider.notifier).initCatalog(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfflineBanner(isOffline: catalogState.isOffline),

              // Announcement Bar
              if (catalogState.announcement != null)
                Container(
                  width: double.infinity,
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: AppColors.primaryGoldLight, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          catalogState.announcement!.loyaltyOffer,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Hero Banners Carousel
              _buildHeroBanner(context),

              const SizedBox(height: 24),

              // "Why Us" Highlights
              _buildWhyUsHighlights(context),

              const SizedBox(height: 24),

              // Department Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Explore Store Departments',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              _buildDepartmentGrid(context, catalogState, ref),

              const SizedBox(height: 24),

              // Google Stitch Featured Bento Grid
              _buildStitchBentoGrid(context),

              const SizedBox(height: 24),

              // Google Stitch Emerald Vertex Highlight Card
              _buildEmeraldVertexCard(context),

              const SizedBox(height: 24),

              // Featured Bestsellers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Featured Collection', style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.go('/catalog'),
                      child: const Text('View All', style: TextStyle(color: AppColors.primaryGold)),
                    ),
                  ],
                ),
              ),

              if (catalogState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ProductCardShimmer(),
                )
              else
                SizedBox(
                  height: 230,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: catalogState.products.length,
                    itemBuilder: (context, index) {
                      final product = catalogState.products[index];
                      return _buildFeaturedProductCard(context, product, ref);
                    },
                  ),
                ),

              const SizedBox(height: 32),

              // Customer Testimonials Carousel Section
              _buildTestimonialsSection(context),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return HoverCard(
      glowColor: const Color(0xFF3525CD),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF3525CD), Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3525CD).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: const Color(0xFF4EDEAE).withValues(alpha: 0.4), width: 1.2),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(Icons.stars_rounded, size: 170, color: const Color(0xFF4EDEAE).withValues(alpha: 0.12)),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4EDEAE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✨ RAMA STORE DESIGN SYSTEM',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF005236)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '10% CASH-BACK',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Elite High-Performance Fashion & Essentials',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bakery, Books, Groceries & Medicine • 100% Shared Database',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildWhyUsHighlights(BuildContext context) {
    final highlights = [
      {'icon': Icons.local_shipping_outlined, 'title': 'Free Local Delivery', 'subtitle': 'Orders above ₹500'},
      {'icon': Icons.card_giftcard, 'title': '10% Loyalty Cash-Back', 'subtitle': 'Credited instantly'},
      {'icon': Icons.verified_user_outlined, 'title': 'Secure Transactions', 'subtitle': '100% Guaranteed'},
      {'icon': Icons.inventory_2_outlined, 'title': 'Curated Essentials', 'subtitle': 'Verified Quality'},
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: highlights.length,
        itemBuilder: (context, index) {
          final h = highlights[index];
          return Container(
            width: 170,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(h['icon'] as IconData, color: AppColors.primaryGold, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h['title'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text(h['subtitle'] as String,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepartmentGrid(BuildContext context, CatalogState state, WidgetRef ref) {
    final departments = [
      {'name': 'Bakery', 'icon': Icons.bakery_dining, 'id': 1},
      {'name': 'Groceries', 'icon': Icons.shopping_basket, 'id': 2},
      {'name': 'Medicine', 'icon': Icons.medical_services, 'id': 3},
      {'name': 'Books', 'icon': Icons.menu_book, 'id': 4},
      {'name': 'Stationery', 'icon': Icons.edit_note, 'id': 5},
      {'name': 'Sports Gear', 'icon': Icons.sports_tennis, 'id': 6},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: departments.length,
      itemBuilder: (context, index) {
        final dept = departments[index];
        return InkWell(
          onTap: () {
            ref.read(catalogNotifierProvider.notifier).setCategory(dept['id'] as int);
            context.go('/catalog');
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(dept['icon'] as IconData, color: AppColors.primaryGoldLight, size: 28),
                const SizedBox(height: 6),
                Text(
                  dept['name'] as String,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturedProductCard(BuildContext context, Product product, WidgetRef ref) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}', extra: product),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const ShimmerLoader(width: double.infinity, height: 90),
                          errorWidget: (context, url, error) => Container(color: AppColors.surfaceLight),
                        )
                      : Container(
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.store, color: AppColors.textMuted),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                product.categoryName ?? 'Essential',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatCurrency(product.sellingPrice),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight),
                  ),
                  InkWell(
                    onTap: () {
                      ref.read(cartNotifierProvider.notifier).addItem(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added ${product.name} to cart'), duration: const Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    final reviews = [
      {'name': 'Rahul S.', 'review': 'Best bookshop & bakery in town! Love the 10% cash-back rewards.', 'rating': 5.0},
      {'name': 'Priya M.', 'review': 'Super fast local delivery above ₹500. Genuine products!', 'rating': 5.0},
      {'name': 'Amit K.', 'review': 'Seamless ordering across web and mobile app!', 'rating': 4.5},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Reviews & Ratings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final r = reviews[index];
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          RatingStars(rating: r['rating'] as double),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r['review'] as String,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchBentoGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Featured Stitch Collections', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // Large Bento Card
          HoverCard(
            glowColor: const Color(0xFF3525CD),
            onTap: () => context.go('/catalog'),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF3525CD), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.secondaryFixedDim.withValues(alpha: 0.3)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(Icons.flash_on, size: 140, color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixedDim,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NEW DROP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF005236))),
                        ),
                        const SizedBox(height: 6),
                        const Text('URBAN OVERDRIVE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Master the streets with reinforced technical fabrics.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Small Bento Cards Row
          Row(
            children: [
              Expanded(
                child: HoverCard(
                  onTap: () => context.go('/catalog'),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.widgets, color: AppColors.secondaryFixedDim, size: 26),
                          SizedBox(height: 6),
                          Text('TECH-FAB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('Honeycomb weave', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HoverCard(
                  glowColor: AppColors.primaryGoldLight,
                  onTap: () => context.go('/catalog'),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.precision_manufacturing, color: AppColors.primaryGoldLight, size: 26),
                          SizedBox(height: 6),
                          Text('GEAR+', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('Titanium essentials', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmeraldVertexCard(BuildContext context) {
    return HoverCard(
      glowColor: const Color(0xFF006C49),
      onTap: () => context.go('/catalog'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2B20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4EDEAE).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006C49).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 2,
                  color: const Color(0xFF4EDEAE),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LIMITED RELEASE',
                  style: TextStyle(color: Color(0xFF4EDEAE), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The Emerald Vertex Series',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Advanced compression layer with heat-mapping ventilation & 4-way stretch titanium fibers.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('PRICE', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text('₹2,499', style: TextStyle(color: Color(0xFF4EDEAE), fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006C49),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () => context.go('/catalog'),
                  icon: const Text('EXPLORE NOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  label: const Icon(Icons.arrow_forward, size: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
