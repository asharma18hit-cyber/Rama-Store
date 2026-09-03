// lib/core/services/msg91_stub.dart
import 'dart:async';
import 'otp_service.dart';

Future<bool> initMsg91Widget({
  String widgetId = 'SecureOTPWidgetS29G',
  String tokenAuth = '',
  String identifier = '',
}) async {
  return false;
}

Future<OtpSendResult> sendMsg91Otp(String identifier) async {
  return const OtpSendResult(isSuccess: false, errorMessage: 'Non-web platform');
}

Future<String?> verifyMsg91Otp(String otp) async {
  return null;
}

Future<OtpSendResult> retryMsg91Otp() async {
  return const OtpSendResult(isSuccess: false, errorMessage: 'Non-web platform');
}
