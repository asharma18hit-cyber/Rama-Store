import 'dart:async';
import '../network/api_client.dart';
import '../../features/auth/data/auth_model.dart';

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

  /// Normalizes any Indian mobile input into standard MSG91 format (91XXXXXXXXXX)
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

  static Map<String, dynamic>? _toMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Dispatches SMS OTP via Secure Backend Gateway using MSG91
  static Future<OtpSendResult> sendOtp(String identifier, {required ApiClient apiClient}) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      return const OtpSendResult(
        isSuccess: false,
        errorMessage: 'Please enter a valid mobile number or email.',
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

    if (!cleanId.contains('@')) {
      final formattedPhone = formatPhoneNumber(cleanId);
      final digits = formattedPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 12) {
        return const OtpSendResult(
          isSuccess: false,
          errorMessage: 'Please enter a valid 10-digit Indian mobile number.',
        );
      }

      try {
        final res = await apiClient.post('/api/auth/otp/send', data: {
          'phone': formattedPhone,
        }).timeout(const Duration(seconds: 15));

        final data = _toMap(res);
        if (data != null && data['success'] == true) {
          _lastSentTimestamps[cleanId] = now;
          return OtpSendResult(
            isSuccess: true,
            message: data['message']?.toString() ?? 'OTP sent via SMS.',
          );
        } else {
          return OtpSendResult(
            isSuccess: false,
            errorMessage: data?['message']?.toString() ?? data?['error']?.toString() ?? 'Failed to send SMS OTP.',
          );
        }
      } catch (e) {
        final msg = e.toString().replaceAll('Exception: ', '');
        return OtpSendResult(
          isSuccess: false,
          errorMessage: msg.contains('503') || msg.contains('unconfigured')
              ? 'SMS provider is currently being configured on the server. Please sign in with password.'
              : msg,
        );
      }
    }

    return const OtpSendResult(
      isSuccess: false,
      errorMessage: 'Email OTP is not supported on this endpoint. Please enter your mobile number.',
    );
  }

  /// Verifies SMS OTP with MSG91 via Secure Backend
  static Future<OtpVerificationResult> verifyOtp(String identifier, String enteredCode, {required ApiClient apiClient}) async {
    final cleanId = identifier.trim();
    final code = enteredCode.trim();

    if (code.isEmpty || code.length != 6) {
      return const OtpVerificationResult(
        isValid: false,
        error: 'Please enter a valid 6-digit verification code.',
      );
    }

    if (!cleanId.contains('@')) {
      final formattedPhone = formatPhoneNumber(cleanId);

      try {
        final res = await apiClient.post('/api/auth/otp/verify', data: {
          'phone': formattedPhone,
          'otp': code,
        }).timeout(const Duration(seconds: 15));

        final data = _toMap(res);
        if (data != null && data['success'] == true) {
          _lastSentTimestamps.remove(cleanId);
          final userJson = _toMap(data['user']);
          final user = userJson != null ? AuthUser.fromJson(userJson) : AuthUser(
            emailOrPhone: formattedPhone,
            fullname: 'Customer',
            role: 'customer',
          );
          return OtpVerificationResult(
            isValid: true,
            user: user,
          );
        } else {
          return OtpVerificationResult(
            isValid: false,
            error: data?['message']?.toString() ?? data?['error']?.toString() ?? 'Incorrect OTP. Please check SMS and try again.',
          );
        }
      } catch (e) {
        return OtpVerificationResult(
          isValid: false,
          error: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }

    return const OtpVerificationResult(
      isValid: false,
      error: 'Invalid identifier for OTP verification.',
    );
  }

  /// Resends SMS OTP via MSG91 Retry API
  static Future<OtpSendResult> resendOtp(String identifier, {required ApiClient apiClient}) async {
    final cleanId = identifier.trim();
    final formattedPhone = formatPhoneNumber(cleanId);

    try {
      final res = await apiClient.post('/api/auth/otp/retry', data: {
        'phone': formattedPhone,
      }).timeout(const Duration(seconds: 15));

      final data = _toMap(res);
      if (data != null && data['success'] == true) {
        _lastSentTimestamps[cleanId] = DateTime.now();
        return OtpSendResult(
          isSuccess: true,
          message: data['message']?.toString() ?? 'New OTP sent via SMS.',
        );
      } else {
        return OtpSendResult(
          isSuccess: false,
          errorMessage: data?['message']?.toString() ?? 'Failed to resend OTP.',
        );
      }
    } catch (e) {
      return OtpSendResult(
        isSuccess: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Verifies MSG91 OTP Widget JWT Access Token server-side
  static Future<OtpVerificationResult> verifyWidgetAccessToken(String accessToken, {required ApiClient apiClient}) async {
    final token = accessToken.trim();
    if (token.isEmpty) {
      return const OtpVerificationResult(
        isValid: false,
        error: 'Access token is required for verification.',
      );
    }

    try {
      final res = await apiClient.post('/api/auth/msg91/verify-token', data: {
        'access_token': token,
      }).timeout(const Duration(seconds: 15));

      final data = _toMap(res);
      if (data != null && data['success'] == true) {
        final userJson = _toMap(data['user']);
        final user = userJson != null ? AuthUser.fromJson(userJson) : null;
        return OtpVerificationResult(
          isValid: true,
          user: user,
        );
      } else {
        return OtpVerificationResult(
          isValid: false,
          error: data?['message']?.toString() ?? 'Invalid or expired MSG91 access token.',
        );
      }
    } catch (e) {
      return OtpVerificationResult(
        isValid: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}
