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
      backgroundColor: const Color(0xFF0B0F19),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.secondaryFixedDim,
            backgroundColor: const Color(0xFF0F172A),
            onRefresh: () => ref.read(catalogNotifierProvider.notifier).initCatalog(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Top Global Announcement Ribbon
                SliverToBoxAdapter(
                  child: _buildTopAnnouncementRibbon(catalogState),
                ),

            // 2. Stitch 2.0 Glassmorphic Header Navigation
            SliverToBoxAdapter(
              child: _buildStitchHeader(context, isDesktop),
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

            // 5. Main Hero Section (Stitch 2.0 Canvas)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 28.0),
                child: _buildStitchHeroSection(context, isDesktop, isTablet),
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

            // 7. Stitch Asymmetric Bento Showcase Grid
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
                title: 'Why Shop With Rama Store',
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
              child: _buildStitchFooter(context, isDesktop),
            ),
          ],
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: const Text(
              'RAMASTORE-NEW-BUILD-2026',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
}

  // --- 1. TOP ANNOUNCEMENT RIBBON ---
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
          const Icon(Icons.stars_rounded, color: AppColors.secondaryFixedDim, size: 14),
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

  // --- 2. STITCH 2.0 HEADER NAVIGATION ---
  Widget _buildStitchHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Brand Logo & Elite Monogram
            GestureDetector(
              onTap: () => context.go('/home'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixedDim,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryFixedDim.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, size: 20, color: Color(0xFF005236)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'RAMA STORE',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'HIGH-PERFORMANCE COMMERCE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.secondaryFixedDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Search Bar Trigger
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/catalog'),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search_rounded, size: 18, color: AppColors.secondaryFixedDim),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search fashion, groceries, books, medicine, sports...',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Loyalty Rewards Button
            IconButton(
              icon: const Icon(Icons.loyalty_rounded, size: 22),
              color: AppColors.accentAmber,
              tooltip: '10% Loyalty Cash-Back',
              onPressed: () => context.push('/loyalty'),
            ),

            // Wishlist Button
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded, size: 22),
              color: AppColors.textPrimary,
              tooltip: 'Wishlist',
              onPressed: () => context.push('/wishlist'),
            ),

            // Cart Button
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, size: 22),
              color: AppColors.textPrimary,
              tooltip: 'Cart',
              onPressed: () => context.go('/cart'),
            ),
          ],
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
        color: Color(0xFF0D1322),
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 1)),
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
                  color: isSelected ? AppColors.secondaryFixedDim : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.secondaryFixedDim : const Color(0xFF334155),
                  ),
                ),
                child: Center(
                  child: Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF005236) : AppColors.textPrimary,
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

  // --- 4. STITCH HERO SECTION ---
  Widget _buildStitchHeroSection(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: HoverCard(
        glowColor: const Color(0xFF3525CD),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF3525CD), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF4EDEAE).withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3525CD).withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -30,
                child: Icon(Icons.flash_on_rounded, size: isDesktop ? 280 : 180, color: Colors.white.withValues(alpha: 0.05)),
              ),
              Padding(
                padding: EdgeInsets.all(isDesktop ? 40.0 : (isTablet ? 28.0 : 20.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edition Badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixedDim,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '⚡ LIMITED RELEASE // AUTUMN 2026',
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
                    const SizedBox(height: 16),

                    // Main Headline
                    Text(
                      'Precision Fashion & Curated Daily Essentials.',
                      style: TextStyle(
                        fontSize: isDesktop ? 32 : (isTablet ? 24 : 20),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Hyper-local 30-min express fulfillment for artisanal bakery, medical prescriptions, organic groceries & literature.',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dual CTAs
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryFixedDim,
                            foregroundColor: const Color(0xFF005236),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Shop Complete Catalog →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => context.go('/catalog'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.secondaryFixedDim),
                          label: const Text('Download Native App APK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => context.push('/downloads'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Live Delivery Indicator Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.bolt_rounded, size: 16, color: AppColors.secondaryFixedDim),
                          SizedBox(width: 8),
                          Text(
                            '📍 Hyper-Local Express Delivery Active • Free on orders above ₹500',
                            style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel, style: const TextStyle(color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold, fontSize: 12)),
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
            glowColor: color,
            onTap: () {
              ref.read(catalogNotifierProvider.notifier).setCategory(dept['id'] as int);
              context.go('/catalog');
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(dept['icon'] as IconData, color: color, size: 24),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dept['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dept['desc'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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

  // --- 6. STITCH BENTO SHOWCASE ---
  Widget _buildBentoShowcase(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large Bento Card
                Expanded(
                  flex: 3,
                  child: _buildBentoCard(
                    context,
                    title: 'URBAN OVERDRIVE',
                    subtitle: 'Master the streets with reinforced technical fabrics & instant delivery.',
                    tag: 'NEW DROP',
                    tagColor: AppColors.secondaryFixedDim,
                    gradient: const [Color(0xFF1E1B4B), Color(0xFF3525CD), Color(0xFF0F172A)],
                    height: 220,
                  ),
                ),
                const SizedBox(width: 14),
                // Small Bento Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildBentoCard(
                        context,
                        title: 'ARTISANAL BAKERY',
                        subtitle: 'Fresh morning sourdough & gourmet pastries.',
                        tag: 'FRESH BATCH',
                        tagColor: const Color(0xFFD97706),
                        gradient: const [Color(0xFF2E1065), Color(0xFF1E293B)],
                        height: 103,
                      ),
                      const SizedBox(height: 14),
                      _buildBentoCard(
                        context,
                        title: 'DAILY GEAR+',
                        subtitle: 'Titanium-grade everyday carry tools.',
                        tag: 'BESTSELLER',
                        tagColor: const Color(0xFF10B981),
                        gradient: const [Color(0xFF064E3B), Color(0xFF0F172A)],
                        height: 103,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildBentoCard(
                  context,
                  title: 'URBAN OVERDRIVE',
                  subtitle: 'Master the streets with reinforced technical fabrics & instant delivery.',
                  tag: 'NEW DROP',
                  tagColor: AppColors.secondaryFixedDim,
                  gradient: const [Color(0xFF1E1B4B), Color(0xFF3525CD), Color(0xFF0F172A)],
                  height: 170,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        context,
                        title: 'ARTISANAL BAKERY',
                        subtitle: 'Fresh sourdough & pastries.',
                        tag: 'FRESH BATCH',
                        tagColor: const Color(0xFFD97706),
                        gradient: const [Color(0xFF2E1065), Color(0xFF1E293B)],
                        height: 120,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBentoCard(
                        context,
                        title: 'DAILY GEAR+',
                        subtitle: 'Titanium tools.',
                        tag: 'BESTSELLER',
                        tagColor: const Color(0xFF10B981),
                        gradient: const [Color(0xFF064E3B), Color(0xFF0F172A)],
                        height: 120,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    required List<Color> gradient,
    required double height,
  }) {
    return HoverCard(
      glowColor: gradient.first,
      onTap: () => context.go('/catalog'),
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: tagColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF003924)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
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
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('No products currently available.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return SizedBox(
      height: 260,
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
        width: 175,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 115,
                    width: double.infinity,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ShimmerLoader(width: double.infinity, height: 115),
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
                      padding: const EdgeInsets.all(5),
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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 10),

                  // Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Formatters.formatCurrency(product.sellingPrice),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.secondaryFixedDim),
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
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryFixedDim,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, size: 15, color: Color(0xFF005236)),
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

  // --- 8. EMERALD LOYALTY BANNER ---
  Widget _buildEmeraldLoyaltyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B291E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondaryFixedDim.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixedDim.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.loyalty_rounded, size: 30, color: AppColors.secondaryFixedDim),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '10% CASH-BACK REWARD PROGRAM',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.secondaryFixedDim),
                ),
                SizedBox(height: 4),
                Text(
                  'Earn on Every Confirmed Purchase',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Cashback balances credit automatically to your wallet upon order delivery.',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 9. TRUST MATRIX ---
  Widget _buildTrustMatrix(BuildContext context, bool isDesktop, bool isTablet) {
    final pillars = [
      {'icon': Icons.local_shipping_outlined, 'title': 'Hyper-Local Delivery', 'desc': 'Within 30 mins • Free > ₹500'},
      {'icon': Icons.card_giftcard_rounded, 'title': '10% Loyalty Cash-Back', 'desc': 'Credited instantly on delivery'},
      {'icon': Icons.verified_user_outlined, 'title': '100% Secure Checkout', 'desc': 'Bank-grade encrypted sandbox'},
      {'icon': Icons.replay_rounded, 'title': 'Zero-Friction Returns', 'desc': '7-day replacement guarantee'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
          childAspectRatio: isDesktop ? 1.6 : 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: pillars.length,
        itemBuilder: (context, index) {
          final p = pillars[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(p['icon'] as IconData, color: AppColors.secondaryFixedDim, size: 24),
                const SizedBox(height: 8),
                Text(p['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(p['desc'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      color: const Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verified Customer Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          SizedBox(
            height: 125,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final r = reviews[index];
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(height: 8),
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

  // --- 11. STITCH FOOTER ---
  Widget _buildStitchFooter(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Color(0xFF050811),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixedDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag_rounded, size: 18, color: Color(0xFF005236)),
              ),
              const SizedBox(width: 10),
              const Text('RAMA STORE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Elite High-Performance Fashion, Bakery, Books, Groceries & Medicine with 10% Loyalty Cash-Back rewards.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              TextButton(onPressed: () => context.go('/catalog'), child: const Text('Catalog', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              TextButton(onPressed: () => context.push('/loyalty'), child: const Text('Loyalty Program', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              TextButton(onPressed: () => context.push('/downloads'), child: const Text('Android App APK', style: TextStyle(color: AppColors.secondaryFixedDim, fontSize: 12))),
            ],
          ),
          const Divider(color: Color(0x1FFFFFFF), height: 32),
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
