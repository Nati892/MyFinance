import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.read(dioProvider)),
);

class BudgetRepository {
  final Dio _dio;
  BudgetRepository(this._dio);

  Future<Map<String, dynamic>> getMonthlyBudget({
    required int householdId,
    required int year,
    required int month,
  }) async {
    final res = await _dio.get('/app/budget/month', queryParameters: {
      'householdId': householdId,
      'year': year,
      'month': month,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> setBaseBudget(Map<String, dynamic> body) =>
      _dio.put('/app/budget/base', data: body);

  Future<void> overrideBudget(Map<String, dynamic> body) =>
      _dio.put('/app/budget/override', data: body);

  Future<Map<String, dynamic>> getByWeek(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/budget/by-week', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getByMonth(Map<String, dynamic> params) async {
    final res = await _dio.get('/app/budget/by-month', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }
}
