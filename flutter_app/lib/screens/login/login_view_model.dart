import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/services/household_service.dart';

final loginViewModelProvider =
    ChangeNotifierProvider.autoDispose<LoginViewModel>((ref) {
  return LoginViewModel(
    ref.read(authServiceProvider),
    ref.read(householdServiceProvider),
  );
});

enum LoginState { idle, loading, noHousehold, error }

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;
  final HouseholdService _householdService;

  LoginViewModel(this._authService, this._householdService);

  LoginState state = LoginState.idle;
  String? errorMessage;
  bool obscurePassword = true;

  bool get isLoading => state == LoginState.loading;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      errorMessage = 'Please enter your username and password';
      state = LoginState.error;
      notifyListeners();
      return;
    }

    state = LoginState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(username.trim(), password);

      final user = _authService.currentUser!;
      if (user.households.isEmpty) {
        state = LoginState.noHousehold;
        notifyListeners();
        return;
      }

      // Seed the household service — GoRouter redirect handles navigation.
      _householdService.setHouseholds(user.households);
      state = LoginState.idle;
      notifyListeners();
    } on Exception catch (e) {
      state = LoginState.error;
      final msg = e.toString();
      // Strip "Exception: " prefix if present
      errorMessage = msg.startsWith('Exception: ')
          ? msg.substring('Exception: '.length)
          : 'Invalid username or password';
      notifyListeners();
    }
  }
}
