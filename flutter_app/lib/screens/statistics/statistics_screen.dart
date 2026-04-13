import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/screens/statistics/statistics_view_model.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:intl/intl.dart' as intl;

// ─── Color constants ──────────────────────────────────────────────────────────
const _primaryColor = Color(0xFF667EEA);
const _expenseColor = Color(0xFFFF6B6B);
const _incomeColor = Color(0xFF00B894);
const _cardBg = Colors.white;

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(statisticsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _expenseColor, size: 48),
            const SizedBox(height: 12),
            Text(l10n.commonError,
                style: const TextStyle(fontSize: 16, color: Color(0xFF444444))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(statisticsViewModelProvider).load(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'he'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            Text(
              l10n.statsTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.statsThisMonth,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 16),

            // ── Summary row ────────────────────────────────────────────────
            _SummaryRow(vm: vm),
            const SizedBox(height: 16),

            // ── Savings rate ───────────────────────────────────────────────
            _SavingsRateCard(vm: vm),
            const SizedBox(height: 16),

            // ── Top categories ─────────────────────────────────────────────
            if (vm.topExpenseCategories.isNotEmpty) ...[
              _TopCategoriesCard(vm: vm),
              const SizedBox(height: 16),
            ],

            // ── Monthly trend ──────────────────────────────────────────────
            _MonthlyTrendCard(vm: vm),
            const SizedBox(height: 16),

            // ── Avg monthly expense ────────────────────────────────────────
            _AvgExpenseCard(vm: vm),
            const SizedBox(height: 16),

            // ── Biggest expense category ───────────────────────────────────
            if (vm.biggestExpenseCategory != null) ...[
              _BiggestCategoryCard(
                category: vm.biggestExpenseCategory!['category'] as Category,
                total: vm.biggestExpenseCategory!['total'] as double,
              ),
              const SizedBox(height: 16),
            ],

            // ── Payment method breakdown ───────────────────────────────────
            if (vm.paymentMethodBreakdown.isNotEmpty) ...[
              _PaymentMethodCard(vm: vm),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final StatisticsViewModel vm;
  const _SummaryRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final netPositive = vm.netBalance >= 0;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: l10n.expensesTitle,
            amount: vm.totalExpenses,
            color: _expenseColor,
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: l10n.incomesTitle,
            amount: vm.totalIncomes,
            color: _incomeColor,
            icon: Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: l10n.commonNetBalance,
            amount: vm.netBalance,
            color: netPositive ? _incomeColor : _expenseColor,
            icon: netPositive ? Icons.trending_up : Icons.trending_down,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₪${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Savings Rate Card ────────────────────────────────────────────────────────

class _SavingsRateCard extends StatelessWidget {
  final StatisticsViewModel vm;
  const _SavingsRateCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rate = vm.savingsRate;
    final color = rate >= 20
        ? _incomeColor
        : rate >= 10
            ? const Color(0xFFFFA500)
            : _expenseColor;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.statsSavingsRate),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Top Categories Card ──────────────────────────────────────────────────────

class _TopCategoriesCard extends StatelessWidget {
  final StatisticsViewModel vm;
  const _TopCategoriesCard({required this.vm});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      return const Color(0xFF888888);
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final maxAmount = vm.topExpenseCategories.isEmpty
        ? 1.0
        : vm.topExpenseCategories.first.amount;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.statsTopCategories),
          const SizedBox(height: 12),
          ...vm.topExpenseCategories.map((cat) {
            final barFraction =
                maxAmount > 0 ? (cat.amount / maxAmount) : 0.0;
            final catColor = _parseColor(cat.color);
            final displayName =
                isHe ? (cat.categoryNameHe ?? cat.categoryName) : cat.categoryName;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: catColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A2E)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₪${cat.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${cat.percentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width: constraints.maxWidth * barFraction,
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Monthly Trend Card ───────────────────────────────────────────────────────

class _MonthlyTrendCard extends StatelessWidget {
  final StatisticsViewModel vm;
  const _MonthlyTrendCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (vm.monthlyTrend.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.statsMonthlyTrend),
            const SizedBox(height: 16),
            Center(
              child: Text(l10n.statsNoData,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 13)),
            ),
          ],
        ),
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final monthAbbr = List.generate(12,
        (i) => intl.DateFormat.MMM(locale).format(DateTime(2000, i + 1)));

    // Find max value for bar scaling
    double maxVal = 1.0;
    for (final t in vm.monthlyTrend) {
      if (t.totalExpenses > maxVal) maxVal = t.totalExpenses;
      if (t.totalIncomes > maxVal) maxVal = t.totalIncomes;
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SectionTitle(l10n.statsMonthlyTrend)),
              Text(l10n.statsLast4Months,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 4),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LegendDot(color: _expenseColor, label: l10n.expensesTitle),
              const SizedBox(width: 12),
              _LegendDot(color: _incomeColor, label: l10n.incomesTitle),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: vm.monthlyTrend.map((t) {
                final expFrac = maxVal > 0 ? t.totalExpenses / maxVal : 0.0;
                final incFrac = maxVal > 0 ? t.totalIncomes / maxVal : 0.0;
                final label =
                    monthAbbr[(t.month - 1).clamp(0, 11)];
                return Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(
                              fraction: expFrac.toDouble(),
                              color: _expenseColor,
                            ),
                            const SizedBox(width: 3),
                            _Bar(
                              fraction: incFrac.toDouble(),
                              color: _incomeColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _Bar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: fraction.clamp(0.03, 1.0),
        child: Container(
          width: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF888888))),
      ],
    );
  }
}

// ─── Avg Monthly Expense Card ─────────────────────────────────────────────────

class _AvgExpenseCard extends StatelessWidget {
  final StatisticsViewModel vm;
  const _AvgExpenseCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today,
                size: 20, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statsAvgMonthlyExpense,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '₪${vm.avgMonthlyExpense.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Biggest Category Card ────────────────────────────────────────────────────

class _BiggestCategoryCard extends StatelessWidget {
  final Category category;
  final double total;
  const _BiggestCategoryCard({required this.category, required this.total});

  Color _parseColor(String? hex) {
    try {
      final clean = (hex ?? '#888888').replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final catName = isHe
        ? (category.nameHe ?? category.name)
        : category.name;
    final catColor = _parseColor(category.color);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.statsBiggestExpense),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    iconDataFromName(category.icon),
                    size: 20,
                    color: catColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  catName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₪${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _expenseColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Payment Method Card ──────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final StatisticsViewModel vm;
  const _PaymentMethodCard({required this.vm});

  static const _dotColors = [
    Color(0xFF667EEA),
    Color(0xFF00B894),
    Color(0xFFFF6B6B),
    Color(0xFFFFA500),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = vm.paymentMethodBreakdown.values
        .fold(0.0, (sum, v) => sum + v);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.statsPaymentMethods),
          const SizedBox(height: 12),
          ...vm.paymentMethodBreakdown.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final pct = total > 0 ? (e.value / total * 100) : 0.0;
            final color = _dotColors[idx % _dotColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                  Text(
                    '₪${e.value.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0E000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}
