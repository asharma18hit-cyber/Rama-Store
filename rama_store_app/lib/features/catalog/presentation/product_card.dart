import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../main.dart';
import '../data/catalog_models.dart';
import 'wishlist_notifier.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final double? width;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(wishlistNotifierProvider).contains(product.id);
    final originalMrp = product.sellingPrice * 1.25;

    return HoverCard(
      glowColor: const Color(0xFF3525CD).withValues(alpha: 0.2),
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        width: width ?? 180,
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
            // Product Image & Badges Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    height: compact ? 105 : 125,
                    width: double.infinity,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => ShimmerLoader(
                              width: double.infinity,
                              height: compact ? 105 : 125,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFEFF4FF),
                              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF777587)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFEFF4FF),
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF777587)),
                          ),
                  ),
                ),
                // Discount Pill
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
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                // Stock Pill (if low stock)
                if (product.stock <= 5 && product.stock > 0)
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '● Only ${product.stock} left',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.accentAmber),
                      ),
                    ),
                  ),
                // Wishlist Heart Button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(wishlistNotifierProvider.notifier).toggleFavorite(product.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFav ? 'Removed ${product.name} from wishlist' : 'Added ${product.name} to wishlist'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
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

            // Product Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.categoryName ?? 'Essential',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF464555)),
                        ),
                      ),
                      const Icon(Icons.star_rounded, size: 13, color: AppColors.accentAmber),
                      const SizedBox(width: 2),
                      const Text(
                        '4.9',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Price Row with Add to Cart Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Formatters.formatCurrency(product.sellingPrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3525CD),
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(originalMrp),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF777587),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.read(cartNotifierProvider.notifier).addItem(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🛍️ Added ${product.name} to cart!'),
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
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
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
}
