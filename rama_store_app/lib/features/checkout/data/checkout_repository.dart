import '../../../core/network/api_client.dart';
import '../../cart/data/cart_model.dart';

abstract class CheckoutRepository {
  Future<Map<String, dynamic>> createCheckoutSession(List<CartItem> cart, String shippingAddress);
  Future<Map<String, dynamic>> processPayment(String trackingNumber, String cardNumber, String cvv, String expiry);
}

class ApiCheckoutRepository implements CheckoutRepository {
  final ApiClient apiClient;
  final bool useMocks;

  ApiCheckoutRepository({
    required this.apiClient,
    this.useMocks = const bool.fromEnvironment('USE_MOCKS', defaultValue: false),
  });

  @override
  Future<Map<String, dynamic>> createCheckoutSession(List<CartItem> cart, String shippingAddress) async {
    if (useMocks) {
      return {
        'message': 'Pending order session created.',
        'session': {
          'tracking_number': 'RAMA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'total': cart.fold(0.0, (s, i) => s + i.lineTotal) * 1.18,
          'cart': cart.map((i) => i.toJson()).toList(),
        }
      };
    }

    final cartPayload = cart.map((item) => {'id': item.product.id, 'qty': item.quantity}).toList();
    return await apiClient.post('/api/checkout', data: {
      'cart': cartPayload,
      'shipping_address': shippingAddress,
    });
  }

  @override
  Future<Map<String, dynamic>> processPayment(String trackingNumber, String cardNumber, String cvv, String expiry) async {
    if (useMocks) {
      if (cardNumber.endsWith('4000')) {
        throw Exception('Card Declined: Insufficient credit limit. Stock reservation rolled back.');
      }
      return {'message': 'Payment success confirmed.', 'status': 'Paid'};
    }

    return await apiClient.post('/api/payment/process', data: {
      'tracking_number': trackingNumber,
      'card_number': cardNumber,
      'cvv': cvv,
      'expiry': expiry,
    });
  }
}
