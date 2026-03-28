import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/budget.dart';
import 'package:household/screens/budget/budget_view_model.dart';
import 'package:household/utils/icon_helper.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  static const _purple = Color(0xFF667EEA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(budgetViewModelProvider);

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

    return Stack(
      children: [
        Column(
          children: [
            // ── View mode tabs ─────────────────────────────────────────────
            _ModeTabs(
              viewMode: vm.viewMode,
              onChanged: vm.setViewMode,
            ),
            // ── Month navigation ───────────────────────────────────────────
            _MonthNav(
              label: vm.monthLabel,
              isCurrentMonth: vm.isCurrentMonth,
              onPrev: vm.prevMonth,
              onNext: vm.nextMonth,
            ),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: vm.viewMode == BudgetViewMode.table
                  ? _TableSection(vm: vm)
                  : _GraphSection(vm: vm),
            ),
          ],
        ),
        // ── FAB — only shown in table mode ─────────────────────────────────
        if (vm.viewMode == BudgetViewMode.table)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showBudgetSheet(context, ref, null),
              backgroundColor: _purple,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  static void _showBudgetSheet(
      BuildContext context, WidgetRef ref, MonthBudgetRow? row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetEditSheet(row: row),
    );
  }
}

// ─── Mode tabs ────────────────────────────────────────────────────────────────

class _ModeTabs extends StatelessWidget {
  final BudgetViewMode viewMode;
  final ValueChanged<BudgetViewMode> onChanged;

  const _ModeTabs({required this.viewMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ModeTab(
            label: AppLocalizations.of(context)!.budgetTable,
            active: viewMode == BudgetViewMode.table,
            onTap: () => onChanged(BudgetViewMode.table),
          ),
          _ModeTab(
            label: AppLocalizations.of(context)!.budgetGraph,
            active: viewMode == BudgetViewMode.graph,
            onTap: () => onChanged(BudgetViewMode.graph),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF667EEA) : const Color(0xFF888888),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Month navigation ─────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final String label;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNav({
    required this.label,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _NavArrow(icon: Icons.chevron_left, onTap: onPrev),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          _NavArrow(
            icon: Icons.chevron_right,
            onTap: onNext,
            muted: isCurrentMonth,
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;

  const _NavArrow({required this.icon, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: muted ? const Color(0xFFCCCCCC) : const Color(0xFF444444),
          size: 20,
        ),
      ),
    );
  }
}

// ─── Table section ────────────────────────────────────────────────────────────

class _TableSection extends ConsumerWidget {
  final BudgetViewModel vm;
  const _TableSection({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vm.state == BudgetLoadState.loading) {
      return _buildSkeleton();
    }
    if (vm.state == BudgetLoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.budgetLoadFailed,
                style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: vm.load, child: Text(AppLocalizations.of(context)!.commonRetry)),
          ],
        ),
      );
    }

    if (vm.budgetRows.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.budgetNoCategories,
            style: const TextStyle(color: Color(0xFF888888))),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      children: [
        // Hint row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.edit, size: 13, color: Color(0xFFAAAAAA)),
              const SizedBox(width: 4),
              Text(AppLocalizations.of(context)!.budgetTapToSet,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
            ],
          ),
        ),
        // Column header
        _TableHeader(),
        // Rows
        ...vm.budgetRows.map((row) => _BudgetRow(row: row, vm: vm)),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(l10n.budgetCategory,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888))),
          ),
          Expanded(
            flex: 3,
            child: Text(l10n.budgetOf,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888))),
          ),
          Expanded(
            flex: 3,
            child: Text(l10n.budgetSpent,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888))),
          ),
          Expanded(
            flex: 3,
            child: Text(l10n.budgetLeft,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888))),
          ),
        ],
      ),
    );
  }
}

// ─── Individual budget row ────────────────────────────────────────────────────

class _BudgetRow extends ConsumerStatefulWidget {
  final MonthBudgetRow row;
  final BudgetViewModel vm;

  const _BudgetRow({required this.row, required this.vm});

  @override
  ConsumerState<_BudgetRow> createState() => _BudgetRowState();
}

class _BudgetRowState extends ConsumerState<_BudgetRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final vm = widget.vm;
    final isEditing = vm.editingBudgetCategoryId == row.id;
    final catColor = _hexColor(row.color);
    final overBudget = vm.isOverBudget(row);
    final fraction = vm.spentFraction(row).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: isEditing
          ? null
          : () {
              _ctrl.text = row.effectiveBudget?.toStringAsFixed(0) ?? '';
              vm.startEditBudget(row);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEditing
                ? const Color(0xFF667EEA)
                : const Color(0xFFEEEEEE),
            width: isEditing ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          children: [
            // ── Main row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  // Icon + name
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: row.icon.isNotEmpty
                                ? Icon(iconDataFromName(row.icon),
                                    size: 16, color: catColor)
                                : Text(
                                    row.name.isNotEmpty
                                        ? row.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: catColor),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            row.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Budget
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.effectiveBudget != null
                          ? '₪${row.effectiveBudget!.toStringAsFixed(0)}'
                          : AppLocalizations.of(context)!.budgetSetBudget,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: row.effectiveBudget != null
                            ? const Color(0xFF333333)
                            : const Color(0xFF667EEA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Spent
                  Expanded(
                    flex: 3,
                    child: Text(
                      '₪${row.spent.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF555555)),
                    ),
                  ),
                  // Result
                  Expanded(
                    flex: 3,
                    child: row.result != null
                        ? Text(
                            row.result! > 0
                                ? '-₪${row.result!.abs().toStringAsFixed(0)}'
                                : '+₪${row.result!.abs().toStringAsFixed(0)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: overBudget
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF43A047),
                            ),
                          )
                        : const Text('—',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                color: Color(0xFFCCCCCC), fontSize: 13)),
                  ),
                ],
              ),
            ),
            // ── Progress bar ──────────────────────────────────────────────
            if (row.effectiveBudget != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overBudget
                          ? const Color(0xFFE53935)
                          : const Color(0xFF43A047),
                    ),
                  ),
                ),
              ),
            // ── Inline editor ─────────────────────────────────────────────
            if (isEditing) _buildEditor(row, vm),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(MonthBudgetRow row, BudgetViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8FF),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode tabs
          Row(
            children: [
              _editModeTab(
                label: AppLocalizations.of(context)!.budgetEveryMonth,
                active: vm.editingBudgetMode == EditMode.base,
                onTap: () => vm.setEditMode(EditMode.base, row),
              ),
              const SizedBox(width: 8),
              _editModeTab(
                label: vm.monthLabel,
                active: vm.editingBudgetMode == EditMode.month,
                onTap: () => vm.setEditMode(EditMode.month, row),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amount input + buttons
          Row(
            children: [
              // Amount field
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('₪',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF444444))),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          onChanged: (v) =>
                              vm.setEditingValue(double.tryParse(v)),
                          onSubmitted: (_) => vm.commitEdit(row.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Save
              GestureDetector(
                onTap: () => vm.commitEdit(row.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(AppLocalizations.of(context)!.budgetSave,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 6),
              // Cancel
              GestureDetector(
                onTap: vm.cancelEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(AppLocalizations.of(context)!.budgetCancel,
                      style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editModeTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF667EEA) : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

// ─── Graph section ────────────────────────────────────────────────────────────

class _GraphSection extends StatelessWidget {
  final BudgetViewModel vm;
  const _GraphSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _CategoryDropdown(vm: vm),
        ),
        // Graph sub-tabs
        _GraphTabs(graphMode: vm.graphMode, onChanged: vm.setGraphMode),
        const SizedBox(height: 12),
        // Chart
        Expanded(
          child: vm.graphLoading
              ? const Center(child: CircularProgressIndicator())
              : _BarChart(vm: vm),
        ),
      ],
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final BudgetViewModel vm;
  const _CategoryDropdown({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: vm.selectedCategoryId,
          isExpanded: true,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(AppLocalizations.of(context)!.budgetAllCategories),
            ),
            ...vm.budgetRows.map(
              (row) => DropdownMenuItem<int?>(
                value: row.id,
                child: Text(row.name),
              ),
            ),
          ],
          onChanged: vm.onCategoryChanged,
        ),
      ),
    );
  }
}

class _GraphTabs extends StatelessWidget {
  final GraphMode graphMode;
  final ValueChanged<GraphMode> onChanged;
  const _GraphTabs({required this.graphMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _GraphTab(
            label: AppLocalizations.of(context)!.budgetByWeek,
            active: graphMode == GraphMode.week,
            onTap: () => onChanged(GraphMode.week),
          ),
          const SizedBox(width: 8),
          _GraphTab(
            label: AppLocalizations.of(context)!.budgetByMonth,
            active: graphMode == GraphMode.month,
            onTap: () => onChanged(GraphMode.month),
          ),
        ],
      ),
    );
  }
}

class _GraphTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _GraphTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF667EEA) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

// ─── Bar chart ────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final BudgetViewModel vm;
  const _BarChart({required this.vm});

  List<({String label, double value})> get _data {
    if (vm.graphMode == GraphMode.week) {
      return vm.weekData
          .map((w) => (label: w.weekLabel, value: w.total))
          .toList();
    } else {
      return vm.monthData
          .map((m) => (label: m.label, value: m.total))
          .toList();
    }
  }

  Color get _barColor {
    if (vm.selectedCategoryId != null) {
      final row = vm.budgetRows
          .where((r) => r.id == vm.selectedCategoryId)
          .firstOrNull;
      if (row != null) {
        try {
          return Color(
              int.parse('FF${row.color.replaceAll('#', '')}', radix: 16));
        } catch (_) {}
      }
    }
    return const Color(0xFF667EEA);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.budgetNoData,
            style: const TextStyle(color: Color(0xFF888888))),
      );
    }

    final maxVal = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final barColor = _barColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: CustomPaint(
        painter:
            _BarChartPainter(data: data, maxVal: maxVal, barColor: barColor),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<({String label, double value})> data;
  final double maxVal;
  final Color barColor;

  _BarChartPainter({
    required this.data,
    required this.maxVal,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = data.length;
    if (n == 0) return;

    final chartHeight = size.height - 40; // reserve 40px for x labels
    final slotWidth = size.width / n;
    final barWidth = slotWidth * 0.55;

    final barPaint = Paint()..color = barColor;
    final baselinePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;

    // Baseline
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      baselinePaint,
    );

    for (int i = 0; i < n; i++) {
      final d = data[i];
      final barH = maxVal > 0 ? (d.value / maxVal) * chartHeight : 0.0;
      final x = i * slotWidth + (slotWidth - barWidth) / 2;
      final y = chartHeight - barH;

      // Bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      // Value label above bar (if bar tall enough)
      if (barH > 16) {
        final valSpan = TextSpan(
          text: '₪${d.value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: barColor,
          ),
        );
        final valPainter =
            TextPainter(text: valSpan, textDirection: TextDirection.ltr)
              ..layout();
        valPainter.paint(
          canvas,
          Offset(x + (barWidth - valPainter.width) / 2, y - 13),
        );
      }

      // X label
      final span = TextSpan(
        text: d.label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
      );
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: slotWidth);
      painter.paint(
        canvas,
        Offset(x + (barWidth - painter.width) / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.maxVal != maxVal || old.barColor != barColor;
}

// ─── Budget quick-add/edit bottom sheet ──────────────────────────────────────

class _BudgetEditSheet extends ConsumerStatefulWidget {
  final MonthBudgetRow? row;
  const _BudgetEditSheet({this.row});

  @override
  ConsumerState<_BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends ConsumerState<_BudgetEditSheet> {
  late TextEditingController _amountCtrl;
  EditMode _editMode = EditMode.base;

  static const _purple = Color(0xFF667EEA);

  @override
  void initState() {
    super.initState();
    final initial = widget.row?.effectiveBudget;
    _amountCtrl = TextEditingController(
        text: initial != null ? initial.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(budgetViewModelProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                const Text('Set Budget',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Category picker (when no row pre-selected)
            if (widget.row == null) ...[
              const Text('Category',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFAFAFA),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: vm.editingBudgetCategoryId,
                    isExpanded: true,
                    hint: const Text('Select category'),
                    items: vm.budgetRows
                        .map((r) => DropdownMenuItem<int?>(
                              value: r.id,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final row =
                            vm.budgetRows.firstWhere((r) => r.id == id);
                        vm.startEditBudget(row);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Edit mode tabs
            const Text('Apply to',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444))),
            const SizedBox(height: 8),
            Row(
              children: [
                _modeChip('Every month', EditMode.base),
                const SizedBox(width: 8),
                _modeChip('${vm.monthLabel} only', EditMode.month),
              ],
            ),
            const SizedBox(height: 16),
            // Amount
            const Text('Amount',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFFAFAFA),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('₪',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444))),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600),
                      onChanged: (v) =>
                          vm.setEditingValue(double.tryParse(v)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final categoryId =
                      widget.row?.id ?? vm.editingBudgetCategoryId;
                  if (categoryId == null) return;
                  final nav = Navigator.of(context);
                  await vm.commitEdit(categoryId);
                  nav.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Budget',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, EditMode mode) {
    final active = _editMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _editMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF667EEA) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}
