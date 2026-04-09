import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';

final apkRepositoryProvider = Provider<ApkRepository>(
  (ref) => ApkRepository(ref.read(dioProvider)),
);

class ApkRepository {
  final Dio _dio;
  ApkRepository(this._dio);

  /// GET /api/apk/latest — returns { version, downloadUrl }
  Future<Map<String, dynamic>> getLatest() async {
    final res = await _dio.get('/apk/latest');
    return res.data as Map<String, dynamic>;
  }

  /// Download APK binary to [savePath] using Dio's built-in streaming download.
  Future<void> downloadApk(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
  }
}
