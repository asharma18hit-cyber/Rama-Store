import 'package:dio/dio.dart';
import '../storage/local_storage_service.dart';
import '../constants/app_constants.dart';

class CookieInterceptor extends Interceptor {
  final LocalStorageService storage;

  CookieInterceptor(this.storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sessionCookie = storage.getString(AppConstants.keyAuthSession);
    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      options.headers['Cookie'] = sessionCookie;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final cookies = response.headers['set-cookie'];
    if (cookies != null && cookies.isNotEmpty) {
      for (final cookie in cookies) {
        if (cookie.contains('session=')) {
          final sessionVal = cookie.split(';')[0];
          storage.setString(AppConstants.keyAuthSession, sessionVal);
          break;
        }
      }
    }
    handler.next(response);
  }
}
