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

class StitchProductCard extends ConsumerWidget {
  final Product product;
  final double? width;
  final bool compact;

  const StitchProductCard({
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
      glowColor: AppColors.primaryContainer,
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        width: width ?? 180,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image & Badges Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                              color: const Color(0xFF334155),
                              child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF334155),
                            child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
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
                      color: const Color(0xFFEF4444),
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
                      color: AppColors.textPrimary,
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
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                      const Icon(Icons.star_rounded, size: 13, color: AppColors.accentAmber),
                      const SizedBox(width: 2),
                      const Text(
                        '4.9',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                              color: AppColors.secondaryFixedDim,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(originalMrp),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textMuted,
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
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 15,
                            color: Color(0xFF005236),
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
