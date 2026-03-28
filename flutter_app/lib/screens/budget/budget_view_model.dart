import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/budget.dart';
import 'package:household/services/budget_service.dart';
import 'package:household/services/household_service.dart';

final budgetViewModelProvider =
    ChangeNotifierProvider.autoDispose<BudgetViewModel>((ref) {
  return BudgetViewModel(
    ref.read(budgetServiceProvider),
    ref.read(householdServiceProvider),
  );
});

enum BudgetLoadState { idle, loading, error }

/// View modes matching the Angular component: table vs. graph.
enum BudgetViewMode { table, graph }

/// Graph sub-modes: spending by week or by month.
enum GraphMode { week, month }

/// Whether an inline edit applies to the recurring base budget or just this month.
enum EditMode { base, month }

class BudgetViewModel extends ChangeNotifier {
  final BudgetService _budgetService;
  final HouseholdService _householdService;

  BudgetViewModel(this._budgetService, this._householdService) {
    _initPeriod();
    load();
  }

  // ── Period ──────────────────────────────────────────────────────────────────
  late int currentYear;
  late int currentMonth; // 1-12

  void _initPeriod() {
    final now = DateTime.now();
    currentYear = now.year;
    currentMonth = now.month;
  }

  bool get isCurrentMonth {
    final now = DateTime.now();
    return currentYear == now.year && currentMonth == now.month;
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get monthLabel => '${_monthNames[currentMonth - 1]} $currentYear';

  void prevMonth() {
    if (currentMonth == 1) {
      currentMonth = 12;
      currentYear--;
    } else {
      currentMonth--;
    }
    load();
    if (viewMode == BudgetViewMode.graph) _loadGraphData();
  }

  void nextMonth() {
    if (currentMonth == 12) {
      currentMonth = 1;
      currentYear++;
    } else {
      currentMonth++;
    }
    load();
    if (viewMode == BudgetViewMode.graph) _loadGraphData();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  List<MonthBudgetRow> budgetRows = [];
  List<WeekSpend> weekData = [];
  List<MonthSpend> monthData = [];

  // ── Load state ──────────────────────────────────────────────────────────────
  BudgetLoadState state = BudgetLoadState.loading;
  bool graphLoading = false;
  String? errorMessage;

  // ── View mode ───────────────────────────────────────────────────────────────
  BudgetViewMode viewMode = BudgetViewMode.table;
  GraphMode graphMode = GraphMode.week;

  int? selectedCategoryId;

  bool get noHousehold => _householdService.currentHouseholdId == null;

  // ── Inline budget editing ───────────────────────────────────────────────────
  int? editingBudgetCategoryId;
  EditMode editingBudgetMode = EditMode.base;
  double? editingBudgetValue;

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = BudgetLoadState.loading;
    notifyListeners();
    try {
      budgetRows = await _budgetService.getMonthlyBudget(
        year: currentYear,
        month: currentMonth,
      );
      state = BudgetLoadState.idle;
    } catch (e) {
      state = BudgetLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── View mode ───────────────────────────────────────────────────────────────

  void setViewMode(BudgetViewMode mode) {
    viewMode = mode;
    if (mode == BudgetViewMode.graph) _loadGraphData();
    notifyListeners();
  }

  void setGraphMode(GraphMode mode) {
    graphMode = mode;
    _loadGraphData();
    notifyListeners();
  }

  void onCategoryChanged(int? categoryId) {
    selectedCategoryId = categoryId;
    notifyListeners();
    _loadGraphData();
  }

  void _loadGraphData() {
    if (graphMode == GraphMode.week) {
      _loadWeekGraph();
    } else {
      _loadMonthGraph();
    }
  }

  Future<void> _loadWeekGraph() async {
    graphLoading = true;
    notifyListeners();
    try {
      weekData = await _budgetService.getByWeek(
        year: currentYear,
        month: currentMonth,
        expenseCategoryId: selectedCategoryId,
      );
    } catch (_) {}
    graphLoading = false;
    notifyListeners();
  }

  Future<void> _loadMonthGraph() async {
    graphLoading = true;
    notifyListeners();
    try {
      int startMonth = currentMonth - 5;
      int startYear = currentYear;
      if (startMonth < 1) {
        startMonth += 12;
        startYear--;
      }
      monthData = await _budgetService.getByMonth(
        year: startYear,
        startMonth: startMonth,
        endMonth: currentMonth,
        expenseCategoryId: selectedCategoryId,
      );
    } catch (_) {}
    graphLoading = false;
    notifyListeners();
  }

  // ── Inline editing ──────────────────────────────────────────────────────────

  void startEditBudget(MonthBudgetRow row, {EditMode mode = EditMode.base}) {
    editingBudgetCategoryId = row.id;
    editingBudgetMode = mode;
    editingBudgetValue = mode == EditMode.month
        ? (row.override ?? row.baseBudget)
        : row.baseBudget;
    notifyListeners();
  }

  void setEditMode(EditMode mode, MonthBudgetRow row) {
    editingBudgetMode = mode;
    editingBudgetValue = mode == EditMode.month
        ? (row.override ?? row.baseBudget)
        : row.baseBudget;
    notifyListeners();
  }

  void setEditingValue(double? v) {
    editingBudgetValue = v;
    notifyListeners();
  }

  void cancelEdit() {
    editingBudgetCategoryId = null;
    editingBudgetValue = null;
    notifyListeners();
  }

  Future<void> commitEdit(int categoryId) async {
    final v = editingBudgetValue;
    if (v == null || v < 0) {
      cancelEdit();
      return;
    }
    try {
      if (editingBudgetMode == EditMode.base) {
        await _budgetService.setBaseBudget(
          expenseCategoryId: categoryId,
          amount: v,
        );
      } else {
        await _budgetService.overrideBudget(
          expenseCategoryId: categoryId,
          year: currentYear,
          month: currentMonth,
          amount: v,
        );
      }
    } catch (_) {}
    editingBudgetCategoryId = null;
    editingBudgetValue = null;
    await load();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool isOverBudget(MonthBudgetRow row) =>
      row.result != null && row.result! > 0;

  /// Returns the progress fraction (0.0–1.0+) for spent vs effectiveBudget.
  double spentFraction(MonthBudgetRow row) {
    final budget = row.effectiveBudget;
    if (budget == null || budget <= 0) return 0;
    return row.spent / budget;
  }
}
