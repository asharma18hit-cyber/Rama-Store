import '../../../core/network/api_client.dart';
import 'order_model.dart';

abstract class OrdersRepository {
  Future<List<OrderModel>> getOrderHistory();
}

class ApiOrdersRepository implements OrdersRepository {
  final ApiClient apiClient;
  final bool useMocks;

  ApiOrdersRepository({
    required this.apiClient,
    this.useMocks = const bool.fromEnvironment('USE_MOCKS', defaultValue: false),
  });

  @override
  Future<List<OrderModel>> getOrderHistory() async {
    if (useMocks) {
      return [
        OrderModel(
          id: 1,
          trackingNumber: 'RAMA-99210A',
          totalAmount: 1178.82,
          taxAmount: 179.82,
          shippingAddress: '123 Main St, Sector 5',
          status: 'Delivered',
          createdAt: '2026-07-20 14:30:00',
          items: [
            OrderItem(productId: 101, name: 'The Art of Clean Code', quantity: 2, priceAtPurchase: 499.0),
          ],
        ),
      ];
    }

    try {
      final res = await apiClient.get('/api/orders/history');
      return (res as List).map((i) => OrderModel.fromJson(i)).toList();
    } catch (_) {
      return [];
    }
  }
}
