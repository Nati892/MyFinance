import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/models/credit_card.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/models/recurring_expense.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:household/utils/financial_calendar.dart';
import 'package:household/models/budget.dart';
import 'package:household/models/expense_schedule.dart';
import 'package:household/screens/transactions/transactions_view_model.dart';
import 'package:household/services/budget_service.dart';
import 'package:household/services/household_service.dart';
import 'package:household/widgets/create_category_sheet.dart';
import 'package:household/widgets/expense_form_sheet.dart';
import 'package:household/widgets/transaction_timeline.dart';
import 'package:image_picker/image_picker.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const _kIncomeGreen = Color(0xFF4CAF50);

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int? _expandedCategoryId;
  double? _expandedCategoryYCenter;
  final GlobalKey _stackKey = GlobalKey();
  // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
  // bool _favoritesExpanded = false;

  // Latest period info reported by TransactionTimeline.onPeriodChanged.
  // Drives the Summary popup contents.
  TimelinePeriodInfo? _periodInfo;

  // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
  // Color _hexColor(String hex) {
  //   try {
  //     final h = hex.trim().replaceFirst('#', '');
  //     return Color(int.parse('FF$h', radix: 16));
  //   } catch (_) {
  //     return Colors.grey;
  //   }
  // }

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
      key: _stackKey,
      children: [
        // ── Main layout ───────────────────────────────────────────────────────
        Row(
          children: [
            // Category sidebar — shows all categories + enhanced filter button
            _TransactionsSidebar(
              categories: vm.allCategories,
              // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
              // favoriteCategories: vm.favoriteCategories,
              filterCategoryId: vm.filterCategoryId,
              viewMode: vm.viewMode,
              priceMin: vm.priceMin,
              priceMax: vm.priceMax,
              filterInstallmentsOnly: vm.filterInstallmentsOnly,
              onFilterChanged: vm.onCategorySelected,
              onViewModeChanged: vm.setViewMode,
              onPriceMinChanged: vm.setPriceMin,
              onPriceMaxChanged: vm.setPriceMax,
              onInstallmentsFilterChanged: vm.setInstallmentsFilter,
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
              // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
              // favoritesExpanded: _favoritesExpanded,
              // onFavoritesToggle: () => setState(() => _favoritesExpanded = !_favoritesExpanded),
              onSummaryTap: () => _showPeriodSummary(context, vm),
            ),
            // Timeline (with optional suggestions banner)
            Expanded(
              child: vm.state == TransactionsLoadState.error
                  ? _buildError(vm)
                  : Column(
                      children: [
                        if (vm.visibleSuggestions.isNotEmpty)
                          _SuggestionsBanner(
                            suggestions: vm.visibleSuggestions,
                            onDismiss: vm.dismissSuggestion,
                            onQuickAdd: (s) {
                              vm.openQuickAddFromSchedule(s);
                              _showTransactionSheet(context, vm);
                            },
                          ),
                        Expanded(
                          child: TransactionTimeline(
                      transactions: vm.filteredTransactions,
                      loading: vm.state == TransactionsLoadState.loading,
                      financialMonthStartDay:
                          ref.watch(householdServiceProvider).currentStartDay,
                      onViewChanged: ({required view, required offset, week, dayDate}) {
                        vm.onViewChanged(
                            view: view, offset: offset, week: week, dayDate: dayDate);
                      },
                      onPeriodChanged: (info) {
                        if (mounted) setState(() => _periodInfo = info);
                      },
                      onEdit: (tx) {
                        if (tx.isRecurring && tx.recurringExpenseId != null) {
                          final rec = vm.recurringExpenses.firstWhere(
                            (r) => r.id == tx.recurringExpenseId,
                            orElse: () => vm.recurringExpenses.first,
                          );
                          vm.openEditRecurringAsExpenseModal(rec);
                          _showTransactionSheet(context, vm);
                        } else if (tx.txType == 'expense') {
                          final expense = vm.expenses.firstWhere((e) => e.id == tx.id);
                          vm.openEditExpenseModal(expense);
                          _showTransactionSheet(context, vm);
                        } else {
                          final income = vm.incomes.firstWhere((i) => i.id == tx.id);
                          vm.openEditIncomeModal(income);
                          _showTransactionSheet(context, vm);
                        }
                      },
                      onDelete: (tx) {
                        if (tx.isRecurring && tx.recurringExpenseId != null) {
                          final rec = vm.recurringExpenses.firstWhere((r) => r.id == tx.recurringExpenseId);
                          _confirmDeleteRecurring(context, vm, rec);
                        } else if (tx.txType == 'expense') {
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
            ),
          ],
        ),

        // ── Floating sub-categories arc ───────────────────────────────────────
        if (_expandedCategoryId != null)
          Builder(builder: (ctx) {
            final parent = vm.allCategories
                .where((c) => c.id == _expandedCategoryId)
                .firstOrNull;
            if (parent == null || parent.subCategories.isEmpty) {
              return const SizedBox.shrink();
            }
            // Vertically center the arc on the parent tile, bounded by screen.
            // Convert global Y center to the Stack's local coordinate system
            // so the arc aligns correctly even when the Stack doesn't start at y=0
            // (e.g. below AppBar / status bar).
            const arcHeight = _SubCategoriesArc.totalHeight;
            final screenHeight = MediaQuery.of(context).size.height;
            double yCenterLocal = _expandedCategoryYCenter ?? screenHeight / 2;
            final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
            if (stackBox != null && _expandedCategoryYCenter != null) {
              yCenterLocal = stackBox.globalToLocal(Offset(0, _expandedCategoryYCenter!)).dy;
            }
            final rawTop = yCenterLocal - arcHeight / 2;
            final stackHeight = stackBox?.size.height ?? screenHeight;
            final top = rawTop.clamp(8.0, stackHeight - arcHeight - 8.0);

            final arc = _SubCategoriesArc(
              parent: parent,
              usageCounts: vm.getCategoryUsageCounts(),
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
              onEditSubCategory: (sub) {
                setState(() {
                  _expandedCategoryId = null;
                  _expandedCategoryYCenter = null;
                });
                _showEditCategorySheet(context, vm, sub);
              },
            );

            final isRTL = Directionality.of(context) == TextDirection.rtl;

            if (isRTL) {
              // Hebrew: sidebar is on the right, arc fans out to the left
              return Positioned(
                right: 80,
                top: top,
                child: arc,
              );
            } else {
              // English: sidebar is on the left, arc fans out to the right
              return Positioned(
                left: 80,
                top: top,
                child: arc,
              );
            }
          }),

        // ── Favorites overlay ────────────────────────────────────────────────
        // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
        // if (_favoritesExpanded) ...[
        //   Positioned.fill(
        //     child: GestureDetector(
        //       behavior: HitTestBehavior.opaque,
        //       onTap: () => setState(() => _favoritesExpanded = false),
        //       child: const SizedBox.expand(),
        //     ),
        //   ),
        //   Positioned.directional(
        //     textDirection: Directionality.of(context),
        //     bottom: 130,
        //     start: 96,
        //     child: Material(
        //       elevation: 6,
        //       borderRadius: BorderRadius.circular(14),
        //       color: Colors.white,
        //       child: Padding(
        //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        //         child: Row(
        //           mainAxisSize: MainAxisSize.min,
        //           children: vm.favoriteCategories.map((cat) {
        //             final isHe = Localizations.localeOf(context).languageCode == 'he';
        //             final name = isHe ? (cat.nameHe?.isNotEmpty == true ? cat.nameHe! : cat.name) : cat.name;
        //             return Padding(
        //               padding: const EdgeInsets.symmetric(horizontal: 6),
        //               child: GestureDetector(
        //                 onTap: () {
        //                   setState(() => _favoritesExpanded = false);
        //                   vm.onCategoryQuickAdd(cat.id);
        //                   _showTransactionSheet(context, vm);
        //                 },
        //                 child: Column(
        //                   mainAxisSize: MainAxisSize.min,
        //                   children: [
        //                     Container(
        //                       width: 44,
        //                       height: 44,
        //                       decoration: BoxDecoration(
        //                         color: _hexColor(cat.color),
        //                         borderRadius: BorderRadius.circular(11),
        //                       ),
        //                       child: Icon(iconDataFromName(cat.icon), color: Colors.white, size: 22),
        //                     ),
        //                     const SizedBox(height: 5),
        //                     SizedBox(
        //                       width: 52,
        //                       child: Text(
        //                         name,
        //                         textAlign: TextAlign.center,
        //                         maxLines: 1,
        //                         overflow: TextOverflow.ellipsis,
        //                         style: const TextStyle(fontSize: 10, color: Color(0xFF444444)),
        //                       ),
        //                     ),
        //                   ],
        //                 ),
        //               ),
        //             );
        //           }).toList(),
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
        // ── FABs (stacked column, bottom-end) ────────────────────────────────
        Positioned.directional(
          textDirection: Directionality.of(context),
          bottom: 16,
          end: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Red FAB — Add Expense (top)
              FloatingActionButton(
                heroTag: 'fab_expense',
                onPressed: () {
                  vm.openAddExpenseModal();
                  _showTransactionSheet(context, vm);
                },
                backgroundColor: const Color(0xFFF44336),
                child: const Icon(Icons.remove, color: Colors.white),
              ),
              const SizedBox(height: 8),
              // Green FAB — Add Income (bottom)
              FloatingActionButton(
                heroTag: 'fab_income',
                onPressed: () {
                  vm.openAddIncomeModal();
                  _showTransactionSheet(context, vm);
                },
                backgroundColor: _kIncomeGreen,
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
          ? const ExpenseFormSheet()
          : const _IncomeFormSheet(),
    );
  }

  void _showPeriodSummary(BuildContext context, TransactionsViewModel vm) {
    final info = _periodInfo;
    if (info == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _PeriodSummaryDialog(info: info),
    );
  }

  void _confirmDeleteExpense(
      BuildContext context, TransactionsViewModel vm, Expense expense) {
    final l10n = AppLocalizations.of(context)!;
    final name = expense.description?.isNotEmpty == true
        ? expense.description!
        : expense.category?.name ?? 'this expense';
    final isInstallmentParent = (expense.installmentTotal ?? 0) > 1 &&
        expense.installmentCurrent == 1 &&
        expense.parentExpenseId == null;
    final remaining = isInstallmentParent
        ? (expense.installmentTotal! - 1)
        : 0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.commonDeleteExpense),
        content: Text(
          isInstallmentParent
              ? 'Delete "$name"? This will also delete $remaining future installment${remaining == 1 ? '' : 's'}.'
              : 'Delete "$name"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.commonDeleteIncome),
        content: Text(
          'Delete "${income.description?.isNotEmpty == true ? income.description : income.category?.name ?? 'this income'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              vm.deleteIncome(income);
            },
            child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecurring(
      BuildContext context, TransactionsViewModel vm, RecurringExpense rec) {
    final l10n = AppLocalizations.of(context)!;
    final name = rec.description?.isNotEmpty == true
        ? rec.description!
        : rec.category?.name ?? 'this recurring expense';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.commonDeleteExpense),
        content: Text('Delete recurring "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              vm.deleteRecurring(rec.id);
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
  // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
  // final List<Category> favoriteCategories;
  final int? filterCategoryId;
  final String viewMode;
  final double? priceMin;
  final double? priceMax;
  final bool filterInstallmentsOnly;
  final ValueChanged<int?> onFilterChanged;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<double?> onPriceMinChanged;
  final ValueChanged<double?> onPriceMaxChanged;
  final ValueChanged<bool> onInstallmentsFilterChanged;
  final ValueChanged<int> onCategoryQuickAdd;
  final void Function(Category)? onEditCategory;
  final void Function(Category)? onDeleteCategory;
  final void Function(Category? parent, bool isExpense)? onAddCategory;
  /// IDs that belong to expense categories (used to distinguish in action sheet)
  final Set<int> expenseCategoryIds;
  final int? expandedCategoryId;
  final void Function(int? id, double? yCenter) onCategoryExpanded;
  // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
  // final VoidCallback? onFavoritesToggle;
  // final bool favoritesExpanded;
  final VoidCallback? onSummaryTap;

  const _TransactionsSidebar({
    required this.categories,
    // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
    // required this.favoriteCategories,
    required this.filterCategoryId,
    required this.viewMode,
    required this.priceMin,
    required this.priceMax,
    required this.filterInstallmentsOnly,
    required this.onFilterChanged,
    required this.onViewModeChanged,
    required this.onPriceMinChanged,
    required this.onPriceMaxChanged,
    required this.onInstallmentsFilterChanged,
    required this.onCategoryQuickAdd,
    this.onEditCategory,
    this.onDeleteCategory,
    this.onAddCategory,
    this.expenseCategoryIds = const {},
    required this.expandedCategoryId,
    required this.onCategoryExpanded,
    // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
    // this.onFavoritesToggle,
    // this.favoritesExpanded = false,
    this.onSummaryTap,
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
    final locale = Localizations.localeOf(context);
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
              filterInstallmentsOnly: widget.filterInstallmentsOnly,
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                ...widget.categories.map((cat) {
                  final key = _categoryKeys.putIfAbsent(cat.id, () => GlobalKey());
                  final catLabel = (locale.languageCode == 'he' && cat.nameHe?.isNotEmpty == true)
                      ? cat.nameHe!
                      : cat.name;
                  return Container(
                    key: key,
                    child: _QuickAddTileWidget(
                      label: catLabel,
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
          // ── Favorites button ─────────────────────────────────────────────
          // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
          // if (widget.favoriteCategories.isNotEmpty && widget.onFavoritesToggle != null) ...[
          //   const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          //   GestureDetector(
          //     onTap: widget.onFavoritesToggle,
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(vertical: 8),
          //       child: Column(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Icon(
          //             widget.favoritesExpanded ? Icons.star : Icons.star_border,
          //             size: 20,
          //             color: widget.favoritesExpanded
          //                 ? const Color(0xFFFFB300)
          //                 : const Color(0xFF888888),
          //           ),
          //           const SizedBox(height: 3),
          //           Text(
          //             AppLocalizations.of(context)!.categoryFavorites,
          //             textAlign: TextAlign.center,
          //             style: TextStyle(
          //               fontSize: 9,
          //               color: widget.favoritesExpanded
          //                   ? const Color(0xFFFFB300)
          //                   : const Color(0xFF888888),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ],
          // ── Summary button ───────────────────────────────────────────────
          if (widget.onSummaryTap != null) ...[
            const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
            GestureDetector(
              onTap: widget.onSummaryTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pie_chart_outline,
                        size: 20, color: Color(0xFF888888)),
                    const SizedBox(height: 3),
                    Text(
                      AppLocalizations.of(context)!.categorySummary,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    final locale = Localizations.localeOf(context);
    final catLabel = (locale.languageCode == 'he' && cat.nameHe?.isNotEmpty == true)
        ? cat.nameHe!
        : cat.name;
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
            Text(catLabel,
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
      // Favorites — currently disabled (see ai_dev/transactions_period_summary_redesign/)
      // ...widget.favoriteCategories,
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
          filterInstallmentsOnly: widget.filterInstallmentsOnly,
          scrollController: scrollController,
          onFilterChanged: (id) {
            Navigator.pop(context);
            widget.onFilterChanged(id);
          },
          onViewModeChanged: widget.onViewModeChanged,
          onPriceMinChanged: widget.onPriceMinChanged,
          onPriceMaxChanged: widget.onPriceMaxChanged,
          onInstallmentsFilterChanged: widget.onInstallmentsFilterChanged,
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
  final bool filterInstallmentsOnly;

  const _FilterTileWidget({
    this.category,
    required this.viewMode,
    this.priceMin,
    this.priceMax,
    this.filterInstallmentsOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    final base = category != null ? _hexColor(category!.color) : indigo;
    final hasFilters = viewMode != 'all' || priceMin != null || priceMax != null || filterInstallmentsOnly;

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

// ── Sub-categories arc ────────────────────────────────────────────────────────

// Layout result for a single arc item — produced by _calculateItemLayout().
class _ArcItemLayout {
  final double xOffset; // how far the item is pushed horizontally from the sidebar edge
  final double yOffset; // signed vertical distance from the viewport center, in pixels
  final double scale;   // size multiplier: 1.0 at center, smaller toward edges
  final double opacity; // 1.0 inside the arc, fades to 0 as item scrolls past the edge

  const _ArcItemLayout({
    required this.xOffset,
    required this.yOffset,
    required this.scale,
    this.opacity = 1.0,
  });
}

// Pure function — all the math for positioning one item on the arc.
_ArcItemLayout _calculateItemLayout({
  required int    itemIndex,
  required double scrollOffsetPx,
  required double itemHeight,
  required double arcRadius,
  required double minScale,
  required int    visibleItems,
}) {
  // Distance from viewport center in item-units
  final distanceInItems = (itemIndex * itemHeight - scrollOffsetPx) / itemHeight;

  // Normalize so ±(visibleItems / 2) maps to ±1
  final halfVisible       = visibleItems / 2.0;
  final normalizedDistance = distanceInItems / halfVisible;

  // Angle on the semicircle: 0 = center, ±π/2 = edges
  final angle = (normalizedDistance * (pi / 2)).clamp(-pi / 2, pi / 2);

  // TRUE CIRCULAR PATH: both X and Y from trig functions
  final cosAngle = cos(angle);
  final xOffset  = arcRadius * cosAngle;
  final yOffset  = arcRadius * sin(angle);

  final scale = minScale + (1.0 - minScale) * cosAngle;

  // Items beyond the visible arc are invisible (ShaderMask handles edge fading)
  final beyond  = (normalizedDistance.abs() - 1.0).clamp(0.0, double.infinity);
  final opacity = beyond > 0 ? 0.0 : 1.0;

  return _ArcItemLayout(xOffset: xOffset, yOffset: yOffset, scale: scale, opacity: opacity);
}

// ─────────────────────────────────────────────────────────────────────────────

typedef _ArcItem = ({int id, String? icon, String name, bool isGeneral});

class _SubCategoriesArc extends StatefulWidget {
  final Category parent;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final ValueChanged<Category>? onEditSubCategory;
  final Map<int, int> usageCounts;

  // ── Tune these to change the feel of the arc ─────────────────────────────
  static const double itemHeight   = 52.0;
  static const double arcRadius    = 80.0; // semicircle radius – engulfs the icons
  static const double minScale     = 0.55; // size ratio of the most-edge item
  static const int    visibleItems = 5;    // items visible at once
  static const double sidebarWidth = 80.0; // width of the category sidebar
  // textZone is computed dynamically in build() from screen width
  // ─────────────────────────────────────────────────────────────────────────

  static const double totalHeight = itemHeight * visibleItems; // 240 px

  const _SubCategoriesArc({
    required this.parent,
    required this.onSelected,
    required this.onClose,
    this.onEditSubCategory,
    this.usageCounts = const {},
  });

  @override
  State<_SubCategoriesArc> createState() => _SubCategoriesArcState();
}

class _SubCategoriesArcState extends State<_SubCategoriesArc>
    with SingleTickerProviderStateMixin {

  late final AnimationController _snapController;
  late Animation<double>         _snapAnimation;
  double _scrollOffsetPx = 0.0; // current scroll position in pixels

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _snapAnimation = const AlwaysStoppedAnimation(0);
  }

  @override
  void didUpdateWidget(covariant _SubCategoriesArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parent.id != widget.parent.id) {
      _snapController.stop();
      _scrollOffsetPx = 0.0;
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  // ── Scroll + snap logic ──────────────────────────────────────────────────

  int get _itemCount => 1 + widget.parent.subCategories.length;

  double get _maxScrollPx =>
      (_itemCount - 1) * _SubCategoriesArc.itemHeight;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _scrollOffsetPx =
          (_scrollOffsetPx - details.delta.dy).clamp(0.0, _maxScrollPx);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    // Find the nearest item index and snap to it
    final nearestIndex =
        (_scrollOffsetPx / _SubCategoriesArc.itemHeight).round()
            .clamp(0, _itemCount - 1);
    _snapTo(nearestIndex * _SubCategoriesArc.itemHeight);
  }

  void _snapTo(double targetPx) {
    final fromPx = _scrollOffsetPx;
    _snapAnimation = Tween<double>(begin: fromPx, end: targetPx).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    )..addListener(() {
        setState(() => _scrollOffsetPx = _snapAnimation.value);
      });
    _snapController.forward(from: 0);
  }

  // ── Item list ─────────────────────────────────────────────────────────────

  List<_ArcItem> _buildItemList(Locale locale, String generalLabel) {
    final isHe = locale.languageCode == 'he';
    final parentName = (isHe && widget.parent.nameHe?.isNotEmpty == true)
        ? widget.parent.nameHe!
        : widget.parent.name;
    // Stable-sort sub-categories by usage count (desc). Ties keep the original
    // server order. "General" (the parent itself) always stays at the top.
    final subs = widget.parent.subCategories.toList();
    if (widget.usageCounts.isNotEmpty) {
      final indexed = <(int, Category)>[
        for (int i = 0; i < subs.length; i++) (i, subs[i]),
      ];
      indexed.sort((a, b) {
        final ca = widget.usageCounts[a.$2.id] ?? 0;
        final cb = widget.usageCounts[b.$2.id] ?? 0;
        if (cb != ca) return cb.compareTo(ca);
        return a.$1.compareTo(b.$1); // stable
      });
      subs
        ..clear()
        ..addAll(indexed.map((e) => e.$2));
    }
    return [
      (
        id: widget.parent.id,
        icon: widget.parent.icon,
        name: '$parentName - $generalLabel',
        isGeneral: true,
      ),
      ...subs.map((s) {
        final subName = (isHe && s.nameHe?.isNotEmpty == true) ? s.nameHe! : s.name;
        return (id: s.id, icon: s.icon, name: subName, isGeneral: false);
      }),
    ];
  }

  // ── Per-item widget (shared between LTR and RTL) ─────────────────────────

  Widget _buildItem({
    required _ArcItem item,
    required int index,
    required Color color,
    required bool isRTL,
    required double textZone,
  }) {
    final layout = _calculateItemLayout(
      itemIndex:      index,
      scrollOffsetPx: _scrollOffsetPx,
      itemHeight:     _SubCategoriesArc.itemHeight,
      arcRadius:      _SubCategoriesArc.arcRadius,
      minScale:       _SubCategoriesArc.minScale,
      visibleItems:   _SubCategoriesArc.visibleItems,
    );

    final itemTop = _SubCategoriesArc.totalHeight / 2
        + layout.yOffset
        - _SubCategoriesArc.itemHeight / 2;

    // Skip items that are scrolled fully outside the viewport.
    // Use 0 (not -itemHeight) as the upper bound so items don't escape the
    // half-oval background at the top. Items below the arc are similarly culled.
    final isOutsideViewport = itemTop < -_SubCategoriesArc.itemHeight * 0.5 ||
        itemTop > _SubCategoriesArc.totalHeight - _SubCategoriesArc.itemHeight * 0.5;
    if (isOutsideViewport) return const SizedBox.shrink();

    // In RTL the arc fans to the left, so we negate the X offset
    final translationX = isRTL ? -layout.xOffset : layout.xOffset;

    return Positioned(
      top:   itemTop,
      left:  isRTL ? null : 0,
      right: isRTL ? 0 : null,
      child: Transform.translate(
        offset: Offset(translationX, 0),
        child: Transform.scale(
          scale: layout.scale,
          // Pin scale to the icon's side so the icon stays on the arc as items
          // shrink toward the edges. LTR: icon is leftmost → scale from left.
          // RTL: icon is rightmost → scale from right.
          alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: layout.opacity,
            child: GestureDetector(
              onTap: layout.opacity > 0.05 ? () => widget.onSelected(item.id) : null,
              onLongPress: (layout.opacity > 0.05 && !item.isGeneral && widget.onEditSubCategory != null)
                  ? () {
                      final sub = widget.parent.subCategories.firstWhere((s) => s.id == item.id);
                      widget.onEditSubCategory!(sub);
                    }
                  : null,
              child: _WheelItem(
                icon:      item.icon,
                name:      item.name,
                color:     color,
                isGeneral: item.isGeneral,
                isRTL:     isRTL,
                textZone:  textZone,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── LTR build (English) ──────────────────────────────────────────────────

  Widget _buildLTR(List<_ArcItem> items, Color color, double textZone) {
    return SizedBox(
      width:  _SubCategoriesArc.arcRadius + textZone,
      height: _SubCategoriesArc.totalHeight,
      child: GestureDetector(
        behavior:             HitTestBehavior.opaque,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd:    _onDragEnd,
        child: ClipRect(
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white, Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.20, 0.50, 0.80, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HalfOvalPainter(color: color, isRTL: false),
                  ),
                ),
                for (int i = 0; i < items.length; i++)
                  _buildItem(item: items[i], index: i, color: color, isRTL: false, textZone: textZone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── RTL build (Hebrew) ───────────────────────────────────────────────────

  Widget _buildRTL(List<_ArcItem> items, Color color, double textZone) {
    return SizedBox(
      width:  _SubCategoriesArc.arcRadius + textZone,
      height: _SubCategoriesArc.totalHeight,
      child: GestureDetector(
        behavior:             HitTestBehavior.opaque,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd:    _onDragEnd,
        child: ClipRect(
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white, Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.20, 0.50, 0.80, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HalfOvalPainter(color: color, isRTL: true),
                  ),
                ),
                for (int i = 0; i < items.length; i++)
                  _buildItem(item: items[i], index: i, color: color, isRTL: true, textZone: textZone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRTL       = Directionality.of(context) == TextDirection.rtl;
    final locale      = Localizations.localeOf(context);
    final generalLabel = AppLocalizations.of(context)!.categoryGeneral;
    final items  = _buildItemList(locale, generalLabel);
    final color  = _hexColor(widget.parent.color);

    // Dynamic text zone: from the arc's left edge to the screen's right edge.
    final screenWidth = MediaQuery.of(context).size.width;
    final textZone = (screenWidth - _SubCategoriesArc.sidebarWidth - _SubCategoriesArc.arcRadius)
        .clamp(100.0, 500.0);

    if (isRTL) {
      return _buildRTL(items, color, textZone);
    } else {
      return _buildLTR(items, color, textZone);
    }
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// Paints the half-oval background behind the subcategory arc.
// For LTR: flat edge on the left (sidebar side), bulge to the right.
// For RTL: flat edge on the right, bulge to the left.
class _HalfOvalPainter extends CustomPainter {
  final Color color;
  final bool  isRTL;

  const _HalfOvalPainter({required this.color, required this.isRTL});

  @override
  void paint(Canvas canvas, Size size) {
    const r = _SubCategoriesArc.arcRadius;
    final cy = size.height / 2;

    final Path path;
    if (!isRTL) {
      // Right-facing D: flat edge on left (x=0), bulge to the right.
      final rect = Rect.fromLTWH(-r, cy - r, r * 2, r * 2);
      path = Path()
        ..moveTo(0, cy - r)
        ..arcTo(rect, -pi / 2, pi, false)
        ..close();
    } else {
      // Left-facing D: flat edge on right (x=width), bulge to the left.
      final rect = Rect.fromLTWH(size.width - r, cy - r, r * 2, r * 2);
      path = Path()
        ..moveTo(size.width, cy - r)
        ..arcTo(rect, -pi / 2, -pi, false)
        ..close();
    }

    // White frosted glow layer — soft blur gives a cool glass/halo feel.
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawPath(path, glowPaint);

    // Solid white base — crisp fill inside the D-shape.
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, whitePaint);

    // Category color tint on top.
    final colorPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, colorPaint);
  }

  @override
  bool shouldRepaint(_HalfOvalPainter old) =>
      old.color != color || old.isRTL != isRTL;
}

class _WheelItem extends StatelessWidget {
  final String? icon;
  final String name;
  final Color color;
  final bool isGeneral;
  final bool isRTL;
  final double textZone;

  const _WheelItem({
    required this.icon,
    required this.name,
    required this.color,
    required this.isGeneral,
    required this.isRTL,
    required this.textZone,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: isGeneral ? 44 : 40,
      height: isGeneral ? 44 : 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isGeneral ? 11 : 10),
      ),
      child: Icon(
        iconDataFromName(icon),
        size: isGeneral ? 24 : 21,
        color: Colors.white,
      ),
    );

    final label = Flexible(
      fit: FlexFit.loose,
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isGeneral ? 14 : 13,
          fontWeight: isGeneral ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      ),
    );

    // Icon inside the circle, text extending outward:
    // LTR (arc fans right): icon left, text right
    // RTL (arc fans left):  icon right, text left
    final children = isRTL
        ? [label, const SizedBox(width: 6), iconBox]
        : [iconBox, const SizedBox(width: 6), label];

    // White rounded background — text zone is bounded by textZone.
    // Row uses mainAxisSize.min so it only takes as much space as needed,
    // up to textZone (no wider than the screen edge).
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: textZone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          textDirection: TextDirection.ltr, // prevent Flutter's auto-RTL reversal
          children: children,
        ),
      ),
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
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final q = _query.toLowerCase();
    final filtered = _query.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                (c.nameHe ?? '').toLowerCase().contains(q))
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
                final displayName = isHe && cat.nameHe?.isNotEmpty == true ? cat.nameHe! : cat.name;
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
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
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
  final bool filterInstallmentsOnly;
  final ScrollController scrollController;
  final ValueChanged<int?> onFilterChanged;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<double?> onPriceMinChanged;
  final ValueChanged<double?> onPriceMaxChanged;
  final ValueChanged<bool> onInstallmentsFilterChanged;

  const _TransactionFilterSheet({
    required this.categories,
    required this.filterCategoryId,
    required this.viewMode,
    required this.priceMin,
    required this.priceMax,
    required this.filterInstallmentsOnly,
    required this.scrollController,
    required this.onFilterChanged,
    required this.onViewModeChanged,
    required this.onPriceMinChanged,
    required this.onPriceMaxChanged,
    required this.onInstallmentsFilterChanged,
  });

  @override
  State<_TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late String _viewMode;
  late bool _filterInstallmentsOnly;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
    _filterInstallmentsOnly = widget.filterInstallmentsOnly;
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

              // ── Installments section ──────────────────────────────────────────
              Text(AppLocalizations.of(context)!.transactionsInstallmentsOnly,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _filterInstallmentsOnly = !_filterInstallmentsOnly);
                  widget.onInstallmentsFilterChanged(_filterInstallmentsOnly);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _filterInstallmentsOnly
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.credit_card_outlined,
                          size: 14,
                          color: _filterInstallmentsOnly
                              ? Colors.white
                              : const Color(0xFF555555)),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.transactionsInstallmentsOnly,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _filterInstallmentsOnly
                              ? Colors.white
                              : const Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                ),
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
  int? _selectedParentId;

  static const _paymentMethodKeys = [
    ('card',         '💳'),
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
    if (vm.formCategoryId != null) {
      for (final cat in vm.incomeCategories) {
        if (cat.id == vm.formCategoryId) {
          _selectedParentId = cat.id;
          break;
        }
        for (final sub in cat.subCategories) {
          if (sub.id == vm.formCategoryId) {
            _selectedParentId = cat.id;
            break;
          }
        }
      }
    }
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
    final locale = Localizations.localeOf(context);
    final selectedCategoryName = _getIncomeCategoryName(vm, locale.languageCode);

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
            _buildHeader(vm, l10n.transactionsIncomeLabel, _kIncomeGreen, l10n, vm.incomeCategories, selectedCategoryName),
            if (vm.modalError != null) _buildError(vm),
            const SizedBox(height: 16),
            _buildAmountField(vm),
            _buildFrequentAmounts(vm, isExpense: false),
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
            const SizedBox(height: 16),
            _buildAttachmentsSection(vm, l10n),
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

  // ── Attachments ───────────────────────────────────────────────────────────

  Widget _buildAttachmentsSection(TransactionsViewModel vm, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(l10n.attachments, optional: true),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAttachButton(
              icon: Icons.camera_alt_outlined,
              label: l10n.attachmentsAddCamera,
              color: _kIncomeGreen,
              onTap: () => _pickCamera(vm),
            ),
            const SizedBox(width: 8),
            _buildAttachButton(
              icon: Icons.attach_file,
              label: l10n.attachmentsAddFiles,
              color: _kIncomeGreen,
              onTap: () => _pickFiles(vm),
            ),
          ],
        ),
        if (vm.pendingAttachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...vm.pendingAttachments.asMap().entries.map((entry) {
            final idx = entry.key;
            final pa = entry.value;
            final nameCtrl = TextEditingController(text: pa.displayName);
            nameCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: nameCtrl.text.length));
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  pa.isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(pa.file.path),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kIncomeGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.insert_drive_file, size: 22, color: _kIncomeGreen),
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      onChanged: (v) => vm.renamePendingAttachment(idx, v),
                      decoration: _inputDeco(l10n.attachmentsName, _kIncomeGreen),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF888888)),
                    onPressed: () => vm.removePendingAttachment(idx),
                    tooltip: l10n.attachmentsRemove,
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAttachButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera(TransactionsViewModel vm) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera);
    if (xFile == null) return;
    final name = xFile.name.contains('.') ? xFile.name.split('.').first : xFile.name;
    vm.addPendingAttachment(PendingAttachment(
      file: File(xFile.path),
      displayName: name,
      isImage: true,
    ));
  }

  Future<void> _pickFiles(TransactionsViewModel vm) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    for (final pf in result.files) {
      if (pf.path == null) continue;
      final ext = pf.extension?.toLowerCase() ?? '';
      final isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
      final nameWithoutExt = pf.name.contains('.')
          ? pf.name.substring(0, pf.name.lastIndexOf('.'))
          : pf.name;
      vm.addPendingAttachment(PendingAttachment(
        file: File(pf.path!),
        displayName: nameWithoutExt,
        isImage: isImg,
      ));
    }
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

  Widget _buildHeader(TransactionsViewModel vm, String type, Color color, AppLocalizations l10n, List<Category> cats, [String? selectedCategoryName]) {
    final editLabel = type == l10n.transactionsExpenseLabel ? l10n.expensesEdit : l10n.incomesEdit;
    final newLabel = type == l10n.transactionsExpenseLabel ? l10n.expensesNew : l10n.incomesNew;
    final title = vm.isEditMode
        ? editLabel
        : (selectedCategoryName != null ? '$newLabel - $selectedCategoryName' : newLabel);
    final selCat = vm.formCategoryId != null ? _findCategoryById(vm.formCategoryId!, cats) : null;
    return Row(
      children: [
        if (selCat != null) ...[
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _hexColor(selCat.color),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(iconDataFromName(selCat.icon), size: 20, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Container(
            width: 6, height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
    return Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAdjustButton('-10', -10, vm),
            _buildAdjustButton('-5', -5, vm),
            _buildAdjustButton('−1', -1, vm),
          ],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFAFAFA),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('₪',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                const SizedBox(width: 4),
                Flexible(
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                      onChanged: (v) => vm.setFormAmount(double.tryParse(v)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAdjustButton('+1', 1, vm),
            _buildAdjustButton('+5', 5, vm),
            _buildAdjustButton('+10', 10, vm),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips(TransactionsViewModel vm, List<Category> cats, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    if (cats.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [_buildNewCategoryChip(vm, l10n)],
      );
    }

    final selectedParent = _selectedParentId != null
        ? cats.where((c) => c.id == _selectedParentId).firstOrNull
        : null;

    // When a parent is selected, only show that parent chip + new-category chip.
    // Tapping the selected parent chip again collapses back to all parents.
    final visibleParents = _selectedParentId != null
        ? cats.where((c) => c.id == _selectedParentId).toList()
        : cats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...visibleParents.map((cat) {
              final isActiveParent = _selectedParentId == cat.id;
              final base = _hexColor(cat.color);
              final catName = (locale.languageCode == 'he' && cat.nameHe?.isNotEmpty == true)
                  ? cat.nameHe!
                  : cat.name;
              return GestureDetector(
                onTap: () {
                  if (isActiveParent) {
                    setState(() => _selectedParentId = null);
                    vm.setFormCategory(null);
                  } else {
                    setState(() => _selectedParentId = cat.id);
                    vm.setFormCategory(cat.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActiveParent ? base : base.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconDataFromName(cat.icon), size: 16,
                          color: isActiveParent ? Colors.white : base),
                      const SizedBox(width: 4),
                      Text(
                        catName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActiveParent ? Colors.white : const Color(0xFF333333),
                        ),
                      ),
                      if (cat.subCategories.isNotEmpty) ...[
                        const SizedBox(width: 2),
                        Icon(
                          isActiveParent ? Icons.expand_less : Icons.chevron_right,
                          size: 14,
                          color: isActiveParent ? Colors.white : base,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            _buildNewCategoryChip(vm, l10n),
          ],
        ),
        if (selectedParent != null && selectedParent.subCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Builder(builder: (ctx) {
              // When a sub is selected, only show that sub. Tapping it → revert to parent.
              final selectedSubId = vm.formCategoryId != null &&
                      selectedParent.subCategories.any((s) => s.id == vm.formCategoryId)
                  ? vm.formCategoryId
                  : null;
              final visibleSubs = selectedSubId != null
                  ? selectedParent.subCategories.where((s) => s.id == selectedSubId).toList()
                  : selectedParent.subCategories;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: visibleSubs.map((sub) {
                  final selected = vm.formCategoryId == sub.id;
                  final base = _hexColor(sub.color.isNotEmpty ? sub.color : selectedParent.color);
                  final subName = (locale.languageCode == 'he' && sub.nameHe?.isNotEmpty == true)
                      ? sub.nameHe!
                      : sub.name;
                  return GestureDetector(
                    onTap: () {
                      if (selected) {
                        vm.setFormCategory(_selectedParentId);
                      } else {
                        vm.setFormCategory(sub.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? base : base.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? base : base.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sub.icon != null && sub.icon!.isNotEmpty) ...[
                            Icon(iconDataFromName(sub.icon), size: 13,
                                color: selected ? Colors.white : base),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            subName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : const Color(0xFF444444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ],
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
    final labels = [l10n.paymentCard, l10n.paymentCash, l10n.paymentTransfer];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        if (vm.formPaymentMethod == 'card') ...[
          const SizedBox(height: 10),
          _buildCardPicker(vm, activeColor, l10n),
        ],
      ],
    );
  }

  Widget _buildCardPicker(TransactionsViewModel vm, Color activeColor, AppLocalizations l10n) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        TxCardChip(
          label: l10n.cardsNone,
          active: vm.formCardId == null,
          color: activeColor,
          onTap: () => vm.setFormCardId(null),
        ),
        ...vm.cards.map((card) => TxCardChip(
          label: card.displayLabel,
          active: vm.formCardId == card.id,
          color: activeColor,
          onTap: () => vm.setFormCardId(card.id),
        )),
        GestureDetector(
          onTap: () => _showCardFormSheet(context, vm, activeColor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: activeColor, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 14, color: activeColor),
                const SizedBox(width: 2),
                Text('+', style: TextStyle(fontSize: 13, color: activeColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCardFormSheet(BuildContext context, TransactionsViewModel vm, Color activeColor, {CreditCard? card}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TxCardFormSheet(card: card, vm: vm, activeColor: activeColor),
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

  void _adjustAmount(double delta, TransactionsViewModel vm) {
    final current = double.tryParse(_amountCtrl.text) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999999.0);
    final formatted = next == next.truncateToDouble()
        ? next.toInt().toString()
        : next.toStringAsFixed(2);
    _amountCtrl.text = formatted;
    vm.setFormAmount(next == 0 ? null : next);
  }

  Widget _buildAdjustButton(String label, double delta, TransactionsViewModel vm) {
    return GestureDetector(
      onTap: () => _adjustAmount(delta, vm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF444444)),
        ),
      ),
    );
  }

  Widget _buildFrequentAmounts(TransactionsViewModel vm, {required bool isExpense}) {
    final amounts = vm.getTopAmountsForCategory(vm.formCategoryId, isExpense: isExpense);
    if (amounts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: amounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = amounts[i];
              final label = a == a.truncateToDouble()
                  ? '₪${a.toInt()}'
                  : '₪${a.toStringAsFixed(2)}';
              return GestureDetector(
                onTap: () {
                  _amountCtrl.text = a == a.truncateToDouble()
                      ? a.toInt().toString()
                      : a.toStringAsFixed(2);
                  vm.setFormAmount(a);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFB0C4FF)),
                  ),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3366CC))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Category? _findCategoryById(int id, List<Category> cats) {
    for (final cat in cats) {
      if (cat.id == id) return cat;
      for (final sub in cat.subCategories) {
        if (sub.id == id) return sub;
      }
    }
    return null;
  }

  String? _getIncomeCategoryName(TransactionsViewModel vm, String languageCode) {
    if (vm.formCategoryId == null) return null;
    for (final cat in vm.incomeCategories) {
      if (cat.id == vm.formCategoryId) {
        return (languageCode == 'he' && cat.nameHe?.isNotEmpty == true) ? cat.nameHe! : cat.name;
      }
      for (final sub in cat.subCategories) {
        if (sub.id == vm.formCategoryId) {
          return (languageCode == 'he' && sub.nameHe?.isNotEmpty == true) ? sub.nameHe! : sub.name;
        }
      }
    }
    return null;
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ─── Suggestions banner ───────────────────────────────────────────────────────

class _SuggestionsBanner extends StatefulWidget {
  final List<ExpenseSchedule> suggestions;
  final void Function(int scheduleId) onDismiss;
  final void Function(ExpenseSchedule) onQuickAdd;

  const _SuggestionsBanner({
    required this.suggestions,
    required this.onDismiss,
    required this.onQuickAdd,
  });

  @override
  State<_SuggestionsBanner> createState() => _SuggestionsBannerState();
}

class _SuggestionsBannerState extends State<_SuggestionsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2FF),
        border: Border(bottom: BorderSide(color: Color(0xFFD8DEFF), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Collapsed header (always visible) ──────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  const Icon(Icons.repeat, size: 13, color: Color(0xFF5C6BC0)),
                  const SizedBox(width: 5),
                  Text(
                    '${l10n.constantExpensesLabel} (${widget.suggestions.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C6BC0),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: const Color(0xFF5C6BC0),
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded chips list ─────────────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 7),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.suggestions.map((s) {
                    final cat = s.category;
                    final catName = cat == null
                        ? ''
                        : (isHe && cat.nameHe?.isNotEmpty == true)
                            ? cat.nameHe!
                            : cat.name;
                    final label = catName.isNotEmpty
                        ? '$catName · ${s.description}'
                        : s.description;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFC5CAE9)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF3949AB)),
                            ),
                            GestureDetector(
                              onTap: () => widget.onQuickAdd(s),
                              child: Container(
                                margin: const EdgeInsets.only(left: 5),
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF5C6BC0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => widget.onDismiss(s.id),
                              child: Container(
                                margin: const EdgeInsets.only(left: 2, right: 4),
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8EAF6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 9, color: Color(0xFF9FA8DA)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Period Summary Dialog ───────────────────────────────────────────────────
//
// Small popup launched from the sidebar Summary tile. Shows the totals,
// net, transaction count for the currently-selected period, and (only in
// monthly view) a list of categories that went over budget for the month.

class _PeriodSummaryDialog extends ConsumerStatefulWidget {
  final TimelinePeriodInfo info;
  const _PeriodSummaryDialog({required this.info});

  @override
  ConsumerState<_PeriodSummaryDialog> createState() => _PeriodSummaryDialogState();
}

class _PeriodSummaryDialogState extends ConsumerState<_PeriodSummaryDialog> {
  bool _loadingBudget = false;
  List<MonthBudgetRow>? _budgetRows;
  Object? _budgetError;

  @override
  void initState() {
    super.initState();
    if (widget.info.view == 'monthly') {
      _loadingBudget = true;
      // Fire-and-forget; UI shows a spinner until it completes.
      Future.microtask(() async {
        try {
          final rows = await ref
              .read(budgetServiceProvider)
              .getMonthlyBudget(year: widget.info.year, month: widget.info.month);
          if (!mounted) return;
          setState(() {
            _budgetRows = rows;
            _loadingBudget = false;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _budgetError = e;
            _loadingBudget = false;
          });
        }
      });
    }
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.trim().replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  String _viewModeLabel(AppLocalizations l10n) {
    switch (widget.info.view) {
      case 'monthly':
        return l10n.timelineMonthly;
      case 'weekly':
        return l10n.timelineWeekly;
      case 'daily':
        return l10n.timelineDaily;
      default:
        return widget.info.view;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final info = widget.info;
    final net = info.totalIn - info.totalOut;
    const incomeGreen = Color(0xFF2E7D32);
    const expenseRed = Color(0xFFC62828);
    const primary = Color(0xFF222222);
    const secondary = Color(0xFF888888);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.summaryDialogTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  info.label,
                  style: const TextStyle(fontSize: 12, color: secondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _viewModeLabel(l10n),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryRow(
                label: l10n.navIncomes,
                value: formatNIS(info.totalIn),
                valueColor: incomeGreen,
              ),
              const Divider(height: 1),
              _SummaryRow(
                label: l10n.navExpenses,
                value: formatNIS(info.totalOut),
                valueColor: expenseRed,
              ),
              const Divider(height: 1),
              _SummaryRow(
                label: l10n.summaryNet,
                value: formatNIS(net),
                valueColor: net >= 0 ? incomeGreen : expenseRed,
                bold: true,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  l10n.summaryTransactionCount(info.transactionCount),
                  style: const TextStyle(fontSize: 13, color: primary),
                ),
              ),
              if (info.view == 'monthly') ...[
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  l10n.summaryOverBudgetTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                if (_loadingBudget)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_budgetError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      l10n.summaryNoOverBudget,
                      style: const TextStyle(fontSize: 12, color: secondary),
                    ),
                  )
                else
                  ..._buildOverBudgetList(l10n, isHe, expenseRed, secondary),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  List<Widget> _buildOverBudgetList(
      AppLocalizations l10n, bool isHe, Color overColor, Color secondary) {
    final rows = (_budgetRows ?? const <MonthBudgetRow>[])
        .where((r) => (r.result ?? 0) > 0)
        .toList()
      ..sort((a, b) => b.result!.compareTo(a.result!));
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            l10n.summaryNoOverBudget,
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ),
      ];
    }
    return rows.map((r) {
      final name = isHe ? (r.nameHe ?? r.name) : r.name;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _parseHexColor(r.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF222222)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${formatNIS(r.result!)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: overColor,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

