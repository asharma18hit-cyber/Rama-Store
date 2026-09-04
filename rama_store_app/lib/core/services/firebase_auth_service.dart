// lib/core/services/firebase_auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthResult {
  final bool isSuccess;
  final String? verificationId;
  final String? message;
  final String? errorMessage;

  const PhoneAuthResult({
    required this.isSuccess,
    this.verificationId,
    this.message,
    this.errorMessage,
  });
}

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // State cache for active web confirmation or native verification ID
  static ConfirmationResult? _webConfirmationResult;
  static String? _activeVerificationId;
  static int? _resendToken;

  /// Returns current authenticated Firebase user
  static User? get currentUser => _auth.currentUser;

  /// Exposes auth state changes stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Formats Indian phone number to E.164 (+91XXXXXXXXXX)
  static String formatPhoneNumber(String input) {
    String clean = input.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91$clean';
    } else if (clean.length == 12 && clean.startsWith('91')) {
      return '+$clean';
    } else if (!input.startsWith('+')) {
      return '+$clean';
    }
    return input.trim();
  }

  /// Sends Firebase Phone SMS OTP (Web and Mobile)
  static Future<PhoneAuthResult> sendPhoneOtp(String rawPhoneNumber) async {
    final formattedPhone = formatPhoneNumber(rawPhoneNumber);

    if (formattedPhone.length < 12) {
      return const PhoneAuthResult(
        isSuccess: false,
        errorMessage: 'Please enter a valid 10-digit Indian mobile number.',
      );
    }

    if (kIsWeb) {
      try {
        _webConfirmationResult = await _auth.signInWithPhoneNumber(formattedPhone);
        return const PhoneAuthResult(
          isSuccess: true,
          message: 'SMS verification code sent via Firebase Auth.',
        );
      } on FirebaseAuthException catch (e) {
        return PhoneAuthResult(
          isSuccess: false,
          errorMessage: e.message ?? 'Failed to send SMS OTP.',
        );
      } catch (e) {
        return PhoneAuthResult(
          isSuccess: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } else {
      // Native Android / iOS Phone Auth
      final completer = Completer<PhoneAuthResult>();

      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          forceResendingToken: _resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              await _auth.signInWithCredential(credential);
              if (!completer.isCompleted) {
                completer.complete(const PhoneAuthResult(
                  isSuccess: true,
                  message: 'Phone number automatically verified.',
                ));
              }
            } catch (_) {}
          },
          verificationFailed: (FirebaseAuthException e) {
            if (!completer.isCompleted) {
              completer.complete(PhoneAuthResult(
                isSuccess: false,
                errorMessage: e.message ?? 'Verification failed.',
              ));
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            _activeVerificationId = verificationId;
            _resendToken = resendToken;
            if (!completer.isCompleted) {
              completer.complete(PhoneAuthResult(
                isSuccess: true,
                verificationId: verificationId,
                message: 'SMS OTP sent successfully.',
              ));
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _activeVerificationId = verificationId;
          },
        );
        return await completer.future;
      } catch (e) {
        return PhoneAuthResult(
          isSuccess: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  /// Verifies the 6-digit SMS OTP code
  static Future<UserCredential> verifySmsCode(String smsCode) async {
    final cleanCode = smsCode.trim();
    if (cleanCode.length != 6) {
      throw Exception('Please enter a valid 6-digit SMS code.');
    }

    if (kIsWeb) {
      if (_webConfirmationResult == null) {
        throw Exception('Please click "Send SMS Verification Code" first.');
      }
      try {
        return await _webConfirmationResult!.confirm(cleanCode);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-verification-code') {
          throw Exception('Incorrect verification code. Please check SMS and try again.');
        } else if (e.code == 'session-expired') {
          throw Exception('Verification code expired. Please click Resend Code.');
        }
        throw Exception(e.message ?? 'OTP verification failed.');
      }
    } else {
      if (_activeVerificationId == null) {
        throw Exception('Please click "Send SMS Verification Code" first.');
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: _activeVerificationId!,
        smsCode: cleanCode,
      );
      try {
        return await _auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-verification-code') {
          throw Exception('Incorrect verification code. Please check SMS and try again.');
        } else if (e.code == 'session-expired') {
          throw Exception('Verification code expired. Please click Resend Code.');
        }
        throw Exception(e.message ?? 'OTP verification failed.');
      }
    }
  }

  /// Signs out of Firebase
  static Future<void> signOut() async {
    _webConfirmationResult = null;
    _activeVerificationId = null;
    _resendToken = null;
    await _auth.signOut();
  }
}
