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

  /// Dispatches OTP via the MSG91 Web SDK Widget or Backend
  static Future<OtpSendResult> sendOtp(
    String identifier, {
    required ApiClient apiClient,
  }) async {
    final cleanPhone = OtpService.formatPhoneNumber(identifier);

    if (kIsWeb) {
      final res = await msg91_impl.sendMsg91Otp(cleanPhone);
      if (res.isSuccess) {
        return res;
      }
    }

    // Direct backend dispatch
    return OtpService.sendOtp(cleanPhone, apiClient: apiClient);
  }

  /// Verifies OTP via the MSG91 Web SDK Widget or Backend
  static Future<OtpVerificationResult> verifyOtp(
    String identifier,
    String enteredCode, {
    required ApiClient apiClient,
  }) async {
    final cleanPhone = OtpService.formatPhoneNumber(identifier);

    if (kIsWeb) {
      final tokenResult = await msg91_impl.verifyMsg91Otp(enteredCode);
      if (tokenResult != null && tokenResult.isNotEmpty) {
        // Exchange MSG91 access token with backend
        return verifyToken(tokenResult, apiClient: apiClient);
      }
    }

    // Direct backend verification
    return OtpService.verifyOtp(cleanPhone, enteredCode, apiClient: apiClient);
  }

  /// Retries/Resends OTP via MSG91 Web SDK Widget or Backend
  static Future<OtpSendResult> resendOtp(
    String identifier, {
    required ApiClient apiClient,
  }) async {
    final cleanPhone = OtpService.formatPhoneNumber(identifier);

    if (kIsWeb) {
      final res = await msg91_impl.retryMsg91Otp();
      if (res.isSuccess) {
        return res;
      }
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
