class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthException extends ApiException {
  AuthException(String message, {int? statusCode = 401})
      : super(message, statusCode: statusCode);
}

class ValidationException extends ApiException {
  ValidationException(String message, {int? statusCode = 400})
      : super(message, statusCode: statusCode);
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message, statusCode: 0);
}
