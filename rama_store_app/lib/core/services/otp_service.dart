import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final UserCredential? credential;
  final String? error;

  const OtpVerificationResult({
    required this.isValid,
    this.credential,
    this.error,
  });
}

class OtpService {
  // Mobile Native Verification IDs
  static final Map<String, String> _nativeVerificationIds = {};
  // Web Confirmation Results
  static final Map<String, ConfirmationResult> _webConfirmationResults = {};
  // Rate limiting cooldowns
  static final Map<String, DateTime> _lastSentTimestamps = {};

  /// Format standard Indian 10-digit number into international E.164 (+91XXXXXXXXXX)
  static String formatPhoneNumber(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    if (rawPhone.startsWith('+')) {
      return rawPhone;
    }
    return '+91$digits';
  }

  /// Request Real-World Carrier SMS OTP via Firebase Phone Authentication
  static Future<OtpSendResult> sendOtp(String identifier) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      return const OtpSendResult(
        isSuccess: false,
        errorMessage: 'Please enter a valid phone number or email.',
      );
    }

    // Rate Limiting (30-second cooldown)
    final now = DateTime.now();
    final lastSent = _lastSentTimestamps[cleanId];
    if (lastSent != null) {
      final elapsed = now.difference(lastSent).inSeconds;
      if (elapsed < 30) {
        return OtpSendResult(
          isSuccess: false,
          errorMessage: 'Please wait ${30 - elapsed}s before requesting a new OTP.',
          cooldownRemaining: 30 - elapsed,
        );
      }
    }

    // Phone Number Authentication
    if (!cleanId.contains('@')) {
      final formattedPhone = formatPhoneNumber(cleanId);
      final phoneDigits = formattedPhone.replaceAll(RegExp(r'\D'), '');
      if (phoneDigits.length < 12) {
        return const OtpSendResult(
          isSuccess: false,
          errorMessage: 'Please enter a valid 10-digit mobile number.',
        );
      }

      if (Firebase.apps.isEmpty) {
        return const OtpSendResult(
          isSuccess: false,
          errorMessage: 'Firebase Authentication is initializing. Please try again in a moment.',
        );
      }

      try {
        final auth = FirebaseAuth.instance;

        if (kIsWeb) {
          // Firebase Web Phone Authentication with automatic reCAPTCHA verifier
          final confirmationResult = await auth.signInWithPhoneNumber(
            formattedPhone,
          );
          _webConfirmationResults[formattedPhone] = confirmationResult;
          _lastSentTimestamps[cleanId] = now;
          return OtpSendResult(
            isSuccess: true,
            message: 'OTP sent via SMS to $formattedPhone.',
          );
        } else {
          // Native Mobile (Android / iOS) Phone Authentication
          final completer = Completer<OtpSendResult>();

          await auth.verifyPhoneNumber(
            phoneNumber: formattedPhone,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (PhoneAuthCredential credential) async {
              try {
                await auth.signInWithCredential(credential);
              } catch (_) {}
            },
            verificationFailed: (FirebaseAuthException e) {
              final errorMsg = _mapFirebaseError(e);
              if (!completer.isCompleted) {
                completer.complete(
                  OtpSendResult(
                    isSuccess: false,
                    errorMessage: errorMsg,
                  ),
                );
              }
            },
            codeSent: (String verificationId, int? resendToken) {
              _nativeVerificationIds[formattedPhone] = verificationId;
              _lastSentTimestamps[cleanId] = now;
              if (!completer.isCompleted) {
                completer.complete(
                  OtpSendResult(
                    isSuccess: true,
                    message: 'SMS verification code dispatched to $formattedPhone.',
                  ),
                );
              }
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              _nativeVerificationIds[formattedPhone] = verificationId;
            },
          );

          return await completer.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () => const OtpSendResult(
              isSuccess: false,
              errorMessage: 'Network timeout requesting SMS from carrier. Please check your connection and retry.',
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        return OtpSendResult(
          isSuccess: false,
          errorMessage: _mapFirebaseError(e),
        );
      } catch (e) {
        return OtpSendResult(
          isSuccess: false,
          errorMessage: 'Failed to send SMS: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }

    // Email-based OTP request (requires real backend dispatch)
    return const OtpSendResult(
      isSuccess: false,
      errorMessage: 'Email OTP dispatch is not enabled on this environment. Please sign in with your mobile number or password.',
    );
  }

  /// Verify 6-digit SMS OTP against Firebase Authentication
  static Future<OtpVerificationResult> verifyOtp(String identifier, String enteredCode) async {
    final cleanId = identifier.trim();
    final code = enteredCode.trim();

    if (code.isEmpty || code.length != 6) {
      return const OtpVerificationResult(
        isValid: false,
        error: 'Please enter the complete 6-digit SMS code.',
      );
    }

    if (!cleanId.contains('@')) {
      final formattedPhone = formatPhoneNumber(cleanId);
      final auth = FirebaseAuth.instance;

      try {
        if (kIsWeb) {
          final confirmationResult = _webConfirmationResults[formattedPhone];
          if (confirmationResult == null) {
            return const OtpVerificationResult(
              isValid: false,
              error: 'No active verification session found. Please request an SMS code first.',
            );
          }

          final userCredential = await confirmationResult.confirm(code);
          _webConfirmationResults.remove(formattedPhone);
          _lastSentTimestamps.remove(cleanId);
          return OtpVerificationResult(
            isValid: true,
            credential: userCredential,
          );
        } else {
          final verificationId = _nativeVerificationIds[formattedPhone];
          if (verificationId == null) {
            return const OtpVerificationResult(
              isValid: false,
              error: 'No active verification session found. Please request an SMS code first.',
            );
          }

          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          );
          final userCredential = await auth.signInWithCredential(credential);
          _nativeVerificationIds.remove(formattedPhone);
          _lastSentTimestamps.remove(cleanId);
          return OtpVerificationResult(
            isValid: true,
            credential: userCredential,
          );
        }
      } on FirebaseAuthException catch (e) {
        return OtpVerificationResult(
          isValid: false,
          error: _mapFirebaseError(e),
        );
      } catch (e) {
        return OtpVerificationResult(
          isValid: false,
          error: 'Verification failed: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }

    return const OtpVerificationResult(
      isValid: false,
      error: 'Invalid verification identifier.',
    );
  }

  static String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The mobile phone number entered is invalid. Please check the number and try again.';
      case 'quota-exceeded':
        return 'SMS daily quota for this project has been exceeded. Please contact support or try again later.';
      case 'too-many-requests':
        return 'Too many attempts from this device. Please wait a few minutes before trying again.';
      case 'invalid-verification-code':
        return 'The 6-digit code you entered is incorrect. Please check your SMS and try again.';
      case 'session-expired':
        return 'This SMS verification session has expired. Please tap "Resend Code" to request a new one.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please refresh the page and try again.';
      case 'app-not-authorized':
        return 'This domain is not authorized in Firebase Console. Please ensure authorized domains are configured.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      default:
        return e.message ?? 'An error occurred during authentication. Please try again.';
    }
  }
}
