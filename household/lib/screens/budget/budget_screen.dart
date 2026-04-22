import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/budget.dart';
import 'package:household/models/category.dart';
import 'package:household/screens/budget/budget_view_model.dart';
import 'package:household/utils/icon_helper.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  // ignore: unused_field
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
              label: vm.monthLabel(Localizations.localeOf(context).languageCode),
              isCurrentMonth: vm.isCurrentMonth,
              onPrev: vm.prevMonth,
              onNext: vm.nextMonth,
            ),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: vm.viewMode == BudgetViewMode.table
                  ? _TableSection(vm: vm)
                  : vm.viewMode == BudgetViewMode.graph
                      ? _GraphSection(vm: vm)
                      : _PlanSection(vm: vm),
            ),
          ],
        ),
      ],
    );
  }

  // ignore: unused_element
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
          _ModeTab(
            label: AppLocalizations.of(context)!.budgetPlan,
            active: viewMode == BudgetViewMode.plan,
            onTap: () => onChanged(BudgetViewMode.plan),
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
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

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
          color: const Color(0xFF444444),
          size: 20,
        ),
      ),
    );
  }
}

// ─── Table section ────────────────────────────────────────────────────────────

class _TableSection extends ConsumerStatefulWidget {
  final BudgetViewModel vm;
  const _TableSection({required this.vm});

  @override
  ConsumerState<_TableSection> createState() => _TableSectionState();
}

class _TableSectionState extends ConsumerState<_TableSection> {
  final Set<int> _expandedIds = {};

  void _toggleExpand(int id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  /// Sum effective budgets for parent + children. Returns null if none are set.
  double? _sumBudgets(MonthBudgetRow parent, List<MonthBudgetRow> children) {
    final all = [parent, ...children];
    final withBudget = all.where((r) => r.effectiveBudget != null);
    if (withBudget.isEmpty) return null;
    return withBudget.fold<double>(0.0, (s, r) => s + r.effectiveBudget!);
  }

  List<Widget> _buildRows(BudgetViewModel vm) {
    final rows = vm.budgetRows;
    final parents = rows.where((r) => r.parentCategoryId == null).toList();
    final childrenByParent = <int, List<MonthBudgetRow>>{};
    for (final r in rows) {
      if (r.parentCategoryId != null) {
        childrenByParent.putIfAbsent(r.parentCategoryId!, () => []).add(r);
      }
    }

    final widgets = <Widget>[];
    for (final parent in parents) {
      final children = childrenByParent[parent.id] ?? [];
      if (children.isEmpty) {
        widgets.add(_BudgetRow(row: parent, vm: vm));
      } else {
        final isExpanded = _expandedIds.contains(parent.id);
        final totalSpent =
            parent.spent + children.fold(0.0, (s, c) => s + c.spent);
        final totalBudget = _sumBudgets(parent, children);
        final totalResult =
            totalBudget != null ? totalSpent - totalBudget : null;

        widgets.add(_BudgetRow(
          row: parent,
          vm: vm,
          hasChildren: true,
          isExpanded: isExpanded,
          onExpandToggle: () => _toggleExpand(parent.id),
          displaySpent: totalSpent,
          displayBudget: totalBudget,
          displayResult: totalResult,
        ));

        if (isExpanded) {
          for (final child in children) {
            widgets.add(_BudgetRow(
              row: child,
              vm: vm,
              parentRow: parent,
              isChild: true,
            ));
          }
        }
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
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
            ElevatedButton(
                onPressed: vm.load,
                child: Text(AppLocalizations.of(context)!.commonRetry)),
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

    return Column(
      children: [
        // Sticky hint + column header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 13, color: Color(0xFFAAAAAA)),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.budgetTapToSet,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFAAAAAA))),
                  ],
                ),
              ),
              const _TableHeader(),
            ],
          ),
        ),
        // Scrollable rows
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            children: _buildRows(vm),
          ),
        ),
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

  /// If set, show a parent icon badge in the top-right corner of the icon.
  final MonthBudgetRow? parentRow;

  /// Whether this row has children (shows expand/collapse chevron).
  final bool hasChildren;

  /// Expansion state (only meaningful when hasChildren == true).
  final bool isExpanded;

  /// Called when the row header is tapped and hasChildren == true.
  final VoidCallback? onExpandToggle;

  /// Whether this row is a child (adds indentation).
  final bool isChild;

  /// Override for the displayed "spent" value (parent shows child sum).
  final double? displaySpent;

  /// Override for the displayed "budget" value (parent shows child sum).
  final double? displayBudget;

  /// Override for the displayed "result" value (parent shows child sum).
  final double? displayResult;

  const _BudgetRow({
    required this.row,
    required this.vm,
    this.parentRow,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onExpandToggle,
    this.isChild = false,
    this.displaySpent,
    this.displayBudget,
    this.displayResult,
  });

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
    final parentRow = widget.parentRow;
    final isEditing = vm.editingBudgetCategoryId == row.id;
    final catColor = _hexColor(row.color);
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final displayName = isHe ? (row.nameHe ?? row.name) : row.name;

    // Main row always shows the category's OWN values.
    final effectiveBudget = row.effectiveBudget;
    final spent = row.spent;
    final result = row.result;
    final overBudget = result != null && result > 0;
    final fraction = (effectiveBudget != null && effectiveBudget > 0)
        ? (spent / effectiveBudget).clamp(0.0, 1.0)
        : 0.0;

    // For parent rows with children: total summary values.
    final totalBudget = widget.displayBudget;
    final totalSpent = widget.displaySpent;
    final totalResult = widget.displayResult;
    final totalOverBudget = totalResult != null && totalResult > 0;
    final totalFraction = (totalBudget != null && totalBudget > 0)
        ? ((totalSpent ?? 0) / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    void openEditor() {
      if (!isEditing) {
        _ctrl.text = row.effectiveBudget?.toStringAsFixed(0) ?? '';
        vm.startEditBudget(row);
      }
    }

    return GestureDetector(
      // Parent rows: tap toggles expand. Child/standalone: tap = edit budget.
      onTap: isEditing
          ? null
          : widget.hasChildren
              ? widget.onExpandToggle
              : openEditor,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: widget.isChild ? 12 : 0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEditing
                ? const Color(0xFF667EEA)
                : widget.hasChildren
                    ? catColor.withValues(alpha: 0.3)
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
                  // Icon (with optional parent badge) + name
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Stack(
                            clipBehavior: Clip.none,
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
                                          displayName.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: catColor),
                                        ),
                                ),
                              ),
                              // Parent icon badge (for sub-categories)
                              if (parentRow != null)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _hexColor(parentRow.color),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        iconDataFromName(parentRow.icon),
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              // Expand/collapse chevron (for parent rows with children)
                              if (widget.hasChildren)
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: catColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        widget.isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: widget.hasChildren
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Budget
                  Expanded(
                    flex: 3,
                    child: Text(
                      effectiveBudget != null
                          ? '₪${effectiveBudget.toStringAsFixed(0)}'
                          : AppLocalizations.of(context)!.budgetSetBudget,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: effectiveBudget != null
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
                      '₪${spent.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF555555)),
                    ),
                  ),
                  // Result
                  Expanded(
                    flex: 3,
                    child: result != null
                        ? Text(
                            result > 0
                                ? '-₪${result.abs().toStringAsFixed(0)}'
                                : '+₪${result.abs().toStringAsFixed(0)}',
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
            // ── Progress bar (own) ────────────────────────────────────────
            if (effectiveBudget != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 0, 12, widget.hasChildren ? 4 : 10),
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
            // ── Total summary row (parent with children only) ─────────────
            if (widget.hasChildren && totalSpent != null)
              GestureDetector(
                onTap: openEditor,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              '∑ Total',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: catColor),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              totalBudget != null
                                  ? '₪${totalBudget.toStringAsFixed(0)}'
                                  : '—',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: catColor),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              '₪${totalSpent.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: catColor),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: totalResult != null
                                ? Text(
                                    totalResult > 0
                                        ? '-₪${totalResult.abs().toStringAsFixed(0)}'
                                        : '+₪${totalResult.abs().toStringAsFixed(0)}',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: totalOverBudget
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF43A047),
                                    ),
                                  )
                                : const Text('—',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFCCCCCC))),
                          ),
                        ],
                      ),
                      if (totalBudget != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: totalFraction,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFE0E0E0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                totalOverBudget
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF43A047),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                label: vm.monthLabel(Localizations.localeOf(context).languageCode),
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
    final isHe = Localizations.localeOf(context).languageCode == 'he';
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
                child: Text(isHe ? (row.nameHe ?? row.name) : row.name),
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

// ─── Plan section ────────────────────────────────────────────────────────────

class _PlanSection extends ConsumerStatefulWidget {
  final BudgetViewModel vm;
  const _PlanSection({required this.vm});

  @override
  ConsumerState<_PlanSection> createState() => _PlanSectionState();
}

class _PlanSectionState extends ConsumerState<_PlanSection> {
  static const _purple = Color(0xFF667EEA);

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    if (vm.planLoading && vm.planItems.isEmpty && vm.allExpenseCategories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
                          children: [
                            TextSpan(text: '${l10n.budgetPlanMin} '),
                            TextSpan(
                              text: '₪${vm.planGrandMin.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF43A047)),
                            ),
                            TextSpan(text: '   ${l10n.budgetPlanMax} '),
                            TextSpan(
                              text: '₪${vm.planGrandMax.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (vm.planMonthConfig?.expectedIncome != null)
                      Builder(builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${l10n.budgetPlanIncome}: ₪${vm.planMonthConfig!.expectedIncome!.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888)),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              // Month prediction settings button
              GestureDetector(
                onTap: () => _showMonthSettings(context, vm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 15, color: _purple),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.budgetPlanPrediction,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _purple)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Category list ────────────────────────────────────────────────
        Expanded(
          child: vm.allExpenseCategories.isEmpty
              ? const Center(
                  child: Text('No categories.',
                      style: TextStyle(color: Color(0xFF888888))))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    for (final cat in vm.allExpenseCategories)
                      _buildCategoryBlock(context, vm, cat),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryBlock(
      BuildContext context, BudgetViewModel vm, Category cat) {
    final catColor = _hexColor(cat.color);
    final catItems = vm.planItemsForCategory(cat.id);
    final minT = vm.planMinTotalForCategoryTree(cat);
    final maxT = vm.planMaxTotalForCategoryTree(cat);
    final expanded = vm.expandedPlanCategories.contains(cat.id);
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final displayName = isHe ? (cat.nameHe ?? cat.name) : cat.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header row — tap to expand/collapse
          GestureDetector(
            onTap: () => vm.togglePlanCategoryExpanded(cat.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(iconDataFromName(cat.icon),
                          size: 15, color: catColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(displayName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  _TotalBadge(min: minT, max: maxT, color: catColor),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFFAAAAAA),
                  ),
                  const SizedBox(width: 2),
                  _AddButton(
                      color: catColor,
                      onTap: () => vm.addPlanItem(categoryId: cat.id)),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            if (catItems.isNotEmpty) ...[
              Divider(
                  height: 1,
                  color: const Color(0xFFF0F0F0),
                  indent: 12,
                  endIndent: 12),
              _expenseColumnHeader(small: false),
              for (final item in catItems)
                _PlanExpenseLine(
                  key: ValueKey('plan_${item.id}'),
                  item: item,
                  color: catColor,
                  onSave: (d, mn, mx) => vm.updatePlanItem(
                      id: item.id,
                      description: d,
                      minAmount: mn,
                      maxAmount: mx),
                  onDelete: () => vm.deletePlanItem(item.id),
                ),
            ],
            // Subcategory sections
            for (final sub in cat.subCategories)
              _buildSubCategorySection(context, vm, sub),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _expenseColumnHeader({required bool small}) {
    final hPad = small ? 10.0 : 12.0;
    final amtW = small ? 62.0 : 70.0;
    const fs = 9.0;
    const color = Color(0xFFAAAAAA);
    return Builder(builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 4, 4, 0),
        child: Row(
          children: [
            const Expanded(
                child: Text('Note',
                    style: TextStyle(fontSize: fs, color: color))),
            const SizedBox(width: 6),
            SizedBox(
              width: amtW,
              child: Text(l10n.budgetPlanMin,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: fs, color: color)),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: amtW,
              child: Text(l10n.budgetPlanMax,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: fs, color: color)),
            ),
            const SizedBox(width: 32),
          ],
        ),
      );
    });
  }

  Widget _buildSubCategorySection(
      BuildContext context, BudgetViewModel vm, Category sub) {
    final subColor = _hexColor(sub.color);
    final subItems = vm.planItemsForCategory(sub.id);
    final minT = vm.planMinTotalForCategory(sub.id);
    final maxT = vm.planMaxTotalForCategory(sub.id);
    final expanded = vm.expandedPlanCategories.contains(sub.id);
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final displaySubName = isHe ? (sub.nameHe ?? sub.name) : sub.name;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: subColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border:
            Border(left: BorderSide(color: subColor.withValues(alpha: 0.5), width: 2)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => vm.togglePlanCategoryExpanded(sub.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                        child: Icon(iconDataFromName(sub.icon),
                            size: 12, color: subColor)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(displaySubName,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subColor)),
                  ),
                  _TotalBadge(min: minT, max: maxT, color: subColor, small: true),
                  const SizedBox(width: 2),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: subColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 2),
                  _AddButton(
                      color: subColor,
                      small: true,
                      onTap: () => vm.addPlanItem(categoryId: sub.id)),
                ],
              ),
            ),
          ),
          if (expanded && subItems.isNotEmpty) ...[
            _expenseColumnHeader(small: true),
            for (final item in subItems)
              _PlanExpenseLine(
                key: ValueKey('plan_${item.id}'),
                item: item,
                color: subColor,
                small: true,
                onSave: (d, mn, mx) => vm.updatePlanItem(
                    id: item.id,
                    description: d,
                    minAmount: mn,
                    maxAmount: mx),
                onDelete: () => vm.deletePlanItem(item.id),
              ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showMonthSettings(BuildContext context, BudgetViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => _MonthSettingsDialog(vm: vm),
    );
  }
}

// ─── Add button ───────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final bool small;

  const _AddButton(
      {required this.color, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 24.0 : 28.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(small ? 6 : 7),
        ),
        child: Icon(Icons.add, size: small ? 14 : 16, color: color),
      ),
    );
  }
}

// ─── Total badge ──────────────────────────────────────────────────────────────

class _TotalBadge extends StatelessWidget {
  final double min;
  final double max;
  final Color color;
  final bool small;

  const _TotalBadge(
      {required this.min,
      required this.max,
      required this.color,
      this.small = false});

  @override
  Widget build(BuildContext context) {
    final fs = small ? 10.0 : 11.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('₪${min.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF43A047))),
        Text('₪${max.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888))),
      ],
    );
  }
}

// ─── Plan expense line ────────────────────────────────────────────────────────

class _PlanExpenseLine extends StatefulWidget {
  final BudgetPlanItem item;
  final Color color;
  final bool small;
  final void Function(String? description, double minAmount, double maxAmount)
      onSave;
  final VoidCallback onDelete;

  const _PlanExpenseLine({
    super.key,
    required this.item,
    required this.color,
    required this.onSave,
    required this.onDelete,
    this.small = false,
  });

  @override
  State<_PlanExpenseLine> createState() => _PlanExpenseLineState();
}

class _PlanExpenseLineState extends State<_PlanExpenseLine> {
  late final TextEditingController _note;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final FocusNode _noteFocus;
  late final FocusNode _minFocus;
  late final FocusNode _maxFocus;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _note = TextEditingController(text: i.description ?? '');
    _min = TextEditingController(
        text: i.minAmount > 0 ? i.minAmount.toStringAsFixed(0) : '');
    _max = TextEditingController(
        text: i.maxAmount > 0 ? i.maxAmount.toStringAsFixed(0) : '');
    _noteFocus = FocusNode()..addListener(_onFocusChange);
    _minFocus = FocusNode()..addListener(_onFocusChange);
    _maxFocus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_noteFocus.hasFocus && !_minFocus.hasFocus && !_maxFocus.hasFocus) {
      _save();
    }
  }

  void _save() {
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final min = double.tryParse(_min.text.trim()) ?? 0.0;
    final max = double.tryParse(_max.text.trim()) ?? 0.0;
    widget.onSave(note, min, max);
  }

  @override
  void dispose() {
    _note.dispose();
    _min.dispose();
    _max.dispose();
    _noteFocus.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDec({String? hint, String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: widget.color, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      );

  @override
  Widget build(BuildContext context) {
    final small = widget.small;
    final hPad = small ? 10.0 : 12.0;
    final fs = small ? 11.0 : 13.0;
    final amtW = small ? 62.0 : 70.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 3, 4, 3),
      child: Row(
        children: [
          // Note
          Expanded(
            child: TextField(
              controller: _note,
              focusNode: _noteFocus,
              decoration: _fieldDec(hint: 'Note...'),
              style: TextStyle(fontSize: fs),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(width: 6),
          // Min
          SizedBox(
            width: amtW,
            child: TextField(
              controller: _min,
              focusNode: _minFocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _fieldDec(hint: '0', prefix: '₪'),
              style: TextStyle(fontSize: fs),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(width: 4),
          // Max
          SizedBox(
            width: amtW,
            child: TextField(
              controller: _max,
              focusNode: _maxFocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _fieldDec(hint: '0', prefix: '₪'),
              style: TextStyle(fontSize: fs),
              onSubmitted: (_) => _save(),
            ),
          ),
          // Delete
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.delete_outline,
                size: small ? 16 : 18, color: const Color(0xFFE53935)),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Month settings dialog ────────────────────────────────────────────────────

class _MonthSettingsDialog extends StatefulWidget {
  final BudgetViewModel vm;
  const _MonthSettingsDialog({required this.vm});

  @override
  State<_MonthSettingsDialog> createState() => _MonthSettingsDialogState();
}

class _MonthSettingsDialogState extends State<_MonthSettingsDialog> {
  late final TextEditingController _incomeCtrl;
  static const _purple = Color(0xFF667EEA);

  @override
  void initState() {
    super.initState();
    final income = widget.vm.planMonthConfig?.expectedIncome;
    _incomeCtrl = TextEditingController(
        text: income != null ? income.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final income = double.tryParse(_incomeCtrl.text.trim());
    final grandMin = vm.planGrandMin;
    final grandMax = vm.planGrandMax;
    final remMin = income != null ? income - grandMin : null;
    final remMax = income != null ? income - grandMax : null;

    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.tune, color: _purple, size: 20),
          const SizedBox(width: 8),
          Text(l10n.budgetPlanMonthPrediction,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.budgetPlanIncome,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('₪',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444))),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _incomeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _row(l10n.budgetPlanTotalMin,
                '₪${grandMin.toStringAsFixed(0)}', const Color(0xFF43A047)),
            _row(l10n.budgetPlanTotalMax,
                '₪${grandMax.toStringAsFixed(0)}', const Color(0xFF888888)),
            if (remMin != null) ...[
              const Divider(height: 20),
              _row(
                l10n.budgetPlanRemainingMin,
                '₪${remMin.toStringAsFixed(0)}',
                remMin >= 0
                    ? const Color(0xFF43A047)
                    : const Color(0xFFE53935),
              ),
              _row(
                l10n.budgetPlanRemainingMax,
                '₪${(remMax ?? 0).toStringAsFixed(0)}',
                (remMax ?? 0) >= 0
                    ? const Color(0xFF43A047)
                    : const Color(0xFFE53935),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel,
              style: const TextStyle(color: Color(0xFF888888))),
        ),
        ElevatedButton(
          onPressed: () {
            final income = double.tryParse(_incomeCtrl.text.trim());
            widget.vm.setExpectedIncome(income);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  Widget _row(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }
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
                _modeChip('${vm.monthLabel(Localizations.localeOf(context).languageCode)} only', EditMode.month),
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
