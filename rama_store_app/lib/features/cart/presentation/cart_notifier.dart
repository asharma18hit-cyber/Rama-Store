import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../catalog/data/catalog_models.dart';
import '../data/cart_model.dart';
import '../data/cart_repository.dart';

class CartState {
  final List<CartItem> items;
  final double loyaltyDiscount;
  final double promoDiscount;
  final bool appliedLoyalty;

  CartState({
    this.items = const [],
    this.loyaltyDiscount = 0.0,
    this.promoDiscount = 0.0,
    this.appliedLoyalty = false,
  });

  double get totalDiscount => loyaltyDiscount + promoDiscount;
  double get discountAmount => totalDiscount;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  bool get qualifiesForFreeDelivery => subtotal >= AppConstants.freeDeliveryThreshold;

  double get deliveryProgress => (subtotal / AppConstants.freeDeliveryThreshold).clamp(0.0, 1.0);

  double get deliveryFee => (subtotal == 0 || qualifiesForFreeDelivery) ? 0.0 : AppConstants.flatDeliveryFee;

  double get taxAmount => (subtotal - totalDiscount).clamp(0.0, double.infinity) * 0.18; // 18% GST

  double get grandTotal => (subtotal + deliveryFee + taxAmount - totalDiscount).clamp(0.0, double.infinity);

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    double? loyaltyDiscount,
    double? promoDiscount,
    bool? appliedLoyalty,
  }) {
    return CartState(
      items: items ?? this.items,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
      promoDiscount: promoDiscount ?? this.promoDiscount,
      appliedLoyalty: appliedLoyalty ?? this.appliedLoyalty,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final CartRepository repository;

  CartNotifier(this.repository) : super(CartState()) {
    _loadCart();
  }

  void _loadCart() {
    final loaded = repository.loadCart();
    state = state.copyWith(items: loaded);
  }

  Future<void> addItem(Product product, {int quantity = 1}) async {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);
    List<CartItem> updated = List.from(state.items);

    if (existingIndex >= 0) {
      final currentQty = updated[existingIndex].quantity;
      updated[existingIndex] = updated[existingIndex].copyWith(quantity: currentQty + quantity);
    } else {
      updated.add(CartItem(product: product, quantity: quantity));
    }

    state = state.copyWith(items: updated);
    await repository.saveCart(updated);
  }

  Future<void> updateQuantity(int productId, int delta) async {
    final existingIndex = state.items.indexWhere((item) => item.product.id == productId);
    if (existingIndex < 0) return;

    List<CartItem> updated = List.from(state.items);
    final newQty = updated[existingIndex].quantity + delta;

    if (newQty <= 0) {
      updated.removeAt(existingIndex);
    } else {
      updated[existingIndex] = updated[existingIndex].copyWith(quantity: newQty);
    }

    state = state.copyWith(items: updated);
    await repository.saveCart(updated);
  }

  Future<void> removeItem(int productId) async {
    List<CartItem> updated = state.items.where((item) => item.product.id != productId).toList();
    state = state.copyWith(items: updated);
    await repository.saveCart(updated);
  }

  void toggleLoyaltyDiscount(double availableLoyaltyPoints) {
    if (state.appliedLoyalty) {
      state = state.copyWith(appliedLoyalty: false, loyaltyDiscount: 0.0);
    } else {
      // 1 point = ₹1 discount, capped at subtotal
      final discount = availableLoyaltyPoints.clamp(0.0, state.subtotal);
      state = state.copyWith(appliedLoyalty: true, loyaltyDiscount: discount);
    }
  }

  void applyDiscount(double amount) {
    final discount = amount.clamp(0.0, state.subtotal);
    state = state.copyWith(promoDiscount: discount);
  }

  Future<void> clearCart() async {
    state = CartState();
    await repository.clearCart();
  }
}
