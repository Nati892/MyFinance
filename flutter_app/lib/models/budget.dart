/// MonthBudgetRow mirrors the Angular MonthBudgetRow interface from budget.service.ts.
/// The API returns these from GET /app/budget/month.
class MonthBudgetRow {
  final int id;
  final String name;
  final String? nameHe;
  final String icon;
  final String color;

  /// Budget set for every month (base).
  final double? baseBudget;

  /// One-off override for a specific month.
  final double? override;

  /// The budget actually used: override ?? baseBudget.
  final double? effectiveBudget;

  /// Total spent in the month for this category.
  final double spent;

  /// spent - effectiveBudget (positive = over budget).
  final double? result;

  const MonthBudgetRow({
    required this.id,
    required this.name,
    this.nameHe,
    required this.icon,
    required this.color,
    this.baseBudget,
    this.override,
    this.effectiveBudget,
    required this.spent,
    this.result,
  });

  factory MonthBudgetRow.fromJson(Map<String, dynamic> json) => MonthBudgetRow(
        id: json['id'] as int,
        name: json['name'] as String,
        nameHe: json['nameHe'] as String?,
        icon: json['icon'] as String? ?? '',
        color: json['color'] as String? ?? '#888888',
        baseBudget: (json['baseBudget'] as num?)?.toDouble(),
        override: (json['override'] as num?)?.toDouble(),
        effectiveBudget: (json['effectiveBudget'] as num?)?.toDouble(),
        spent: (json['spent'] as num?)?.toDouble() ?? 0,
        result: (json['result'] as num?)?.toDouble(),
      );
}

/// A single planned expense item under a category for a given month.
class BudgetPlanItem {
  final int id;
  final int expenseCategoryId;
  final int year;
  final int month;
  final String? description;
  final double minAmount;
  final double maxAmount;

  const BudgetPlanItem({
    required this.id,
    required this.expenseCategoryId,
    required this.year,
    required this.month,
    this.description,
    required this.minAmount,
    required this.maxAmount,
  });

  factory BudgetPlanItem.fromJson(Map<String, dynamic> json) => BudgetPlanItem(
        id: json['id'] as int,
        expenseCategoryId: json['expenseCategoryId'] as int,
        year: json['year'] as int,
        month: json['month'] as int,
        description: json['description'] as String?,
        minAmount: (json['minAmount'] as num?)?.toDouble() ?? 0,
        maxAmount: (json['maxAmount'] as num?)?.toDouble() ?? 0,
      );

  BudgetPlanItem copyWith({String? description, double? minAmount, double? maxAmount}) =>
      BudgetPlanItem(
        id: id,
        expenseCategoryId: expenseCategoryId,
        year: year,
        month: month,
        description: description ?? this.description,
        minAmount: minAmount ?? this.minAmount,
        maxAmount: maxAmount ?? this.maxAmount,
      );
}

/// Per-month household config — start amount and expected income for the plan view.
class BudgetMonthConfig {
  final double? startAmount;
  final double? expectedIncome;

  const BudgetMonthConfig({this.startAmount, this.expectedIncome});

  factory BudgetMonthConfig.fromJson(Map<String, dynamic> json) => BudgetMonthConfig(
        startAmount: (json['startAmount'] as num?)?.toDouble(),
        expectedIncome: (json['expectedIncome'] as num?)?.toDouble(),
      );
}

/// Spending per calendar week — from GET /app/budget/by-week.
class WeekSpend {
  final String weekLabel;
  final double total;

  const WeekSpend({required this.weekLabel, required this.total});

  factory WeekSpend.fromJson(Map<String, dynamic> json) => WeekSpend(
        weekLabel: json['weekLabel'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

/// Spending per month — from GET /app/budget/by-month.
class MonthSpend {
  final String label;
  final double total;

  const MonthSpend({required this.label, required this.total});

  factory MonthSpend.fromJson(Map<String, dynamic> json) => MonthSpend(
        label: json['label'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}
