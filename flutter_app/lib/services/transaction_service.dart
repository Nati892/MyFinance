import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
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
    String? description,
    String? note,
  }) {
    return _repo.createExpense({
      'amount': amount,
      'dateTime': dateTime,
      'paymentMethod': paymentMethod,
      'expenseCategoryId': expenseCategoryId,
      'householdId': _householdId,
      if (description != null && description.isNotEmpty) 'description': description,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> updateExpense(int id, Map<String, dynamic> fields) =>
      _repo.updateExpense(id, fields);

  Future<void> deleteExpense(int id) => _repo.deleteExpense(id);

  // ── Incomes ───────────────────────────────────────────────────────────────

  Future<List<Income>> getIncomes({
    required String view,
    required int periodOffset,
    int? categoryId,
  }) {
    return _repo.getIncomes({
      'householdId': _householdId,
      'view': view,
      'periodOffset': periodOffset,
      if (categoryId != null) 'categoryId': categoryId,
    });
  }

  Future<void> createIncome({
    required double amount,
    required String dateTime,
    required String paymentMethod,
    required int incomeCategoryId,
    String? description,
    String? note,
  }) {
    return _repo.createIncome({
      'amount': amount,
      'dateTime': dateTime,
      'paymentMethod': paymentMethod,
      'incomeCategoryId': incomeCategoryId,
      'householdId': _householdId,
      if (description != null && description.isNotEmpty) 'description': description,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> updateIncome(int id, Map<String, dynamic> fields) =>
      _repo.updateIncome(id, fields);

  Future<void> deleteIncome(int id) => _repo.deleteIncome(id);
}
