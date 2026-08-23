import 'package:flutter_test/flutter_test.dart';
import 'package:rama_store_app/features/auth/data/auth_model.dart';
import 'package:rama_store_app/features/auth/data/auth_repository.dart';
import 'package:rama_store_app/features/auth/presentation/auth_notifier.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> checkAuthStatus() async {
    return null;
  }

  @override
  Future<AuthUser> loginPassword(String emailOrPhone, String password) async {
    if (emailOrPhone == 'customer@ramastore.com' && password == 'Password123') {
      return AuthUser(emailOrPhone: emailOrPhone, fullname: 'Customer Name', role: 'customer');
    }
    throw Exception('Invalid credentials');
  }

  @override
  Future<Map<String, dynamic>> registerRequest(String username, String email, String password) async {
    return {'message': 'OTP Sent', 'otp_sent': true, 'debug_otp': '123456'};
  }

  @override
  Future<AuthUser> registerVerify(String otp) async {
    if (otp == '123456') {
      return AuthUser(emailOrPhone: 'newuser@example.com', fullname: 'New User', role: 'customer');
    }
    throw Exception('Invalid verification code');
  }

  @override
  Future<Map<String, dynamic>> loginOtpRequest(String emailOrPhone) async {
    return {'message': 'OTP sent'};
  }

  @override
  Future<AuthUser> loginOtpVerify(String otp) async {
    return AuthUser(emailOrPhone: 'otpuser@example.com', fullname: 'OTP User', role: 'customer');
  }

  @override
  Future<Map<String, dynamic>> forgotPasswordRequest(String emailOrPhone) async {
    return {'message': 'Reset code sent'};
  }

  @override
  Future<void> resetPassword(String emailOrPhone, String otp, String newPassword) async {}

  @override
  Future<Map<String, dynamic>> adminLoginRequest(String emailOrPhone, String password) async {
    return {'message': 'Admin 2FA sent'};
  }

  @override
  Future<void> adminLoginVerify(String otp) async {}

  @override
  Future<void> logout() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier Unit Tests', () {
    late AuthNotifier authNotifier;

    setUp(() {
      authNotifier = AuthNotifier(MockAuthRepository());
    });

    test('Initial AuthState should be unauthenticated', () {
      expect(authNotifier.state.isAuthenticated, false);
      expect(authNotifier.state.isLoading, false);
    });

    test('Valid password login updates state to authenticated', () async {
      final ok = await authNotifier.loginPassword('customer@ramastore.com', 'Password123');
      expect(ok, true);
      expect(authNotifier.state.isAuthenticated, true);
      expect(authNotifier.state.user?.fullname, 'Customer Name');
    });

    test('Invalid password login sets error message', () async {
      final ok = await authNotifier.loginPassword('wrong@user.com', 'wrongpass');
      expect(ok, false);
      expect(authNotifier.state.isAuthenticated, false);
      expect(authNotifier.state.errorMessage != null, true);
    });

    test('Registration request sets pending OTP state', () async {
      final ok = await authNotifier.registerRequest('johndoe', 'john@example.com', 'Password123');
      expect(ok, true);
      expect(authNotifier.state.pendingOtp, '123456');
    });

    test('Logout resets authenticated state', () async {
      await authNotifier.loginPassword('customer@ramastore.com', 'Password123');
      expect(authNotifier.state.isAuthenticated, true);
      await authNotifier.logout();
      expect(authNotifier.state.isAuthenticated, false);
    });
  });
}
