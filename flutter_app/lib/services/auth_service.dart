import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/storage/secure_storage.dart';
import 'package:household/models/app_user.dart';
import 'package:household/repositories/auth_repository.dart';

/// ChangeNotifierProvider so GoRouter can use it as refreshListenable.
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
  );
});

class AuthService extends ChangeNotifier {
  final AuthRepository _repo;
  final SecureStorage _storage;

  AuthService(this._repo, this._storage);

  String? accessToken;
  AppUser? currentUser;

  bool get isLoggedIn => accessToken != null && currentUser != null;

  /// Called at app startup — restores session from secure storage.
  Future<void> tryRestoreSession() async {
    final token = await _storage.getAccessToken();
    if (token == null) return;
    accessToken = token;
    try {
      final data = await _repo.getProfile();
      // Profile endpoint may return { appUser: {...} } or the user directly.
      final userJson = data['appUser'] ?? data['user'] ?? data;
      currentUser = AppUser.fromJson(userJson as Map<String, dynamic>);
    } catch (_) {
      final refreshed = await tryRefresh();
      if (!refreshed) {
        accessToken = null;
        currentUser = null;
      }
    }
    // No notifyListeners here — called before the widget tree exists.
  }

  Future<void> signIn(String username, String password) async {
    final data = await _repo.signIn(username, password);
    accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    await _storage.saveTokens(
      accessToken: accessToken!,
      refreshToken: refreshToken,
    );
    final userJson = data['user'] ?? data['appUser'];
    currentUser = AppUser.fromJson(userJson as Map<String, dynamic>);
    notifyListeners(); // triggers GoRouter redirect
  }

  /// Called by AuthInterceptor on 401.
  Future<bool> tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final data = await _repo.refresh(refreshToken);
      accessToken = data['accessToken'] as String;
      await _storage.saveTokens(
        accessToken: accessToken!,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
      );
      return true;
    } catch (_) {
      await signOut();
      return false;
    }
  }

  Future<void> signOut() async {
    accessToken = null;
    currentUser = null;
    await _storage.clearTokens();
    notifyListeners(); // triggers GoRouter redirect back to /login
  }
}
