import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';

class WishlistNotifier extends StateNotifier<List<int>> {
  final LocalStorageService storage;
  static const _keyWishlist = 'wishlist_product_ids';

  WishlistNotifier(this.storage) : super([]) {
    _loadWishlist();
  }

  void _loadWishlist() {
    final idsStr = storage.getStringList(_keyWishlist) ?? [];
    state = idsStr.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0).toList();
  }

  Future<void> toggleFavorite(int productId) async {
    if (state.contains(productId)) {
      state = state.where((id) => id != productId).toList();
    } else {
      state = [...state, productId];
    }
    await storage.setStringList(_keyWishlist, state.map((e) => e.toString()).toList());
  }

  bool isFavorite(int productId) {
    return state.contains(productId);
  }
}
