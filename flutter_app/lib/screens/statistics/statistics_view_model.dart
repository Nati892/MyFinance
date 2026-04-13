import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/transaction_service.dart';
import 'package:household/services/household_service.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class CategoryStat {
  final int? categoryId;
  final String categoryName;
  final String? categoryNameHe;
  final String color;
  final String? icon;
  final double amount;
  final double percentage;

  const CategoryStat({
    this.categoryId,
    required this.categoryName,
    this.categoryNameHe,
    required this.color,
    required this.icon,
    required this.amount,
    required this.percentage,
  });
}

class MonthTrend {
  final int month;
  final int year;
  final double totalExpenses;
  final double totalIncomes;

  const MonthTrend({
    required this.month,
    required this.year,
    required this.totalExpenses,
    required this.totalIncomes,
  });
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

final statisticsViewModelProvider =
    ChangeNotifierProvider.autoDispose<StatisticsViewModel>((ref) {
  final vm = StatisticsViewModel(
    ref.read(transactionServiceProvider),
    ref.read(householdServiceProvider),
    ref.read(categoryRepositoryProvider),
  );
  vm.load();
  return vm;
});

class StatisticsViewModel extends ChangeNotifier {
  final TransactionService _transactionService;
  final HouseholdService _householdService;
  final CategoryRepository _categoryRepo;

  StatisticsViewModel(this._transactionService, this._householdService, this._categoryRepo);

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  String? error;

  // This month
  double totalExpenses = 0;
  double totalIncomes = 0;
  double get netBalance => totalIncomes - totalExpenses;
  double get savingsRate {
    if (totalIncomes <= 0) return 0;
    final rate = (totalIncomes - totalExpenses) / totalIncomes * 100;
    return rate.clamp(0.0, 100.0);
  }

  List<CategoryStat> topExpenseCategories = [];
  List<MonthTrend> monthlyTrend = [];
  double avgMonthlyExpense = 0;
  Map<String, dynamic>? biggestExpenseCategory; // {category: Category, total: double}
  Map<String, double> paymentMethodBreakdown = {};
  List<Category> _expenseCategories = [];

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> load() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      // Fetch categories + current month (offset=0) and past 3 months (offset -1,-2,-3)
      final results = await Future.wait([
        _transactionService.getExpenses(view: 'monthly', periodOffset: 0),
        _transactionService.getIncomes(view: 'monthly', periodOffset: 0),
        _transactionService.getExpenses(view: 'monthly', periodOffset: -1),
        _transactionService.getIncomes(view: 'monthly', periodOffset: -1),
        _transactionService.getExpenses(view: 'monthly', periodOffset: -2),
        _transactionService.getIncomes(view: 'monthly', periodOffset: -2),
        _transactionService.getExpenses(view: 'monthly', periodOffset: -3),
        _transactionService.getIncomes(view: 'monthly', periodOffset: -3),
        _categoryRepo.getExpenseCategories(hid),
      ]);

      final expenses0 = results[0] as List<Expense>;
      final incomes0 = results[1] as List<Income>;
      final expenses1 = results[2] as List<Expense>;
      final incomes1 = results[3] as List<Income>;
      final expenses2 = results[4] as List<Expense>;
      final incomes2 = results[5] as List<Income>;
      final expenses3 = results[6] as List<Expense>;
      final incomes3 = results[7] as List<Income>;
      _expenseCategories = results[8] as List<Category>;

      // ── This month totals ──────────────────────────────────────────────────
      totalExpenses = expenses0.fold(0.0, (s, e) => s + e.amount);
      totalIncomes = incomes0.fold(0.0, (s, e) => s + e.amount);

      // ── Top expense categories ─────────────────────────────────────────────
      final catMap = <int?, _CatAccum>{};
      for (final e in expenses0) {
        final key = e.category?.id;
        final acc = catMap.putIfAbsent(
          key,
          () => _CatAccum(
            id: key,
            name: e.category?.name ?? 'Other',
            nameHe: e.category?.nameHe,
            color: e.category?.color ?? '#888888',
            icon: e.category?.icon,
          ),
        );
        acc.amount += e.amount;
      }

      final sortedCats = catMap.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      final top5 = sortedCats.take(5).toList();

      topExpenseCategories = top5
          .map((c) => CategoryStat(
                categoryId: c.id,
                categoryName: c.name,
                categoryNameHe: c.nameHe,
                color: c.color,
                icon: c.icon,
                amount: c.amount,
                percentage: totalExpenses > 0
                    ? (c.amount / totalExpenses * 100)
                    : 0,
              ))
          .toList();

      // ── Monthly trend (last 4 months) ──────────────────────────────────────
      final now = DateTime.now();
      final expGroups = [expenses3, expenses2, expenses1, expenses0];
      final incGroups = [incomes3, incomes2, incomes1, incomes0];
      monthlyTrend = List.generate(4, (i) {
        // i=0 → offset=-3, i=3 → offset=0
        final offset = i - 3;
        final dt = DateTime(now.year, now.month + offset, 1);
        return MonthTrend(
          month: dt.month,
          year: dt.year,
          totalExpenses: expGroups[i].fold(0.0, (s, e) => s + e.amount),
          totalIncomes: incGroups[i].fold(0.0, (s, e) => s + e.amount),
        );
      });

      // ── Avg monthly expense (last 3 months, excluding current) ─────────────
      final pastExpenses = [
        expenses1.fold(0.0, (s, e) => s + e.amount),
        expenses2.fold(0.0, (s, e) => s + e.amount),
        expenses3.fold(0.0, (s, e) => s + e.amount),
      ];
      avgMonthlyExpense = pastExpenses.reduce((a, b) => a + b) / 3;

      // ── Biggest expense category (with sub-category rollup) ───────────────
      biggestExpenseCategory = null;
      if (expenses0.isNotEmpty && _expenseCategories.isNotEmpty) {
        // Build lookup: category id -> root category
        final rootLookup = <int, Category>{};
        for (final cat in _expenseCategories) {
          rootLookup[cat.id] = cat;
          for (final sub in cat.subCategories) {
            rootLookup[sub.id] = cat;
          }
        }
        // Sum amounts per root category
        final rootTotals = <int, double>{};
        for (final e in expenses0) {
          final catId = e.category?.id;
          if (catId == null) continue;
          final root = rootLookup[catId];
          if (root == null) continue;
          rootTotals[root.id] = (rootTotals[root.id] ?? 0) + e.amount;
        }
        if (rootTotals.isNotEmpty) {
          final bestId = rootTotals.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
          final bestCat = _expenseCategories.firstWhere((c) => c.id == bestId);
          biggestExpenseCategory = {
            'category': bestCat,
            'total': rootTotals[bestId]!,
          };
        }
      }

      // ── Payment method breakdown ───────────────────────────────────────────
      final pmMap = <String, double>{};
      for (final e in expenses0) {
        pmMap[e.paymentMethod] = (pmMap[e.paymentMethod] ?? 0) + e.amount;
      }
      // Sort by amount desc
      paymentMethodBreakdown = Map.fromEntries(
        pmMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

// ─── Internal accumulator ─────────────────────────────────────────────────────
class _CatAccum {
  final int? id;
  final String name;
  final String? nameHe;
  final String color;
  final String? icon;
  double amount = 0;

  _CatAccum({
    required this.id,
    required this.name,
    this.nameHe,
    required this.color,
    required this.icon,
  });
}
