import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/models/recurring_expense.dart';
import 'package:household/models/expense_schedule.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.read(dioProvider)),
);

class TransactionRepository {
  final Dio _dio;
  TransactionRepository(this._dio);

  // ── Expenses ──────────────────────────────────────────────────────────────

  Future<List<Expense>> getExpenses(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/expenses', queryParameters: params);
    return (res.data['expenses'] as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createExpense(Map<String, dynamic> body) =>
      _dio.post('/app/expenses', data: body);

  Future<void> updateExpense(int id, Map<String, dynamic> body) =>
      _dio.put('/app/expenses/$id', data: body);

  Future<void> updateExpenseInstallmentAmount(int id, double amount, String scope) =>
      _dio.put('/app/expenses/$id/installment-amount', data: {'amount': amount, 'scope': scope});

  Future<void> deleteExpense(int id) =>
      _dio.delete('/app/expenses/$id');

  // ── Recurring Expenses ────────────────────────────────────────────────────

  Future<List<RecurringExpense>> getRecurringExpenses(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/recurring-expenses', queryParameters: params);
    return (res.data['recurringExpenses'] as List)
        .map((e) => RecurringExpense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RecurringExpense> createRecurringExpense(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/recurring-expenses', data: body);
    return RecurringExpense.fromJson(res.data['recurringExpense'] as Map<String, dynamic>);
  }

  Future<RecurringExpense> updateRecurringExpense(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/recurring-expenses/$id', data: body);
    return RecurringExpense.fromJson(res.data['recurringExpense'] as Map<String, dynamic>);
  }

  Future<void> deleteRecurringExpense(int id) =>
      _dio.delete('/app/recurring-expenses/$id');

  // ── Expense Schedules ─────────────────────────────────────────────────────

  Future<List<ExpenseSchedule>> getExpenseSchedules(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/expense-schedules', queryParameters: params);
    return (res.data['expenseSchedules'] as List)
        .map((e) => ExpenseSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseSchedule> createExpenseSchedule(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/expense-schedules', data: body);
    return ExpenseSchedule.fromJson(res.data['expenseSchedule'] as Map<String, dynamic>);
  }

  Future<ExpenseSchedule> updateExpenseSchedule(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/expense-schedules/$id', data: body);
    return ExpenseSchedule.fromJson(res.data['expenseSchedule'] as Map<String, dynamic>);
  }

  Future<void> deleteExpenseSchedule(int id) =>
      _dio.delete('/app/expense-schedules/$id');

  Future<List<ExpenseSchedule>> getTodayScheduleSuggestions(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/expense-schedules/today-suggestions', queryParameters: params);
    return (res.data['suggestions'] as List)
        .map((e) => ExpenseSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Incomes ───────────────────────────────────────────────────────────────

  Future<List<Income>> getIncomes(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/incomes', queryParameters: params);
    return (res.data['incomes'] as List)
        .map((e) => Income.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createIncome(Map<String, dynamic> body) =>
      _dio.post('/app/incomes', data: body);

  Future<void> updateIncome(int id, Map<String, dynamic> body) =>
      _dio.put('/app/incomes/$id', data: body);

  Future<void> deleteIncome(int id) =>
      _dio.delete('/app/incomes/$id');
}
