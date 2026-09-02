import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../admin/data/store_config_model.dart';
import '../../admin/presentation/store_config_notifier.dart';
import '../../../main.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _couponController = TextEditingController();
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final storeConfig = ref.read(storeConfigProvider);
    final coupon = storeConfig.coupons.firstWhere(
      (c) => c.code.toUpperCase() == code,
      orElse: () => StoreCoupon(code: '', description: '', discountType: 'flat', discountValue: 0.0, minOrderAmount: 0.0, isActive: false),
    );

    if (coupon.code.isEmpty || !coupon.isActive) {
      setState(() => _couponError = 'Invalid or expired promo code "$code"');
      return;
    }

    final cartState = ref.read(cartNotifierProvider);
    if (cartState.subtotal < coupon.minOrderAmount) {
      setState(() => _couponError = 'Minimum order of ₹${coupon.minOrderAmount.toStringAsFixed(0)} required for this code');
      return;
    }

    final success = ref.read(cartNotifierProvider.notifier).applyCoupon(coupon);
    if (success) {
      setState(() {
        _couponError = null;
        _couponController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✨ Promo code "${coupon.code}" applied successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartNotifierProvider);
    final storeConfig = ref.watch(storeConfigProvider);
    final loyaltyPoints = ref.watch(loyaltyRepositoryProvider).getStoredPoints();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

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
          'BAG (${cartState.totalItemCount} ITEMS)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textPrimary),
        ),
        actions: [
          if (cartState.items.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(cartNotifierProvider.notifier).clearCart(),
              child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: cartState.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'YOUR BAG IS EMPTY',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explore our hyper-local catalog and daily essentials.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      text: 'Explore Catalog',
                      icon: Icons.storefront_rounded,
                      width: 220,
                      onPressed: () => context.go('/catalog'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48.0 : 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Dynamic Delivery Threshold Banner
                    _buildDeliveryMeter(cartState, storeConfig),
                    const SizedBox(height: 24),

                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildItemsList(cartState),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 5,
                            child: _buildOrderSummary(cartState, loyaltyPoints, storeConfig),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildItemsList(cartState),
                          const SizedBox(height: 24),
                          _buildOrderSummary(cartState, loyaltyPoints, storeConfig),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDeliveryMeter(cartState, storeConfig) {
    final threshold = cartState.freeDeliveryThreshold;
    final subtotal = cartState.subtotal;
    final remaining = (threshold - subtotal).clamp(0.0, threshold);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppColors.secondaryFixedDim, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Free Delivery (Orders > ₹${threshold.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cartState.qualifiesForFreeDelivery
                      ? AppColors.secondaryFixedDim.withValues(alpha: 0.2)
                      : const Color(0xFF3525CD).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cartState.qualifiesForFreeDelivery
                      ? 'FREE SHIPPING UNLOCKED'
                      : 'Add ${Formatters.formatCurrency(remaining)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: cartState.qualifiesForFreeDelivery ? AppColors.secondaryFixedDim : AppColors.primaryFixedDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cartState.deliveryProgress,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation<Color>(
                cartState.qualifiesForFreeDelivery ? AppColors.secondaryFixedDim : AppColors.primaryFixedDim,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(cartState) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cartState.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = cartState.items[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.product.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, err) => Container(
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
              const SizedBox(width: 14),

              // Title & Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(item.product.sellingPrice),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondaryFixedDim, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.textPrimary, size: 14),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => ref.read(cartNotifierProvider.notifier).updateQuantity(item.product.id, -1),
                    ),
                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.textPrimary, size: 14),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => ref.read(cartNotifierProvider.notifier).updateQuantity(item.product.id, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Remove Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                onPressed: () => ref.read(cartNotifierProvider.notifier).removeItem(item.product.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(cartState, double loyaltyPoints, storeConfig) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // Coupon / Promo Code Box
          if (cartState.appliedCouponCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryGoldLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: AppColors.primaryGoldLight, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Coupon: ${cartState.appliedCouponCode} (-${Formatters.formatCurrency(cartState.promoDiscount)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryGoldLight),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.primaryGoldLight),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ref.read(cartNotifierProvider.notifier).removeCoupon(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _couponController,
                    label: 'Have a Promo Code?',
                    hint: 'e.g. RAMA50, FESTIVE10',
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryFixedDim,
                      foregroundColor: const Color(0xFF005236),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _applyCoupon,
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 4),
              Text(_couponError!, style: const TextStyle(fontSize: 11, color: AppColors.error)),
            ],
            const SizedBox(height: 12),
          ],

          // Loyalty points toggle
          GestureDetector(
            onTap: () => ref.read(cartNotifierProvider.notifier).toggleLoyaltyDiscount(loyaltyPoints),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cartState.appliedLoyalty ? AppColors.secondaryFixedDim.withValues(alpha: 0.15) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cartState.appliedLoyalty ? AppColors.secondaryFixedDim : const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Icon(
                    cartState.appliedLoyalty ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: cartState.appliedLoyalty ? AppColors.secondaryFixedDim : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Redeem Loyalty Points (${loyaltyPoints.toStringAsFixed(0)} available)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(Formatters.formatCurrency(cartState.subtotal), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Delivery', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(
                cartState.qualifiesForFreeDelivery ? 'FREE' : Formatters.formatCurrency(cartState.standardDeliveryFee),
                style: TextStyle(
                  color: cartState.qualifiesForFreeDelivery ? AppColors.secondaryFixedDim : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (cartState.promoDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Promo Coupon Discount', style: TextStyle(color: AppColors.primaryGoldLight, fontSize: 13)),
                Text('-${Formatters.formatCurrency(cartState.promoDiscount)}', style: const TextStyle(color: AppColors.primaryGoldLight, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (cartState.appliedLoyalty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Loyalty Discount', style: TextStyle(color: AppColors.secondaryFixedDim, fontSize: 13)),
                Text('-${Formatters.formatCurrency(cartState.loyaltyDiscount)}', style: const TextStyle(color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const Divider(color: Color(0xFF334155), height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              Text(
                Formatters.formatCurrency(cartState.grandTotal),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryFixedDim),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(
            text: 'Proceed to Checkout',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push('/checkout'),
          ),
        ],
      ),
    );
  }
}
