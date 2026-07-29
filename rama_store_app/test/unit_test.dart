import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rama_store_app/core/storage/local_storage_service.dart';
import 'package:rama_store_app/features/catalog/data/catalog_models.dart';
import 'package:rama_store_app/features/cart/data/cart_repository.dart';
import 'package:rama_store_app/features/cart/presentation/cart_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartNotifier Unit Tests', () {
    late LocalStorageService storage;
    late CartRepository cartRepo;
    late CartNotifier cartNotifier;
    late Product sampleProduct;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      cartRepo = CartRepository(storage);
      cartNotifier = CartNotifier(cartRepo);
      sampleProduct = Product(
        id: 1,
        sku: 'BK-001',
        name: 'The Art of Clean Code',
        sellingPrice: 500.0,
        stock: 10,
        status: 'published',
      );
    });

    test('Initial cart state should be empty', () {
      expect(cartNotifier.state.items.isEmpty, true);
      expect(cartNotifier.state.subtotal, 0.0);
    });

    test('Adding product should update total item count and subtotal', () async {
      await cartNotifier.addItem(sampleProduct, quantity: 2);
      expect(cartNotifier.state.totalItemCount, 2);
      expect(cartNotifier.state.subtotal, 1000.0);
    });

    test('Free delivery threshold calculation (₹500)', () async {
      await cartNotifier.addItem(sampleProduct, quantity: 1); // ₹500
      expect(cartNotifier.state.qualifiesForFreeDelivery, true);
      expect(cartNotifier.state.deliveryFee, 0.0);
    });

    test('Loyalty discount toggle applies discount capped at subtotal', () async {
      await cartNotifier.addItem(sampleProduct, quantity: 1); // ₹500
      cartNotifier.toggleLoyaltyDiscount(150.0); // 150 points
      expect(cartNotifier.state.appliedLoyalty, true);
      expect(cartNotifier.state.loyaltyDiscount, 150.0);
    });

    test('Clearing cart resets state', () async {
      await cartNotifier.addItem(sampleProduct, quantity: 2);
      await cartNotifier.clearCart();
      expect(cartNotifier.state.items.isEmpty, true);
      expect(cartNotifier.state.subtotal, 0.0);
    });
  });
}
