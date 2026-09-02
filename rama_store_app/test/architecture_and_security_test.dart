import 'package:flutter_test/flutter_test.dart';
import 'package:rama_store_app/core/network/api_exceptions.dart';
import 'package:rama_store_app/core/result/result.dart';
import 'package:rama_store_app/core/utils/formatters.dart';
import 'package:rama_store_app/features/auth/data/auth_model.dart';
import 'package:rama_store_app/features/profile/data/address_model.dart';

void main() {
  group('Architecture & Security Hardening Tests', () {
    test('Result.success holds data and isSuccess is true', () {
      final result = Result.success('Test payload');
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.dataOrNull, 'Test payload');
      expect(result.errorOrNull, isNull);
    });

    test('Result.failure holds ApiException and isFailure is true', () {
      final result = Result<String>.failure(AuthException('Unauthorized', statusCode: 401));
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull?.message, 'Unauthorized');
      expect(result.errorOrNull?.statusCode, 401);
    });

    test('Formatters formats INR currency correctly with ₹ prefix', () {
      expect(Formatters.formatCurrency(1299.0), '₹1,299.00');
      expect(Formatters.formatCurrency(0.0), '₹0.00');
      expect(Formatters.formatCurrency(500), '₹500.00');
    });

    test('AuthUser role evaluation distinguishing customer and admin', () {
      final customer = AuthUser(
        emailOrPhone: 'customer@ramastore.com',
        fullname: 'Rahul Customer',
        role: 'customer',
      );
      expect(customer.isAdmin, false);

      final admin = AuthUser(
        emailOrPhone: 'admin@ramastore.com',
        fullname: 'Store Admin',
        role: 'admin',
      );
      expect(admin.isAdmin, true);
    });

    test('DeliveryAddress model serialization and deserialization integrity', () {
      final json = {
        'id': 'addr-1',
        'label': 'Home',
        'fullAddress': '123 Main Street, Sector 5',
        'city': 'New Delhi',
        'postalCode': '110001',
        'isDefault': true,
      };

      final address = DeliveryAddress.fromJson(json);
      expect(address.id, 'addr-1');
      expect(address.label, 'Home');
      expect(address.fullAddress, '123 Main Street, Sector 5');
      expect(address.isDefault, true);

      final serialized = address.toJson();
      expect(serialized['label'], 'Home');
      expect(serialized['city'], 'New Delhi');
    });
  });
}
