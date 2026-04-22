import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';

// Uses bareDioProvider (no auth interceptor) to avoid circular dependency:
// dioProvider → AuthInterceptor → AuthService → AuthRepository → dioProvider
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(bareDioProvider)),
);

class AuthRepository {
  final Dio _dio;
  AuthRepository(this._dio);

  /// POST /api/app/auth/signin
  Future<Map<String, dynamic>> signIn(String username, String password) async {
    final res = await _dio.post('/app/auth/signin', data: {
      'username': username,
      'password': password,
    });
    return res.data as Map<String, dynamic>;
  }

  /// POST /api/app/auth/refresh
  Future<Map<String, dynamic>> refresh(String refreshToken, int userId) async {
    final res = await _dio.post('/app/auth/refresh', data: {
      'refreshToken': refreshToken,
      'userId': userId,
    });
    return res.data as Map<String, dynamic>;
  }

  /// GET /api/app/auth/profile
  /// Pass [token] to inject the Authorization header (bareDio has no interceptor).
  Future<Map<String, dynamic>> getProfile({required String token}) async {
    final res = await _dio.get(
      '/app/auth/profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return res.data as Map<String, dynamic>;
  }
}
