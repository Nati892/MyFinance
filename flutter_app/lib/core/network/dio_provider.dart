import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/auth_interceptor.dart';
import 'package:household/core/network/logging_interceptor.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL — web uses localhost, Android emulator uses 10.0.2.2 (which maps to host localhost).
/// For a real device on the same LAN, change 10.0.2.2 to your machine's IP.
final String kBaseUrl = kIsWeb
    ? 'http://localhost:1234/api'
    : 'http://10.0.2.2:1234/api';

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: kBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Content-Type': 'application/json'},
);

/// Unauthenticated Dio — used only by AuthRepository (login, refresh).
/// No auth interceptor so there is no circular dependency.
final bareDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(LoggingInterceptor());
  return dio;
});

/// Authenticated Dio — used by all feature repositories.
/// The AuthInterceptor reads AuthService lazily via [ref] to avoid cycles.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.addAll([
    AuthInterceptor(dio, ref),
    LoggingInterceptor(),
  ]);
  return dio;
});
