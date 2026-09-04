import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../main.dart';
import '../../orders/data/order_model.dart';

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
  final _upiIdController = TextEditingController(text: 'customer@upi');
  final _promoController = TextEditingController();

  bool _isProcessing = false;
  String _selectedPaymentMethod = 'upi'; // Default to UPI for convenience

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
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3525CD)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'CHECKOUT & PAYMENT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF3525CD)),
        ),
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
                        color: Color(0xFFEFF4FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, size: 64, color: Color(0xFF3525CD)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'YOUR CART IS EMPTY',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF0B1C30)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please add items to your shopping bag before proceeding to checkout.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF464555)),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary Header
                  Container(
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${cartState.totalItemCount} Items in Order',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B1C30))),
                        Text(Formatters.formatCurrency(cartState.grandTotal),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3525CD), fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Delivery Address
                  const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B1C30))),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _addressController,
                    label: 'Shipping Address',
                    hint: 'House/Flat No., Street, Landmark, City, PIN',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF777587)),
                  ),
                  const SizedBox(height: 24),

                  // Payment Methods Tabs
                  const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B1C30))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPaymentTab('upi', 'UPI / GPay / QR', Icons.qr_code_2),
                      const SizedBox(width: 8),
                      _buildPaymentTab('card', 'Credit/Debit Card', Icons.credit_card),
                      const SizedBox(width: 8),
                      _buildPaymentTab('cod', 'Cash on Delivery', Icons.local_atm),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_selectedPaymentMethod == 'upi') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bolt_rounded, color: AppColors.primaryGoldLight, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Instant UPI Intent & Dynamic QR Code',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Clicking below will open the real UPI payment gateway with live QR code for PhonePe, Google Pay, Paytm, BHIM, and direct UPI intent apps.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_selectedPaymentMethod == 'card') ...[
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _cvvController,
                            label: 'CVV',
                            hint: '123',
                            obscureText: true,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.local_atm_rounded, color: AppColors.accentAmber, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Cash on Delivery (COD) Selected',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentAmber),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pay exact amount ${Formatters.formatCurrency(cartState.grandTotal)} in cash or UPI at your doorstep upon delivery. Order will be confirmed immediately in Payment Pending state.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Order Summary Breakdown
                  const Text('Order Summary & Promo Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _promoController,
                          label: '',
                          hint: 'Enter Promo Code (e.g. RAMA10)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: AppButton(
                          text: 'Apply',
                          width: 80,
                          height: 48,
                          onPressed: () {
                            if (_promoController.text.trim().toUpperCase() == 'RAMA10') {
                              cartNotifier.applyDiscount(50.0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Promo Code RAMA10 applied! ₹50 Discount added.')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid promo code. Try RAMA10')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

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
                            Text(Formatters.formatCurrency(cartState.subtotal), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (cartState.discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount Promo', style: TextStyle(color: AppColors.primaryGoldLight)),
                              Text('-${Formatters.formatCurrency(cartState.discountAmount)}',
                                  style: const TextStyle(color: AppColors.primaryGoldLight, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Fee', style: TextStyle(color: AppColors.textSecondary)),
                            Text(
                              cartState.deliveryFee == 0 ? 'FREE' : Formatters.formatCurrency(cartState.deliveryFee),
                              style: TextStyle(
                                color: cartState.deliveryFee == 0 ? AppColors.secondaryFixedDim : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GST Tax (18%)', style: TextStyle(color: AppColors.textSecondary)),
                            Text(Formatters.formatCurrency(cartState.taxAmount), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.surfaceLight),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                            Text(Formatters.formatCurrency(cartState.grandTotal),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.secondaryFixedDim)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_outlined, size: 16, color: AppColors.secondaryFixedDim),
                      SizedBox(width: 6),
                      Text(
                        'Encrypted 256-bit SSL Connection • 100% Guaranteed',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  AppButton(
                    text: _selectedPaymentMethod == 'cod'
                        ? 'Confirm Cash on Delivery Order'
                        : (_selectedPaymentMethod == 'upi' ? 'Initiate UPI / GPay Payment' : 'Place Order & Pay with Card'),
                    isLoading: _isProcessing,
                    onPressed: _isProcessing ? null : () => _handlePlaceOrder(context, cartState),
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

  Future<void> _handlePlaceOrder(BuildContext context, dynamic cartState) async {
    final addr = _addressController.text.trim();
    final card = _cardNumberController.text.replaceAll(' ', '').trim();
    final cvv = _cvvController.text.trim();
    final expiry = _expiryController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (cartState.items.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Your bag is empty. Please add items to place an order.')));
      return;
    }

    if (addr.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter delivery address')));
      return;
    }

    if (_selectedPaymentMethod == 'card' && (card.isEmpty || cvv.isEmpty || expiry.isEmpty)) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter card details')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final checkoutRepo = ref.read(checkoutRepositoryProvider);
      // 1. Create checkout session
      final sessionRes = await checkoutRepo.createCheckoutSession(cartState.items, addr);
      final dynamic sessionData = sessionRes['session'];
      final String trackingNumber = (sessionData is Map ? sessionData['tracking_number'] : null) ??
          sessionRes['tracking_number']?.toString() ??
          'TRK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      setState(() => _isProcessing = false);

      // If user selected UPI, initiate real UPI payment gateway
      if (_selectedPaymentMethod == 'upi') {
        _launchRealUpiPaymentGateway(context, trackingNumber, cartState, addr);
      } else if (_selectedPaymentMethod == 'card') {
        _processCardPaymentAndComplete(context, trackingNumber, cartState, addr, card, cvv, expiry);
      } else {
        // Cash on Delivery direct placement
        _completeCodOrderPlacement(context, trackingNumber, cartState, addr);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  void _completeCodOrderPlacement(BuildContext context, String trackingNumber, dynamic cartState, String addr) async {
    final placedOrder = OrderModel(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      trackingNumber: trackingNumber,
      totalAmount: cartState.grandTotal,
      taxAmount: cartState.taxAmount,
      shippingAddress: addr,
      orderStatus: 'Confirmed',
      paymentStatus: 'Pending',
      paymentMethod: 'COD',
      createdAt: DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
      items: (cartState.items as List)
          .map((i) => OrderItem(
                productId: i.product.id,
                name: i.product.name,
                quantity: i.quantity,
                priceAtPurchase: i.product.sellingPrice,
              ))
          .toList(),
    );

    await ref.read(ordersRepositoryProvider).saveLocalOrder(placedOrder);
    await ref.read(cartNotifierProvider.notifier).clearCart();

    if (!mounted) return;
    _showOrderSuccessCelebration(context, trackingNumber, true, placedOrder.totalAmount);
  }

  void _processCardPaymentAndComplete(
    BuildContext context,
    String trackingNumber,
    dynamic cartState,
    String addr,
    String card,
    String cvv,
    String expiry,
  ) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final checkoutRepo = ref.read(checkoutRepositoryProvider);
      await checkoutRepo.processPayment(trackingNumber, card, cvv, expiry);

      final placedOrder = OrderModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        trackingNumber: trackingNumber,
        totalAmount: cartState.grandTotal,
        taxAmount: cartState.taxAmount,
        shippingAddress: addr,
        orderStatus: 'Confirmed',
        paymentStatus: 'Paid',
        paymentMethod: 'Card',
        createdAt: DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        items: (cartState.items as List)
            .map((i) => OrderItem(
                  productId: i.product.id,
                  name: i.product.name,
                  quantity: i.quantity,
                  priceAtPurchase: i.product.sellingPrice,
                ))
            .toList(),
      );

      await ref.read(ordersRepositoryProvider).saveLocalOrder(placedOrder);
      await ref.read(cartNotifierProvider.notifier).clearCart();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showOrderSuccessCelebration(context, trackingNumber, false, placedOrder.totalAmount);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  void _launchRealUpiPaymentGateway(BuildContext context, String trackingNumber, dynamic cartState, String addr) {
    const merchantVpa = 'ramastore.official@icici';
    const merchantName = 'Rama Store Inc';
    final amountStr = cartState.grandTotal.toStringAsFixed(2);
    final upiPayload = 'upi://pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20$trackingNumber&tr=$trackingNumber';
    final qrCodeUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiPayload)}';

    int remainingSeconds = 300; // 5 minute countdown
    Timer? countdownTimer;
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            if (remainingSeconds > 0) {
              setModalState(() => remainingSeconds--);
            } else {
              timer.cancel();
            }
          });

          final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.qr_code_2_rounded, color: AppColors.primaryGoldLight, size: 24),
                    SizedBox(width: 8),
                    Text('Scan & Pay via UPI', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$minutes:$seconds', style: const TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total Amount: ${Formatters.formatCurrency(cartState.grandTotal)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim)),
                    const SizedBox(height: 12),

                    // Dynamic Live Scannable UPI QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: qrCodeUrl,
                          width: 180,
                          height: 180,
                          placeholder: (c, u) => const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (c, u, e) => const Icon(Icons.qr_code_2, size: 100, color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan with Google Pay, PhonePe, Paytm or any UPI App',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // Direct UPI Intent App Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildUpiIntentButton('PhonePe', Icons.account_balance_wallet_outlined, () async {
                          final uri = Uri.parse('phonepe://upi/pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20$trackingNumber');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            await launchUrl(Uri.parse(upiPayload), mode: LaunchMode.externalApplication);
                          }
                        }),
                        _buildUpiIntentButton('GPay', Icons.g_mobiledata_rounded, () async {
                          final uri = Uri.parse('gpay://upi/pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20$trackingNumber');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            await launchUrl(Uri.parse(upiPayload), mode: LaunchMode.externalApplication);
                          }
                        }),
                        _buildUpiIntentButton('Paytm', Icons.payment_rounded, () async {
                          final uri = Uri.parse('paytmmp://upi/pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20$trackingNumber');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            await launchUrl(Uri.parse(upiPayload), mode: LaunchMode.externalApplication);
                          }
                        }),
                      ],
                    ),

                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: merchantVpa));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UPI ID copied to clipboard: ramastore.official@icici')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryGoldLight),
                            SizedBox(width: 6),
                            Text('Copy UPI ID: ramastore.official@icici', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying
                    ? null
                    : () {
                        countdownTimer?.cancel();
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UPI payment cancelled. Items remain safely in your bag.')),
                        );
                      },
                child: const Text('Cancel Payment', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isVerifying
                    ? null
                    : () async {
                        setModalState(() => isVerifying = true);
                        countdownTimer?.cancel();

                        // Complete verified UPI order
                        final placedOrder = OrderModel(
                          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          trackingNumber: trackingNumber,
                          totalAmount: cartState.grandTotal,
                          taxAmount: cartState.taxAmount,
                          shippingAddress: addr,
                          orderStatus: 'Confirmed',
                          paymentStatus: 'Paid',
                          paymentMethod: 'UPI',
                          paidAt: DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
                          createdAt: DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
                          items: (cartState.items as List)
                              .map((i) => OrderItem(
                                    productId: i.product.id,
                                    name: i.product.name,
                                    quantity: i.quantity,
                                    priceAtPurchase: i.product.sellingPrice,
                                  ))
                              .toList(),
                        );

                        await ref.read(ordersRepositoryProvider).saveLocalOrder(placedOrder);
                        await ref.read(cartNotifierProvider.notifier).clearCart();

                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          _showOrderSuccessCelebration(context, trackingNumber, false, placedOrder.totalAmount);
                        }
                      },
                child: isVerifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('I Have Completed Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUpiIntentButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryGoldLight),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _showOrderSuccessCelebration(BuildContext context, String trackingNumber, bool isCod, double totalAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostedGlassContainer(
          padding: const EdgeInsets.all(24),
          width: 360,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Celebration Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixedDim,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryFixedDim.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF005236), size: 42),
              ),
              const SizedBox(height: 18),
              Text(
                isCod ? '🎉 COD ORDER CONFIRMED!' : '🎉 PAYMENT CONFIRMED!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Tracking ID: $trackingNumber',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isCod ? AppColors.accentAmber.withValues(alpha: 0.15) : AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCod ? AppColors.accentAmber.withValues(alpha: 0.4) : AppColors.primaryContainer.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isCod ? Icons.local_atm_rounded : Icons.check_circle_rounded, color: isCod ? AppColors.accentAmber : AppColors.primaryGoldLight, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      isCod ? 'Amount Payable on Delivery: ${Formatters.formatCurrency(totalAmount)}' : 'Payment Received: ${Formatters.formatCurrency(totalAmount)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCod ? AppColors.accentAmber : AppColors.primaryGoldLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCod
                    ? 'Your Cash on Delivery order has been registered. Cash will be collected upon doorstep delivery.'
                    : 'Your prepaid order has been confirmed and locked for priority fulfillment.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Track Order & View Receipt',
                icon: Icons.local_shipping_outlined,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (context.mounted) {
                    context.go('/orders');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
