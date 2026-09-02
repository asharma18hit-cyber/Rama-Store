import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import 'order_model.dart';

abstract class OrdersRepository {
  Future<List<OrderModel>> getOrderHistory();
  Future<void> saveLocalOrder(OrderModel order);
  Future<void> cancelOrder(String trackingNumber, String reason, {String? reasonDetail});
  Future<void> payOrderNow(String trackingNumber, String method, {String? cardNumber, String? upiId});
  Future<void> adminCollectCodPayment(String trackingNumber);
}

class ApiOrdersRepository implements OrdersRepository {
  final ApiClient apiClient;
  final LocalStorageService storage;
  final bool useMocks;

  ApiOrdersRepository({
    required this.apiClient,
    required this.storage,
    this.useMocks = const bool.fromEnvironment('USE_MOCKS', defaultValue: false),
  });

  @override
  Future<void> saveLocalOrder(OrderModel order) async {
    // Only save valid non-empty orders
    if (order.items.isEmpty || order.totalAmount <= 0) return;

    final existingOrders = await _getLocalOrders();
    existingOrders.removeWhere((o) => o.trackingNumber == order.trackingNumber);
    existingOrders.insert(0, order);
    final jsonList = existingOrders.map((o) => o.toJson()).toList();
    await storage.setString(AppConstants.keyCachedOrders, jsonEncode(jsonList));
  }

  @override
  Future<void> cancelOrder(String trackingNumber, String reason, {String? reasonDetail}) async {
    final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    // 1. Send cancellation request to backend API if available
    try {
      await apiClient.post('/api/orders/$trackingNumber/cancel', data: {
        'reason': reason,
        'reason_detail': reasonDetail,
      });
    } catch (_) {}

    // 2. Update local order status to Cancelled
    final existingOrders = await _getLocalOrders();
    final index = existingOrders.indexWhere((o) => o.trackingNumber == trackingNumber);
    if (index != -1) {
      final old = existingOrders[index];
      // For COD unpaid, payment status becomes Unpaid and refund is None
      // For Prepaid paid, refund is Refund Pending
      final newPaymentStatus = old.isPaid ? 'Paid' : 'Unpaid';
      final newRefundStatus = old.isPaid ? 'Refund Pending' : null;
      existingOrders[index] = old.copyWith(
        orderStatus: 'Cancelled',
        paymentStatus: newPaymentStatus,
        cancellationReason: reason,
        cancellationReasonDetail: reasonDetail,
        cancelledAt: now,
        refundStatus: newRefundStatus,
      );
      final jsonList = existingOrders.map((o) => o.toJson()).toList();
      await storage.setString(AppConstants.keyCachedOrders, jsonEncode(jsonList));
    }
  }

  @override
  Future<void> payOrderNow(String trackingNumber, String method, {String? cardNumber, String? upiId}) async {
    final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    try {
      await apiClient.post('/api/orders/$trackingNumber/pay-now', data: {
        'payment_method': method,
        'card_number': cardNumber,
        'upi_id': upiId,
      });
    } catch (_) {}

    final existingOrders = await _getLocalOrders();
    final index = existingOrders.indexWhere((o) => o.trackingNumber == trackingNumber);
    if (index != -1) {
      final old = existingOrders[index];
      existingOrders[index] = old.copyWith(
        paymentStatus: 'Paid',
        paymentMethod: method,
        paidAt: now,
      );
      final jsonList = existingOrders.map((o) => o.toJson()).toList();
      await storage.setString(AppConstants.keyCachedOrders, jsonEncode(jsonList));
    }
  }

  @override
  Future<void> adminCollectCodPayment(String trackingNumber) async {
    final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    try {
      await apiClient.post('/api/orders/$trackingNumber/collect-cod');
    } catch (_) {}

    final existingOrders = await _getLocalOrders();
    final index = existingOrders.indexWhere((o) => o.trackingNumber == trackingNumber);
    if (index != -1) {
      final old = existingOrders[index];
      existingOrders[index] = old.copyWith(
        paymentStatus: 'Paid',
        paidAt: now,
      );
      final jsonList = existingOrders.map((o) => o.toJson()).toList();
      await storage.setString(AppConstants.keyCachedOrders, jsonEncode(jsonList));
    }
  }

  Future<List<OrderModel>> _getLocalOrders() async {
    try {
      final raw = storage.getString(AppConstants.keyCachedOrders);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .map((i) => OrderModel.fromJson(i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i)))
            .where((o) => o.items.isNotEmpty && o.totalAmount > 0)
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

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
          orderStatus: 'Delivered',
          paymentStatus: 'Paid',
          paymentMethod: 'Card',
          createdAt: '2026-07-20 14:30:00',
          items: [
            OrderItem(productId: 101, name: 'The Art of Clean Code', quantity: 2, priceAtPurchase: 499.0),
          ],
        ),
      ];
    }

    final localOrders = await _getLocalOrders();

    try {
      final res = await apiClient.get('/api/orders/history');
      if (res is List) {
        final remoteOrders = res
            .map((i) => OrderModel.fromJson(i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i)))
            .where((o) => o.items.isNotEmpty && o.totalAmount > 0)
            .toList();
        final Map<String, OrderModel> merged = {};
        for (var o in localOrders) {
          merged[o.trackingNumber] = o;
        }
        for (var o in remoteOrders) {
          merged[o.trackingNumber] = o;
        }
        return merged.values.toList();
      }
    } catch (_) {}

    return localOrders;
  }
}
