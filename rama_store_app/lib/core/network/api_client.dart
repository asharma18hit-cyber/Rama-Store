import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/local_storage_service.dart';
import 'cookie_interceptor.dart';
import 'api_exceptions.dart';

class ApiClient {
  late final Dio _dio;
  final LocalStorageService storage;
  final String baseUrl;

  ApiClient({required this.storage, String? baseUrl})
      : baseUrl = baseUrl ??
            (kIsWeb
                ? ''
                : const String.fromEnvironment('BASE_URL', defaultValue: AppConstants.defaultBaseUrl)) {
    _dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(CookieInterceptor(storage));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          final mappedError = _mapDioError(e);
          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: mappedError,
              response: e.response,
              type: e.type,
            ),
          );
        },
      ),
    );
  }

  ApiException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException('Network connection failed. Please check your internet connection.');
    }

    final response = error.response;
    if (response != null) {
      final data = response.data;
      String message = 'An unexpected error occurred.';
      if (data is Map && data.containsKey('error')) {
        message = data['error'].toString();
      }

      if (response.statusCode == 401) {
        return AuthException(message, statusCode: 401);
      } else if (response.statusCode == 400 || response.statusCode == 409) {
        return ValidationException(message, statusCode: response.statusCode);
      }
      return ApiException(message, statusCode: response.statusCode);
    }

    return ApiException(error.message ?? 'Unknown connection error');
  }

  dynamic _normalizeData(dynamic data) {
    if (data is String) {
      final trimmed = data.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {}
      }
    }
    return data;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _normalizeData(response.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(e.message ?? 'GET request failed');
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return _normalizeData(response.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(e.message ?? 'POST request failed');
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return _normalizeData(response.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(e.message ?? 'PUT request failed');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return _normalizeData(response.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(e.message ?? 'DELETE request failed');
    }
  }
}
