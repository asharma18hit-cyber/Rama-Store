import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../main.dart';
import '../data/order_model.dart';

final ordersFutureProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.watch(ordersRepositoryProvider);
  return await repo.getOrderHistory();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders & History'),
      ),
      body: ordersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: ProductCardShimmer(),
        ),
        error: (err, stack) => Center(
          child: Text('Error loading orders: $err', style: const TextStyle(color: AppColors.error)),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history_outlined, size: 80, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No past orders found', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(ordersFutureProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderCard(context, order, ref);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order, WidgetRef ref) {
    final isCancelled = order.isCancelled;
    final isCod = order.isCod;
    final isPaid = order.isPaid;

    Color orderStatusColor;
    if (isCancelled) {
      orderStatusColor = AppColors.error;
    } else if (order.orderStatus == 'Delivered') {
      orderStatusColor = AppColors.success;
    } else if (order.orderStatus == 'Dispatched' || order.orderStatus == 'Shipped') {
      orderStatusColor = AppColors.info;
    } else {
      orderStatusColor = AppColors.secondaryFixedDim;
    }

    Color paymentStatusColor;
    String paymentBadgeText;
    if (isCancelled) {
      paymentStatusColor = AppColors.textMuted;
      paymentBadgeText = isPaid ? 'Refund Pending' : 'Not Paid';
    } else if (isPaid) {
      paymentStatusColor = AppColors.success;
      paymentBadgeText = 'Paid';
    } else {
      paymentStatusColor = AppColors.accentAmber;
      paymentBadgeText = 'Payment Pending';
    }

    int currentStep = 1;
    if (order.orderStatus == 'Packed' || order.orderStatus == 'Processing') currentStep = 2;
    if (order.orderStatus == 'Dispatched' || order.orderStatus == 'Shipped' || order.orderStatus == 'In Transit') currentStep = 3;
    if (order.orderStatus == 'Delivered') currentStep = 4;

    return HoverCard(
      child: FrostedGlassContainer(
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Tracking & Status Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_rounded, size: 18, color: AppColors.secondaryFixedDim),
                    const SizedBox(width: 6),
                    Text(
                      'Tracking: ${order.trackingNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    // Order Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: orderStatusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: orderStatusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        order.orderStatus,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: orderStatusColor),
                      ),
                    ),
                    // Payment Method Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.paymentMethod,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(Formatters.formatDate(order.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 16),

            // Stepper / Cancelled Banner
            if (isCancelled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Order Cancelled',
                          style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (order.cancellationReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reason: ${order.cancellationReason}${order.cancellationReasonDetail != null && order.cancellationReasonDetail!.isNotEmpty ? ' (${order.cancellationReasonDetail})' : ''}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (order.cancelledAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Cancelled On: ${Formatters.formatDate(order.cancelledAt!)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      isPaid
                          ? 'Refund Status: Refund Pending (${Formatters.formatCurrency(order.totalAmount)})'
                          : 'Payment Status: Not Paid (₹0.00 Collected)',
                      style: TextStyle(color: isPaid ? AppColors.accentAmber : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              _buildLiveDeliveryStepper(currentStep),

            const Divider(color: AppColors.surfaceLight, height: 24),

            // Items Summary
            const Text('ORDER ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x  ${item.name}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(Formatters.formatCurrency(item.priceAtPurchase * item.quantity), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    ],
                  ),
                )),

            const Divider(color: AppColors.surfaceLight, height: 20),

            // Dedicated Payment Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PAYMENT INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textMuted)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: paymentStatusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: paymentStatusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          paymentBadgeText,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: paymentStatusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(isCod ? 'Cash on Delivery (COD)' : order.paymentMethod, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(Formatters.formatCurrency(order.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount Due:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        Formatters.formatCurrency(order.amountDue),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: order.amountDue > 0 ? AppColors.accentAmber : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (order.canPayNow) ...[
                    const SizedBox(height: 12),
                    AppButton(
                      text: 'Pay Now Online (${Formatters.formatCurrency(order.totalAmount)})',
                      icon: Icons.qr_code_2_rounded,
                      height: 38,
                      onPressed: () => _openPayNowModal(context, order, ref),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Actions: Cancel / Reorder
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (order.isCancellable) ...[
                  AppButton(
                    text: 'Cancel Order',
                    width: 120,
                    height: 36,
                    isOutlined: true,
                    onPressed: () => _openCancelOrderReasonDialog(context, order, ref),
                  ),
                  const SizedBox(width: 8),
                ],
                AppButton(
                  text: 'Reorder',
                  width: 90,
                  height: 36,
                  isOutlined: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Items from order #${order.trackingNumber} reordered!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPayNowModal(BuildContext context, OrderModel order, WidgetRef ref) {
    const merchantVpa = 'ramastore.official@icici';
    const merchantName = 'Rama Store Inc';
    final amountStr = order.totalAmount.toStringAsFixed(2);
    final upiPayload = 'upi://pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20${order.trackingNumber}&tr=${order.trackingNumber}';
    final qrCodeUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiPayload)}';

    String selectedMethod = 'upi';
    final cardController = TextEditingController(text: '4532 1111 2222 3333');
    final cvvController = TextEditingController(text: '123');
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.payment_rounded, color: AppColors.primaryGoldLight, size: 22),
                const SizedBox(width: 8),
                Text('Pay for Order #${order.trackingNumber}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total Amount Due: ${Formatters.formatCurrency(order.totalAmount)}',
                        style: const TextStyle(color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Scan & Pay UPI')),
                            selected: selectedMethod == 'upi',
                            onSelected: (val) => setModalState(() => selectedMethod = 'upi'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Debit/Credit Card')),
                            selected: selectedMethod == 'card',
                            onSelected: (val) => setModalState(() => selectedMethod = 'card'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedMethod == 'upi') ...[
                      // Dynamic Live Scannable UPI QR Code
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: qrCodeUrl,
                            width: 170,
                            height: 170,
                            placeholder: (c, u) => const SizedBox(
                              width: 170,
                              height: 170,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (c, u, e) => const Icon(Icons.qr_code_2, size: 90, color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Scan with Google Pay, PhonePe, Paytm, BHIM or any UPI App',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildUpiIntentChip('PhonePe', () async {
                            final uri = Uri.parse('phonepe://upi/pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20${order.trackingNumber}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              await launchUrl(Uri.parse(upiPayload), mode: LaunchMode.externalApplication);
                            }
                          }),
                          _buildUpiIntentChip('GPay', () async {
                            final uri = Uri.parse('gpay://upi/pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20${order.trackingNumber}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              await launchUrl(Uri.parse(upiPayload), mode: LaunchMode.externalApplication);
                            }
                          }),
                          _buildUpiIntentChip('Paytm', () async {
                            final uri = Uri.parse('paytmmp://upi/pay?pa=$merchantVpa&pn=${Uri.encodeComponent(merchantName)}&am=$amountStr&cu=INR&tn=Order%20${order.trackingNumber}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              await launchUrl(Uri.parse(upiPayload), mode: LaunchMode.externalApplication);
                            }
                          }),
                        ],
                      ),
                    ] else ...[
                      AppTextField(
                        controller: cardController,
                        label: 'Card Number',
                        hint: '4532 1111 2222 3333',
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: cvvController,
                        label: 'CVV',
                        hint: '123',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setModalState(() => isProcessing = true);
                        await ref.read(ordersRepositoryProvider).payOrderNow(
                              order.trackingNumber,
                              selectedMethod == 'card' ? 'Card' : 'UPI',
                              cardNumber: cardController.text,
                            );
                        ref.refresh(ordersFutureProvider);
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment confirmed for order #${order.trackingNumber}!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                child: isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(selectedMethod == 'upi' ? 'I Have Completed Payment' : 'Pay ${Formatters.formatCurrency(order.totalAmount)}'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUpiIntentChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight)),
      ),
    );
  }

  void _openCancelOrderReasonDialog(BuildContext context, OrderModel order, WidgetRef ref) {
    final reasons = [
      'I ordered by mistake',
      'I found a better price elsewhere',
      'I no longer need the product',
      'Delivery is taking too long',
      'I want to change the delivery address',
      'I want to change the payment method',
      'I ordered the wrong product/quantity',
      'Other',
    ];

    String? selectedReason;
    final otherReasonController = TextEditingController();
    bool isProcessing = false;
    String? validationError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final isOther = selectedReason == 'Other';

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Cancel Order', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Please select a reason for cancelling this order:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 12),
                    ...reasons.map((r) => RadioListTile<String>(
                          value: r,
                          groupValue: selectedReason,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primaryGold,
                          title: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                          onChanged: isProcessing
                              ? null
                              : (val) {
                                  setModalState(() {
                                    selectedReason = val;
                                    validationError = null;
                                  });
                                },
                        )),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: otherReasonController,
                        label: 'Please tell us why you want to cancel (Required)',
                        hint: 'Enter your reason here...',
                        maxLines: 2,
                      ),
                    ],
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(validationError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                    const Divider(color: AppColors.surfaceLight, height: 24),
                    // Summary before final confirmation
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order: #${order.trackingNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('Amount: ${Formatters.formatCurrency(order.totalAmount)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            order.isPaid
                                ? 'Refund will be initiated to your payment source.'
                                : 'Cash on Delivery — No payment has been collected.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: order.isPaid ? AppColors.accentAmber : AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
                child: const Text('Keep Order', style: TextStyle(color: AppColors.textPrimary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (selectedReason == null) {
                          setModalState(() => validationError = 'Please select a cancellation reason.');
                          return;
                        }
                        if (selectedReason == 'Other' && otherReasonController.text.trim().isEmpty) {
                          setModalState(() => validationError = 'Please provide a custom cancellation reason.');
                          return;
                        }

                        setModalState(() => isProcessing = true);
                        final reasonDetail = isOther ? otherReasonController.text.trim() : null;

                        await ref.read(ordersRepositoryProvider).cancelOrder(
                              order.trackingNumber,
                              selectedReason!,
                              reasonDetail: reasonDetail,
                            );

                        ref.refresh(ordersFutureProvider);
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(order.isPaid
                                  ? 'Order #${order.trackingNumber} cancelled. Refund will be processed.'
                                  : 'Order #${order.trackingNumber} cancelled. No payment was collected.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                child: isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Cancellation'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveDeliveryStepper(int currentStep) {
    final steps = [
      {'label': 'Confirmed', 'icon': Icons.check_circle_outline},
      {'label': 'Packed', 'icon': Icons.inventory_2_outlined},
      {'label': 'Dispatched', 'icon': Icons.local_shipping_outlined},
      {'label': 'Delivered', 'icon': Icons.home_outlined},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentStep - 1;
          return Expanded(
            child: Container(
              height: 2,
              color: isCompleted ? AppColors.secondaryFixedDim : AppColors.surfaceLight,
            ),
          );
        } else {
          final stepIndex = index ~/ 2;
          final isPassed = stepIndex < currentStep;
          final isCurrent = stepIndex == currentStep - 1;
          final step = steps[stepIndex];

          return Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPassed ? AppColors.secondaryFixedDim : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPassed ? AppColors.secondaryFixedDim : AppColors.surfaceLight,
                    width: 1.5,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.secondaryFixedDim.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  step['icon'] as IconData,
                  size: 16,
                  color: isPassed ? const Color(0xFF005236) : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isPassed ? FontWeight.bold : FontWeight.normal,
                  color: isPassed ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}
