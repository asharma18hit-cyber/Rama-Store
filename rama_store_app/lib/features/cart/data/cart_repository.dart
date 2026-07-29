import 'dart:convert';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import 'cart_model.dart';

class CartRepository {
  final LocalStorageService storage;

  CartRepository(this.storage);

  List<CartItem> loadCart() {
    final raw = storage.getString(AppConstants.keyCartData);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((item) => CartItem.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCart(List<CartItem> cart) async {
    final encoded = jsonEncode(cart.map((item) => item.toJson()).toList());
    await storage.setString(AppConstants.keyCartData, encoded);
  }

  Future<void> clearCart() async {
    await storage.remove(AppConstants.keyCartData);
  }
}
