import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/services/auth_service.dart';

/// Injects the Bearer token on every request.
/// On 401, attempts a token refresh and retries once.
/// Uses [Ref] to read AuthService lazily, breaking the Dio ↔ AuthService cycle.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final Ref _ref;

  AuthInterceptor(this._dio, this._ref);

  AuthService get _authService => _ref.read(authServiceProvider);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _authService.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _authService.tryRefresh();
      if (refreshed) {
        // Retry original request with new token.
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${_authService.accessToken}';
        try {
          final response = await _dio.fetch(opts);
          handler.resolve(response);
          return;
        } catch (_) {
          // Retry failed — fall through to sign-out.
        }
      }
      // Refresh failed — clear session, router redirect handles navigation.
      await _authService.signOut();
    }
    handler.next(err);
  }
}
