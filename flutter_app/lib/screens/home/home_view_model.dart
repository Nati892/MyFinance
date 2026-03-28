import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';

final homeViewModelProvider =
    ChangeNotifierProvider.autoDispose<HomeViewModel>((ref) {
  return HomeViewModel(
    ref.read(transactionServiceProvider),
    ref.read(householdServiceProvider),
  );
});

enum HomeLoadState { idle, loading, error }

class HomeViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final HouseholdService _householdService;

  HomeViewModel(this._txService, this._householdService) {
    load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Expense> expenses = [];
  List<Income> incomes = [];

  // ── State ──────────────────────────────────────────────────────────────────
  HomeLoadState state = HomeLoadState.loading;
  String? errorMessage;

  bool get noHousehold => _householdService.currentHouseholdId == null;

  // ── Computed summaries ─────────────────────────────────────────────────────

  double get totalExpenses =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);

  double get totalIncomes =>
      incomes.fold(0.0, (sum, i) => sum + i.amount);

  double get balance => totalIncomes - totalExpenses;

  /// Most recent transactions (expenses + incomes), sorted newest first, limited to 10.
  List<RecentTx> get recentTransactions {
    final List<RecentTx> all = [
      ...expenses.map((e) => RecentTx.fromExpense(e)),
      ...incomes.map((i) => RecentTx.fromIncome(i)),
    ];
    all.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return all.take(10).toList();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_householdService.currentHouseholdId == null) return;
    state = HomeLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait([
        _txService.getExpenses(view: 'monthly', periodOffset: 0),
        _txService.getIncomes(view: 'monthly', periodOffset: 0),
      ]);
      expenses = results[0] as List<Expense>;
      incomes = results[1] as List<Income>;
      state = HomeLoadState.idle;
    } catch (e) {
      state = HomeLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }
}

// ── Helper model ──────────────────────────────────────────────────────────────

class RecentTx {
  final int id;
  final bool isExpense;
  final double amount;
  final String dateTime;
  final String? description;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;

  const RecentTx({
    required this.id,
    required this.isExpense,
    required this.amount,
    required this.dateTime,
    this.description,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
  });

  factory RecentTx.fromExpense(Expense e) => RecentTx(
        id: e.id,
        isExpense: true,
        amount: e.amount,
        dateTime: e.dateTime,
        description: e.description,
        categoryName: e.category?.name,
        categoryColor: e.category?.color,
        categoryIcon: e.category?.icon,
      );

  factory RecentTx.fromIncome(Income i) => RecentTx(
        id: i.id,
        isExpense: false,
        amount: i.amount,
        dateTime: i.dateTime,
        description: i.description,
        categoryName: i.category?.name,
        categoryColor: i.category?.color,
        categoryIcon: i.category?.icon,
      );
}
