import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/expense.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';

final expensesViewModelProvider =
    ChangeNotifierProvider.autoDispose<ExpensesViewModel>((ref) {
  return ExpensesViewModel(
    ref.read(transactionServiceProvider),
    ref.read(categoryRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

enum ExpensesLoadState { idle, loading, error }

class ExpensesViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final CategoryRepository _categoryRepo;
  final HouseholdService _householdService;

  ExpensesViewModel(this._txService, this._categoryRepo, this._householdService) {
    load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Expense> expenses = [];
  List<Category> categories = [];
  List<Category> favoriteCategories = [];

  // ── State ──────────────────────────────────────────────────────────────────
  ExpensesLoadState state = ExpensesLoadState.loading;
  String? errorMessage;

  // ── View config ────────────────────────────────────────────────────────────
  String viewType = 'monthly'; // 'monthly' | 'weekly' | 'daily'
  int periodOffset = 0;
  int? weekNumber;
  String? date;
  int? selectedCategoryId;

  // ── Modal ──────────────────────────────────────────────────────────────────
  bool modalOpen = false;
  bool modalSaving = false;
  String? modalError;
  bool isEditMode = false;
  int? editingId;

  // Form fields
  double? formAmount;
  int? formCategoryId;
  DateTime formDateTime = DateTime.now();
  String formPaymentMethod = 'credit_card';
  String formDescription = '';
  String formNote = '';

  bool get noHousehold => _householdService.currentHouseholdId == null;
  int get householdId => _householdService.currentHouseholdId ?? 0;

  // ── Load ───────────────────────────────────────────────────────────────────

  void load() {
    loadCategories();
    loadExpenses();
  }

  Future<void> loadCategories() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      final results = await Future.wait([
        _categoryRepo.getExpenseCategories(hid),
        _categoryRepo.getExpenseFavorites(hid),
      ]);
      categories = results[0];
      favoriteCategories = results[1];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadExpenses() async {
    state = ExpensesLoadState.loading;
    notifyListeners();
    try {
      expenses = await _txService.getExpenses(
        view: viewType,
        periodOffset: periodOffset,
        categoryId: selectedCategoryId,
        weekNumber: weekNumber,
        date: date,
      );
      state = ExpensesLoadState.idle;
    } catch (e) {
      state = ExpensesLoadState.error;
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
    loadExpenses();
  }

  void onCategorySelected(int? categoryId) {
    selectedCategoryId = categoryId;
    notifyListeners();
    loadExpenses();
  }

  void onCategoryQuickAdd(int categoryId) {
    openAddModal(categoryId: categoryId);
  }

  // ── Modal ──────────────────────────────────────────────────────────────────

  void openAddModal({int? categoryId}) {
    isEditMode = false;
    editingId = null;
    modalError = null;
    formAmount = null;
    formCategoryId = categoryId ?? selectedCategoryId;
    formDateTime = DateTime.now();
    formPaymentMethod = 'credit_card';
    formDescription = '';
    formNote = '';
    modalOpen = true;
    notifyListeners();
  }

  void openEditModal(Expense expense) {
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

  void closeModal() {
    modalOpen = false;
    modalError = null;
    notifyListeners();
  }

  void setFormAmount(double? v)       { formAmount = v; notifyListeners(); }
  void setFormCategory(int? id)        { formCategoryId = id; notifyListeners(); }
  void setFormDateTime(DateTime dt)    { formDateTime = dt; notifyListeners(); }
  void setFormPayment(String method)   { formPaymentMethod = method; notifyListeners(); }
  void setFormDescription(String v)    { formDescription = v; notifyListeners(); }
  void setFormNote(String v)           { formNote = v; notifyListeners(); }

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

  Future<void> deleteExpense(Expense expense) async {
    try {
      await _txService.deleteExpense(expense.id);
      load();
    } catch (_) {}
  }

  // ── Add category (from sheet) ──────────────────────────────────────────────

  void addCategory(Category cat) {
    categories = [...categories, cat];
    notifyListeners();
  }

  // ── Create category ────────────────────────────────────────────────────────

  Future<void> createCategory(String name, String color, String icon) async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      await _categoryRepo.createExpenseCategory({
        'name': name,
        'color': color,
        'icon': icon,
        'householdId': hid,
      });
      await loadCategories();
    } catch (_) {}
  }
}
