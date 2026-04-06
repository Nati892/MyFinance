import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/widgets/app_shell.dart';
import 'package:household/screens/login/login_screen.dart';
import 'package:household/screens/home/home_screen.dart';
import 'package:household/screens/expenses/expenses_screen.dart';
import 'package:household/screens/incomes/incomes_screen.dart';
import 'package:household/screens/budget/budget_screen.dart';
import 'package:household/screens/assets/assets_screen.dart';
import 'package:household/screens/board/board_screen.dart';
import 'package:household/screens/credit_cards/credit_cards_screen.dart';
import 'package:household/screens/transactions/transactions_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/transactions',
    refreshListenable: authService,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authService.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/transactions';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // All authenticated routes share the AppShell (header + bottom nav)
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
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
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/board',
            builder: (context, state) => const BoardScreen(),
          ),
          GoRoute(
            path: '/credit-cards',
            builder: (context, state) => const CreditCardsScreen(),
          ),
        ],
      ),
    ],
  );
});
