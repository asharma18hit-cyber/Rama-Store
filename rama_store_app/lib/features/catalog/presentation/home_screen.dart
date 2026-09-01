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
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../main.dart';
import '../data/catalog_models.dart';
import 'catalog_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(catalogNotifierProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _buildStitchAppBar(context, ref),
      ),
      body: RefreshIndicator(
        color: AppColors.secondaryFixedDim,
        backgroundColor: const Color(0xFF0F172A),
        onRefresh: () => ref.read(catalogNotifierProvider.notifier).initCatalog(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfflineBanner(isOffline: catalogState.isOffline),

              // 1. Top Announcement Ribbon
              _buildTopAnnouncementRibbon(catalogState),

              const SizedBox(height: 16),

              // 2. Hero Section (Stitch 2.0 Canvas)
              _buildStitchHeroSection(context, isDesktop),

              const SizedBox(height: 28),

              // 3. Category Discovery Bar
              _buildCategoryDiscoveryHeader(context),
              const SizedBox(height: 12),
              _buildStitchCategoryGrid(context, catalogState, ref, isDesktop),

              const SizedBox(height: 32),

              // 4. Stitch Bento Showcase Grid
              _buildStitchBentoShowcase(context, isDesktop),

              const SizedBox(height: 32),

              // 5. Featured Products & Flash Drops
              _buildProductSectionHeader(
                context,
                title: '⚡ Flash Drops & Bestsellers',
                subtitle: 'Handpicked premium items with instant 10% loyalty cashback',
                onViewAll: () => context.go('/catalog'),
              ),
              const SizedBox(height: 14),
              _buildFeaturedProductsList(context, catalogState, ref),

              const SizedBox(height: 36),

              // 6. Emerald Vertex Highlight Banner
              _buildEmeraldHighlightBanner(context),

              const SizedBox(height: 36),

              // 7. Trust & Security Bento Matrix
              _buildTrustMatrix(context, isDesktop),

              const SizedBox(height: 36),

              // 8. Verified Customer Reviews
              _buildCustomerReviews(context),

              const SizedBox(height: 48),

              // 9. Premium E-Commerce Footer
              _buildStitchFooter(context, isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. STITCH APP BAR ---
  Widget _buildStitchAppBar(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: Color(0x1FFFFFFF), width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            // Brand Logo & Elite Pill
            GestureDetector(
              onTap: () => context.go('/home'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixedDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, size: 18, color: Color(0xFF005236)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'RAMA STORE',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'HIGH PERFORMANCE RETAIL',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: AppColors.secondaryFixedDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Search Bar Trigger
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/catalog'),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search_rounded, size: 17, color: AppColors.secondaryFixedDim),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search fashion, groceries, books, medicine...',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Loyalty Rewards Button
            IconButton(
              icon: const Icon(Icons.loyalty_rounded, size: 20),
              color: AppColors.accentAmber,
              tooltip: '10% Loyalty Cash-Back',
              onPressed: () => context.push('/loyalty'),
            ),

            // Wishlist Button
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded, size: 20),
              color: AppColors.textPrimary,
              tooltip: 'Wishlist',
              onPressed: () => context.push('/wishlist'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. TOP ANNOUNCEMENT RIBBON ---
  Widget _buildTopAnnouncementRibbon(CatalogState state) {
    final text = state.announcement?.loyaltyOffer ??
        '⚡ 10% Instant Loyalty Cashback on all orders • Free local delivery on orders above ₹500';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3525CD), Color(0xFF006C49)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.secondaryFixedDim, size: 15),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. HERO SECTION (STITCH 2.0 CANVAS) ---
  Widget _buildStitchHeroSection(BuildContext context, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: HoverCard(
        glowColor: const Color(0xFF3525CD),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF3525CD), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF4EDEAE).withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3525CD).withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.shopping_bag_rounded, size: isDesktop ? 240 : 160, color: Colors.white.withValues(alpha: 0.05)),
              ),
              Padding(
                padding: EdgeInsets.all(isDesktop ? 36.0 : 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixedDim,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '⚡ LIMITED RELEASE // 2026',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF005236)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '10% CASH-BACK',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Main Headline
                    Text(
                      'Precision Fashion & Curated Daily Essentials',
                      style: TextStyle(
                        fontSize: isDesktop ? 28 : 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Bakery, Books, Groceries & Medicine with 100% Authoritative Multi-Platform Sync.',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dual CTAs
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryFixedDim,
                            foregroundColor: const Color(0xFF005236),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Explore Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => context.go('/catalog'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.secondaryFixedDim),
                          label: const Text('Download App APK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => context.push('/downloads'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Express Delivery Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.bolt_rounded, size: 15, color: AppColors.secondaryFixedDim),
                          SizedBox(width: 6),
                          Text(
                            'Express Local Delivery Active • Free on orders above ₹500',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. CATEGORY DISCOVERY GRID ---
  Widget _buildCategoryDiscoveryHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Explore Departments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('Browse curated categories with live inventory', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          TextButton(
            onPressed: () => context.go('/catalog'),
            child: const Text('All Categories →', style: TextStyle(color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchCategoryGrid(BuildContext context, CatalogState state, WidgetRef ref, bool isDesktop) {
    final departments = [
      {'name': 'Bakery & Pastries', 'icon': Icons.bakery_dining_rounded, 'id': 1, 'color': Color(0xFFD97706), 'items': '18 items'},
      {'name': 'Groceries', 'icon': Icons.shopping_basket_rounded, 'id': 2, 'color': Color(0xFF10B981), 'items': '45 items'},
      {'name': 'Medicine', 'icon': Icons.medical_services_rounded, 'id': 3, 'color': Color(0xFFEF4444), 'items': '22 items'},
      {'name': 'Books & Novels', 'icon': Icons.menu_book_rounded, 'id': 4, 'color': Color(0xFF6366F1), 'items': '34 items'},
      {'name': 'Stationery', 'icon': Icons.edit_note_rounded, 'id': 5, 'color': Color(0xFFEC4899), 'items': '19 items'},
      {'name': 'Sports Gear', 'icon': Icons.sports_tennis_rounded, 'id': 6, 'color': Color(0xFF06B6D4), 'items': '12 items'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 6 : 3,
          childAspectRatio: isDesktop ? 1.1 : 0.95,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: departments.length,
        itemBuilder: (context, index) {
          final dept = departments[index];
          final color = dept['color'] as Color;

          return HoverCard(
            glowColor: color,
            onTap: () {
              ref.read(catalogNotifierProvider.notifier).setCategory(dept['id'] as int);
              context.go('/catalog');
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(dept['icon'] as IconData, color: color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dept['name'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dept['items'] as String,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 5. STITCH BENTO SHOWCASE GRID ---
  Widget _buildStitchBentoShowcase(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Featured Stitch Collections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          // Large Hero Bento Card
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
                    padding: const EdgeInsets.all(18.0),
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
                        const Text('URBAN OVERDRIVE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Master the streets with reinforced technical fabrics & instant delivery.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Small Bento Row
          Row(
            children: [
              Expanded(
                child: HoverCard(
                  onTap: () => context.go('/catalog'),
                  child: Container(
                    height: 115,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.widgets_rounded, color: AppColors.secondaryFixedDim, size: 24),
                        SizedBox(height: 6),
                        Text('TECH-FAB', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('Honeycomb weave fabrics', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
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
                    height: 115,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.precision_manufacturing_rounded, color: AppColors.primaryGoldLight, size: 24),
                        SizedBox(height: 6),
                        Text('DAILY GEAR+', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('Titanium-grade essentials', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
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

  // --- 6. FEATURED PRODUCTS & FLASH DROPS ---
  Widget _buildProductSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All →', style: TextStyle(color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProductsList(BuildContext context, CatalogState state, WidgetRef ref) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: ProductCardShimmer(),
      );
    }

    if (state.products.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('No products currently available.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final product = state.products[index];
          return _buildStitchProductCard(context, product, ref);
        },
      ),
    );
  }

  Widget _buildStitchProductCard(BuildContext context, Product product, WidgetRef ref) {
    final isFav = ref.watch(wishlistNotifierProvider).contains(product.id);
    final originalMrp = product.sellingPrice * 1.25;

    return HoverCard(
      glowColor: AppColors.primaryContainer,
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ShimmerLoader(width: double.infinity, height: 110),
                            errorWidget: (context, url, error) => Container(color: const Color(0xFF334155)),
                          )
                        : Container(
                            color: const Color(0xFF334155),
                            child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '-20%',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(wishlistNotifierProvider.notifier).toggleFavorite(product.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Updated wishlist for ${product.name}'), duration: const Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 14,
                        color: isFav ? const Color(0xFFEF4444) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.categoryName ?? 'Essential',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),

                  // Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Formatters.formatCurrency(product.sellingPrice),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.secondaryFixedDim),
                          ),
                          Text(
                            Formatters.formatCurrency(originalMrp),
                            style: const TextStyle(fontSize: 9, color: AppColors.textMuted, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.read(cartNotifierProvider.notifier).addItem(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🛍️ Added ${product.name} to cart!'),
                              backgroundColor: const Color(0xFF0F172A),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryFixedDim,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: Color(0xFF005236)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 7. EMERALD VERTEX HIGHLIGHT BANNER ---
  Widget _buildEmeraldHighlightBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B291E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryFixedDim.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixedDim.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.loyalty_rounded, size: 28, color: AppColors.secondaryFixedDim),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '10% CASH-BACK PROGRAM',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.secondaryFixedDim),
                ),
                SizedBox(height: 2),
                Text(
                  'Earn on Every Single Purchase',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Cashback credits immediately to your wallet upon order delivery.',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 8. TRUST MATRIX ---
  Widget _buildTrustMatrix(BuildContext context, bool isDesktop) {
    final pillars = [
      {'icon': Icons.local_shipping_outlined, 'title': 'Hyper-Local Delivery', 'desc': 'Within 30 mins • Free > ₹500'},
      {'icon': Icons.card_giftcard_rounded, 'title': '10% Loyalty Cash-Back', 'desc': 'Credited instantly on delivery'},
      {'icon': Icons.verified_user_outlined, 'title': '100% Secure Checkout', 'desc': 'Bank-grade encrypted sandbox'},
      {'icon': Icons.replay_rounded, 'title': 'Zero-Friction Returns', 'desc': '7-day replacement guarantee'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why Shop With Rama Store', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              childAspectRatio: isDesktop ? 1.6 : 1.3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: pillars.length,
            itemBuilder: (context, index) {
              final p = pillars[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(p['icon'] as IconData, color: AppColors.secondaryFixedDim, size: 22),
                    const SizedBox(height: 6),
                    Text(p['title'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(p['desc'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 9. CUSTOMER REVIEWS ---
  Widget _buildCustomerReviews(BuildContext context) {
    final reviews = [
      {'name': 'Rahul S.', 'review': 'Best bookshop & bakery in town! Love the 10% instant cashback.', 'rating': 5.0},
      {'name': 'Priya M.', 'review': 'Super fast local delivery above ₹500. Genuine products & clean UI!', 'rating': 5.0},
      {'name': 'Amit K.', 'review': 'Seamless ordering across web and the native mobile app!', 'rating': 4.8},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: const Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verified Customer Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final r = reviews[index];
                return Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          RatingStars(rating: r['rating'] as double),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r['review'] as String,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

  // --- 10. STITCH FOOTER ---
  Widget _buildStitchFooter(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF050811),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixedDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag_rounded, size: 16, color: Color(0xFF005236)),
              ),
              const SizedBox(width: 8),
              const Text('RAMA STORE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Elite High-Performance Fashion, Bakery, Books, Groceries & Medicine with 10% Loyalty Cash-Back rewards.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              TextButton(onPressed: () => context.go('/catalog'), child: const Text('Catalog', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              TextButton(onPressed: () => context.push('/loyalty'), child: const Text('Loyalty', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              TextButton(onPressed: () => context.push('/downloads'), child: const Text('Mobile App APK', style: TextStyle(color: AppColors.secondaryFixedDim, fontSize: 12))),
            ],
          ),
          const Divider(color: Color(0x1FFFFFFF), height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('© 2026 Rama Store Inc. All Rights Reserved.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              Text('Google Stitch 2.0 System', style: TextStyle(fontSize: 10, color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
