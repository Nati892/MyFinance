import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs HTTP requests and responses in debug mode only.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP →] ${options.method} ${options.path}');
      if (options.queryParameters.isNotEmpty) {
        debugPrint('         params: ${options.queryParameters}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP ←] ${response.statusCode} ${response.requestOptions.path}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP ✕] ${err.response?.statusCode} ${err.requestOptions.path} — ${err.message}');
    }
    handler.next(err);
  }
}
