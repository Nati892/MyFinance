import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/screens/login/login_screen.dart';
import 'package:household/screens/home/home_screen.dart';
import 'package:household/screens/expenses/expenses_screen.dart';
import 'package:household/screens/incomes/incomes_screen.dart';
import 'package:household/screens/budget/budget_screen.dart';
import 'package:household/screens/assets/assets_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/expenses',
    // GoRouter re-runs redirect whenever authService calls notifyListeners()
    refreshListenable: authService,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authService.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/expenses';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/incomes',
        builder: (context, state) => const IncomesScreen(),
      ),
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/assets',
        builder: (context, state) => const AssetsScreen(),
      ),
    ],
  );
});
