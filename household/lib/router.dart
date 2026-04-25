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
import 'package:household/screens/settings/settings_screen.dart';
import 'package:household/screens/statistics/statistics_screen.dart';
import 'package:household/screens/schedules/schedules_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/app/transactions',
    refreshListenable: authService,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authService.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/app/login';

      if (!isLoggedIn && !isOnLogin) return '/app/login';
      if (isLoggedIn && isOnLogin) return '/app/transactions';
      return null;
    },
    routes: [
      GoRoute(
        path: '/app/login',
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
            path: '/app/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/app/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/app/incomes',
            builder: (context, state) => const IncomesScreen(),
          ),
          GoRoute(
            path: '/app/budget',
            builder: (context, state) => const BudgetScreen(),
          ),
          GoRoute(
            path: '/app/assets',
            builder: (context, state) => const AssetsScreen(),
          ),
          GoRoute(
            path: '/app/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/app/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/app/board',
            builder: (context, state) => const BoardScreen(),
          ),
          GoRoute(
            path: '/app/credit-cards',
            builder: (context, state) => const CreditCardsScreen(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/app/schedules',
            builder: (context, state) => const SchedulesScreen(),
          ),
        ],
      ),
    ],
  );
});
