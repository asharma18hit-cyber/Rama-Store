import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static const bool _isProduction = kReleaseMode;

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(LogLevel level, String message, [dynamic error, StackTrace? stackTrace]) {
    if (_isProduction && level == LogLevel.debug) return;

    final sanitizedMessage = _sanitize(message);
    final timestamp = DateTime.now().toIso8601String();
    final prefix = switch (level) {
      LogLevel.debug => '🔍 [DEBUG]',
      LogLevel.info => 'ℹ️ [INFO]',
      LogLevel.warning => '⚠️ [WARN]',
      LogLevel.error => '🚨 [ERROR]',
    };

    debugPrint('$prefix $timestamp: $sanitizedMessage');
    if (error != null) {
      debugPrint('   Error: ${_sanitize(error.toString())}');
    }
    if (stackTrace != null && !_isProduction) {
      debugPrint('   StackTrace: $stackTrace');
    }
  }

  static String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'password=[^&\s,]+', caseSensitive: false), 'password=***')
        .replaceAll(RegExp(r'otp=[^&\s,]+', caseSensitive: false), 'otp=***')
        .replaceAll(RegExp(r'token=[^&\s,]+', caseSensitive: false), 'token=***')
        .replaceAll(RegExp(r'cvv=[^&\s,]+', caseSensitive: false), 'cvv=***')
        .replaceAll(RegExp(r'card_number=[^&\s,]+', caseSensitive: false), 'card_number=***');
  }
}
