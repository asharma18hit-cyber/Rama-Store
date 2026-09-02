import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../../main.dart';
import '../data/catalog_models.dart';
import 'catalog_notifier.dart';
import 'wishlist_notifier.dart';
import 'product_card.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final catalogState = ref.watch(catalogNotifierProvider);
    final isFav = ref.watch(wishlistNotifierProvider).contains(p.id);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final originalMrp = p.sellingPrice * 1.25;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? const Color(0xFFEF4444) : AppColors.textSecondary,
            ),
            onPressed: () {
              ref.read(wishlistNotifierProvider.notifier).toggleFavorite(p.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isFav ? 'Removed from wishlist' : 'Added to wishlist'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product link copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Layout: 2 Columns on Desktop, 1 Column on Mobile
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildProductGallery(p),
                    ),
                    const SizedBox(width: 36),
                    Expanded(
                      flex: 6,
                      child: _buildProductInfo(p, originalMrp),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductGallery(p),
                    const SizedBox(height: 20),
                    _buildProductInfo(p, originalMrp),
                  ],
                ),

              const SizedBox(height: 40),

              // Trust & Warranty Bento Grid
              _buildTrustBento(),

              const SizedBox(height: 40),

              // Related Products Section
              const Text(
                'RELATED STORE DROPS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: catalogState.products.length,
                  itemBuilder: (context, index) {
                    final rel = catalogState.products[index];
                    if (rel.id == p.id) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 14.0),
                      child: ProductCard(product: rel, width: 175),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGallery(Product p) {
    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Center(
              child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const ShimmerLoader(width: double.infinity, height: 380),
                      errorWidget: (context, url, error) => const Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textMuted),
                    )
                  : const Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textMuted),
            ),
          ),
          // Edition Pill
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF3525CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚡ LIMITED RELEASE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
              ),
            ),
          ),
          // Stock indicator
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.isInStock ? AppColors.secondaryFixedDim : const Color(0xFFEF4444)),
              ),
              child: Text(
                p.isInStock ? '● In Stock (${p.stock} units available)' : '● Out of Stock',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: p.isInStock ? AppColors.secondaryFixedDim : const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo(Product p, double originalMrp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3525CD).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3525CD)),
          ),
          child: Text(
            p.categoryName?.toUpperCase() ?? 'ESSENTIAL',
            style: const TextStyle(fontSize: 11, color: AppColors.primaryFixedDim, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),

        // Product Title
        Text(
          p.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text('SKU: ${p.sku}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'monospace')),
        const SizedBox(height: 16),

        // Price Row with Discount Pill
        Row(
          children: [
            Text(
              Formatters.formatCurrency(p.sellingPrice),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.secondaryFixedDim,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              Formatters.formatCurrency(originalMrp),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '-20% OFF',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Description
        const Text(
          'Curated high-performance item from the official Rama Store autumn drop. Tested for durability, hyper-local express dispatch within 30 minutes, and eligible for 10% loyalty cashback.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Quantity Selector & Action CTAs
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: AppColors.textPrimary, size: 18),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.textPrimary, size: 18),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AppButton(
                text: 'Add to Cart',
                icon: Icons.add_shopping_cart_rounded,
                isOutlined: true,
                onPressed: p.isInStock
                    ? () {
                        ref.read(cartNotifierProvider.notifier).addItem(p, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🛍️ Added $_quantity x ${p.name} to cart!'),
                            backgroundColor: const Color(0xFF0F172A),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                text: 'Buy Now',
                icon: Icons.bolt_rounded,
                onPressed: p.isInStock
                    ? () {
                        ref.read(cartNotifierProvider.notifier).addItem(p, quantity: _quantity);
                        context.push('/checkout');
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBento() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.local_shipping_outlined, color: AppColors.secondaryFixedDim, size: 24),
                SizedBox(height: 8),
                Text('30-Min Express', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Hyper-local doorstep dispatch', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.verified_outlined, color: AppColors.secondaryFixedDim, size: 24),
                SizedBox(height: 8),
                Text('100% Genuine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Direct authorized sourcing', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.stars_outlined, color: AppColors.secondaryFixedDim, size: 24),
                SizedBox(height: 8),
                Text('10% Cashback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Loyalty coins on fulfillment', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
