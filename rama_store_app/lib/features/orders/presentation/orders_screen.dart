import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
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
    final statusColor = order.status == 'Delivered'
        ? AppColors.success
        : (order.status == 'Paid' || order.status == 'Shipped' ? AppColors.info : AppColors.warning);

    int currentStep = 1;
    if (order.status == 'Paid' || order.status == 'Processing') currentStep = 2;
    if (order.status == 'Shipped' || order.status == 'In Transit') currentStep = 3;
    if (order.status == 'Delivered') currentStep = 4;

    return HoverCard(
      child: FrostedGlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(Formatters.formatDate(order.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 16),

            // Live Delivery Stepper Indicator
            _buildLiveDeliveryStepper(currentStep),

            const Divider(color: AppColors.surfaceLight, height: 24),

            // Items Summary
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${Formatters.formatCurrency(order.totalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim)),
                AppButton(
                  text: 'Reorder',
                  width: 100,
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
