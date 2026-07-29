import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../main.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController(text: '123 Main Street, Sector 5, City');
  final _cardNumberController = TextEditingController(text: '4532 1111 2222 3333');
  final _cvvController = TextEditingController(text: '123');
  final _expiryController = TextEditingController(text: '12/28');

  bool _isProcessing = false;

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    _cvvController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            AppTextField(
              controller: _addressController,
              label: 'Shipping Address',
              hint: 'Full street address, city & postal code',
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 24),
            const Text('Payment Credentials (Sandbox)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
              ),
              child: const Text(
                'Tip: Use card ending in 4000 (e.g. 4000 0000 0000 4000) to test gateway declination & rollback simulation.',
                style: TextStyle(fontSize: 12, color: AppColors.accentAmber),
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _cardNumberController,
              label: 'Card Number (16 Digits)',
              hint: '4532 1111 2222 3333',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.credit_card, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _expiryController,
                    label: 'Expiry (MM/YY)',
                    hint: '12/28',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppTextField(
                    controller: _cvvController,
                    label: 'CVV (3 Digits)',
                    hint: '123',
                    obscureText: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                      Text(Formatters.formatCurrency(cartState.subtotal), style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Fee', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        cartState.qualifiesForFreeDelivery ? 'FREE' : Formatters.formatCurrency(cartState.deliveryFee),
                        style: TextStyle(color: cartState.qualifiesForFreeDelivery ? AppColors.success : AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GST Tax (18%)', style: TextStyle(color: AppColors.textSecondary)),
                      Text(Formatters.formatCurrency(cartState.taxAmount), style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  if (cartState.appliedLoyalty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Loyalty Discount', style: TextStyle(color: AppColors.success)),
                        Text('-${Formatters.formatCurrency(cartState.loyaltyDiscount)}', style: const TextStyle(color: AppColors.success)),
                      ],
                    ),
                  ],
                  const Divider(color: AppColors.surfaceLight, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text(Formatters.formatCurrency(cartState.grandTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            AppButton(
              text: 'Place Order & Pay',
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () async {
                final addr = _addressController.text.trim();
                final card = _cardNumberController.text.replaceAll(' ', '').trim();
                final cvv = _cvvController.text.trim();
                final expiry = _expiryController.text.trim();
                final messenger = ScaffoldMessenger.of(context);

                if (addr.isEmpty || card.isEmpty || cvv.isEmpty || expiry.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Please fill out all address & payment fields')),
                  );
                  return;
                }

                setState(() => _isProcessing = true);

                try {
                  final checkoutRepo = ref.read(checkoutRepositoryProvider);
                  // 1. Create checkout session
                  final sessionRes = await checkoutRepo.createCheckoutSession(cartState.items, addr);
                  final trackingNumber = sessionRes['session']['tracking_number'];

                  // 2. Process payment
                  await checkoutRepo.processPayment(trackingNumber, card, cvv, expiry);

                  // 3. Clear cart on success
                  await ref.read(cartNotifierProvider.notifier).clearCart();

                  if (!mounted) return;
                  setState(() => _isProcessing = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Order #$trackingNumber Placed Successfully!'), backgroundColor: AppColors.success),
                  );
                  if (context.mounted) {
                    context.go('/orders');
                  }
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isProcessing = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
