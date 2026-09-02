import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_model.dart';
import '../data/auth_repository.dart';

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    String? infoMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
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
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> registerRequest(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await repository.registerRequest(username, email, password);
      state = state.copyWith(
        isLoading: false,
        infoMessage: res['message'] ?? 'OTP sent successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> registerVerify(String email, String otp, {String? username}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await repository.registerVerify(email, otp, username: username);
      state = state.copyWith(user: user, isLoading: false, infoMessage: 'Registration successful! Welcome to Rama Store.');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> loginOtpRequest(String emailOrPhone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await repository.loginOtpRequest(emailOrPhone);
      state = state.copyWith(
        isLoading: false,
        infoMessage: res['message'] ?? 'OTP code sent successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> loginOtpVerify(String emailOrPhone, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await repository.loginOtpVerify(emailOrPhone, otp);
      state = state.copyWith(user: user, isLoading: false, infoMessage: 'Authentication successful! Welcome.');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> forgotPasswordRequest(String emailOrPhone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await repository.forgotPasswordRequest(emailOrPhone);
      state = state.copyWith(
        isLoading: false,
        infoMessage: res['message'] ?? 'Password reset OTP sent.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> resetPassword(String emailOrPhone, String otp, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await repository.resetPassword(emailOrPhone, otp, newPassword);
      state = state.copyWith(isLoading: false, infoMessage: 'Password reset successfully! Please sign in.');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await repository.logout();
    state = state.copyWith(clearUser: true, isLoading: false, infoMessage: 'Signed out successfully.');
  }
}
