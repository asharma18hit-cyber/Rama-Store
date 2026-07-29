import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../main.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartNotifierProvider);
    final loyaltyPoints = ref.watch(loyaltyRepositoryProvider).getStoredPoints();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Shopping Cart (${cartState.totalItemCount})'),
      ),
      body: cartState.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('Your store cart is empty', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Explore Catalog',
                    width: 200,
                    onPressed: () => context.go('/catalog'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Free Delivery Progress Meter
                Container(
                  padding: const EdgeInsets.all(14),
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.local_shipping, color: AppColors.primaryGold, size: 18),
                              SizedBox(width: 8),
                              Text('Free Local Delivery Threshold (₹500)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          Text(
                            cartState.qualifiesForFreeDelivery
                                ? 'UNLOCKED!'
                                : 'Add ${Formatters.formatCurrency(AppConstants.freeDeliveryThreshold - cartState.subtotal)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cartState.qualifiesForFreeDelivery ? AppColors.success : AppColors.accentAmber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: cartState.deliveryProgress,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          cartState.qualifiesForFreeDelivery ? AppColors.success : AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Cart Line Items List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartState.items.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.surfaceLight),
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_basket, color: AppColors.primaryGold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text(Formatters.formatCurrency(item.product.sellingPrice), style: const TextStyle(color: AppColors.primaryGoldLight)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 22),
                                  onPressed: () => ref.read(cartNotifierProvider.notifier).updateQuantity(item.product.id, -1),
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryGold, size: 22),
                                  onPressed: () => ref.read(cartNotifierProvider.notifier).updateQuantity(item.product.id, 1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                                  onPressed: () => ref.read(cartNotifierProvider.notifier).removeItem(item.product.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Subtotal & Checkout Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Apply Loyalty Points Toggle
                      InkWell(
                        onTap: () => ref.read(cartNotifierProvider.notifier).toggleLoyaltyDiscount(loyaltyPoints),
                        child: Row(
                          children: [
                            Icon(
                              cartState.appliedLoyalty ? Icons.check_box : Icons.check_box_outline_blank,
                              color: AppColors.primaryGold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Apply Loyalty Cash-Back (${loyaltyPoints.toStringAsFixed(0)} pts available)',
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                          Text(Formatters.formatCurrency(cartState.subtotal), style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Delivery', style: TextStyle(color: AppColors.textSecondary)),
                          Text(
                            cartState.qualifiesForFreeDelivery ? 'FREE' : Formatters.formatCurrency(AppConstants.flatDeliveryFee),
                            style: TextStyle(color: cartState.qualifiesForFreeDelivery ? AppColors.success : AppColors.textPrimary),
                          ),
                        ],
                      ),
                      if (cartState.appliedLoyalty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Loyalty Points Discount', style: TextStyle(color: AppColors.success)),
                            Text('-${Formatters.formatCurrency(cartState.loyaltyDiscount)}', style: const TextStyle(color: AppColors.success)),
                          ],
                        ),
                      ],
                      const Divider(color: AppColors.surfaceLight, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(
                            Formatters.formatCurrency(cartState.grandTotal),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Proceed to Checkout',
                        icon: Icons.arrow_forward,
                        onPressed: () => context.push('/checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
