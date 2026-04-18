import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/expense_schedule.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';

final schedulesViewModelProvider =
    ChangeNotifierProvider.autoDispose<SchedulesViewModel>((ref) {
  return SchedulesViewModel(
    ref.read(transactionServiceProvider),
    ref.read(categoryRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

enum SchedulesLoadState { idle, loading, error }

class SchedulesViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final CategoryRepository _categoryRepo;
  final HouseholdService _householdService;

  SchedulesViewModel(this._txService, this._categoryRepo, this._householdService) {
    load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  List<ExpenseSchedule> schedules = [];
  List<Category> expenseCategories = [];

  // ── State ──────────────────────────────────────────────────────────────────
  SchedulesLoadState loadState = SchedulesLoadState.loading;
  String? errorMessage;

  bool get noHousehold => _householdService.currentHouseholdId == null;
  int get householdId => _householdService.currentHouseholdId ?? 0;

  // ── Form state ─────────────────────────────────────────────────────────────
  bool formOpen = false;
  bool formSaving = false;
  String? formError;
  bool isEditMode = false;
  int? editingId;

  String formDescription = '';
  int? formCategoryId;
  double? formAmount;
  String formPaymentMethod = 'bank_transfer';
  bool formPaymentMethodSet = false; // true if user explicitly picked a payment method
  List<int> formDaysOfWeek = [];
  bool formIsActive = true;
  String formNote = '';

  int? _selectedParentId;
  int? get selectedParentId => _selectedParentId;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    loadState = SchedulesLoadState.loading;
    notifyListeners();
    try {
      final hid = _householdService.currentHouseholdId;
      if (hid == null) {
        loadState = SchedulesLoadState.idle;
        notifyListeners();
        return;
      }
      final results = await Future.wait([
        _txService.getExpenseSchedules(),
        _categoryRepo.getExpenseCategories(hid),
      ]);
      schedules = results[0] as List<ExpenseSchedule>;
      expenseCategories = results[1] as List<Category>;
      loadState = SchedulesLoadState.idle;
    } catch (e) {
      loadState = SchedulesLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Form open/close ────────────────────────────────────────────────────────

  void openAdd() {
    isEditMode = false;
    editingId = null;
    formDescription = '';
    formCategoryId = null;
    formAmount = null;
    formPaymentMethod = 'bank_transfer';
    formPaymentMethodSet = false;
    formDaysOfWeek = [];
    formIsActive = true;
    formNote = '';
    formError = null;
    _selectedParentId = null;
    formOpen = true;
    notifyListeners();
  }

  void openEdit(ExpenseSchedule schedule) {
    isEditMode = true;
    editingId = schedule.id;
    formDescription = schedule.description;
    formCategoryId = schedule.expenseCategoryId;
    formAmount = schedule.amount;
    formPaymentMethod = schedule.paymentMethod ?? 'bank_transfer';
    formPaymentMethodSet = schedule.paymentMethod != null;
    formDaysOfWeek = List<int>.from(schedule.daysOfWeek);
    formIsActive = schedule.isActive;
    formNote = schedule.note ?? '';
    formError = null;
    // Find parent category
    _selectedParentId = null;
    for (final cat in expenseCategories) {
      if (cat.id == schedule.expenseCategoryId) {
        _selectedParentId = cat.id;
        break;
      }
      for (final sub in cat.subCategories) {
        if (sub.id == schedule.expenseCategoryId) {
          _selectedParentId = cat.id;
          break;
        }
      }
      if (_selectedParentId != null) break;
    }
    formOpen = true;
    notifyListeners();
  }

  void closeForm() {
    formOpen = false;
    formError = null;
    notifyListeners();
  }

  // ── Form field setters ─────────────────────────────────────────────────────

  void setDescription(String v) { formDescription = v; notifyListeners(); }

  void setCategory(int? parentId, int? subId) {
    _selectedParentId = parentId;
    formCategoryId = subId ?? parentId;
    notifyListeners();
  }

  void setAmount(double? v) { formAmount = v; notifyListeners(); }

  void setPaymentMethod(String? v) {
    formPaymentMethod = v ?? 'bank_transfer';
    formPaymentMethodSet = v != null;
    notifyListeners();
  }

  void toggleDay(int day) {
    if (formDaysOfWeek.contains(day)) {
      formDaysOfWeek = formDaysOfWeek.where((d) => d != day).toList();
    } else {
      formDaysOfWeek = [...formDaysOfWeek, day]..sort();
    }
    notifyListeners();
  }

  void setIsActive(bool v) { formIsActive = v; notifyListeners(); }
  void setNote(String v) { formNote = v; notifyListeners(); }

  // ── Save / Delete ──────────────────────────────────────────────────────────

  Future<void> save() async {
    if (formDescription.trim().isEmpty) {
      formError = 'Please enter a description.';
      notifyListeners();
      return;
    }
    if (formCategoryId == null) {
      formError = 'Please select a category.';
      notifyListeners();
      return;
    }
    if (formDaysOfWeek.isEmpty) {
      formError = 'Please select at least one day.';
      notifyListeners();
      return;
    }

    formSaving = true;
    formError = null;
    notifyListeners();

    try {
      if (!isEditMode) {
        final created = await _txService.createExpenseSchedule(
          description: formDescription.trim(),
          expenseCategoryId: formCategoryId!,
          daysOfWeek: formDaysOfWeek,
          amount: formAmount,
          paymentMethod: formPaymentMethodSet ? formPaymentMethod : null,
          note: formNote.isNotEmpty ? formNote : null,
          isActive: formIsActive,
        );
        schedules = [...schedules, created];
      } else {
        final updated = await _txService.updateExpenseSchedule(editingId!, {
          'description': formDescription.trim(),
          'expenseCategoryId': formCategoryId,
          'daysOfWeek': formDaysOfWeek,
          'amount': formAmount,
          'paymentMethod': formPaymentMethodSet ? formPaymentMethod : null,
          'note': formNote,
          'isActive': formIsActive,
        });
        schedules = schedules.map((s) => s.id == updated.id ? updated : s).toList();
      }
      formSaving = false;
      formOpen = false;
      notifyListeners();
    } catch (e) {
      formSaving = false;
      formError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  Future<void> delete(int id) async {
    try {
      await _txService.deleteExpenseSchedule(id);
      schedules = schedules.where((s) => s.id != id).toList();
      formOpen = false;
      notifyListeners();
    } catch (e) {
      formError = 'Failed to delete.';
      notifyListeners();
    }
  }
}
