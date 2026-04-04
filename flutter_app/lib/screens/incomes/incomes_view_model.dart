import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/income.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';

final incomesViewModelProvider =
    ChangeNotifierProvider.autoDispose<IncomesViewModel>((ref) {
  return IncomesViewModel(
    ref.read(transactionServiceProvider),
    ref.read(categoryRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

enum IncomesLoadState { idle, loading, error }

class IncomesViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final CategoryRepository _categoryRepo;
  final HouseholdService _householdService;

  IncomesViewModel(this._txService, this._categoryRepo, this._householdService) {
    load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Income> incomes = [];
  List<Category> categories = [];
  List<Category> favoriteCategories = [];

  // ── State ──────────────────────────────────────────────────────────────────
  IncomesLoadState state = IncomesLoadState.loading;
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
    loadIncomes();
  }

  Future<void> loadCategories() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      categories = await _categoryRepo.getIncomeCategories(hid);
      favoriteCategories = [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadIncomes() async {
    state = IncomesLoadState.loading;
    notifyListeners();
    try {
      incomes = await _txService.getIncomes(
        view: viewType,
        periodOffset: periodOffset,
        categoryId: selectedCategoryId,
        weekNumber: weekNumber,
        date: date,
      );
      state = IncomesLoadState.idle;
    } catch (e) {
      state = IncomesLoadState.error;
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
    loadIncomes();
  }

  void onCategorySelected(int? categoryId) {
    selectedCategoryId = categoryId;
    notifyListeners();
    loadIncomes();
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

  void openEditModal(Income income) {
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

  void setFormAmount(double? v)       { formAmount = v; notifyListeners(); }
  void setFormCategory(int? id)        { formCategoryId = id; notifyListeners(); }
  void setFormDateTime(DateTime dt)    { formDateTime = dt; notifyListeners(); }
  void setFormPayment(String method)   { formPaymentMethod = method; notifyListeners(); }
  void setFormDescription(String v)    { formDescription = v; notifyListeners(); }
  void setFormNote(String v)           { formNote = v; notifyListeners(); }

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

  Future<void> deleteIncome(Income income) async {
    try {
      await _txService.deleteIncome(income.id);
      load();
    } catch (_) {}
  }

  // ── Add category (from sheet) ──────────────────────────────────────────────

  void addCategory(Category cat) {
    categories = [...categories, cat];
    notifyListeners();
  }

  void updateCategoryInList(Category updated) {
    categories = categories.map((c) => c.id == updated.id ? updated : c).toList();
    notifyListeners();
  }

  Future<void> deleteCategory(int id, {bool deleteRefs = false}) async {
    try {
      await _categoryRepo.deleteIncomeCategory(id, deleteRefs: deleteRefs);
      categories = categories.where((c) => c.id != id).toList();
      if (selectedCategoryId == id) selectedCategoryId = null;
      notifyListeners();
      loadIncomes();
    } catch (_) {}
  }

  // ── Create category ────────────────────────────────────────────────────────

  Future<void> createCategory(String name, String color, String icon) async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      await _categoryRepo.createIncomeCategory({
        'name': name,
        'color': color,
        'icon': icon,
        'householdId': hid,
      });
      await loadCategories();
    } catch (_) {}
  }
}
