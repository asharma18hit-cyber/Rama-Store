import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/store_config_model.dart';

class StoreConfigNotifier extends StateNotifier<StoreConfig> {
  StoreConfigNotifier() : super(const StoreConfig());

  void updateDeliverySettings({required double freeThreshold, required double standardFee}) {
    state = state.copyWith(
      freeDeliveryThreshold: freeThreshold,
      standardDeliveryFee: standardFee,
    );
  }

  void updateAnnouncement(String newText, {double flashSalePercent = 0.0}) {
    state = state.copyWith(
      announcementText: newText,
      flashSaleDiscountPercent: flashSalePercent,
    );
  }

  void addCoupon(StoreCoupon coupon) {
    final updated = List<StoreCoupon>.from(state.coupons)
      ..removeWhere((c) => c.code.toUpperCase() == coupon.code.toUpperCase())
      ..add(coupon);
    state = state.copyWith(coupons: updated);
  }

  void removeCoupon(String code) {
    final updated = state.coupons.where((c) => c.code.toUpperCase() != code.toUpperCase()).toList();
    state = state.copyWith(coupons: updated);
  }

  void toggleCouponStatus(String code) {
    final updated = state.coupons.map((c) {
      if (c.code.toUpperCase() == code.toUpperCase()) {
        return c.copyWith(isActive: !c.isActive);
      }
      return c;
    }).toList();
    state = state.copyWith(coupons: updated);
  }
}

final storeConfigProvider = StateNotifierProvider<StoreConfigNotifier, StoreConfig>((ref) {
  return StoreConfigNotifier();
});
