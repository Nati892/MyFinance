import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/screens/home/home_view_model.dart';
import 'package:household/utils/icon_helper.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(homeViewModelProvider);

    final l10n = AppLocalizations.of(context)!;

    if (vm.noHousehold) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏠', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(l10n.commonNoHousehold,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(l10n.commonNoHouseholdMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF888888))),
          ],
        ),
      );
    }

    if (vm.state == HomeLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.state == HomeLoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.commonError,
                style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: vm.load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildSummaryHeader(context, vm),
          const SizedBox(height: 24),
          _buildRecentTransactions(context, vm),
        ],
      ),
    );
  }

  // ── Summary header with gradient cards ──────────────────────────────────────

  Widget _buildSummaryHeader(BuildContext context, HomeViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final monthName = _monthName(now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$monthName ${now.year}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.commonThisMonthSummary,
          style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: l10n.navExpenses,
                amount: vm.totalExpenses,
                isExpense: true,
                gradientStart: const Color(0xFFFF6B6B),
                gradientEnd: const Color(0xFFEE5A24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: l10n.navIncomes,
                amount: vm.totalIncomes,
                isExpense: false,
                gradientStart: const Color(0xFF55EFC4),
                gradientEnd: const Color(0xFF00B894),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _BalanceCard(balance: vm.balance),
      ],
    );
  }

  // ── Recent transactions list ─────────────────────────────────────────────────

  Widget _buildRecentTransactions(BuildContext context, HomeViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    final List<RecentTx> recent = vm.recentTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.commonRecentTransactions,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                l10n.commonNoTransactionsMonth,
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: recent.asMap().entries.map((entry) {
                final index = entry.key;
                final tx = entry.value;
                return _TxListTile(
                  tx: tx,
                  showDivider: index < recent.length - 1,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}

// ── Summary Card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final bool isExpense;
  final Color gradientStart;
  final Color gradientEnd;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.isExpense,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientEnd.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₪${_fmt(amount)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
  }
}

// ── Balance Card ────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.commonNetBalance,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isPositive ? '+' : ''}₪${balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction list tile ───────────────────────────────────────────────────

class _TxListTile extends StatelessWidget {
  final RecentTx tx;
  final bool showDivider;

  const _TxListTile({required this.tx, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(tx.categoryColor);
    final l10n = AppLocalizations.of(context)!;
    final label = tx.description?.isNotEmpty == true
        ? tx.description!
        : (tx.categoryName ?? (tx.isExpense ? l10n.commonExpense : l10n.commonIncome));
    final date = _formatDate(tx.dateTime, l10n);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Category icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconDataFromName(tx.categoryIcon),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Label + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '${tx.isExpense ? '-' : '+'}₪${tx.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tx.isExpense
                      ? const Color(0xFFE53935)
                      : const Color(0xFF00B894),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 68, endIndent: 16),
      ],
    );
  }

  Color _hexColor(String? hex) {
    if (hex == null) return const Color(0xFF888888);
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  String _formatDate(String iso, AppLocalizations l10n) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final txDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(txDay).inDays;
      if (diff == 0) return l10n.commonToday;
      if (diff == 1) return l10n.commonYesterday;
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
