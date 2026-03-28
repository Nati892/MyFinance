import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';

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

  Future<void> deleteExpense(int id) =>
      _dio.delete('/app/expenses/$id');

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
