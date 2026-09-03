import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/otp_service.dart';
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
      // Real Phone OTP via Backend MSG91
      final result = await OtpService.sendOtp(cleanInput, apiClient: apiClient);
      if (!result.isSuccess) {
        throw Exception(result.errorMessage ?? 'Failed to send SMS OTP.');
      }
      return {
        'success': true,
        'message': result.message ?? 'OTP sent via SMS.',
      };
    } else {
      // Backend email request
      final res = await apiClient.post('/api/auth/login-otp-request', data: {
        'email_or_phone': cleanInput.toLowerCase(),
      });
      return res ?? {'success': true, 'message': 'Email verification dispatched.'};
    }
  }

  @override
  Future<AuthUser> loginOtpVerify(String emailOrPhone, String otp) async {
    final cleanInput = emailOrPhone.trim();
    final cleanOtp = otp.trim();

    if (!cleanInput.contains('@')) {
      // Real Phone OTP verification via Backend MSG91
      final result = await OtpService.verifyOtp(cleanInput, cleanOtp, apiClient: apiClient);
      if (!result.isValid) {
        throw Exception(result.error ?? 'Invalid SMS code. Please try again.');
      }

      final user = result.user ?? AuthUser(
        emailOrPhone: OtpService.formatPhoneNumber(cleanInput),
        fullname: 'Customer',
        role: 'customer',
      );
      await _saveUserLocal(user);
      return user;
    } else {
      final res = await apiClient.post('/api/auth/login-otp-verify', data: {
        'email_or_phone': cleanInput.toLowerCase(),
        'otp': cleanOtp,
      });

      if (res != null && res['user'] != null) {
        final user = AuthUser.fromJson(res['user']);
        await _saveUserLocal(user);
        return user;
      }
      throw Exception(res?['error'] ?? 'OTP verification failed.');
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
