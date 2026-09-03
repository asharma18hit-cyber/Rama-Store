import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import 'otp_service.dart';

import 'msg91_stub.dart'
    if (dart.library.js) 'msg91_web.dart' as msg91_impl;

class Msg91WidgetService {
  static const String defaultWidgetId = 'SecureOTPWidgetS29G';

  /// Initializes the MSG91 Web SDK Widget
  static Future<bool> initWidget({
    String widgetId = defaultWidgetId,
    String tokenAuth = '',
    String identifier = '',
  }) async {
    return msg91_impl.initMsg91Widget(
      widgetId: widgetId,
      tokenAuth: tokenAuth,
      identifier: identifier,
    );
  }

  /// Dispatches OTP via the official MSG91 Web SDK Widget
  static Future<OtpSendResult> sendOtp(
    String identifier, {
    required ApiClient apiClient,
  }) async {
    final cleanPhone = OtpService.formatPhoneNumber(identifier);

    if (kIsWeb) {
      // Authoritative Web flow: 100% MSG91 Web SDK
      return msg91_impl.sendMsg91Otp(cleanPhone);
    }

    // Native platform flow
    return OtpService.sendOtp(cleanPhone, apiClient: apiClient);
  }

  /// Verifies OTP via the official MSG91 Web SDK Widget and exchanges JWT Access Token
  static Future<OtpVerificationResult> verifyOtp(
    String identifier,
    String enteredCode, {
    required ApiClient apiClient,
  }) async {
    final cleanPhone = OtpService.formatPhoneNumber(identifier);

    if (kIsWeb) {
      // Authoritative Web flow: MSG91 widget verifyOtp -> JWT token -> Backend verifyAccessToken
      final tokenResult = await msg91_impl.verifyMsg91Otp(enteredCode);
      if (tokenResult != null && tokenResult.isNotEmpty) {
        return verifyToken(tokenResult, apiClient: apiClient);
      }
      return const OtpVerificationResult(
        isValid: false,
        error: 'Incorrect OTP code or expired session. Please check your SMS and try again.',
      );
    }

    // Native platform flow
    return OtpService.verifyOtp(cleanPhone, enteredCode, apiClient: apiClient);
  }

  /// Retries/Resends OTP via MSG91 Web SDK Widget
  static Future<OtpSendResult> resendOtp(
    String identifier, {
    required ApiClient apiClient,
  }) async {
    final cleanPhone = OtpService.formatPhoneNumber(identifier);

    if (kIsWeb) {
      return msg91_impl.retryMsg91Otp();
    }

    return OtpService.resendOtp(cleanPhone, apiClient: apiClient);
  }

  /// Verifies the token received from the MSG91 widget against our secure backend.
  static Future<OtpVerificationResult> verifyToken(
    String accessToken, {
    required ApiClient apiClient,
  }) async {
    return OtpService.verifyWidgetAccessToken(accessToken, apiClient: apiClient);
  }
}
