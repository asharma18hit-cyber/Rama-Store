import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../main.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistIds = ref.watch(wishlistNotifierProvider);
    final catalogState = ref.watch(catalogNotifierProvider);

    final favoriteProducts = catalogState.products
        .where((p) => wishlistIds.contains(p.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Saved Wishlist (${favoriteProducts.length})'),
      ),
      body: favoriteProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 80, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('Your wishlist is empty', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Tap the heart icon on any product to save it here', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Explore Catalog',
                    width: 200,
                    onPressed: () => context.go('/catalog'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favoriteProducts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = favoriteProducts[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(imageUrl: product.imageUrl!, fit: BoxFit.cover)
                              : Container(color: AppColors.surfaceLight, child: const Icon(Icons.store, color: AppColors.textMuted)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.categoryName ?? 'Essential',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.formatCurrency(product.sellingPrice),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryGoldLight),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () => ref.read(wishlistNotifierProvider.notifier).toggleFavorite(product.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart, color: AppColors.primaryGold),
                            onPressed: () {
                              ref.read(cartNotifierProvider.notifier).addItem(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added ${product.name} to cart!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
