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
    print('[APK] Original download URL from server: $url');
    final httpUrl = url.replaceFirst('https://', 'http://');
    print('[APK] Final download URL (after http swap): $httpUrl');
    print('[APK] Saving APK to: $savePath');
    final downloadDio = _buildDownloadDio();
    try {
      await downloadDio.download(
        httpUrl,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: Options(responseType: ResponseType.bytes),
      );
      print('[APK] Download completed successfully');
    } on DioException catch (e) {
      print('[APK] DioException type: ${e.type}');
      print('[APK] DioException message: ${e.message}');
      print('[APK] DioException response status: ${e.response?.statusCode}');
      print('[APK] DioException response data: ${e.response?.data}');
      print('[APK] DioException error: ${e.error}');
      rethrow;
    } catch (e, st) {
      print('[APK] Unexpected error: $e');
      print('[APK] Stack trace: $st');
      rethrow;
    }
  }
}
