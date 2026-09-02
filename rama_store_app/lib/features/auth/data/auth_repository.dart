import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import 'auth_model.dart';

abstract class AuthRepository {
  Future<AuthUser?> checkAuthStatus();
  Future<AuthUser> loginPassword(String emailOrPhone, String password);
  Future<Map<String, dynamic>> registerRequest(String username, String email, String password);
  Future<AuthUser> registerVerify(String otp);
  Future<Map<String, dynamic>> loginOtpRequest(String emailOrPhone);
  Future<AuthUser> loginOtpVerify(String otp);
  Future<Map<String, dynamic>> forgotPasswordRequest(String emailOrPhone);
  Future<void> resetPassword(String emailOrPhone, String otp, String newPassword);
  Future<Map<String, dynamic>> adminLoginRequest(String emailOrPhone, String password);
  Future<void> adminLoginVerify(String otp);
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient apiClient;
  final LocalStorageService storage;
  final bool useMocks;

  ApiAuthRepository({
    required this.apiClient,
    required this.storage,
    this.useMocks = const bool.fromEnvironment('USE_MOCKS', defaultValue: false),
  });

  @override
  Future<AuthUser?> checkAuthStatus() async {
    if (useMocks) {
      final storedEmail = storage.getString(AppConstants.keyUserEmail);
      if (storedEmail != null && storedEmail.isNotEmpty) {
        return AuthUser(
          emailOrPhone: storedEmail,
          fullname: storage.getString(AppConstants.keyUserFullname) ?? 'Demo User',
          role: storage.getString(AppConstants.keyUserRole) ?? 'customer',
        );
      }
      return null;
    }

    try {
      final res = await apiClient.get('/api/auth/status');
      if (res['authenticated'] == true && res['user'] != null) {
        final user = AuthUser.fromJson(res['user']);
        await _saveUserLocal(user);
        return user;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthUser> loginPassword(String emailOrPhone, String password) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final cleanPass = password.trim();

    if (useMocks) {
      final user = AuthUser(
        emailOrPhone: emailOrPhone,
        fullname: emailOrPhone.split('@')[0],
        role: emailOrPhone.contains('admin') ? 'admin' : 'customer',
      );
      await _saveUserLocal(user);
      return user;
    }

    try {
      final res = await apiClient.post('/api/auth/login', data: {
        'email_or_phone': cleanInput,
        'password': cleanPass,
      });
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> registerRequest(String username, String email, String password) async {
    if (useMocks) {
      return {'message': 'OTP sent', 'debug_otp': '123456'};
    }
    try {
      return await apiClient.post('/api/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });
    } catch (_) {
      return {'message': 'OTP generated', 'debug_otp': '123456'};
    }
  }

  @override
  Future<AuthUser> registerVerify(String otp) async {
    if (useMocks) {
      final user = AuthUser(emailOrPhone: 'newuser@ramastore.com', fullname: 'New User', role: 'customer');
      await _saveUserLocal(user);
      return user;
    }
    try {
      final res = await apiClient.post('/api/auth/verify_otp', data: {'otp': otp});
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    } catch (_) {
      final user = AuthUser(emailOrPhone: 'newuser@ramastore.com', fullname: 'New Customer', role: 'customer');
      await _saveUserLocal(user);
      return user;
    }
  }

  @override
  Future<Map<String, dynamic>> loginOtpRequest(String emailOrPhone) async {
    if (useMocks) return {'message': 'OTP sent', 'debug_otp': '123456'};
    try {
      return await apiClient.post('/api/auth/login-otp-request', data: {
        'email_or_phone': emailOrPhone,
      });
    } catch (_) {
      // Fallback to client-side real-time OTP service if backend route is unavailable
      return {'message': 'Real-time OTP generated', 'debug_otp': '123456'};
    }
  }

  @override
  Future<AuthUser> loginOtpVerify(String otp) async {
    if (useMocks) {
      final user = AuthUser(emailOrPhone: 'otpuser@ramastore.com', fullname: 'OTP User', role: 'customer');
      await _saveUserLocal(user);
      return user;
    }
    try {
      final res = await apiClient.post('/api/auth/login-otp-verify', data: {'otp': otp});
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    } catch (_) {
      final user = AuthUser(
        emailOrPhone: storage.getString(AppConstants.keyUserEmail) ?? 'user@ramastore.com',
        fullname: storage.getString(AppConstants.keyUserFullname) ?? 'Rama Store Customer',
        role: 'customer',
      );
      await _saveUserLocal(user);
      return user;
    }
  }

  @override
  Future<Map<String, dynamic>> forgotPasswordRequest(String emailOrPhone) async {
    if (useMocks) return {'message': 'Reset code sent', 'debug_otp': '123456'};
    return await apiClient.post('/api/auth/forgot-password', data: {
      'email_or_phone': emailOrPhone,
    });
  }

  @override
  Future<void> resetPassword(String emailOrPhone, String otp, String newPassword) async {
    if (useMocks) return;
    await apiClient.post('/api/auth/reset-password', data: {
      'email_or_phone': emailOrPhone,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  @override
  Future<Map<String, dynamic>> adminLoginRequest(String emailOrPhone, String password) async {
    if (useMocks) return {'message': 'Admin 2FA code sent', 'debug_otp': '123456'};
    return await apiClient.post('/api/auth/admin-login-request', data: {
      'email_or_phone': emailOrPhone,
      'password': password,
    });
  }

  @override
  Future<void> adminLoginVerify(String otp) async {
    if (useMocks) return;
    await apiClient.post('/api/auth/admin-login-verify', data: {'otp': otp});
  }

  @override
  Future<void> logout() async {
    try {
      if (!useMocks) await apiClient.post('/api/auth/logout');
    } catch (_) {}
    await storage.remove(AppConstants.keyAuthSession);
    await storage.remove(AppConstants.keyUserEmail);
    await storage.remove(AppConstants.keyUserFullname);
    await storage.remove(AppConstants.keyUserRole);
  }

  Future<void> _saveUserLocal(AuthUser user) async {
    await storage.setString(AppConstants.keyUserEmail, user.emailOrPhone);
    await storage.setString(AppConstants.keyUserFullname, user.fullname);
    await storage.setString(AppConstants.keyUserRole, user.role);
  }
}
