import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../orders/data/order_model.dart';

class LoyaltyRepository {
  final LocalStorageService storage;

  LoyaltyRepository(this.storage);

  double calculatePointsFromOrders(List<OrderModel> orders) {
    double totalEarned = 0.0;
    for (final order in orders) {
      if (order.status == 'Paid' || order.status == 'Shipped' || order.status == 'Delivered') {
        totalEarned += order.totalAmount * AppConstants.loyaltyCashbackRate;
      }
    }
    // Save locally
    storage.setDouble(AppConstants.keyLoyaltyBalance, totalEarned);
    return totalEarned;
  }

  double getStoredPoints() {
    return storage.getDouble(AppConstants.keyLoyaltyBalance) ?? 150.0; // Default 150 points for new users
  }
}
