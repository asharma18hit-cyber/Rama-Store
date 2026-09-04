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
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3525CD)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3525CD)),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? const Color(0xFFBA1A1A) : const Color(0xFF464555),
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
            icon: const Icon(Icons.share_outlined, color: Color(0xFF464555)),
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
                  color: Color(0xFF0B1C30),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const ShimmerLoader(width: double.infinity, height: 380),
                      errorWidget: (context, url, error) => const Icon(Icons.inventory_2_outlined, size: 80, color: Color(0xFF777587)),
                    )
                  : const Icon(Icons.inventory_2_outlined, size: 80, color: Color(0xFF777587)),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.isInStock ? const Color(0xFF3525CD) : const Color(0xFFBA1A1A)),
              ),
              child: Text(
                p.isInStock ? '● In Stock (${p.stock} units available)' : '● Out of Stock',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: p.isInStock ? const Color(0xFF3525CD) : const Color(0xFFBA1A1A),
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
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3525CD)),
          ),
          child: Text(
            p.categoryName?.toUpperCase() ?? 'ESSENTIAL',
            style: const TextStyle(fontSize: 11, color: Color(0xFF3525CD), fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),

        // Product Title
        Text(
          p.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0B1C30),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text('SKU: ${p.sku}', style: const TextStyle(color: Color(0xFF777587), fontSize: 13, fontFamily: 'monospace')),
        const SizedBox(height: 16),

        // Price Row with Discount Pill
        Row(
          children: [
            Text(
              Formatters.formatCurrency(p.sellingPrice),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3525CD),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              Formatters.formatCurrency(originalMrp),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF777587),
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFBA1A1A),
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
          style: TextStyle(color: Color(0xFF464555), height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Quantity Selector & Action CTAs
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Color(0xFF0B1C30), size: 18),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF0B1C30), size: 18),
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
                            backgroundColor: const Color(0xFF3525CD),
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
              children: const [
                Icon(Icons.local_shipping_outlined, color: Color(0xFF3525CD), size: 24),
                SizedBox(height: 8),
                Text('30-Min Express', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30))),
                Text('Hyper-local doorstep dispatch', style: TextStyle(fontSize: 11, color: Color(0xFF464555))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
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
              children: const [
                Icon(Icons.verified_outlined, color: Color(0xFF3525CD), size: 24),
                SizedBox(height: 8),
                Text('100% Genuine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30))),
                Text('Direct authorized sourcing', style: TextStyle(fontSize: 11, color: Color(0xFF464555))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
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
              children: const [
                Icon(Icons.stars_outlined, color: Color(0xFF3525CD), size: 24),
                SizedBox(height: 8),
                Text('10% Cashback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30))),
                Text('Loyalty coins on fulfillment', style: TextStyle(fontSize: 11, color: Color(0xFF464555))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
