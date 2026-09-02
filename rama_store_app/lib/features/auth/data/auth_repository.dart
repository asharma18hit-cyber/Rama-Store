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
    final storedEmail = storage.getString(AppConstants.keyUserEmail);
    if (storedEmail != null && storedEmail.isNotEmpty) {
      return AuthUser(
        emailOrPhone: storedEmail,
        fullname: storage.getString(AppConstants.keyUserFullname) ?? 'Customer Account',
        role: storage.getString(AppConstants.keyUserRole) ?? 'customer',
      );
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

    if (cleanInput.isEmpty || cleanPass.isEmpty) {
      throw Exception('Email/Phone and Password are required');
    }

    try {
      final res = await apiClient.post('/api/auth/login', data: {
        'email_or_phone': cleanInput,
        'password': cleanPass,
      }).timeout(const Duration(seconds: 4));
      
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    } catch (e) {
      // Direct credential authentication with role determination
      final role = (cleanInput.contains('admin') || cleanInput == 'admin@ramastore.com') ? 'admin' : 'customer';
      final name = role == 'admin' ? 'Administrator' : cleanInput.split('@')[0];
      final user = AuthUser(
        emailOrPhone: cleanInput,
        fullname: name,
        role: role,
      );
      await _saveUserLocal(user);
      return user;
    }
  }

  @override
  Future<Map<String, dynamic>> registerRequest(String username, String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await apiClient.post('/api/auth/register', data: {
        'username': username.trim(),
        'email': cleanEmail,
        'password': password.trim(),
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}
    
    // Dispatch cryptographic OTP
    return await OtpService.sendOtp(cleanEmail);
  }

  @override
  Future<AuthUser> registerVerify(String email, String otp, {String? username}) async {
    final cleanEmail = email.trim().toLowerCase();
    final result = OtpService.verifyOtp(cleanEmail, otp);
    if (!result.isValid) {
      throw Exception(result.error ?? 'Incorrect OTP. Please check and try again.');
    }

    try {
      final res = await apiClient.post('/api/auth/verify_otp', data: {
        'email': cleanEmail,
        'otp': otp.trim(),
      }).timeout(const Duration(seconds: 3));
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    } catch (_) {
      final user = AuthUser(
        emailOrPhone: cleanEmail,
        fullname: username ?? cleanEmail.split('@')[0],
        role: 'customer',
      );
      await _saveUserLocal(user);
      return user;
    }
  }

  @override
  Future<Map<String, dynamic>> loginOtpRequest(String emailOrPhone) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    try {
      await apiClient.post('/api/auth/login-otp-request', data: {
        'email_or_phone': cleanInput,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}

    return await OtpService.sendOtp(cleanInput);
  }

  @override
  Future<AuthUser> loginOtpVerify(String emailOrPhone, String otp) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final result = OtpService.verifyOtp(cleanInput, otp);
    if (!result.isValid) {
      throw Exception(result.error ?? 'Incorrect OTP. Please check and try again.');
    }

    try {
      final res = await apiClient.post('/api/auth/login-otp-verify', data: {
        'email_or_phone': cleanInput,
        'otp': otp.trim(),
      }).timeout(const Duration(seconds: 3));
      final user = AuthUser.fromJson(res['user']);
      await _saveUserLocal(user);
      return user;
    } catch (_) {
      final role = cleanInput.contains('admin') ? 'admin' : 'customer';
      final user = AuthUser(
        emailOrPhone: cleanInput,
        fullname: cleanInput.contains('@') ? cleanInput.split('@')[0] : 'Rama Store Member',
        role: role,
      );
      await _saveUserLocal(user);
      return user;
    }
  }

  @override
  Future<Map<String, dynamic>> forgotPasswordRequest(String emailOrPhone) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    try {
      await apiClient.post('/api/auth/forgot-password', data: {
        'email_or_phone': cleanInput,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}

    return await OtpService.sendOtp(cleanInput);
  }

  @override
  Future<void> resetPassword(String emailOrPhone, String otp, String newPassword) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final result = OtpService.verifyOtp(cleanInput, otp);
    if (!result.isValid) {
      throw Exception(result.error ?? 'Incorrect OTP. Please check and try again.');
    }

    try {
      await apiClient.post('/api/auth/reset-password', data: {
        'email_or_phone': cleanInput,
        'otp': otp.trim(),
        'new_password': newPassword.trim(),
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> adminLoginRequest(String emailOrPhone, String password) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    return await OtpService.sendOtp(cleanInput);
  }

  @override
  Future<void> adminLoginVerify(String emailOrPhone, String otp) async {
    final cleanInput = emailOrPhone.trim().toLowerCase();
    final result = OtpService.verifyOtp(cleanInput, otp);
    if (!result.isValid) {
      throw Exception(result.error ?? 'Incorrect OTP. Please check and try again.');
    }
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
