import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/budget.dart';
import 'package:household/models/category.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/budget_service.dart';
import 'package:household/services/household_service.dart';

final budgetViewModelProvider =
    ChangeNotifierProvider.autoDispose<BudgetViewModel>((ref) {
  return BudgetViewModel(
    ref.read(budgetServiceProvider),
    ref.read(householdServiceProvider),
    ref.read(categoryRepositoryProvider),
  );
});

enum BudgetLoadState { idle, loading, error }

/// View modes matching the Angular component: table vs. graph, plus plan.
enum BudgetViewMode { table, graph, plan }

/// Graph sub-modes: spending by week or by month.
enum GraphMode { week, month }

/// Whether an inline edit applies to the recurring base budget or just this month.
enum EditMode { base, month }

class BudgetViewModel extends ChangeNotifier {
  final BudgetService _budgetService;
  final HouseholdService _householdService;
  final CategoryRepository _categoryRepo;

  BudgetViewModel(this._budgetService, this._householdService, this._categoryRepo) {
    _initPeriod();
    load();
    loadExpenseCategories();
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

  static const _monthNamesEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthNamesHe = [
    'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  String monthLabel(String locale) {
    final names = locale == 'he' ? _monthNamesHe : _monthNamesEn;
    return '${names[currentMonth - 1]} $currentYear';
  }

  void prevMonth() {
    if (currentMonth == 1) {
      currentMonth = 12;
      currentYear--;
    } else {
      currentMonth--;
    }
    load();
    if (viewMode == BudgetViewMode.graph) _loadGraphData();
    if (viewMode == BudgetViewMode.plan) loadPlanData();
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
    if (viewMode == BudgetViewMode.plan) loadPlanData();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  List<MonthBudgetRow> budgetRows = [];
  List<WeekSpend> weekData = [];
  List<MonthSpend> monthData = [];
  List<Category> allExpenseCategories = [];

  // ── Plan data ────────────────────────────────────────────────────────────────
  List<BudgetPlanItem> planItems = [];
  BudgetMonthConfig? planMonthConfig;
  bool planLoading = false;

  /// IDs of categories currently expanded in plan view.
  Set<int> expandedPlanCategories = {};

  // ── Load state ──────────────────────────────────────────────────────────────
  BudgetLoadState state = BudgetLoadState.loading;
  bool graphLoading = false;
  String? errorMessage;

  // ── View mode ───────────────────────────────────────────────────────────────
  BudgetViewMode viewMode = BudgetViewMode.table;
  GraphMode graphMode = GraphMode.week;

  int? selectedCategoryId;

  bool get noHousehold => _householdService.currentHouseholdId == null;
  int? get householdId => _householdService.currentHouseholdId;

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

  Future<void> loadExpenseCategories() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      allExpenseCategories = await _categoryRepo.getExpenseCategories(hid);
      notifyListeners();
    } catch (_) {}
  }


  void setViewMode(BudgetViewMode mode) {
    viewMode = mode;
    if (mode == BudgetViewMode.graph) _loadGraphData();
    if (mode == BudgetViewMode.plan) {
      loadExpenseCategories();
      loadPlanData();
      // Start all categories expanded by default
    }
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

  // ── Plan data ────────────────────────────────────────────────────────────────

  Future<void> loadPlanData() async {
    planLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _budgetService.getPlanItems(year: currentYear, month: currentMonth),
        _budgetService.getMonthConfig(year: currentYear, month: currentMonth),
      ]);
      planItems = results[0] as List<BudgetPlanItem>;
      planMonthConfig = results[1] as BudgetMonthConfig?;

      // Default all categories to expanded
      if (expandedPlanCategories.isEmpty && allExpenseCategories.isNotEmpty) {
        expandedPlanCategories = {
          ...allExpenseCategories.map((c) => c.id),
          ...allExpenseCategories.expand((c) => c.subCategories.map((s) => s.id)),
        };
      }
    } catch (_) {}
    planLoading = false;
    notifyListeners();
  }

  void togglePlanCategoryExpanded(int categoryId) {
    if (expandedPlanCategories.contains(categoryId)) {
      expandedPlanCategories = {...expandedPlanCategories}..remove(categoryId);
    } else {
      expandedPlanCategories = {...expandedPlanCategories, categoryId};
    }
    notifyListeners();
  }

  List<BudgetPlanItem> planItemsForCategory(int categoryId) =>
      planItems.where((i) => i.expenseCategoryId == categoryId).toList();

  double planMinTotalForCategory(int categoryId) =>
      planItemsForCategory(categoryId).fold(0.0, (sum, i) => sum + i.minAmount);

  double planMaxTotalForCategory(int categoryId) =>
      planItemsForCategory(categoryId).fold(0.0, (sum, i) => sum + i.maxAmount);

  /// Sum of min amounts for a parent category AND all its subcategories.
  double planMinTotalForCategoryTree(Category cat) =>
      planMinTotalForCategory(cat.id) +
      cat.subCategories.fold(0.0, (sum, sub) => sum + planMinTotalForCategory(sub.id));

  /// Sum of max amounts for a parent category AND all its subcategories.
  double planMaxTotalForCategoryTree(Category cat) =>
      planMaxTotalForCategory(cat.id) +
      cat.subCategories.fold(0.0, (sum, sub) => sum + planMaxTotalForCategory(sub.id));

  double get planGrandMin => planItems.fold(0.0, (sum, i) => sum + i.minAmount);
  double get planGrandMax => planItems.fold(0.0, (sum, i) => sum + i.maxAmount);

  Future<void> addPlanItem({
    required int categoryId,
  }) async {
    try {
      final item = await _budgetService.createPlanItem(
        expenseCategoryId: categoryId,
        year: currentYear,
        month: currentMonth,
        description: null,
        minAmount: 0,
        maxAmount: 0,
      );
      planItems = [...planItems, item];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updatePlanItem({
    required int id,
    required String? description,
    required double minAmount,
    required double maxAmount,
  }) async {
    try {
      final updated = await _budgetService.updatePlanItem(
        id: id,
        description: description,
        minAmount: minAmount,
        maxAmount: maxAmount,
      );
      planItems = planItems.map((i) => i.id == id ? updated : i).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deletePlanItem(int id) async {
    try {
      await _budgetService.deletePlanItem(id);
      planItems = planItems.where((i) => i.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPlanStartAmount(double? amount) async {
    planMonthConfig = BudgetMonthConfig(
        startAmount: amount, expectedIncome: planMonthConfig?.expectedIncome);
    notifyListeners();
    try {
      await _budgetService.upsertMonthConfig(
        year: currentYear,
        month: currentMonth,
        startAmount: amount,
        expectedIncome: planMonthConfig?.expectedIncome,
      );
    } catch (_) {}
  }

  Future<void> setExpectedIncome(double? income) async {
    planMonthConfig = BudgetMonthConfig(
        startAmount: planMonthConfig?.startAmount, expectedIncome: income);
    notifyListeners();
    try {
      await _budgetService.upsertMonthConfig(
        year: currentYear,
        month: currentMonth,
        startAmount: planMonthConfig?.startAmount,
        expectedIncome: income,
      );
    } catch (_) {}
  }

  // ── Category management (for plan view) ──────────────────────────────────────

  Future<void> createExpenseCategory(Map<String, dynamic> body) async {
    try {
      final cat = await _categoryRepo.createExpenseCategory(body);
      allExpenseCategories = [...allExpenseCategories, cat];
      // Auto-expand the new category
      expandedPlanCategories = {...expandedPlanCategories, cat.id};
      notifyListeners();
    } catch (_) {}
  }

  void updateExpenseCategoryInList(Category updated) {
    allExpenseCategories = allExpenseCategories.map((c) => c.id == updated.id ? updated : c).toList();
    notifyListeners();
  }

  Future<void> deleteExpenseCategory(int id, {bool deleteRefs = false}) async {
    try {
      await _categoryRepo.deleteExpenseCategory(id, deleteRefs: deleteRefs);
      allExpenseCategories = allExpenseCategories.where((c) => c.id != id).toList();
      planItems = planItems.where((i) => i.expenseCategoryId != id).toList();
      expandedPlanCategories = {...expandedPlanCategories}..remove(id);
      notifyListeners();
    } catch (_) {}
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
