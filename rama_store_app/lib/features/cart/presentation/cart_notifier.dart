import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../catalog/data/catalog_models.dart';
import '../../admin/data/store_config_model.dart';
import '../data/cart_model.dart';
import '../data/cart_repository.dart';

class CartState {
  final List<CartItem> items;
  final double loyaltyDiscount;
  final double promoDiscount;
  final bool appliedLoyalty;
  final String? appliedCouponCode;
  final double freeDeliveryThreshold;
  final double standardDeliveryFee;

  CartState({
    this.items = const [],
    this.loyaltyDiscount = 0.0,
    this.promoDiscount = 0.0,
    this.appliedLoyalty = false,
    this.appliedCouponCode,
    this.freeDeliveryThreshold = AppConstants.freeDeliveryThreshold,
    this.standardDeliveryFee = AppConstants.flatDeliveryFee,
  });

  double get totalDiscount => loyaltyDiscount + promoDiscount;
  double get discountAmount => totalDiscount;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  bool get qualifiesForFreeDelivery => subtotal >= freeDeliveryThreshold;

  double get deliveryProgress => freeDeliveryThreshold > 0
      ? (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0)
      : 1.0;

  double get deliveryFee => (subtotal == 0 || qualifiesForFreeDelivery) ? 0.0 : standardDeliveryFee;

  double get taxAmount => (subtotal - totalDiscount).clamp(0.0, double.infinity) * 0.18; // 18% GST

  double get grandTotal => (subtotal + deliveryFee + taxAmount - totalDiscount).clamp(0.0, double.infinity);

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    double? loyaltyDiscount,
    double? promoDiscount,
    bool? appliedLoyalty,
    String? appliedCouponCode,
    bool clearCoupon = false,
    double? freeDeliveryThreshold,
    double? standardDeliveryFee,
  }) {
    return CartState(
      items: items ?? this.items,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
      promoDiscount: promoDiscount ?? this.promoDiscount,
      appliedLoyalty: appliedLoyalty ?? this.appliedLoyalty,
      appliedCouponCode: clearCoupon ? null : (appliedCouponCode ?? this.appliedCouponCode),
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      standardDeliveryFee: standardDeliveryFee ?? this.standardDeliveryFee,
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

  void updateDeliveryConfig({required double threshold, required double fee}) {
    state = state.copyWith(
      freeDeliveryThreshold: threshold,
      standardDeliveryFee: fee,
    );
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

  void toggleLoyaltyDiscount(double pointsBalance) {
    if (state.appliedLoyalty) {
      state = state.copyWith(appliedLoyalty: false, loyaltyDiscount: 0.0);
    } else {
      final discount = pointsBalance.clamp(0.0, state.subtotal);
      state = state.copyWith(appliedLoyalty: true, loyaltyDiscount: discount);
    }
  }

  bool applyCoupon(StoreCoupon coupon) {
    if (!coupon.isActive) return false;
    if (state.subtotal < coupon.minOrderAmount) return false;

    final discount = coupon.calculateDiscount(state.subtotal);
    state = state.copyWith(
      appliedCouponCode: coupon.code,
      promoDiscount: discount,
    );
    return true;
  }

  void applyDiscount(double amount) {
    state = state.copyWith(promoDiscount: amount.clamp(0.0, state.subtotal));
  }

  void removeCoupon() {
    state = state.copyWith(
      clearCoupon: true,
      promoDiscount: 0.0,
    );
  }

  Future<void> clearCart() async {
    state = state.copyWith(
      items: [],
      loyaltyDiscount: 0.0,
      promoDiscount: 0.0,
      appliedLoyalty: false,
      clearCoupon: true,
    );
    await repository.clearCart();
  }
}
