import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_model.dart';
import '../data/auth_repository.dart';

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;
  final String? pendingOtp; // For debug display if present

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
    this.pendingOtp,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    String? infoMessage,
    String? pendingOtp,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      pendingOtp: pendingOtp ?? this.pendingOtp,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repository;

  AuthNotifier(this.repository) : super(AuthState()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await repository.checkAuthStatus();
      state = state.copyWith(user: user, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> loginPassword(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await repository.loginPassword(emailOrPhone, password);
      state = state.copyWith(user: user, isLoading: false, infoMessage: 'Welcome back, ${user.fullname}!');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> registerRequest(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await repository.registerRequest(username, email, password);
      state = state.copyWith(
        isLoading: false,
        infoMessage: res['message'] ?? 'OTP sent',
        pendingOtp: res['debug_otp']?.toString(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> registerVerify(String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await repository.registerVerify(otp);
      state = state.copyWith(user: user, isLoading: false, infoMessage: 'Registration successful!');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> loginOtpRequest(String emailOrPhone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await repository.loginOtpRequest(emailOrPhone);
      state = state.copyWith(
        isLoading: false,
        infoMessage: res['message'] ?? 'OTP code sent',
        pendingOtp: res['debug_otp']?.toString(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> loginOtpVerify(String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await repository.loginOtpVerify(otp);
      state = state.copyWith(user: user, isLoading: false, infoMessage: 'Welcome!');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> forgotPasswordRequest(String emailOrPhone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await repository.forgotPasswordRequest(emailOrPhone);
      state = state.copyWith(
        isLoading: false,
        infoMessage: res['message'] ?? 'Reset code sent',
        pendingOtp: res['debug_otp']?.toString(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> resetPassword(String emailOrPhone, String otp, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await repository.resetPassword(emailOrPhone, otp, newPassword);
      state = state.copyWith(isLoading: false, infoMessage: 'Password reset successfully! Please log in.');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await repository.logout();
    state = state.copyWith(clearUser: true, isLoading: false, infoMessage: 'Logged out successfully');
  }
}
