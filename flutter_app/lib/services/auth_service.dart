import 'package:dio/dio.dart';
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
    final storedToken = await _storage.getAccessToken();
    if (storedToken == null) return;
    accessToken = storedToken;

    try {
      // Try the stored access token first.
      final data = await _repo.getProfile(token: storedToken);
      final userJson = Map<String, dynamic>.from(
        (data['appUser'] ?? data['user'] ?? data) as Map<String, dynamic>,
      );
      // Profile endpoint returns households at the top level rather than
      // nested inside the user object (unlike sign-in).
      if (userJson['households'] == null && data['households'] != null) {
        userJson['households'] = data['households'];
      }
      currentUser = AppUser.fromJson(userJson);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        // Access token expired — try the refresh token.
        final refreshed = await tryRefresh();
        if (refreshed) {
          try {
            final data = await _repo.getProfile(token: accessToken!);
            final userJson = Map<String, dynamic>.from(
              (data['appUser'] ?? data['user'] ?? data) as Map<String, dynamic>,
            );
            if (userJson['households'] == null && data['households'] != null) {
              userJson['households'] = data['households'];
            }
            currentUser = AppUser.fromJson(userJson);
          } catch (_) {
            // Profile fetch failed even after refresh — force sign-out.
            await signOut();
          }
        }
        // If !refreshed, tryRefresh already called signOut() — tokens/user cleared.
      } else {
        // Network error or other transient failure — don't wipe tokens.
        // User will see login screen this launch but tokens survive for next attempt.
        accessToken = null;
      }
    } catch (_) {
      // Non-network exception (e.g. JSON parse error) — don't wipe tokens.
      accessToken = null;
    }
    // notifyListeners intentionally omitted — called before the widget tree exists.
  }

  Future<void> signIn(String username, String password) async {
    final data = await _repo.signIn(username, password);
    accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final userJson = data['user'] ?? data['appUser'];
    currentUser = AppUser.fromJson(userJson as Map<String, dynamic>);
    await _storage.saveTokens(
      accessToken: accessToken!,
      refreshToken: refreshToken,
      userId: currentUser!.id,
    );
    notifyListeners(); // triggers GoRouter redirect
  }

  /// Called by AuthInterceptor on 401.
  Future<bool> tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    final userId = await _storage.getUserId();
    if (refreshToken == null || userId == null) return false;
    try {
      final data = await _repo.refresh(refreshToken, userId);
      accessToken = data['accessToken'] as String;
      await _storage.saveTokens(
        accessToken: accessToken!,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
        userId: userId,
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 401 ||
          e.response?.statusCode == 403) {
        // Refresh token is definitively rejected — clear everything.
        await signOut();
      }
      // Network error or other transient failure — don't wipe tokens.
      return false;
    } catch (_) {
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
