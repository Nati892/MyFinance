import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/models/recurring_expense.dart';
import 'package:household/models/expense_schedule.dart';
import 'package:household/repositories/transaction_repository.dart';
import 'package:household/services/household_service.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(
    ref.read(transactionRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

class TransactionService {
  final TransactionRepository _repo;
  final HouseholdService _householdService;

  TransactionService(this._repo, this._householdService);

  int get _householdId {
    final id = _householdService.currentHouseholdId;
    if (id == null) throw Exception('No household selected');
    return id;
  }

  Future<List<Expense>> getExpenses({
    required String view,
    required int periodOffset,
    int? categoryId,
    int? weekNumber,
    String? date,
  }) {
    return _repo.getExpenses({
      'householdId': _householdId,
      'view': view,
      'periodOffset': periodOffset,
      if (categoryId != null) 'categoryId': categoryId,
      if (weekNumber != null) 'weekNumber': weekNumber,
      if (date != null) 'date': date,
    });
  }

  Future<void> createExpense({
    required double amount,
    required String dateTime,
    required String paymentMethod,
    required int expenseCategoryId,
    int? cardId,
    String? description,
    String? note,
    int? installmentTotal,
    int? installmentCurrent,
  }) {
    return _repo.createExpense({
      'amount': amount,
      'dateTime': dateTime,
      'paymentMethod': paymentMethod,
      'cardId': cardId,
      'expenseCategoryId': expenseCategoryId,
      'householdId': _householdId,
      if (description != null && description.isNotEmpty) 'description': description,
      if (note != null && note.isNotEmpty) 'note': note,
      if (installmentTotal != null) 'installmentTotal': installmentTotal,
      if (installmentCurrent != null) 'installmentCurrent': installmentCurrent,
    });
  }

  Future<void> updateExpense(int id, Map<String, dynamic> fields) =>
      _repo.updateExpense(id, fields);

  Future<void> updateExpenseInstallmentAmount(int id, double amount, String scope) =>
      _repo.updateExpenseInstallmentAmount(id, amount, scope);

  Future<void> deleteExpense(int id) => _repo.deleteExpense(id);

  // ── Recurring Expenses ────────────────────────────────────────────────────

  Future<List<RecurringExpense>> getRecurringExpenses() =>
      _repo.getRecurringExpenses({'householdId': _householdId});

  Future<RecurringExpense> createRecurringExpense({
    required double amount,
    required int expenseCategoryId,
    required String paymentMethod,
    required int dayOfMonth,
    required int startYear,
    required int startMonth,
    String? description,
    String? note,
  }) =>
      _repo.createRecurringExpense({
        'amount': amount,
        'expenseCategoryId': expenseCategoryId,
        'householdId': _householdId,
        'paymentMethod': paymentMethod,
        'dayOfMonth': dayOfMonth,
        'startYear': startYear,
        'startMonth': startMonth,
        if (description != null && description.isNotEmpty) 'description': description,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  Future<RecurringExpense> updateRecurringExpense(int id, Map<String, dynamic> fields) =>
      _repo.updateRecurringExpense(id, fields);

  Future<void> deleteRecurringExpense(int id) => _repo.deleteRecurringExpense(id);

  // ── Expense Schedules ─────────────────────────────────────────────────────

  Future<List<ExpenseSchedule>> getExpenseSchedules() =>
      _repo.getExpenseSchedules({'householdId': _householdId});

  Future<ExpenseSchedule> createExpenseSchedule({
    required String description,
    required int expenseCategoryId,
    required List<int> daysOfWeek,
    double? amount,
    String? paymentMethod,
    String? note,
    bool isActive = true,
  }) =>
      _repo.createExpenseSchedule({
        'description': description,
        'expenseCategoryId': expenseCategoryId,
        'householdId': _householdId,
        'daysOfWeek': daysOfWeek,
        if (amount != null) 'amount': amount,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
        if (note != null && note.isNotEmpty) 'note': note,
        'isActive': isActive,
      });

  Future<ExpenseSchedule> updateExpenseSchedule(int id, Map<String, dynamic> fields) =>
      _repo.updateExpenseSchedule(id, fields);

  Future<void> deleteExpenseSchedule(int id) => _repo.deleteExpenseSchedule(id);

  Future<List<ExpenseSchedule>> getTodayScheduleSuggestions() =>
      _repo.getTodayScheduleSuggestions({'householdId': _householdId});

  // ── Incomes ───────────────────────────────────────────────────────────────

  Future<List<Income>> getIncomes({
    required String view,
    required int periodOffset,
    int? categoryId,
    int? weekNumber,
    String? date,
  }) {
    return _repo.getIncomes({
      'householdId': _householdId,
      'view': view,
      'periodOffset': periodOffset,
      if (categoryId != null) 'categoryId': categoryId,
      if (weekNumber != null) 'weekNumber': weekNumber,
      if (date != null) 'date': date,
    });
  }

  Future<void> createIncome({
    required double amount,
    required String dateTime,
    required String paymentMethod,
    required int incomeCategoryId,
    String? description,
    String? note,
    int? cardId,
  }) {
    return _repo.createIncome({
      'amount': amount,
      'dateTime': dateTime,
      'paymentMethod': paymentMethod,
      'incomeCategoryId': incomeCategoryId,
      'householdId': _householdId,
      if (description != null && description.isNotEmpty) 'description': description,
      if (note != null && note.isNotEmpty) 'note': note,
      if (cardId != null) 'cardId': cardId,
    });
  }

  Future<void> updateIncome(int id, Map<String, dynamic> fields) =>
      _repo.updateIncome(id, fields);

  Future<void> deleteIncome(int id) => _repo.deleteIncome(id);
}
