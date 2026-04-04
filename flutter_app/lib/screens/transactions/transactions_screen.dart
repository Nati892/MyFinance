import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:household/screens/transactions/transactions_view_model.dart';
import 'package:household/widgets/create_category_sheet.dart';
import 'package:household/widgets/transaction_timeline.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const _kExpensePurple = Color(0xFF667EEA);
const _kIncomeGreen   = Color(0xFF4CAF50);

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int? _expandedCategoryId;
  double? _expandedCategoryYCenter;

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(transactionsViewModelProvider);

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
        // ── Main layout ───────────────────────────────────────────────────────
        Row(
          children: [
            // Category sidebar — shows all categories + enhanced filter button
            _TransactionsSidebar(
              categories: vm.allCategories,
              favoriteCategories: vm.favoriteCategories,
              filterCategoryId: vm.filterCategoryId,
              viewMode: vm.viewMode,
              priceMin: vm.priceMin,
              priceMax: vm.priceMax,
              onFilterChanged: vm.onCategorySelected,
              onViewModeChanged: vm.setViewMode,
              onPriceMinChanged: vm.setPriceMin,
              onPriceMaxChanged: vm.setPriceMax,
              onCategoryQuickAdd: (id) {
                vm.onCategoryQuickAdd(id);
                _showTransactionSheet(context, vm);
              },
              onEditCategory: (cat) => _showEditCategorySheet(context, vm, cat),
              onDeleteCategory: (cat) => _confirmDeleteCategory(context, vm, cat),
              onAddCategory: (parent, isExpense) =>
                  _showAddCategorySheet(context, vm, isExpense: isExpense, parent: parent),
              expenseCategoryIds: vm.expenseCategories
                  .expand((c) => c.flatList)
                  .map((c) => c.id)
                  .toSet(),
              expandedCategoryId: _expandedCategoryId,
              onCategoryExpanded: (id, yCenter) => setState(() {
                _expandedCategoryId = id;
                _expandedCategoryYCenter = yCenter;
              }),
            ),
            // Timeline
            Expanded(
              child: vm.state == TransactionsLoadState.error
                  ? _buildError(vm)
                  : TransactionTimeline(
                      transactions: vm.filteredTransactions,
                      loading: vm.state == TransactionsLoadState.loading,
                      onViewChanged: ({required view, required offset, week, dayDate}) {
                        vm.onViewChanged(
                            view: view, offset: offset, week: week, dayDate: dayDate);
                      },
                      onEdit: (tx) {
                        if (tx.txType == 'expense') {
                          final expense = vm.expenses.firstWhere((e) => e.id == tx.id);
                          vm.openEditExpenseModal(expense);
                        } else {
                          final income = vm.incomes.firstWhere((i) => i.id == tx.id);
                          vm.openEditIncomeModal(income);
                        }
                        _showTransactionSheet(context, vm);
                      },
                      onDelete: (tx) {
                        if (tx.txType == 'expense') {
                          final expense = vm.expenses.firstWhere((e) => e.id == tx.id);
                          _confirmDeleteExpense(context, vm, expense);
                        } else {
                          final income = vm.incomes.firstWhere((i) => i.id == tx.id);
                          _confirmDeleteIncome(context, vm, income);
                        }
                      },
                    ),
            ),
          ],
        ),

        // ── Floating sub-categories wheel ─────────────────────────────────────
        if (_expandedCategoryId != null)
          Builder(builder: (ctx) {
            final parent = vm.allCategories
                .where((c) => c.id == _expandedCategoryId)
                .firstOrNull;
            if (parent == null || parent.subCategories.isEmpty) {
              return const SizedBox.shrink();
            }
            // Vertically center the wheel on the parent tile, bounded by screen
            const wheelHeight = _SubCategoriesWheel.totalHeight;
            final screenHeight = MediaQuery.of(context).size.height;
            final rawTop = (_expandedCategoryYCenter ?? screenHeight / 2) - wheelHeight / 2;
            final top = rawTop.clamp(8.0, screenHeight - wheelHeight - 8.0);
            return Positioned(
              left: 80,
              top: top,
              child: _SubCategoriesWheel(
                parent: parent,
                onSelected: (id) {
                  setState(() {
                    _expandedCategoryId = null;
                    _expandedCategoryYCenter = null;
                  });
                  vm.onCategoryQuickAdd(id);
                  _showTransactionSheet(ctx, vm);
                },
                onClose: () => setState(() {
                  _expandedCategoryId = null;
                  _expandedCategoryYCenter = null;
                }),
              ),
            );
          }),

        // ── FABs (stacked column, bottom-end) ────────────────────────────────
        Positioned.directional(
          textDirection: Directionality.of(context),
          bottom: 16,
          end: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Green FAB — Add Income (top)
              FloatingActionButton(
                heroTag: 'fab_income',
                onPressed: () {
                  vm.openAddIncomeModal();
                  _showTransactionSheet(context, vm);
                },
                backgroundColor: _kIncomeGreen,
                child: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(height: 8),
              // Purple FAB — Add Expense (bottom)
              FloatingActionButton(
                heroTag: 'fab_expense',
                onPressed: () {
                  vm.openAddExpenseModal();
                  _showTransactionSheet(context, vm);
                },
                backgroundColor: _kExpensePurple,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(TransactionsViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.transactionsLoadFailed,
              style: const TextStyle(color: Color(0xFF888888))),
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: vm.loadTransactions, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }

  void _showTransactionSheet(BuildContext context, TransactionsViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => vm.isExpenseMode
          ? const _ExpenseFormSheet()
          : const _IncomeFormSheet(),
    );
  }

  void _confirmDeleteExpense(
      BuildContext context, TransactionsViewModel vm, Expense expense) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.commonDeleteExpense),
        content: Text(
          'Delete "${expense.description?.isNotEmpty == true ? expense.description : expense.category?.name ?? 'this expense'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteExpense(expense);
            },
            child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteIncome(
      BuildContext context, TransactionsViewModel vm, Income income) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.commonDeleteIncome),
        content: Text(
          'Delete "${income.description?.isNotEmpty == true ? income.description : income.category?.name ?? 'this income'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteIncome(income);
            },
            child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddCategorySheet(
    BuildContext context,
    TransactionsViewModel vm, {
    required bool isExpense,
    Category? parent,
  }) {
    final topLevel = isExpense
        ? vm.expenseCategories.where((c) => c.parentCategoryId == null).toList()
        : vm.incomeCategories.where((c) => c.parentCategoryId == null).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCategorySheet(
        categoryType: isExpense ? 'expense' : 'income',
        householdId: vm.householdId,
        topLevelCategories: topLevel,
        preselectedParentId: parent?.id,
        onCreated: (_) => vm.loadCategories(),
      ),
    );
  }

  void _showEditCategorySheet(BuildContext context, TransactionsViewModel vm, Category cat) {
    final isExpense = vm.expenseCategories.expand((c) => c.flatList).any((c) => c.id == cat.id);
    final topLevel = isExpense
        ? vm.expenseCategories.where((c) => c.parentCategoryId == null).toList()
        : vm.incomeCategories.where((c) => c.parentCategoryId == null).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCategorySheet(
        categoryType: isExpense ? 'expense' : 'income',
        householdId: vm.householdId,
        existing: cat,
        topLevelCategories: topLevel,
        onCreated: (updated) => isExpense
            ? vm.updateExpenseCategoryInList(updated)
            : vm.updateIncomeCategoryInList(updated),
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, TransactionsViewModel vm, Category cat) {
    final l10n = AppLocalizations.of(context)!;
    final isExpense = vm.expenseCategories.expand((c) => c.flatList).any((c) => c.id == cat.id);
    bool deleteRefs = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.categoryDeleteConfirm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat.name),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: deleteRefs,
                    onChanged: (v) => setDialogState(() => deleteRefs = v ?? false),
                  ),
                  Expanded(child: Text(l10n.categoryDeleteRefs, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (isExpense) {
                  vm.deleteExpenseCategory(cat.id, deleteRefs: deleteRefs);
                } else {
                  vm.deleteIncomeCategory(cat.id, deleteRefs: deleteRefs);
                }
              },
              child: Text(l10n.categoryDelete, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transactions-specific sidebar ───────────────────────────────────────────

class _TransactionsSidebar extends StatefulWidget {
  final List<Category> categories;
  final List<Category> favoriteCategories;
  final int? filterCategoryId;
  final String viewMode;
  final double? priceMin;
  final double? priceMax;
  final ValueChanged<int?> onFilterChanged;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<double?> onPriceMinChanged;
  final ValueChanged<double?> onPriceMaxChanged;
  final ValueChanged<int> onCategoryQuickAdd;
  final void Function(Category)? onEditCategory;
  final void Function(Category)? onDeleteCategory;
  final void Function(Category? parent, bool isExpense)? onAddCategory;
  /// IDs that belong to expense categories (used to distinguish in action sheet)
  final Set<int> expenseCategoryIds;
  final int? expandedCategoryId;
  final void Function(int? id, double? yCenter) onCategoryExpanded;

  const _TransactionsSidebar({
    required this.categories,
    required this.favoriteCategories,
    required this.filterCategoryId,
    required this.viewMode,
    required this.priceMin,
    required this.priceMax,
    required this.onFilterChanged,
    required this.onViewModeChanged,
    required this.onPriceMinChanged,
    required this.onPriceMaxChanged,
    required this.onCategoryQuickAdd,
    this.onEditCategory,
    this.onDeleteCategory,
    this.onAddCategory,
    this.expenseCategoryIds = const {},
    required this.expandedCategoryId,
    required this.onCategoryExpanded,
  });

  @override
  State<_TransactionsSidebar> createState() => _TransactionsSidebarState();
}

class _TransactionsSidebarState extends State<_TransactionsSidebar> {
  final Map<int, GlobalKey> _categoryKeys = {};

  void _handleCategoryTap(Category cat) {
    if (cat.subCategories.isEmpty) {
      if (widget.expandedCategoryId != null) {
        widget.onCategoryExpanded(null, null);
      }
      widget.onCategoryQuickAdd(cat.id);
    } else if (widget.expandedCategoryId == cat.id) {
      // Toggle off
      widget.onCategoryExpanded(null, null);
    } else {
      // Open wheel — compute Y center of this tile
      final key = _categoryKeys[cat.id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      final globalPos = box?.localToGlobal(Offset.zero);
      final height = box?.size.height ?? 72.0;
      final yCenter = (globalPos?.dy ?? 0) + height / 2;
      widget.onCategoryExpanded(cat.id, yCenter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterCat = widget.filterCategoryId != null
        ? widget.categories
            .expand((c) => c.flatList)
            .where((c) => c.id == widget.filterCategoryId)
            .firstOrNull
        : null;

    return Container(
      width: 80,
      color: Colors.white,
      child: Column(
        children: [
          // Enhanced filter tile
          GestureDetector(
            onTap: () => _showFilterSheet(context),
            child: _FilterTileWidget(
              category: filterCat,
              viewMode: widget.viewMode,
              priceMin: widget.priceMin,
              priceMax: widget.priceMax,
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                ...widget.categories.map((cat) {
                  final key = _categoryKeys.putIfAbsent(cat.id, () => GlobalKey());
                  return Container(
                    key: key,
                    child: _QuickAddTileWidget(
                      label: cat.name,
                      color: cat.color,
                      icon: cat.icon,
                      hasSubCategories: cat.subCategories.isNotEmpty,
                      isExpanded: widget.expandedCategoryId == cat.id,
                      onTap: () => _handleCategoryTap(cat),
                      onLongPress: (widget.onEditCategory != null ||
                              widget.onDeleteCategory != null)
                          ? () => _showCategoryActions(context, cat)
                          : null,
                    ),
                  );
                }),
                if (widget.favoriteCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(
                        height: 1, thickness: 1, indent: 8, endIndent: 8),
                  ),
                  const Center(
                    child: Text('★',
                        style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                  ),
                  ...widget.favoriteCategories.map((cat) => _QuickAddTileWidget(
                        label: cat.name,
                        color: cat.color,
                        icon: cat.icon,
                        hasSubCategories: false,
                        isExpanded: false,
                        onTap: () => widget.onCategoryQuickAdd(cat.id),
                      )),
                ],
                // ── Add category button ──────────────────────────────────────
                if (widget.onAddCategory != null)
                  GestureDetector(
                    onTap: () => _showAddTypeDialog(context),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFDDDDDD), width: 1),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: Color(0xFF888888)),
                          SizedBox(height: 2),
                          Text(
                            '+',
                            style: TextStyle(
                                fontSize: 9, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Search button (pinned at bottom) ──────────────────────────────
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          GestureDetector(
            onTap: () => _showSearchSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 20, color: Color(0xFF888888)),
                  const SizedBox(height: 3),
                  Text(
                    AppLocalizations.of(context)!.categorySearch,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.categoryNewExpense.replaceAll(' Category', ''),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.trending_down,
                  color: Color(0xFF667EEA)),
              title: Text(l10n.categoryNewExpense),
              onTap: () {
                Navigator.pop(context);
                widget.onAddCategory!(null, true);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.trending_up, color: Color(0xFF4CAF50)),
              title: Text(l10n.categoryNewIncome),
              onTap: () {
                Navigator.pop(context);
                widget.onAddCategory!(null, false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCategoryActions(BuildContext context, Category cat) {
    final l10n = AppLocalizations.of(context)!;
    // Determine if category is expense or income to enable "Add Subcategory"
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(cat.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            if (widget.onAddCategory != null && cat.parentCategoryId == null)
              ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right,
                    color: Color(0xFF888888)),
                title: Text(l10n.categorySubNew),
                onTap: () {
                  Navigator.pop(context);
                  final isExpense = widget.expenseCategoryIds.contains(cat.id);
                  widget.onAddCategory!(cat, isExpense);
                },
              ),
            if (widget.onEditCategory != null)
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: Color(0xFF667EEA)),
                title: Text(l10n.categoryEdit),
                onTap: () {
                  Navigator.pop(context);
                  widget.onEditCategory!(cat);
                },
              ),
            if (widget.onDeleteCategory != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(l10n.categoryDelete,
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDeleteCategory!(cat);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    final allCats = [
      ...widget.categories.expand((c) => c.flatList),
      ...widget.favoriteCategories
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CategorySearchSheet(
        categories: allCats,
        onCategorySelected: (id) {
          Navigator.pop(context);
          widget.onCategoryQuickAdd(id);
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => _TransactionFilterSheet(
          categories: widget.categories,
          filterCategoryId: widget.filterCategoryId,
          viewMode: widget.viewMode,
          priceMin: widget.priceMin,
          priceMax: widget.priceMax,
          scrollController: scrollController,
          onFilterChanged: (id) {
            Navigator.pop(context);
            widget.onFilterChanged(id);
          },
          onViewModeChanged: widget.onViewModeChanged,
          onPriceMinChanged: widget.onPriceMinChanged,
          onPriceMaxChanged: widget.onPriceMaxChanged,
        ),
      ),
    );
  }
}

// ── Local copies of sidebar sub-widgets ──────────────────────────────────────

class _FilterTileWidget extends StatelessWidget {
  final Category? category;
  final String viewMode;
  final double? priceMin;
  final double? priceMax;

  const _FilterTileWidget({
    this.category,
    required this.viewMode,
    this.priceMin,
    this.priceMax,
  });

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    final base = category != null ? _hexColor(category!.color) : indigo;
    final hasFilters = viewMode != 'all' || priceMin != null || priceMax != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      padding: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category != null ? iconDataFromName(category!.icon) : Icons.filter_list,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(height: 3),
              Text(
                category?.name ?? AppLocalizations.of(context)!.transactionsAll,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (hasFilters)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5252),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

class _QuickAddTileWidget extends StatelessWidget {
  final String label;
  final String color;
  final String? icon;
  final bool hasSubCategories;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickAddTileWidget({
    required this.label,
    required this.color,
    required this.icon,
    this.hasSubCategories = false,
    this.isExpanded = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final base = _hexColor(color);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(iconDataFromName(icon), size: 20, color: base),
                if (hasSubCategories)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 12,
                      color: base.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: base),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ── Enhanced filter bottom sheet ─────────────────────────────────────────────

// ── Sub-categories wheel ──────────────────────────────────────────────────────

class _SubCategoriesWheel extends StatelessWidget {
  final Category parent;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  static const double _itemExtent = 76.0;
  static const int _visibleItems = 3;
  static const double totalHeight = _itemExtent * _visibleItems;

  const _SubCategoriesWheel({
    required this.parent,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final base = _hexColor(parent.color);
    // Items: General (parent) first, then subcategories
    final items = <({int id, String? icon, String name, bool isGeneral})>[
      (id: parent.id, icon: parent.icon, name: 'General', isGeneral: true),
      ...parent.subCategories.map(
        (s) => (id: s.id, icon: s.icon, name: s.name, isGeneral: false),
      ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 76,
          height: totalHeight,
          child: ListWheelScrollView(
            itemExtent: _itemExtent,
            diameterRatio: 1.4,
            perspective: 0.004,
            squeeze: 1.0,
            physics: const FixedExtentScrollPhysics(),
            children: items.map((item) {
              return GestureDetector(
                onTap: () => onSelected(item.id),
                child: _WheelItem(
                  icon: item.icon,
                  name: item.name,
                  color: base,
                  isGeneral: item.isGeneral,
                ),
              );
            }).toList(),
          ),
        ),
        // Close button
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onClose,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close, size: 11, color: base.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

class _WheelItem extends StatelessWidget {
  final String? icon;
  final String name;
  final Color color;
  final bool isGeneral;

  const _WheelItem({
    required this.icon,
    required this.name,
    required this.color,
    required this.isGeneral,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: isGeneral ? 38 : 32,
          height: isGeneral ? 38 : 32,
          decoration: BoxDecoration(
            color: isGeneral
                ? color.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(isGeneral ? 10 : 8),
            border: isGeneral
                ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Icon(
            iconDataFromName(icon),
            size: isGeneral ? 20 : 17,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isGeneral ? 9 : 8,
            fontWeight: isGeneral ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Category search sheet ─────────────────────────────────────────────────────

class _CategorySearchSheet extends StatefulWidget {
  final List<Category> categories;
  final ValueChanged<int> onCategorySelected;

  const _CategorySearchSheet({required this.categories, required this.onCategorySelected});

  @override
  State<_CategorySearchSheet> createState() => _CategorySearchSheetState();
}

class _CategorySearchSheetState extends State<_CategorySearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.categorySearch,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: filtered.map((cat) {
                final color = _hexColor(cat.color);
                return ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(iconDataFromName(cat.icon), size: 18, color: color),
                    ),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => widget.onCategorySelected(cat.id),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TransactionFilterSheet extends StatefulWidget {
  final List<Category> categories;
  final int? filterCategoryId;
  final String viewMode;
  final double? priceMin;
  final double? priceMax;
  final ScrollController scrollController;
  final ValueChanged<int?> onFilterChanged;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<double?> onPriceMinChanged;
  final ValueChanged<double?> onPriceMaxChanged;

  const _TransactionFilterSheet({
    required this.categories,
    required this.filterCategoryId,
    required this.viewMode,
    required this.priceMin,
    required this.priceMax,
    required this.scrollController,
    required this.onFilterChanged,
    required this.onViewModeChanged,
    required this.onPriceMinChanged,
    required this.onPriceMaxChanged,
  });

  @override
  State<_TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late String _viewMode;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
    _minCtrl = TextEditingController(
        text: widget.priceMin != null ? widget.priceMin.toString() : '');
    _maxCtrl = TextEditingController(
        text: widget.priceMax != null ? widget.priceMax.toString() : '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Fixed header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)!.transactionsFilters,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // ── Show section ─────────────────────────────────────────────────
              Text(AppLocalizations.of(context)!.transactionsShow,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildViewModeChip('all', AppLocalizations.of(context)!.transactionsAll),
                  const SizedBox(width: 8),
                  _buildViewModeChip('expenses', AppLocalizations.of(context)!.transactionsExpensesOnly),
                  const SizedBox(width: 8),
                  _buildViewModeChip('incomes', AppLocalizations.of(context)!.transactionsIncomesOnly),
                ],
              ),
              const SizedBox(height: 16),

              // ── Price range section ───────────────────────────────────────────
              Text(AppLocalizations.of(context)!.transactionsPriceRange,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF555555))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco(AppLocalizations.of(context)!.transactionsMinUnlimited),
                      onChanged: (v) => widget.onPriceMinChanged(double.tryParse(v)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('–', style: TextStyle(fontSize: 16, color: Color(0xFF888888))),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco(AppLocalizations.of(context)!.transactionsMaxUnlimited),
                      onChanged: (v) => widget.onPriceMaxChanged(double.tryParse(v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Category section header ───────────────────────────────────────
              Text(AppLocalizations.of(context)!.transactionsCategory,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF555555))),
              const SizedBox(height: 4),
            ],
          ),
        ),

        // ── Scrollable category list ──────────────────────────────────────────
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.select_all, size: 18, color: Color(0xFF6366F1)),
                  ),
                ),
                title: Text(AppLocalizations.of(context)!.transactionsAll,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: widget.filterCategoryId == null
                    ? const Icon(Icons.check, color: Color(0xFF6366F1))
                    : null,
                onTap: () => widget.onFilterChanged(null),
              ),
              ...widget.categories.map((cat) {
                final color = _hexColor(cat.color);
                final selected = widget.filterCategoryId == cat.id;
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(iconDataFromName(cat.icon), size: 18, color: color),
                    ),
                  ),
                  title: Text(cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: selected ? Icon(Icons.check, color: color) : null,
                  onTap: () => widget.onFilterChanged(cat.id),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewModeChip(String value, String label) {
    final active = _viewMode == value;
    return GestureDetector(
      onTap: () {
        setState(() => _viewMode = value);
        widget.onViewModeChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
  );

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ─── Expense form sheet ───────────────────────────────────────────────────────

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet();

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _noteCtrl;

  static const _paymentMethodKeys = [
    ('credit_card', '💳'),
    ('debit_card',  '💳'),
    ('cash',        '💵'),
    ('bank_transfer','🏦'),
  ];

  @override
  void initState() {
    super.initState();
    final vm = ref.read(transactionsViewModelProvider);
    _amountCtrl = TextEditingController(
        text: vm.formAmount != null ? vm.formAmount.toString() : '');
    _descCtrl = TextEditingController(text: vm.formDescription);
    _noteCtrl = TextEditingController(text: vm.formNote);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(transactionsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
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
            _buildHandle(),
            const SizedBox(height: 16),
            _buildHeader(vm, l10n.transactionsExpenseLabel, _kExpensePurple, l10n),
            if (vm.modalError != null) _buildError(vm),
            const SizedBox(height: 16),
            _buildAmountField(vm),
            const SizedBox(height: 16),
            _buildLabel(l10n.expensesCategory),
            const SizedBox(height: 8),
            _buildCategoryChips(vm, vm.expenseCategories, l10n),
            const SizedBox(height: 16),
            _buildLabel(l10n.expensesDate),
            const SizedBox(height: 8),
            _buildDateTimePicker(vm),
            const SizedBox(height: 16),
            _buildLabel(l10n.expensesPaymentMethod),
            const SizedBox(height: 8),
            _buildPaymentSegment(vm, _kExpensePurple, l10n),
            const SizedBox(height: 16),
            _buildLabel(l10n.expensesDescription, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              onChanged: vm.setFormDescription,
              decoration: _inputDeco(l10n.expensesDescriptionPlaceholder, _kExpensePurple),
              maxLength: 200,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
            const SizedBox(height: 16),
            _buildLabel(l10n.expensesNote, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              onChanged: vm.setFormNote,
              decoration: _inputDeco(l10n.expensesNotePlaceholder, _kExpensePurple),
              maxLines: 3,
              maxLength: 500,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
            const SizedBox(height: 20),
            _buildSaveButton(
              vm: vm,
              color: _kExpensePurple,
              editLabel: l10n.expensesSave,
              addLabel: l10n.expensesAdd,
              onSave: vm.saveExpense,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader(TransactionsViewModel vm, String type, Color color, AppLocalizations l10n) {
    final editLabel = type == l10n.transactionsExpenseLabel ? l10n.expensesEdit : l10n.incomesEdit;
    final newLabel = type == l10n.transactionsExpenseLabel ? l10n.expensesNew : l10n.incomesNew;
    return Row(
      children: [
        Container(
          width: 6, height: 20,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Text(
          vm.isEditMode ? editLabel : newLabel,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            vm.closeModal();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildError(TransactionsViewModel vm) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            border: Border.all(color: const Color(0xFFFFCDD2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(vm.modalError!,
              style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildAmountField(TransactionsViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              onChanged: (v) => vm.setFormAmount(double.tryParse(v)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(TransactionsViewModel vm, List<Category> cats, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    if (cats.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildNewCategoryChip(vm, l10n),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...cats.map((cat) {
          final selected = vm.formCategoryId == cat.id;
          final base = _hexColor(cat.color);
          final catName = (locale.languageCode == 'he' && cat.nameHe?.isNotEmpty == true)
              ? cat.nameHe!
              : cat.name;
          return GestureDetector(
            onTap: () => vm.setFormCategory(cat.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? base : base.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconDataFromName(cat.icon),
                      size: 16, color: selected ? Colors.white : base),
                  const SizedBox(width: 4),
                  Text(
                    catName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        _buildNewCategoryChip(vm, l10n),
      ],
    );
  }

  Widget _buildNewCategoryChip(TransactionsViewModel vm, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _openCreateCategorySheet(context, ref, vm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Color(0xFF666666)),
            const SizedBox(width: 4),
            Text(l10n.commonNew, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }

  void _openCreateCategorySheet(BuildContext context, WidgetRef ref, TransactionsViewModel vm) {
    final categoryType = vm.isExpenseMode ? 'expense' : 'income';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCategorySheet(
        categoryType: categoryType,
        householdId: vm.householdId,
        onCreated: (cat) {
          if (vm.isExpenseMode) {
            vm.addExpenseCategory(cat);
          } else {
            vm.addIncomeCategory(cat);
          }
          vm.setFormCategory(cat.id);
        },
      ),
    );
  }

  Widget _buildDateTimePicker(TransactionsViewModel vm) {
    final dt = vm.formDateTime;
    final formatted =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: vm.formDateTime,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(vm.formDateTime),
        );
        if (time == null) return;
        vm.setFormDateTime(
            DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFFAFAFA),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF888888)),
            const SizedBox(width: 8),
            Text(formatted,
                style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSegment(TransactionsViewModel vm, Color activeColor, AppLocalizations l10n) {
    final labels = [l10n.paymentCard, l10n.paymentDebit, l10n.paymentCash, l10n.paymentTransfer];
    return Row(
      children: _paymentMethodKeys.asMap().entries.map((entry) {
        final idx = entry.key;
        final pm = entry.value;
        final active = vm.formPaymentMethod == pm.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => vm.setFormPayment(pm.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? activeColor : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(pm.$2, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    labels[idx],
                    style: TextStyle(
                      fontSize: 10,
                      color: active ? Colors.white : const Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton({
    required TransactionsViewModel vm,
    required Color color,
    required String editLabel,
    required String addLabel,
    required Future<void> Function() onSave,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: vm.modalSaving
            ? null
            : () async {
                final nav = Navigator.of(context);
                await onSave();
                if (vm.modalError == null) nav.pop();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: vm.modalSaving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(vm.isEditMode ? editLabel : addLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444))),
        if (optional)
          Text(' ${AppLocalizations.of(context)!.commonOptional}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, Color focusColor) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: focusColor, width: 1.5)),
  );

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ─── Income form sheet ────────────────────────────────────────────────────────

class _IncomeFormSheet extends ConsumerStatefulWidget {
  const _IncomeFormSheet();

  @override
  ConsumerState<_IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends ConsumerState<_IncomeFormSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _noteCtrl;

  static const _paymentMethodKeys = [
    ('credit_card',  '💳'),
    ('debit_card',   '💳'),
    ('cash',         '💵'),
    ('bank_transfer','🏦'),
  ];

  @override
  void initState() {
    super.initState();
    final vm = ref.read(transactionsViewModelProvider);
    _amountCtrl = TextEditingController(
        text: vm.formAmount != null ? vm.formAmount.toString() : '');
    _descCtrl = TextEditingController(text: vm.formDescription);
    _noteCtrl = TextEditingController(text: vm.formNote);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(transactionsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
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
            _buildHandle(),
            const SizedBox(height: 16),
            _buildHeader(vm, l10n.transactionsIncomeLabel, _kIncomeGreen, l10n),
            if (vm.modalError != null) _buildError(vm),
            const SizedBox(height: 16),
            _buildAmountField(vm),
            const SizedBox(height: 16),
            _buildLabel(l10n.incomesCategory),
            const SizedBox(height: 8),
            _buildCategoryChips(vm, vm.incomeCategories, l10n),
            const SizedBox(height: 16),
            _buildLabel(l10n.incomesDate),
            const SizedBox(height: 8),
            _buildDateTimePicker(vm),
            const SizedBox(height: 16),
            _buildLabel(l10n.incomesPaymentMethod),
            const SizedBox(height: 8),
            _buildPaymentSegment(vm, _kIncomeGreen, l10n),
            const SizedBox(height: 16),
            _buildLabel(l10n.incomesDescription, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              onChanged: vm.setFormDescription,
              decoration: _inputDeco(l10n.incomesDescriptionPlaceholder, _kIncomeGreen),
              maxLength: 200,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
            const SizedBox(height: 16),
            _buildLabel(l10n.incomesNote, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              onChanged: vm.setFormNote,
              decoration: _inputDeco(l10n.incomesNotePlaceholder, _kIncomeGreen),
              maxLines: 3,
              maxLength: 500,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
            const SizedBox(height: 20),
            _buildSaveButton(
              vm: vm,
              color: _kIncomeGreen,
              editLabel: l10n.incomesSave,
              addLabel: l10n.incomesAdd,
              onSave: vm.saveIncome,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader(TransactionsViewModel vm, String type, Color color, AppLocalizations l10n) {
    final editLabel = type == l10n.transactionsExpenseLabel ? l10n.expensesEdit : l10n.incomesEdit;
    final newLabel = type == l10n.transactionsExpenseLabel ? l10n.expensesNew : l10n.incomesNew;
    return Row(
      children: [
        Container(
          width: 6, height: 20,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Text(
          vm.isEditMode ? editLabel : newLabel,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            vm.closeModal();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildError(TransactionsViewModel vm) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            border: Border.all(color: const Color(0xFFFFCDD2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(vm.modalError!,
              style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildAmountField(TransactionsViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              onChanged: (v) => vm.setFormAmount(double.tryParse(v)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(TransactionsViewModel vm, List<Category> cats, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    if (cats.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildNewCategoryChip(vm, l10n),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...cats.map((cat) {
          final selected = vm.formCategoryId == cat.id;
          final base = _hexColor(cat.color);
          final catName = (locale.languageCode == 'he' && cat.nameHe?.isNotEmpty == true)
              ? cat.nameHe!
              : cat.name;
          return GestureDetector(
            onTap: () => vm.setFormCategory(cat.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? base : base.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconDataFromName(cat.icon),
                      size: 16, color: selected ? Colors.white : base),
                  const SizedBox(width: 4),
                  Text(
                    catName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        _buildNewCategoryChip(vm, l10n),
      ],
    );
  }

  Widget _buildNewCategoryChip(TransactionsViewModel vm, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _openCreateCategorySheet(context, ref, vm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Color(0xFF666666)),
            const SizedBox(width: 4),
            Text(l10n.commonNew, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }

  void _openCreateCategorySheet(BuildContext context, WidgetRef ref, TransactionsViewModel vm) {
    final categoryType = vm.isExpenseMode ? 'expense' : 'income';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCategorySheet(
        categoryType: categoryType,
        householdId: vm.householdId,
        onCreated: (cat) {
          if (vm.isExpenseMode) {
            vm.addExpenseCategory(cat);
          } else {
            vm.addIncomeCategory(cat);
          }
          vm.setFormCategory(cat.id);
        },
      ),
    );
  }

  Widget _buildDateTimePicker(TransactionsViewModel vm) {
    final dt = vm.formDateTime;
    final formatted =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: vm.formDateTime,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(vm.formDateTime),
        );
        if (time == null) return;
        vm.setFormDateTime(
            DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFFAFAFA),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF888888)),
            const SizedBox(width: 8),
            Text(formatted,
                style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSegment(TransactionsViewModel vm, Color activeColor, AppLocalizations l10n) {
    final labels = [l10n.paymentCard, l10n.paymentDebit, l10n.paymentCash, l10n.paymentTransfer];
    return Row(
      children: _paymentMethodKeys.asMap().entries.map((entry) {
        final idx = entry.key;
        final pm = entry.value;
        final active = vm.formPaymentMethod == pm.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => vm.setFormPayment(pm.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? activeColor : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(pm.$2, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    labels[idx],
                    style: TextStyle(
                      fontSize: 10,
                      color: active ? Colors.white : const Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton({
    required TransactionsViewModel vm,
    required Color color,
    required String editLabel,
    required String addLabel,
    required Future<void> Function() onSave,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: vm.modalSaving
            ? null
            : () async {
                final nav = Navigator.of(context);
                await onSave();
                if (vm.modalError == null) nav.pop();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: vm.modalSaving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(vm.isEditMode ? editLabel : addLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444))),
        if (optional)
          Text(' ${AppLocalizations.of(context)!.commonOptional}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, Color focusColor) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: focusColor, width: 1.5)),
  );

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}
