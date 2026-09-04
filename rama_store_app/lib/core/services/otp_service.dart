import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../network/api_client.dart';
import '../../features/auth/data/auth_model.dart';
import 'firebase_auth_service.dart';

class OtpSendResult {
  final bool isSuccess;
  final String? message;
  final String? errorMessage;
  final int cooldownRemaining;

  const OtpSendResult({
    required this.isSuccess,
    this.message,
    this.errorMessage,
    this.cooldownRemaining = 0,
  });
}

class OtpVerificationResult {
  final bool isValid;
  final AuthUser? user;
  final String? error;

  const OtpVerificationResult({
    required this.isValid,
    this.user,
    this.error,
  });
}

class OtpService {
  static final Map<String, DateTime> _lastSentTimestamps = {};

  /// Normalizes any Indian mobile input into standard 91XXXXXXXXXX format
  static String formatPhoneNumber(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '91$digits';
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits;
    }
    return digits;
  }

  /// Masks phone number for secure UI display (e.g. +91 98*** **210)
  static String maskPhoneNumber(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final tenDigits = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      final first2 = tenDigits.substring(0, 2);
      final last3 = tenDigits.substring(7);
      return '+91 $first2*** **$last3';
    }
    return rawPhone;
  }

  /// Dispatches Firebase Phone SMS OTP
  static Future<OtpSendResult> sendOtp(String identifier, {ApiClient? apiClient}) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      return const OtpSendResult(
        isSuccess: false,
        errorMessage: 'Please enter a valid mobile number.',
      );
    }

    final now = DateTime.now();
    final lastSent = _lastSentTimestamps[cleanId];
    if (lastSent != null && now.difference(lastSent).inSeconds < 30) {
      final remaining = 30 - now.difference(lastSent).inSeconds;
      return OtpSendResult(
        isSuccess: false,
        errorMessage: 'Please wait ${remaining}s before requesting a new code.',
        cooldownRemaining: remaining,
      );
    }

    final phoneResult = await FirebaseAuthService.sendPhoneOtp(cleanId);
    if (phoneResult.isSuccess) {
      _lastSentTimestamps[cleanId] = now;
      return OtpSendResult(
        isSuccess: true,
        message: phoneResult.message ?? 'SMS verification code sent.',
      );
    } else {
      return OtpSendResult(
        isSuccess: false,
        errorMessage: phoneResult.errorMessage ?? 'Failed to send SMS OTP.',
      );
    }
  }

  /// Verifies 6-digit SMS OTP using Firebase Auth
  static Future<OtpVerificationResult> verifyOtp(String identifier, String enteredCode, {ApiClient? apiClient}) async {
    try {
      final userCred = await FirebaseAuthService.verifySmsCode(enteredCode);
      final fbUser = userCred.user;
      if (fbUser != null) {
        final phone = fbUser.phoneNumber ?? FirebaseAuthService.formatPhoneNumber(identifier);
        final user = AuthUser(
          emailOrPhone: phone,
          fullname: fbUser.displayName ?? 'Customer',
          role: 'customer',
        );
        return OtpVerificationResult(
          isValid: true,
          user: user,
        );
      }
      return const OtpVerificationResult(
        isValid: false,
        error: 'Authentication failed. Please try again.',
      );
    } catch (e) {
      return OtpVerificationResult(
        isValid: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Resends SMS OTP via Firebase Auth
  static Future<OtpSendResult> resendOtp(String identifier, {ApiClient? apiClient}) async {
    return sendOtp(identifier, apiClient: apiClient);
  }
}
