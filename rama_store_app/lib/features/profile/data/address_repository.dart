import 'dart:convert';
import '../../../core/storage/local_storage_service.dart';
import 'address_model.dart';

class AddressRepository {
  final LocalStorageService storage;
  static const _keyAddresses = 'user_saved_delivery_addresses';

  AddressRepository(this.storage);

  List<DeliveryAddress> loadAddresses() {
    final raw = storage.getString(_keyAddresses);
    if (raw == null || raw.isEmpty) {
      return [
        DeliveryAddress(
          id: '1',
          label: 'Home',
          fullAddress: '123 Main Street, Sector 5',
          city: 'City Center',
          postalCode: '110001',
          isDefault: true,
        ),
      ];
    }
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => DeliveryAddress.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAddresses(List<DeliveryAddress> addresses) async {
    final encoded = jsonEncode(addresses.map((e) => e.toJson()).toList());
    await storage.setString(_keyAddresses, encoded);
  }
}
