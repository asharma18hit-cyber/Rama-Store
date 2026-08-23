import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../main.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController(text: '123 Main Street, Sector 5, City');
  final _cardNumberController = TextEditingController(text: '4532 1111 2222 3333');
  final _cvvController = TextEditingController(text: '123');
  final _expiryController = TextEditingController(text: '12/28');
  final _upiIdController = TextEditingController(text: 'user@upi');
  final _promoController = TextEditingController();

  bool _isProcessing = false;
  String _selectedPaymentMethod = 'card';

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    _cvvController.dispose();
    _expiryController.dispose();
    _upiIdController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);

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
            // Order Summary Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${cartState.totalItemCount} Items in Order',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text(Formatters.formatCurrency(cartState.grandTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Methods Tabs
            const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPaymentTab('card', 'Credit/Debit Card', Icons.credit_card),
                const SizedBox(width: 8),
                _buildPaymentTab('upi', 'UPI / GPay', Icons.qr_code_2),
                const SizedBox(width: 8),
                _buildPaymentTab('cod', 'Cash on Delivery', Icons.local_atm),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedPaymentMethod == 'card') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Tip: Card ending in 4000 simulates payment declination rollback test.',
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
            ] else if (_selectedPaymentMethod == 'upi') ...[
              AppTextField(
                controller: _upiIdController,
                label: 'Enter Virtual Payment Address (VPA / UPI ID)',
                hint: 'username@okaxis / 9876543210@paytm',
                prefixIcon: const Icon(Icons.qr_code, color: AppColors.primaryGold),
              ),
              const SizedBox(height: 8),
              const Text('Supports Google Pay, PhonePe, Paytm & BHIM UPI', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cash on Delivery Selected. Pay cash or UPI directly to the delivery partner upon arrival.',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),
            const Text('Order Summary & Promo Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  // Promo Code Input Box (Stitch Design)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter Promo Code (e.g. RAMA10)',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            isDense: true,
                            fillColor: AppColors.inputBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Promo Code "RAMA10" Applied! 10% Cash-Back Discount Credited.'),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                        },
                        child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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

            const SizedBox(height: 16),
            // Google Stitch 256-bit SSL Security Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.verified_user_outlined, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Encrypted 256-bit SSL Connection • 100% Guaranteed',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),

            const SizedBox(height: 32),
            AppButton(
              text: _selectedPaymentMethod == 'cod' ? 'Confirm Cash on Delivery Order' : 'Place Order & Pay Now',
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () async {
                final addr = _addressController.text.trim();
                final card = _cardNumberController.text.replaceAll(' ', '').trim();
                final cvv = _cvvController.text.trim();
                final expiry = _expiryController.text.trim();
                final upiId = _upiIdController.text.trim();
                final messenger = ScaffoldMessenger.of(context);

                if (addr.isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Please enter delivery address')));
                  return;
                }

                if (_selectedPaymentMethod == 'card' && (card.isEmpty || cvv.isEmpty || expiry.isEmpty)) {
                  messenger.showSnackBar(const SnackBar(content: Text('Please enter card details')));
                  return;
                }

                if (_selectedPaymentMethod == 'upi' && upiId.isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Please enter valid UPI ID')));
                  return;
                }

                setState(() => _isProcessing = true);

                try {
                  final checkoutRepo = ref.read(checkoutRepositoryProvider);
                  // 1. Create checkout session
                  final sessionRes = await checkoutRepo.createCheckoutSession(cartState.items, addr);
                  final trackingNumber = sessionRes['session']['tracking_number'];

                  // 2. Process payment (mock / sandbox API)
                  final payCard = _selectedPaymentMethod == 'card' ? card : '4532111122223333';
                  await checkoutRepo.processPayment(trackingNumber, payCard, '123', '12/28');

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

  Widget _buildPaymentTab(String id, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGold : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primaryGold : AppColors.surfaceLight),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
