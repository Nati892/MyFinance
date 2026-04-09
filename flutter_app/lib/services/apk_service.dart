import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:household/repositories/apk_repository.dart';

final apkServiceProvider = Provider<ApkService>(
  (ref) => ApkService(ref.read(apkRepositoryProvider)),
);

class ApkUpdateInfo {
  final int latestVersion;
  final String downloadUrl;
  final bool isUpdateAvailable;

  const ApkUpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.isUpdateAvailable,
  });
}

class ApkService {
  final ApkRepository _repo;
  ApkService(this._repo);

  /// Check if a newer APK version is available.
  /// Returns null if the check fails (network error, no APK uploaded, etc.).
  Future<ApkUpdateInfo?> checkForUpdate() async {
    try {
      final data = await _repo.getLatest();
      final latestVersion = data['version'] as int;
      final downloadUrl = data['downloadUrl'] as String;

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      return ApkUpdateInfo(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        isUpdateAvailable: latestVersion > currentBuild,
      );
    } catch (_) {
      return null;
    }
  }

  /// Download the APK at [downloadUrl] and trigger the system installer.
  Future<void> downloadAndInstall(
    String downloadUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      // Storage permission (needed on Android < 10 for external storage)
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isPermanentlyDenied) {
        throw Exception('Storage permission permanently denied');
      }

      // Install packages permission (Android 8+)
      final installStatus = await Permission.requestInstallPackages.request();
      if (!installStatus.isGranted) {
        throw Exception(
          'Install packages permission not granted. '
          'Please enable "Install unknown apps" for this app in system settings.',
        );
      }
    }

    final dir = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();

    final savePath = '${dir.path}/household_update.apk';

    await _repo.downloadApk(
      downloadUrl,
      savePath,
      onReceiveProgress: onProgress != null
          ? (received, total) => onProgress(received, total)
          : null,
    );

    final result = await OpenFile.open(savePath);
    if (result.type != ResultType.done) {
      throw Exception('Failed to open installer: ${result.message}');
    }
  }
}
