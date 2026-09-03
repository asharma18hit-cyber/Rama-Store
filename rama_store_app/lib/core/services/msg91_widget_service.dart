import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../../features/auth/data/auth_model.dart';
import 'otp_service.dart';

class Msg91WidgetService {
  static const String defaultWidgetId = 'SecureOTPWidgetS29G';

  /// Verifies the token received from the MSG91 widget against our secure backend.
  static Future<OtpVerificationResult> verifyToken(
    String accessToken, {
    required ApiClient apiClient,
  }) async {
    return OtpService.verifyWidgetAccessToken(accessToken, apiClient: apiClient);
  }
}
