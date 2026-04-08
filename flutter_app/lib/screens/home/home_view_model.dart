import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/services/budget_service.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';

final homeViewModelProvider =
    ChangeNotifierProvider.autoDispose<HomeViewModel>((ref) {
  return HomeViewModel(
    ref.read(transactionServiceProvider),
    ref.read(householdServiceProvider),
    ref.read(budgetServiceProvider),
  );
});

enum HomeLoadState { idle, loading, error }

class HomeViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final HouseholdService _householdService;
  final BudgetService _budgetService;

  HomeViewModel(this._txService, this._householdService, this._budgetService) {
    load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Expense> expenses = [];
  List<Income> incomes = [];

  /// Manually confirmed start amount for this month.
  double? _confirmedStartAmount;

  /// Whether the displayed start amount was manually set (vs predicted).
  bool _isStartConfirmed = false;

  /// Predicted start amount derived from previous month's end balance.
  double? _predictedStartAmount;

  // ── State ──────────────────────────────────────────────────────────────────
  HomeLoadState state = HomeLoadState.loading;
  bool isSavingStart = false;
  String? errorMessage;

  bool get noHousehold => _householdService.currentHouseholdId == null;

  // ── Computed summaries ─────────────────────────────────────────────────────

  double get totalExpenses => expenses.fold(0.0, (s, e) => s + e.amount);

  double get totalIncomes => incomes.fold(0.0, (s, i) => s + i.amount);

  double get balance => totalIncomes - totalExpenses;

  /// The effective start amount: confirmed if manually set, otherwise predicted.
  double? get startAmount =>
      _isStartConfirmed ? _confirmedStartAmount : _predictedStartAmount;

  bool get isStartConfirmed => _isStartConfirmed;

  bool get hasStartAmount => startAmount != null;

  /// Predicted end balance = startAmount + incomes - expenses.
  double? get predictedEndBalance =>
      startAmount != null ? startAmount! + totalIncomes - totalExpenses : null;

  List<RecentTx> get recentTransactions {
    final all = [
      ...expenses.map(RecentTx.fromExpense),
      ...incomes.map(RecentTx.fromIncome),
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
      final now = DateTime.now();

      final txFutures = await Future.wait([
        _txService.getExpenses(view: 'monthly', periodOffset: 0),
        _txService.getIncomes(view: 'monthly', periodOffset: 0),
      ]);
      expenses = txFutures[0] as List<Expense>;
      incomes = txFutures[1] as List<Income>;

      final config = await _budgetService.getMonthConfig(
          year: now.year, month: now.month);

      if (config?.startAmount != null) {
        _confirmedStartAmount = config!.startAmount;
        _isStartConfirmed = true;
        _predictedStartAmount = null;
      } else {
        _confirmedStartAmount = null;
        _isStartConfirmed = false;
        _predictedStartAmount = await _computePredictedStart(now);
      }

      state = HomeLoadState.idle;
    } catch (e) {
      state = HomeLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Computes the predicted start of [now] from previous month's confirmed end.
  Future<double?> _computePredictedStart(DateTime now) async {
    try {
      final prevYear = now.month == 1 ? now.year - 1 : now.year;
      final prevMonth = now.month == 1 ? 12 : now.month - 1;

      final prevConfig = await _budgetService.getMonthConfig(
          year: prevYear, month: prevMonth);
      if (prevConfig?.startAmount == null) return null;

      final prevTxFutures = await Future.wait([
        _txService.getExpenses(view: 'monthly', periodOffset: -1),
        _txService.getIncomes(view: 'monthly', periodOffset: -1),
      ]);
      final prevExpenses = prevTxFutures[0] as List<Expense>;
      final prevIncomes = prevTxFutures[1] as List<Income>;

      final prevExp = prevExpenses.fold(0.0, (s, e) => s + e.amount);
      final prevInc = prevIncomes.fold(0.0, (s, i) => s + i.amount);
      return prevConfig!.startAmount! + prevInc - prevExp;
    } catch (_) {
      return null;
    }
  }

  // ── Save start amount ──────────────────────────────────────────────────────

  Future<void> saveStartAmount(double amount) async {
    isSavingStart = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      await _budgetService.upsertMonthConfig(
          year: now.year, month: now.month, startAmount: amount);
      _confirmedStartAmount = amount;
      _isStartConfirmed = true;
      _predictedStartAmount = null;
    } finally {
      isSavingStart = false;
      notifyListeners();
    }
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
  final String? categoryNameHe;
  final String? categoryColor;
  final String? categoryIcon;

  const RecentTx({
    required this.id,
    required this.isExpense,
    required this.amount,
    required this.dateTime,
    this.description,
    this.categoryName,
    this.categoryNameHe,
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
        categoryNameHe: e.category?.nameHe,
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
        categoryNameHe: i.category?.nameHe,
        categoryColor: i.category?.color,
        categoryIcon: i.category?.icon,
      );
}
