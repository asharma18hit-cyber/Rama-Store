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
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Left: Search Button Trigger
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.search_rounded, size: 24, color: Color(0xFF464555)),
                        onPressed: () => context.go('/catalog'),
                      ),
                    ),
                  ),

                  // Center: Brand Logo in Primary Indigo
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: const Text(
                      'Rama Store',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: Color(0xFF3525CD),
                      ),
                    ),
                  ),

                  // Right: Account & Cart Actions
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline_rounded, size: 24, color: Color(0xFF464555)),
                          tooltip: 'Account',
                          onPressed: () => context.go('/profile'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.shopping_bag_outlined, size: 24, color: Color(0xFF464555)),
                          tooltip: 'Cart',
                          onPressed: () => context.go('/cart'),
                        ),
                      ],
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: isSelected
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF3525CD), width: 2)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF3525CD) : const Color(0xFF464555),
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
        color: Color(0xFFEFF4FF),
        border: Border(bottom: BorderSide(color: Color(0xFFE1E3E4), width: 0.8)),
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
                  color: isSelected ? const Color(0xFF3525CD) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3525CD) : const Color(0xFFC7C4D8),
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

  // --- 4. HERO SECTION (Exact Stitch Spec) ---
  Widget _buildHeroSection(BuildContext context, bool isDesktop, bool isTablet) {
    return Container(
      height: isDesktop ? 600 : (isTablet ? 480 : 420),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBT_wnjFgL5Xp01ccSxfgiRcjTYsvPdt8XLqcOJCpCJhB8E0T2HDGL9mJnfNynIrBGxzFUzHXUwcGaKOLMpaEQYhhS_cFZQ9uHPGXJyKYlsFdSOYfa2-Jt3MPzfxh5gZbtvUQNII-y5ubhEgAmDev5I2jYTxfnTOEzVd89t0JyfsgEDqRlEO2C0b5h9EkZyNLluRl5eZfvlShB3-DAoY18L2uFDuTPV_Q6ydNg7mTKiTFVK-eVYScNF',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF0B1C30)),
              ),
            ),

            // Black/40 Dark Overlay
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),

            // Hero Text & Call-To-Action Content
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ENGINEERED FOR EXCELLENCE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 44 : (isTablet ? 32 : 24),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Text(
                        'Discover the intersection of high-performance engineering and industrial luxury. Precision-crafted gear for the modern elite.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3525CD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 4,
                      ),
                      onPressed: () => context.go('/catalog'),
                      child: const Text(
                        'Explore the Elite Series',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7C4D8), width: 0.8),
                boxShadow: const [
                  BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
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
                      borderRadius: BorderRadius.circular(8),
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dept['desc'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF464555)),
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

  // --- 6. CURATED BENTO SHOWCASE (Exact Stitch HTML Layout) ---
  Widget _buildBentoShowcase(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              // Footwear (8-col)
              Expanded(
                flex: isDesktop ? 8 : 1,
                child: _buildBentoImageCard(
                  context,
                  title: 'Footwear',
                  subtitle: 'Precision traction and dynamic response.',
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCxLNFETdk0vc8tl9bCc8DjPLHUGE_9Vtp8kRoCpTkm3PIpkFkRjjM6KlkmU22eZH49jKvIxFsPtVpVmW4PXTVJ4u3RkDpBTKAqfyX777FpX66E3J3PXBWLW3Nm407u4UMbYW48iqdxwWUPhWcICjSpzfkMohkoGIZtLWk02BB09Aa6-Mdo8s4u8Hm-An7GdDnxhbLY2X_ioUT61bddRHlLmaa8BGhM-2HjmfoxxeLnv6Zx6oxD06UX',
                  height: 260,
                ),
              ),
              if (isDesktop) const SizedBox(width: 16),
              if (isDesktop)
                // Accessories (4-col)
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 260,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC7C4D8), width: 0.8),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(Icons.watch_rounded, size: 100, color: Color(0x333525CD)),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Accessories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0B1C30))),
                              const SizedBox(height: 4),
                              Row(
                                children: const [
                                  Text('Shop Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3525CD))),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF3525CD)),
                                ],
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
              // Apparel (4-col)
              Expanded(
                flex: isDesktop ? 4 : 1,
                child: _buildBentoImageCard(
                  context,
                  title: 'Apparel',
                  subtitle: 'Engineered performance clothing.',
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDBkTG9HuXuwsoakC986CqU4KWLlEos1USaNBznXY6rUF0Vx_Od--RwshpBIspT4_rn5UAQBP4H7LY6ZUOom658sGHXVAouYIA8j17-gAvQ4JCaBt2J2LYb1dbD3ivzGYj5GyOEHBZpcG0QDxFT4aXG0vZpZ9P9NKs7aeKhobaXmmLRNEyZXXJrOIvIcTeuEBnzkq1Hzrm-S4eKxoN4NB1Lia7oubJHzkOBqSIZaCi_QgzFYRYkK0oZ',
                  height: 240,
                ),
              ),
              if (isDesktop) const SizedBox(width: 16),
              if (isDesktop)
                // Tech Gear (8-col)
                Expanded(
                  flex: 8,
                  child: _buildBentoImageCard(
                    context,
                    title: 'Tech Gear',
                    subtitle: 'Seamless integration for optimal performance.',
                    imageUrl:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCEEm8VGdFDLhW5Kb2RICN9WcsWW1OW7xGfVag5mdtRTdlVMr62UZn7hSedr66rn1fKE_DxC321xDuVxmwXe_FIz7um6MZy4xvsAwtmRqrnqwV4DCUBItUheBrCrUM7ihrvJCUMDilPmBECeA2oS2OvSXLwtnBIh2ynv8m79jUbuj5B8OPdh7XMMdCAm7-frjO9xlYKM6hcSKXzvu4EIxC397uFVILtZFuTQnqRfgZTMqtTTjphPZ-O',
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
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFFE5EEFF)),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
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
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7C4D8)),
        ),
        child: const Center(
          child: Text('No products currently available.', style: TextStyle(color: Color(0xFF464555))),
        ),
      );
    }

    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final product = state.products[index];
          return _buildProductCard(context, product, ref);
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, WidgetRef ref) {
    final isFav = ref.watch(wishlistNotifierProvider).contains(product.id);
    final originalMrp = product.sellingPrice * 1.25;

    return HoverCard(
      glowColor: const Color(0xFF3525CD),
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7C4D8), width: 0.8),
          boxShadow: const [
            BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ProductImageView(
                  imageUrl: product.imageUrl,
                  height: 125,
                  width: double.infinity,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBA1A1A),
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
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 14,
                        color: isFav ? const Color(0xFFBA1A1A) : const Color(0xFF464555),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.categoryName ?? 'Essential',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF464555)),
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF3525CD)),
                          ),
                          Text(
                            Formatters.formatCurrency(originalMrp),
                            style: const TextStyle(fontSize: 9, color: Color(0xFF777587), decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.read(cartNotifierProvider.notifier).addItem(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${product.name} to cart!'),
                              backgroundColor: const Color(0xFF3525CD),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3525CD),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, size: 15, color: Colors.white),
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
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF3525CD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.loyalty_rounded, size: 28, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '10% CASH-BACK REWARD PROGRAM',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF3525CD)),
                ),
                SizedBox(height: 4),
                Text(
                  'Earn on Every Confirmed Purchase',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                ),
                SizedBox(height: 4),
                Text(
                  'Cashback balances credit automatically to your wallet upon order delivery.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF464555)),
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
      {'icon': Icons.verified_user_outlined, 'title': '100% Secure Checkout', 'desc': 'Bank-grade encrypted payment'},
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(p['icon'] as IconData, color: const Color(0xFF3525CD), size: 24),
                const SizedBox(height: 8),
                Text(p['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30))),
                const SizedBox(height: 2),
                Text(p['desc'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF464555))),
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
      color: const Color(0xFFEFF4FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verified Customer Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30))),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1C30))),
                          RatingStars(rating: r['rating'] as double),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r['review'] as String,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF464555)),
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
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFC7C4D8), width: 1)),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('RAMA STORE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF3525CD), letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Elite High-Performance Fashion, Bakery, Books, Groceries & Medicine with 10% Loyalty Cash-Back rewards.',
            style: TextStyle(fontSize: 11, color: Color(0xFF464555), height: 1.4),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              TextButton(onPressed: () => context.go('/catalog'), child: const Text('Catalog', style: TextStyle(color: Color(0xFF464555), fontSize: 12))),
              TextButton(onPressed: () => context.push('/loyalty'), child: const Text('Loyalty Program', style: TextStyle(color: Color(0xFF464555), fontSize: 12))),
              TextButton(onPressed: () => context.push('/downloads'), child: const Text('Android App APK', style: TextStyle(color: Color(0xFF3525CD), fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(color: Color(0xFFC7C4D8), height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('© 2026 Rama Store Inc. All Rights Reserved.', style: TextStyle(fontSize: 10, color: Color(0xFF777587))),
              Text('Authentic Quality Guaranteed', style: TextStyle(fontSize: 10, color: Color(0xFF777587))),
            ],
          ),
        ],
      ),
    );
  }
}
