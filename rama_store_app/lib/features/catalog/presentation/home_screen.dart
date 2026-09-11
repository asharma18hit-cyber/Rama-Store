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
import '../../../shared/widgets/product_image_view.dart';
import '../../../main.dart';
import '../data/catalog_models.dart';
import '../presentation/catalog_notifier.dart';
import '../presentation/product_card.dart';
import '../../admin/presentation/store_config_notifier.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCategoryTab = 0;

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogNotifierProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: RefreshIndicator(
        color: const Color(0xFF3525CD),
        backgroundColor: Colors.white,
        onRefresh: () => ref.read(catalogNotifierProvider.notifier).initCatalog(),
        child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Top Global Announcement Ribbon
                SliverToBoxAdapter(
                  child: _buildTopAnnouncementRibbon(catalogState),
                ),

            // 2. Header Navigation (Stitch Light Theme)
            SliverToBoxAdapter(
              child: _buildHeader(context, isDesktop),
            ),

            // 3. Category Quick Filter Strip
            SliverToBoxAdapter(
              child: _buildCategoryFilterStrip(context, ref),
            ),

            // 4. Offline Connectivity Indicator
            if (catalogState.isOffline)
              SliverToBoxAdapter(
                child: OfflineBanner(isOffline: catalogState.isOffline),
              ),

            // 5. Main Hero Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 28.0),
                child: _buildHeroSection(context, isDesktop, isTablet),
              ),
            ),

            // 6. Department Discovery Grid
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                title: 'Explore Store Departments',
                subtitle: 'Authentic essentials curated across bakery, books, groceries & medicine',
                actionLabel: 'All Departments →',
                onAction: () => context.go('/catalog'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 32.0),
                child: _buildDepartmentGrid(context, catalogState, ref, isDesktop, isTablet),
              ),
            ),

            // 7. Curated Collections Bento Showcase Grid
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                title: 'Curated Collections // 2026 Drops',
                subtitle: 'High-performance engineering meets premium daily lifestyle',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 36.0),
                child: _buildBentoShowcase(context, isDesktop),
              ),
            ),

            // 8. Flash Drops & Bestsellers
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                title: '⚡ Flash Drops & Bestsellers',
                subtitle: 'Limited quantity essentials with instant 10% loyalty cashback',
                actionLabel: 'View All →',
                onAction: () => context.go('/catalog'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 36.0),
                child: _buildProductsHorizontalList(context, catalogState, ref),
              ),
            ),

            // 9. Promotional Highlight Program
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36.0),
                child: _buildEmeraldLoyaltyBanner(context),
              ),
            ),

            // 10. Why Shop With Us (Trust Matrix)
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                title: 'Why Shop With Samaur Mart',
                subtitle: 'Our commitment to authentic quality and frictionless commerce',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 36.0),
                child: _buildTrustMatrix(context, isDesktop, isTablet),
              ),
            ),

            // 11. Verified Customer Reviews
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: _buildCustomerReviews(context),
              ),
            ),

            // 12. Premium E-Commerce Footer
            SliverToBoxAdapter(
              child: _buildFooter(context, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. TOP ANNOUNCEMENT RIBBON ---
  Widget _buildTopAnnouncementRibbon(CatalogState state) {
    final storeConfig = ref.watch(storeConfigProvider);
    final text = storeConfig.announcementText.isNotEmpty
        ? storeConfig.announcementText
        : (state.announcement?.loyaltyOffer ??
            '⚡ 10% Instant Loyalty Cashback on all orders • Free local delivery on orders above ₹500');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF3525CD)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.secondaryFixedDim, size: 14),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            onTap: () => context.push('/download-app'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.phone_android_rounded, size: 13, color: AppColors.secondaryFixedDim),
                SizedBox(width: 4),
                Text(
                  'Download Android App',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryFixedDim,
                    decoration: TextDecoration.underline,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 11, color: AppColors.secondaryFixedDim),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. HEADER NAVIGATION (Stitch Spec) ---
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFC7C4D8), width: 0.8)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar Row
            Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Left: Brand Logo & Title
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3525CD),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3525CD).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Samaur Mart',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            Text(
                              'HIGH-PERFORMANCE COMMERCE',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Color(0xFF3525CD),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Center: Search Bar (Desktop/Tablet) or Expandable Trigger
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.go('/catalog'),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search fashion, groceries, books, medicine, sports...',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right: Account, Wishlist & Cart Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDesktop) ...[
                        OutlinedButton.icon(
                          onPressed: () => context.push('/download-app'),
                          icon: const Icon(Icons.phone_android_rounded, size: 15, color: Color(0xFF3525CD)),
                          label: const Text(
                            'Get App',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3525CD)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3525CD), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: const Size(0, 34),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        icon: const Icon(Icons.favorite_border_rounded, size: 22, color: Color(0xFF334155)),
                        tooltip: 'Wishlist',
                        onPressed: () => context.push('/wishlist'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded, size: 22, color: Color(0xFF334155)),
                        tooltip: 'Account',
                        onPressed: () => context.go('/profile'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, size: 22, color: Color(0xFF3525CD)),
                        tooltip: 'Cart',
                        onPressed: () => context.go('/cart'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Navigation Tier (Desktop Link Bar)
            if (isDesktop)
              Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border(top: BorderSide(color: Color(0xFFE1E3E4), width: 0.8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTopNavLink(context, 'Shop', '/catalog', isSelected: true),
                    const SizedBox(width: 32),
                    _buildTopNavLink(context, 'Collections', '/catalog'),
                    const SizedBox(width: 32),
                    _buildTopNavLink(context, 'New Arrivals', '/catalog'),
                    const SizedBox(width: 32),
                    _buildTopNavLink(context, 'Brands', '/catalog'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavLink(BuildContext context, String label, String route, {bool isSelected = false}) {
    return InkWell(
      onTap: () => context.go(route),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: isSelected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF3525CD), width: 2.5),
                ),
              )
            : null,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF3525CD) : const Color(0xFF464555),
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. CATEGORY QUICK FILTER STRIP ---
  Widget _buildCategoryFilterStrip(BuildContext context, WidgetRef ref) {
    final filterTabs = [
      {'label': '🔥 All Drops', 'id': null},
      {'label': '🥐 Bakery & Pastries', 'id': 1},
      {'label': '🛒 Groceries & Essentials', 'id': 2},
      {'label': '💊 Health & Medicine', 'id': 3},
      {'label': '📚 Books & Novels', 'id': 4},
      {'label': '✏️ Stationery', 'id': 5},
      {'label': '🎾 Sports & Fitness', 'id': 6},
    ];

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filterTabs.length,
        itemBuilder: (context, index) {
          final tab = filterTabs[index];
          final isSelected = _selectedCategoryTab == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _selectedCategoryTab = index);
                if (tab['id'] != null) {
                  ref.read(catalogNotifierProvider.notifier).setCategory(tab['id'] as int);
                  context.go('/catalog');
                } else {
                  ref.read(catalogNotifierProvider.notifier).setCategory(null);
                  context.go('/catalog');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3525CD) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3525CD) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF0B1C30),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 4. HERO SECTION ---
  Widget _buildHeroSection(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      height: isDesktop ? 440 : (isTablet ? 390 : 350),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl:
                    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=1600&q=80',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF3525CD)],
                    ),
                  ),
                ),
              ),
            ),

            // Modern Dark Gradient Overlay for Maximum Legibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF0F172A).withValues(alpha: 0.92),
                      const Color(0xFF0F172A).withValues(alpha: 0.75),
                      const Color(0xFF1E1B4B).withValues(alpha: 0.50),
                    ],
                  ),
                ),
              ),
            ),

            // Hero Content
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 44.0 : 20.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 650 : 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_awesome, size: 13, color: AppColors.secondaryFixedDim),
                            SizedBox(width: 6),
                            Text(
                              'SPRING 2026 DROPS • 30-MIN RAPID DELIVERY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Headline
                      Text(
                        'Everyday Essentials &\nCurated Drops.',
                        style: TextStyle(
                          fontSize: isDesktop ? 44 : (isTablet ? 32 : 25),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Discover fresh bakery delights, organic groceries, verified pharmaceuticals, best-selling books & sports essentials with 10% instant loyalty cashback.',
                        style: TextStyle(
                          fontSize: isDesktop ? 15 : 12.5,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Action Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3525CD),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 26 : 18,
                                vertical: isDesktop ? 14 : 11,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            icon: const Icon(Icons.shopping_bag_outlined, size: 17),
                            label: const Text(
                              'Explore Catalog',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () => context.go('/catalog'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70, width: 1.2),
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 22 : 16,
                                vertical: isDesktop ? 14 : 11,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.stars_rounded, size: 17, color: AppColors.secondaryFixedDim),
                            label: const Text(
                              '10% Loyalty Perks',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () => context.push('/loyalty'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. DEPARTMENT DISCOVERY GRID ---
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF3525CD)),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  color: Color(0xFF3525CD),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildDepartmentGrid(
    BuildContext context,
    CatalogState state,
    WidgetRef ref,
    bool isDesktop,
    bool isTablet,
  ) {
    final departments = [
      {'name': 'Bakery & Pastries', 'icon': Icons.bakery_dining_rounded, 'id': 1, 'color': const Color(0xFFD97706), 'desc': 'Fresh daily artisan batches'},
      {'name': 'Groceries', 'icon': Icons.shopping_basket_rounded, 'id': 2, 'color': const Color(0xFF10B981), 'desc': 'Farm fresh & packaged essentials'},
      {'name': 'Health & Medicine', 'icon': Icons.medical_services_rounded, 'id': 3, 'color': const Color(0xFFEF4444), 'desc': 'Verified pharmaceutical care'},
      {'name': 'Books & Novels', 'icon': Icons.menu_book_rounded, 'id': 4, 'color': const Color(0xFF6366F1), 'desc': 'Bestsellers, fiction & academic'},
      {'name': 'Stationery', 'icon': Icons.edit_note_rounded, 'id': 5, 'color': const Color(0xFFEC4899), 'desc': 'Premium notebooks & desk tools'},
      {'name': 'Sports & Fitness', 'icon': Icons.sports_tennis_rounded, 'id': 6, 'color': const Color(0xFF06B6D4), 'desc': 'High-performance sporting gear'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 6 : (isTablet ? 3 : 2),
          childAspectRatio: isDesktop ? 1.05 : 1.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: departments.length,
        itemBuilder: (context, index) {
          final dept = departments[index];
          final color = dept['color'] as Color;

          return HoverCard(
            glowColor: color.withValues(alpha: 0.2),
            onTap: () {
              ref.read(catalogNotifierProvider.notifier).setCategory(dept['id'] as int);
              context.go('/catalog');
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(dept['icon'] as IconData, color: color, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dept['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dept['desc'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 6. CURATED BENTO SHOWCASE ---
  Widget _buildBentoShowcase(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: isDesktop ? 8 : 1,
                child: _buildBentoImageCard(
                  context,
                  title: 'Daily Artisan Bakery',
                  subtitle: 'Oven-fresh bread, pastries & confections.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80',
                  height: 260,
                ),
              ),
              if (isDesktop) const SizedBox(width: 16),
              if (isDesktop)
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 260,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEFF4FF), Color(0xFFDBEAFE)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(Icons.menu_book_rounded, size: 100, color: Color(0x223525CD)),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3525CD),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'BESTSELLERS',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Books & Novels', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => context.go('/catalog'),
                                child: Row(
                                  children: const [
                                    Text('Shop Collection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3525CD))),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF3525CD)),
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: isDesktop ? 4 : 1,
                child: _buildBentoImageCard(
                  context,
                  title: 'Health & Pharmacy',
                  subtitle: '100% verified medicines & wellness.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=800&q=80',
                  height: 240,
                ),
              ),
              if (isDesktop) const SizedBox(width: 16),
              if (isDesktop)
                Expanded(
                  flex: 8,
                  child: _buildBentoImageCard(
                    context,
                    title: 'Farm Fresh Groceries',
                    subtitle: 'Direct harvest vegetables, dairy & staples delivered in 30 mins.',
                    imageUrl:
                        'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80',
                    height: 240,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoImageCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String imageUrl,
    required double height,
  }) {
    return GestureDetector(
      onTap: () => context.go('/catalog'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0F172A).withValues(alpha: 0.85),
                        const Color(0xFF0F172A).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 7. PRODUCTS HORIZONTAL LIST ---
  Widget _buildProductsHorizontalList(BuildContext context, CatalogState state, WidgetRef ref) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No products currently available.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return SizedBox(
      height: 290,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final product = state.products[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: ProductCard(product: product, width: 190),
          );
        },
      ),
    );
  }

  // --- 8. EMERALD LOYALTY BANNER ---
  Widget _buildEmeraldLoyaltyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F172A), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF006C49),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.stars_rounded, size: 30, color: AppColors.secondaryFixedDim),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '10% INSTANT LOYALTY CASHBACK',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.secondaryFixedDim),
                ),
                SizedBox(height: 4),
                Text(
                  'Earn on Every Confirmed Purchase',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Cashback balances credit automatically to your Samaur Mart wallet upon order delivery.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryFixedDim,
              foregroundColor: const Color(0xFF005236),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.push('/loyalty'),
            child: const Text('Rewards Hub', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // --- 9. TRUST MATRIX ---
  Widget _buildTrustMatrix(BuildContext context, bool isDesktop, bool isTablet) {
    final pillars = [
      {'icon': Icons.local_shipping_outlined, 'title': 'Hyper-Local Express', 'desc': 'Within 30 mins • Free > ₹500'},
      {'icon': Icons.card_giftcard_rounded, 'title': '10% Loyalty Cash-Back', 'desc': 'Instant credit on delivery'},
      {'icon': Icons.verified_user_outlined, 'title': '100% Secure Checkout', 'desc': 'Bank-grade encrypted gateway'},
      {'icon': Icons.replay_rounded, 'title': 'Zero-Friction Guarantee', 'desc': '7-day replacement guarantee'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
          childAspectRatio: isDesktop ? 1.7 : 1.3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: pillars.length,
        itemBuilder: (context, index) {
          final p = pillars[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(p['icon'] as IconData, color: const Color(0xFF3525CD), size: 20),
                ),
                const SizedBox(height: 10),
                Text(p['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text(p['desc'] as String, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 10. CUSTOMER REVIEWS ---
  Widget _buildCustomerReviews(BuildContext context) {
    final reviews = [
      {'name': 'Rahul S.', 'review': 'Best bookshop & bakery in town! Love the 10% instant cashback.', 'rating': 5.0},
      {'name': 'Priya M.', 'review': 'Super fast local delivery above ₹500. Genuine products & clean UI!', 'rating': 5.0},
      {'name': 'Amit K.', 'review': 'Seamless ordering across web and the native mobile app!', 'rating': 4.8},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verified Customer Reviews', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final r = reviews[index];
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                            ],
                          ),
                          RatingStars(rating: r['rating'] as double),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r['review'] as String,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
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

  // --- 11. FOOTER ---
  Widget _buildFooter(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3525CD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('SAMAUR MART', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Samaur Mart - Modern Retail Superstore. Fresh Bakery, Organics, Books, Medicines & Sports Essentials with 10% Loyalty Cash-Back rewards.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              TextButton(onPressed: () => context.go('/catalog'), child: const Text('Catalog', style: TextStyle(color: Colors.white70, fontSize: 12.5))),
              TextButton(onPressed: () => context.push('/loyalty'), child: const Text('Loyalty Program', style: TextStyle(color: Colors.white70, fontSize: 12.5))),
              TextButton(onPressed: () => context.push('/download-app'), child: const Text('Download Android App', style: TextStyle(color: AppColors.secondaryFixedDim, fontSize: 12.5, fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.push('/help'), child: const Text('Help & Support', style: TextStyle(color: Colors.white70, fontSize: 12.5))),
              TextButton(onPressed: () => context.push('/privacy'), child: const Text('Privacy Policy', style: TextStyle(color: Colors.white70, fontSize: 12.5))),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('© 2026 Samaur Mart. All Rights Reserved.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text('100% Authentic Quality Guaranteed', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
}

