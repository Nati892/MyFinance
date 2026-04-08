import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.read(dioProvider)),
);

class BudgetRepository {
  final Dio _dio;
  BudgetRepository(this._dio);

  /// GET /app/budget/month — returns typed list of [MonthBudgetRow].
  Future<List<MonthBudgetRow>> getMonthlyBudget({
    required int householdId,
    required int year,
    required int month,
  }) async {
    final res = await _dio.get('/app/budget/month', queryParameters: {
      'householdId': householdId,
      'year': year,
      'month': month,
    });
    final data = res.data as Map<String, dynamic>;
    final categories = data['categories'] as List<dynamic>? ?? [];
    return categories
        .map((e) => MonthBudgetRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /app/budget/base — sets the recurring monthly budget for a category.
  /// body: { expenseCategoryId, householdId, amount }
  Future<void> setBaseBudget({
    required int expenseCategoryId,
    required int householdId,
    required double amount,
  }) =>
      _dio.put('/app/budget/base', data: {
        'expenseCategoryId': expenseCategoryId,
        'householdId': householdId,
        'amount': amount,
      });

  /// PUT /app/budget/override — overrides budget for a specific month only.
  /// body: { expenseCategoryId, householdId, year, month, amount }
  Future<void> overrideBudget({
    required int expenseCategoryId,
    required int householdId,
    required int year,
    required int month,
    required double amount,
  }) =>
      _dio.put('/app/budget/override', data: {
        'expenseCategoryId': expenseCategoryId,
        'householdId': householdId,
        'year': year,
        'month': month,
        'amount': amount,
      });

  /// GET /app/budget/by-week — weekly spend breakdown for a given month.
  Future<List<WeekSpend>> getByWeek({
    required int householdId,
    required int year,
    required int month,
    int? expenseCategoryId,
  }) async {
    final params = <String, dynamic>{
      'householdId': householdId,
      'year': year,
      'month': month,
    };
    if (expenseCategoryId != null) {
      params['expenseCategoryId'] = expenseCategoryId;
    }
    final res = await _dio.get('/app/budget/by-week', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    final weeks = data['weeks'] as List<dynamic>? ?? [];
    return weeks
        .map((e) => WeekSpend.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /app/budget/plan-items — all plan items for a month.
  Future<List<BudgetPlanItem>> getPlanItems({
    required int householdId,
    required int year,
    required int month,
  }) async {
    final res = await _dio.get('/app/budget/plan-items', queryParameters: {
      'householdId': householdId,
      'year': year,
      'month': month,
    });
    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => BudgetPlanItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /app/budget/plan-items — create a new plan item.
  Future<BudgetPlanItem> createPlanItem({
    required int householdId,
    required int expenseCategoryId,
    required int year,
    required int month,
    required String? description,
    required double amount,
  }) async {
    final res = await _dio.post('/app/budget/plan-items', data: {
      'householdId': householdId,
      'expenseCategoryId': expenseCategoryId,
      'year': year,
      'month': month,
      'description': description,
      'amount': amount,
    });
    return BudgetPlanItem.fromJson(res.data['item'] as Map<String, dynamic>);
  }

  /// PUT /app/budget/plan-items/:id — update description/amount.
  Future<BudgetPlanItem> updatePlanItem({
    required int id,
    required String? description,
    required double amount,
  }) async {
    final res = await _dio.put('/app/budget/plan-items/$id', data: {
      'description': description,
      'amount': amount,
    });
    return BudgetPlanItem.fromJson(res.data['item'] as Map<String, dynamic>);
  }

  /// DELETE /app/budget/plan-items/:id
  Future<void> deletePlanItem(int id) => _dio.delete('/app/budget/plan-items/$id');

  /// GET /app/budget/month-config
  Future<BudgetMonthConfig?> getMonthConfig({
    required int householdId,
    required int year,
    required int month,
  }) async {
    final res = await _dio.get('/app/budget/month-config', queryParameters: {
      'householdId': householdId,
      'year': year,
      'month': month,
    });
    final data = res.data as Map<String, dynamic>;
    final config = data['config'];
    if (config == null) return null;
    return BudgetMonthConfig.fromJson(config as Map<String, dynamic>);
  }

  /// PUT /app/budget/month-config — upsert startAmount.
  Future<void> upsertMonthConfig({
    required int householdId,
    required int year,
    required int month,
    required double? startAmount,
  }) =>
      _dio.put('/app/budget/month-config', data: {
        'householdId': householdId,
        'year': year,
        'month': month,
        'startAmount': startAmount,
      });

  /// GET /app/budget/by-month — monthly spend over a range of months.
  Future<List<MonthSpend>> getByMonth({
    required int householdId,
    required int year,
    required int startMonth,
    required int endMonth,
    int? expenseCategoryId,
  }) async {
    final params = <String, dynamic>{
      'householdId': householdId,
      'year': year,
      'startMonth': startMonth,
      'endMonth': endMonth,
    };
    if (expenseCategoryId != null) {
      params['expenseCategoryId'] = expenseCategoryId;
    }
    final res = await _dio.get('/app/budget/by-month', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    final months = data['months'] as List<dynamic>? ?? [];
    return months
        .map((e) => MonthSpend.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
