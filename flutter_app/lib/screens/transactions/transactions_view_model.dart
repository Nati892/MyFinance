import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';
import 'package:household/widgets/transaction_timeline.dart';

final transactionsViewModelProvider =
    ChangeNotifierProvider.autoDispose<TransactionsViewModel>((ref) {
  return TransactionsViewModel(
    ref.read(transactionServiceProvider),
    ref.read(categoryRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

enum TransactionsLoadState { idle, loading, error }

class TransactionsViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final CategoryRepository _categoryRepo;
  final HouseholdService _householdService;

  TransactionsViewModel(
      this._txService, this._categoryRepo, this._householdService) {
    load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Expense> expenses = [];
  List<Income> incomes = [];
  List<Category> expenseCategories = [];
  List<Category> incomeCategories = [];
  List<Category> expenseFavoriteCategories = [];

  // ── State ──────────────────────────────────────────────────────────────────
  TransactionsLoadState state = TransactionsLoadState.loading;
  String? errorMessage;

  // ── View config ────────────────────────────────────────────────────────────
  String viewType = 'monthly'; // 'monthly' | 'weekly' | 'daily'
  int periodOffset = 0;
  int? weekNumber;
  String? date;

  /// 'all' | 'expenses' | 'incomes'
  String viewMode = 'all';

  /// Category filter (applies to combined list by category id)
  int? filterCategoryId;

  /// Optional price range filter
  double? priceMin;
  double? priceMax;

  bool get noHousehold => _householdService.currentHouseholdId == null;
  int get householdId => _householdService.currentHouseholdId ?? 0;

  // Sidebar shows combined deduped categories
  List<Category> get allCategories {
    final seen = <int>{};
    final combined = <Category>[];
    for (final c in [...expenseCategories, ...incomeCategories]) {
      if (seen.add(c.id)) combined.add(c);
    }
    return combined;
  }

  List<Category> get favoriteCategories => expenseFavoriteCategories;

  /// The filtered + combined list of TimelineTx items to show.
  List<TimelineTx> get filteredTransactions {
    final List<TimelineTx> all = [];

    if (viewMode != 'incomes') {
      all.addAll(expenses.map(TimelineTx.fromExpense));
    }
    if (viewMode != 'expenses') {
      all.addAll(incomes.map(TimelineTx.fromIncome));
    }

    return all.where((tx) {
      if (filterCategoryId != null) {
        // look up the category id from the original objects
        if (tx.txType == 'expense') {
          final e = expenses.firstWhere((x) => x.id == tx.id,
              orElse: () => expenses.first);
          if (e.category?.id != filterCategoryId) return false;
        } else {
          final i = incomes.firstWhere((x) => x.id == tx.id,
              orElse: () => incomes.first);
          if (i.category?.id != filterCategoryId) return false;
        }
      }
      if (priceMin != null && tx.amount < priceMin!) return false;
      if (priceMax != null && tx.amount > priceMax!) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // ── Modal state ────────────────────────────────────────────────────────────
  bool modalOpen = false;
  bool modalSaving = false;
  String? modalError;
  bool isEditMode = false;
  int? editingId;
  /// true = expense form, false = income form
  bool isExpenseMode = true;

  // Form fields (shared between expense/income forms)
  double? formAmount;
  int? formCategoryId;
  DateTime formDateTime = DateTime.now();
  String formPaymentMethod = 'credit_card';
  String formDescription = '';
  String formNote = '';

  // ── Load ───────────────────────────────────────────────────────────────────

  void load() {
    loadCategories();
    loadTransactions();
  }

  Future<void> loadCategories() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      final results = await Future.wait([
        _categoryRepo.getExpenseCategories(hid),
        _categoryRepo.getIncomeCategories(hid),
        _categoryRepo.getExpenseFavorites(hid),
      ]);
      expenseCategories = results[0];
      incomeCategories = results[1];
      expenseFavoriteCategories = results[2];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadTransactions() async {
    state = TransactionsLoadState.loading;
    notifyListeners();
    try {
      final expensesFuture = _txService.getExpenses(
        view: viewType,
        periodOffset: periodOffset,
        weekNumber: weekNumber,
        date: date,
      );
      final incomesFuture = _txService.getIncomes(
        view: viewType,
        periodOffset: periodOffset,
        weekNumber: weekNumber,
        date: date,
      );
      expenses = await expensesFuture;
      incomes = await incomesFuture;
      state = TransactionsLoadState.idle;
    } catch (e) {
      state = TransactionsLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── View config changes ────────────────────────────────────────────────────

  void onViewChanged({
    required String view,
    required int offset,
    int? week,
    String? dayDate,
  }) {
    viewType = view;
    periodOffset = offset;
    weekNumber = week;
    date = dayDate;
    loadTransactions();
  }

  void onCategorySelected(int? categoryId) {
    filterCategoryId = categoryId;
    notifyListeners();
  }

  void onCategoryQuickAdd(int categoryId) {
    // Determine if this category belongs to expense or income
    final isExpense = expenseCategories.any((c) => c.id == categoryId);
    if (isExpense) {
      openAddExpenseModal(categoryId: categoryId);
    } else {
      openAddIncomeModal(categoryId: categoryId);
    }
  }

  void setViewMode(String mode) {
    viewMode = mode;
    notifyListeners();
  }

  void setPriceMin(double? v) {
    priceMin = v;
    notifyListeners();
  }

  void setPriceMax(double? v) {
    priceMax = v;
    notifyListeners();
  }

  // ── Modal open/close ───────────────────────────────────────────────────────

  void openAddExpenseModal({int? categoryId}) {
    isExpenseMode = true;
    isEditMode = false;
    editingId = null;
    modalError = null;
    formAmount = null;
    formCategoryId = categoryId ?? filterCategoryId;
    formDateTime = DateTime.now();
    formPaymentMethod = 'credit_card';
    formDescription = '';
    formNote = '';
    modalOpen = true;
    notifyListeners();
  }

  void openAddIncomeModal({int? categoryId}) {
    isExpenseMode = false;
    isEditMode = false;
    editingId = null;
    modalError = null;
    formAmount = null;
    formCategoryId = categoryId ?? filterCategoryId;
    formDateTime = DateTime.now();
    formPaymentMethod = 'credit_card';
    formDescription = '';
    formNote = '';
    modalOpen = true;
    notifyListeners();
  }

  void openEditExpenseModal(Expense expense) {
    isExpenseMode = true;
    isEditMode = true;
    editingId = expense.id;
    modalError = null;
    formAmount = expense.amount;
    formCategoryId = expense.category?.id;
    formDateTime = DateTime.parse(expense.dateTime).toLocal();
    formPaymentMethod = expense.paymentMethod;
    formDescription = expense.description ?? '';
    formNote = expense.note ?? '';
    modalOpen = true;
    notifyListeners();
  }

  void openEditIncomeModal(Income income) {
    isExpenseMode = false;
    isEditMode = true;
    editingId = income.id;
    modalError = null;
    formAmount = income.amount;
    formCategoryId = income.category?.id;
    formDateTime = DateTime.parse(income.dateTime).toLocal();
    formPaymentMethod = income.paymentMethod;
    formDescription = income.description ?? '';
    formNote = income.note ?? '';
    modalOpen = true;
    notifyListeners();
  }

  void closeModal() {
    modalOpen = false;
    modalError = null;
    notifyListeners();
  }

  void setFormAmount(double? v) { formAmount = v; notifyListeners(); }
  void setFormCategory(int? id)  { formCategoryId = id; notifyListeners(); }
  void setFormDateTime(DateTime dt) { formDateTime = dt; notifyListeners(); }
  void setFormPayment(String method) { formPaymentMethod = method; notifyListeners(); }
  void setFormDescription(String v) { formDescription = v; notifyListeners(); }
  void setFormNote(String v) { formNote = v; notifyListeners(); }

  // ── Save / Delete ──────────────────────────────────────────────────────────

  Future<void> saveExpense() async {
    if (formAmount == null || formAmount! <= 0) {
      modalError = 'Please enter a valid amount.';
      notifyListeners();
      return;
    }
    if (formCategoryId == null) {
      modalError = 'Please select a category.';
      notifyListeners();
      return;
    }

    modalSaving = true;
    modalError = null;
    notifyListeners();

    try {
      final isoDateTime = formDateTime.toUtc().toIso8601String();

      if (!isEditMode) {
        await _txService.createExpense(
          amount: formAmount!,
          dateTime: isoDateTime,
          paymentMethod: formPaymentMethod,
          expenseCategoryId: formCategoryId!,
          description: formDescription.isNotEmpty ? formDescription : null,
          note: formNote.isNotEmpty ? formNote : null,
        );
      } else {
        await _txService.updateExpense(editingId!, {
          'amount': formAmount,
          'dateTime': isoDateTime,
          'paymentMethod': formPaymentMethod,
          'expenseCategoryId': formCategoryId,
          'description': formDescription,
          'note': formNote,
        });
      }

      modalSaving = false;
      modalOpen = false;
      notifyListeners();
      load();
    } catch (e) {
      modalSaving = false;
      modalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  Future<void> saveIncome() async {
    if (formAmount == null || formAmount! <= 0) {
      modalError = 'Please enter a valid amount.';
      notifyListeners();
      return;
    }
    if (formCategoryId == null) {
      modalError = 'Please select a category.';
      notifyListeners();
      return;
    }

    modalSaving = true;
    modalError = null;
    notifyListeners();

    try {
      final isoDateTime = formDateTime.toUtc().toIso8601String();

      if (!isEditMode) {
        await _txService.createIncome(
          amount: formAmount!,
          dateTime: isoDateTime,
          paymentMethod: formPaymentMethod,
          incomeCategoryId: formCategoryId!,
          description: formDescription.isNotEmpty ? formDescription : null,
          note: formNote.isNotEmpty ? formNote : null,
        );
      } else {
        await _txService.updateIncome(editingId!, {
          'amount': formAmount,
          'dateTime': isoDateTime,
          'paymentMethod': formPaymentMethod,
          'incomeCategoryId': formCategoryId,
          'description': formDescription,
          'note': formNote,
        });
      }

      modalSaving = false;
      modalOpen = false;
      notifyListeners();
      load();
    } catch (e) {
      modalSaving = false;
      modalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  // ── Add category (from sheet) ──────────────────────────────────────────────

  void addExpenseCategory(Category cat) {
    expenseCategories = [...expenseCategories, cat];
    notifyListeners();
  }

  void addIncomeCategory(Category cat) {
    incomeCategories = [...incomeCategories, cat];
    notifyListeners();
  }

  Future<void> deleteExpense(Expense expense) async {
    try {
      await _txService.deleteExpense(expense.id);
      load();
    } catch (_) {}
  }

  Future<void> deleteIncome(Income income) async {
    try {
      await _txService.deleteIncome(income.id);
      load();
    } catch (_) {}
  }
}
