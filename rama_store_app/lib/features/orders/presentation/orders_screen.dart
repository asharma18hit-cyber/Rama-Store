import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../main.dart';
import '../data/order_model.dart';

final ordersFutureProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.watch(ordersRepositoryProvider);
  return await repo.getOrderHistory();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({Key? key}) : super(key: key);

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tracking: ${order.trackingNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(Formatters.formatDate(order.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const Divider(color: AppColors.surfaceLight, height: 20),

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
              Text('Total: ${Formatters.formatCurrency(order.totalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight)),
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
    );
  }
}
