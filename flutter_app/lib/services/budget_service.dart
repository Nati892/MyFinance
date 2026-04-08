import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/budget.dart';
import 'package:household/repositories/budget_repository.dart';
import 'package:household/services/household_service.dart';

final budgetServiceProvider = ChangeNotifierProvider<BudgetService>(
  (ref) => BudgetService(
    ref.read(budgetRepositoryProvider),
    ref.read(householdServiceProvider),
  ),
);

class BudgetService extends ChangeNotifier {
  final BudgetRepository _repo;
  final HouseholdService _householdService;

  BudgetService(this._repo, this._householdService);

  int? get currentHouseholdId => _householdService.currentHouseholdId;

  /// Fetch budget rows for [year]/[month] for the current household.
  Future<List<MonthBudgetRow>> getMonthlyBudget({
    required int year,
    required int month,
  }) async {
    final hid = currentHouseholdId;
    if (hid == null) return [];
    return _repo.getMonthlyBudget(
      householdId: hid,
      year: year,
      month: month,
    );
  }

  /// Set recurring monthly budget for a category.
  Future<void> setBaseBudget({
    required int expenseCategoryId,
    required double amount,
  }) async {
    final hid = currentHouseholdId;
    if (hid == null) return;
    await _repo.setBaseBudget(
      expenseCategoryId: expenseCategoryId,
      householdId: hid,
      amount: amount,
    );
  }

  /// Override budget for a specific month.
  Future<void> overrideBudget({
    required int expenseCategoryId,
    required int year,
    required int month,
    required double amount,
  }) async {
    final hid = currentHouseholdId;
    if (hid == null) return;
    await _repo.overrideBudget(
      expenseCategoryId: expenseCategoryId,
      householdId: hid,
      year: year,
      month: month,
      amount: amount,
    );
  }

  /// Plan items for a given month.
  Future<List<BudgetPlanItem>> getPlanItems({required int year, required int month}) async {
    final hid = currentHouseholdId;
    if (hid == null) return [];
    return _repo.getPlanItems(householdId: hid, year: year, month: month);
  }

  Future<BudgetPlanItem> createPlanItem({
    required int expenseCategoryId,
    required int year,
    required int month,
    required String? description,
    required double amount,
  }) async {
    final hid = currentHouseholdId!;
    return _repo.createPlanItem(
      householdId: hid,
      expenseCategoryId: expenseCategoryId,
      year: year, month: month,
      description: description, amount: amount,
    );
  }

  Future<BudgetPlanItem> updatePlanItem({
    required int id,
    required String? description,
    required double amount,
  }) =>
      _repo.updatePlanItem(id: id, description: description, amount: amount);

  Future<void> deletePlanItem(int id) => _repo.deletePlanItem(id);

  Future<BudgetMonthConfig?> getMonthConfig({required int year, required int month}) async {
    final hid = currentHouseholdId;
    if (hid == null) return null;
    return _repo.getMonthConfig(householdId: hid, year: year, month: month);
  }

  Future<void> upsertMonthConfig({
    required int year,
    required int month,
    required double? startAmount,
  }) async {
    final hid = currentHouseholdId;
    if (hid == null) return;
    await _repo.upsertMonthConfig(householdId: hid, year: year, month: month, startAmount: startAmount);
  }

  /// Weekly spending breakdown.
  Future<List<WeekSpend>> getByWeek({
    required int year,
    required int month,
    int? expenseCategoryId,
  }) async {
    final hid = currentHouseholdId;
    if (hid == null) return [];
    return _repo.getByWeek(
      householdId: hid,
      year: year,
      month: month,
      expenseCategoryId: expenseCategoryId,
    );
  }

  /// Monthly spending over a range.
  Future<List<MonthSpend>> getByMonth({
    required int year,
    required int startMonth,
    required int endMonth,
    int? expenseCategoryId,
  }) async {
    final hid = currentHouseholdId;
    if (hid == null) return [];
    return _repo.getByMonth(
      householdId: hid,
      year: year,
      startMonth: startMonth,
      endMonth: endMonth,
      expenseCategoryId: expenseCategoryId,
    );
  }
}
