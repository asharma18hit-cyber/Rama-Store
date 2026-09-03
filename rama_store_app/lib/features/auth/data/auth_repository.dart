import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/msg91_widget_service.dart';
import 'auth_model.dart';

abstract class AuthRepository {
  Future<AuthUser?> checkAuthStatus();
  Future<AuthUser> loginPassword(String emailOrPhone, String password);
  Future<Map<String, dynamic>> registerRequest(String username, String email, String password);
  Future<AuthUser> registerVerify(String email, String otp, {String? username});
  Future<Map<String, dynamic>> loginOtpRequest(String emailOrPhone);
  Future<AuthUser> loginOtpVerify(String emailOrPhone, String otp);
  Future<Map<String, dynamic>> forgotPasswordRequest(String emailOrPhone);
  Future<void> resetPassword(String emailOrPhone, String otp, String newPassword);
  Future<Map<String, dynamic>> adminLoginRequest(String emailOrPhone, String password);
  Future<void> adminLoginVerify(String emailOrPhone, String otp);
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

  Map<String, dynamic> _toMap(dynamic res) {
    if (res == null) return {};
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is String) {
      final trimmed = res.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return {'message': trimmed.isNotEmpty ? trimmed : 'OTP sent via SMS.'};
    }
    return {};
  }

  @override
  Future<AuthUser?> checkAuthStatus() async {
    try {
      final res = await apiClient.get('/api/auth/status');
      if (res != null && res['authenticated'] == true && res['user'] != null) {
        final user = AuthUser.fromJson(res['user']);
        await _saveUserLocal(user);
        return user;
      }
    } catch (_) {}

    final storedEmail = storage.getString(AppConstants.keyUserEmail);
    if (storedEmail != null && storedEmail.isNotEmpty) {
      return AuthUser(
        emailOrPhone: storedEmail,
        fullname: storage.getString(AppConstants.keyUserFullname) ?? 'Customer',
        role: storage.getString(AppConstants.keyUserRole) ?? 'customer',
      );
    }

    return null;
  }

  @override
  Future<AuthUser> loginPassword(String emailOrPhone, String password) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanInput.isEmpty || cleanPass.isEmpty) {
      throw Exception('Email/Phone and Password are required.');
    }

    try {
      final res = await apiClient.post('/api/auth/login', data: {
        'email_or_phone': cleanInput,
        'password': cleanPass,
      }).timeout(const Duration(seconds: 8));

      if (res != null && res['user'] != null) {
        final user = AuthUser.fromJson(res['user']);
        await _saveUserLocal(user);
        return user;
      } else {
        throw Exception(res?['error'] ?? res?['message'] ?? 'Invalid email/phone or password.');
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('401') || msg.contains('Invalid')) {
        throw Exception('Invalid email/phone or password. Please check your credentials.');
      }
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> registerRequest(String username, String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUser = username.trim();
    final cleanPass = password.trim();

    if (cleanUser.isEmpty || cleanEmail.isEmpty || cleanPass.isEmpty) {
      throw Exception('All registration fields are required.');
    }

    final res = await apiClient.post('/api/auth/register', data: {
      'username': cleanUser,
      'email': cleanEmail,
      'password': cleanPass,
    });

    return res ?? {'success': true, 'message': 'Account created successfully.'};
  }

  @override
  Future<AuthUser> registerVerify(String email, String otp, {String? username}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    final res = await apiClient.post('/api/auth/verify_otp', data: {
      'email': cleanEmail,
      'otp': cleanOtp,
    });

    if (res != null && res['user'] != null) {
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    }

    throw Exception(res?['error'] ?? 'Registration verification failed.');
  }

  @override
  Future<Map<String, dynamic>> loginOtpRequest(String emailOrPhone) async {
    final cleanInput = emailOrPhone.trim();

    if (!cleanInput.contains('@')) {
      // 1. Try MSG91 Widget / Direct Gateway
      try {
        final result = await Msg91WidgetService.sendOtp(cleanInput, apiClient: apiClient);
        if (result.isSuccess) {
          return {
            'success': true,
            'message': result.message ?? 'OTP sent via SMS.',
          };
        }
      } catch (_) {}

      // 2. Direct server fallback to /api/auth/login-otp-request
      try {
        final res = await apiClient.post('/api/auth/login-otp-request', data: {
          'email_or_phone': cleanInput,
        });
        final map = _toMap(res);
        return {
          'success': true,
          'message': map['message']?.toString() ?? 'OTP sent via SMS.',
        };
      } catch (e) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }

      throw Exception('Failed to send SMS OTP.');
    } else {
      // Backend email request
      final res = await apiClient.post('/api/auth/login-otp-request', data: {
        'email_or_phone': cleanInput.toLowerCase(),
      });
      final map = _toMap(res);
      return {'success': true, 'message': map['message']?.toString() ?? 'Email verification dispatched.'};
    }
  }

  @override
  Future<AuthUser> loginOtpVerify(String emailOrPhone, String otp) async {
    final cleanInput = emailOrPhone.trim();
    final cleanOtp = otp.trim();

    if (!cleanInput.contains('@')) {
      // 1. Try MSG91 Widget / Direct Gateway verify
      try {
        final result = await Msg91WidgetService.verifyOtp(cleanInput, cleanOtp, apiClient: apiClient);
        if (result.isValid && result.user != null) {
          await _saveUserLocal(result.user!);
          return result.user!;
        }
      } catch (_) {}

      // 2. Direct server fallback to /api/auth/login-otp-verify
      try {
        final res = await apiClient.post('/api/auth/login-otp-verify', data: {
          'email_or_phone': cleanInput,
          'otp': cleanOtp,
        });
        final map = _toMap(res);
        final userJson = map['user'] is Map ? Map<String, dynamic>.from(map['user']) : null;
        if (userJson != null) {
          final user = AuthUser.fromJson(userJson);
          await _saveUserLocal(user);
          return user;
        }
        throw Exception(map['error']?.toString() ?? map['message']?.toString() ?? 'Invalid verification code. Please check your SMS and try again.');
      } catch (e) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }

      throw Exception('Invalid SMS code. Please try again.');
    } else {
      final res = await apiClient.post('/api/auth/login-otp-verify', data: {
        'email_or_phone': cleanInput.toLowerCase(),
        'otp': cleanOtp,
      });

      final map = _toMap(res);
      final userJson = map['user'] is Map ? Map<String, dynamic>.from(map['user']) : null;
      if (userJson != null) {
        final user = AuthUser.fromJson(userJson);
        await _saveUserLocal(user);
        return user;
      }
      throw Exception(map['error']?.toString() ?? 'OTP verification failed.');
    }
  }

  @override
  Future<Map<String, dynamic>> forgotPasswordRequest(String emailOrPhone) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final res = await apiClient.post('/api/auth/forgot-password', data: {
      'email_or_phone': cleanInput,
    });
    return res ?? {'success': true, 'message': 'Password reset request dispatched.'};
  }

  @override
  Future<void> resetPassword(String emailOrPhone, String otp, String newPassword) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final cleanOtp = otp.trim();
    final cleanPass = newPassword.trim();

    await apiClient.post('/api/auth/reset-password', data: {
      'email_or_phone': cleanInput,
      'otp': cleanOtp,
      'new_password': cleanPass,
    });
  }

  @override
  Future<Map<String, dynamic>> adminLoginRequest(String emailOrPhone, String password) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final cleanPass = password.trim();

    final res = await apiClient.post('/api/auth/admin-login-request', data: {
      'email_or_phone': cleanInput,
      'password': cleanPass,
    });
    return res ?? {'success': true, 'message': 'Admin MFA challenge initiated.'};
  }

  @override
  Future<void> adminLoginVerify(String emailOrPhone, String otp) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final cleanOtp = otp.trim();

    await apiClient.post('/api/auth/admin-login-verify', data: {
      'email_or_phone': cleanInput,
      'otp': cleanOtp,
    });
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.post('/api/auth/logout');
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
