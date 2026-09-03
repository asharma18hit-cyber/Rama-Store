// lib/core/services/msg91_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js' as js;
import 'otp_service.dart';

Future<bool> initMsg91Widget({
  String widgetId = 'SecureOTPWidgetS29G',
  String tokenAuth = '',
  String identifier = '',
}) async {
  try {
    if (js.context.hasProperty('initMsg91Widget')) {
      final res = js.context.callMethod('initMsg91Widget', [widgetId, tokenAuth, identifier]);
      return res == true;
    }
  } catch (e) {
    // Graceful fallback
  }
  return false;
}

Future<OtpSendResult> sendMsg91Otp(String identifier) async {
  try {
    // Ensure widget is initialized
    initMsg91Widget(identifier: identifier);

    if (js.context.hasProperty('msg91SendOtp')) {
      final completer = Completer<OtpSendResult>();
      const successCb = '__msg91_send_success';
      const errorCb = '__msg91_send_error';

      js.context[successCb] = (dynamic data) {
        if (!completer.isCompleted) {
          completer.complete(const OtpSendResult(
            isSuccess: true,
            message: 'OTP sent via MSG91 SMS.',
          ));
        }
      };

      js.context[errorCb] = (dynamic err) {
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult(
            isSuccess: false,
            errorMessage: err?.toString() ?? 'MSG91 send failed',
          ));
        }
      };

      final called = js.context.callMethod('msg91SendOtp', [identifier, successCb, errorCb]);
      if (called == true) {
        return await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => const OtpSendResult(
            isSuccess: false,
            errorMessage: 'Timeout contacting MSG91 widget.',
          ),
        );
      }
    }
  } catch (e) {
    // Fallback
  }
  return const OtpSendResult(isSuccess: false, errorMessage: 'Widget not initialized');
}

Future<String?> verifyMsg91Otp(String otp) async {
  try {
    if (js.context.hasProperty('msg91VerifyOtp')) {
      final completer = Completer<String?>();
      const successCb = '__msg91_verify_success';
      const errorCb = '__msg91_verify_error';

      js.context[successCb] = (dynamic token) {
        if (!completer.isCompleted) {
          completer.complete(token?.toString());
        }
      };

      js.context[errorCb] = (dynamic err) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      };

      final called = js.context.callMethod('msg91VerifyOtp', [otp, successCb, errorCb]);
      if (called == true) {
        return await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => null,
        );
      }
    }
  } catch (e) {
    // Fallback
  }
  return null;
}

Future<OtpSendResult> retryMsg91Otp() async {
  try {
    if (js.context.hasProperty('msg91RetryOtp')) {
      final completer = Completer<OtpSendResult>();
      const successCb = '__msg91_retry_success';
      const errorCb = '__msg91_retry_error';

      js.context[successCb] = (dynamic data) {
        if (!completer.isCompleted) {
          completer.complete(const OtpSendResult(
            isSuccess: true,
            message: 'New OTP dispatched via MSG91 SMS.',
          ));
        }
      };

      js.context[errorCb] = (dynamic err) {
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult(
            isSuccess: false,
            errorMessage: err?.toString() ?? 'Failed to resend OTP',
          ));
        }
      };

      final called = js.context.callMethod('msg91RetryOtp', [successCb, errorCb]);
      if (called == true) {
        return await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => const OtpSendResult(
            isSuccess: false,
            errorMessage: 'Timeout contacting MSG91 widget.',
          ),
        );
      }
    }
  } catch (e) {
    // Fallback
  }
  return const OtpSendResult(isSuccess: false, errorMessage: 'Widget retry failed');
}
