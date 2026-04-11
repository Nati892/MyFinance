import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';

final apkRepositoryProvider = Provider<ApkRepository>(
  (ref) => ApkRepository(ref.read(dioProvider)),
);

/// A Dio instance used only for APK binary downloads.
/// It bypasses SSL certificate validation because the server uses a
/// self-signed / IP-address certificate that fails hostname checking.
Dio _buildDownloadDio() {
  final dio = Dio(BaseOptions(receiveTimeout: const Duration(minutes: 10)));
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    },
  );
  return dio;
}

class ApkRepository {
  final Dio _dio;
  ApkRepository(this._dio);

  /// GET /api/apk/latest — returns { version, downloadUrl }
  Future<Map<String, dynamic>> getLatest() async {
    final res = await _dio.get('/apk/latest');
    return res.data as Map<String, dynamic>;
  }

  /// Download APK binary to [savePath].
  /// Uses a separate Dio instance that accepts self-signed certificates,
  /// because the download URL is HTTPS with an IP-based cert that Dio
  /// rejects on the normal authenticated client.
  Future<void> downloadApk(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final downloadDio = _buildDownloadDio();
    await downloadDio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
