import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/expense.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:household/screens/expenses/expenses_view_model.dart';
import 'package:household/widgets/category_sidebar.dart';
import 'package:household/widgets/create_category_sheet.dart';
import 'package:household/widgets/transaction_timeline.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(expensesViewModelProvider);

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
        // ── Main layout ─────────────────────────────────────────────────────
        Row(
          children: [
            // Category sidebar
            CategorySidebar(
              categories: vm.categories,
              favoriteCategories: vm.favoriteCategories,
              filterCategoryId: vm.selectedCategoryId,
              onFilterChanged: vm.onCategorySelected,
              onCategoryQuickAdd: (id) {
                vm.onCategoryQuickAdd(id);
                _showExpenseSheet(context);
              },
              onEditCategory: (cat) => _showEditCategorySheet(context, vm, cat),
              onDeleteCategory: (cat) => _confirmDeleteCategory(context, vm, cat),
            ),
            // Timeline
            Expanded(
              child: vm.state == ExpensesLoadState.error
                  ? _buildError(vm)
                  : TransactionTimeline(
                      transactions: vm.expenses
                          .map(TimelineTx.fromExpense)
                          .toList(),
                      loading: vm.state == ExpensesLoadState.loading,
                      onViewChanged: ({required view, required offset, week, dayDate}) {
                        vm.onViewChanged(
                            view: view, offset: offset, week: week, dayDate: dayDate);
                      },
                      onEdit: (tx) {
                        final expense = vm.expenses.firstWhere((e) => e.id == tx.id);
                        vm.openEditModal(expense);
                        _showExpenseSheet(context);
                      },
                      onDelete: (tx) => _confirmDelete(context, vm,
                          vm.expenses.firstWhere((e) => e.id == tx.id)),
                    ),
            ),
          ],
        ),
        // ── FAB ─────────────────────────────────────────────────────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              vm.openAddModal();
              _showExpenseSheet(context);
            },
            backgroundColor: const Color(0xFF667EEA),
            child: const Icon(Icons.remove, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ExpensesViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.expensesLoadFailed,
              style: const TextStyle(color: Color(0xFF888888))),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: vm.loadExpenses, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }

  void _showExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ExpenseFormSheet(),
    );
  }

  void _confirmDelete(BuildContext context, ExpensesViewModel vm, Expense expense) {
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

  void _showEditCategorySheet(BuildContext context, ExpensesViewModel vm, cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCategorySheet(
        categoryType: 'expense',
        householdId: vm.householdId,
        existing: cat,
        topLevelCategories: vm.categories.where((c) => c.parentCategoryId == null).toList(),
        onCreated: vm.updateCategoryInList,
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, ExpensesViewModel vm, cat) {
    final l10n = AppLocalizations.of(context)!;
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
                vm.deleteCategory(cat.id, deleteRefs: deleteRefs);
              },
              child: Text(l10n.categoryDelete, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add / Edit bottom sheet ─────────────────────────────────────────────────

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet();

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _noteCtrl;
  int? _selectedParentId;

  static const _purple = Color(0xFF667EEA);

  static const _paymentMethodKeys = [
    ('credit_card', '💳'),
    ('debit_card', '💳'),
    ('cash', '💵'),
    ('bank_transfer', '🏦'),
  ];

  @override
  void initState() {
    super.initState();
    final vm = ref.read(expensesViewModelProvider);
    _amountCtrl = TextEditingController(
        text: vm.formAmount != null ? vm.formAmount.toString() : '');
    _descCtrl = TextEditingController(text: vm.formDescription);
    _noteCtrl = TextEditingController(text: vm.formNote);
    // Pre-select parent based on current formCategoryId
    if (vm.formCategoryId != null) {
      for (final cat in vm.categories) {
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
    final vm = ref.watch(expensesViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final locale = Localizations.localeOf(context);
    final selectedCategoryName = _getCategoryDisplayName(vm, locale.languageCode);

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
                Expanded(
                  child: Text(
                    vm.isEditMode
                        ? l10n.expensesEdit
                        : selectedCategoryName != null
                            ? '${l10n.expensesNew} - $selectedCategoryName'
                            : l10n.expensesNew,
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
            ),
            // Error
            if (vm.modalError != null) ...[
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
            const SizedBox(height: 16),
            // Amount
            _buildAmountField(vm),
            const SizedBox(height: 16),
            // Category
            _buildLabel(l10n.expensesCategory),
            const SizedBox(height: 8),
            _buildCategoryChips(vm, l10n),
            const SizedBox(height: 16),
            // Date/time
            _buildLabel(l10n.expensesDate),
            const SizedBox(height: 8),
            _buildDateTimePicker(vm),
            const SizedBox(height: 16),
            // Payment method
            _buildLabel(l10n.expensesPaymentMethod),
            const SizedBox(height: 8),
            _buildPaymentSegment(vm, l10n),
            const SizedBox(height: 16),
            // Description
            _buildLabel(l10n.expensesDescription, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              onChanged: vm.setFormDescription,
              decoration: _inputDeco(l10n.expensesDescriptionPlaceholder),
              maxLength: 200,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
            const SizedBox(height: 16),
            // Note
            _buildLabel(l10n.expensesNote, optional: true),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              onChanged: vm.setFormNote,
              decoration: _inputDeco(l10n.expensesNotePlaceholder),
              maxLines: 3,
              maxLength: 500,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
            const SizedBox(height: 20),
            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.modalSaving
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        await vm.saveExpense();
                        if (vm.modalError == null) nav.pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: vm.modalSaving
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(vm.isEditMode ? l10n.expensesSave : l10n.expensesAdd,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(ExpensesViewModel vm) {
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
            child: Text('₪', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
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

  Widget _buildCategoryChips(ExpensesViewModel vm, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    if (vm.categories.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [_buildNewCategoryChip(vm, l10n)],
      );
    }

    final selectedParent = _selectedParentId != null
        ? vm.categories.where((c) => c.id == _selectedParentId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...vm.categories.map((cat) {
              final isActiveParent = _selectedParentId == cat.id;
              final base = _hexColor(cat.color);
              final catName = (locale.languageCode == 'he' && cat.nameHe?.isNotEmpty == true)
                  ? cat.nameHe!
                  : cat.name;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedParentId = cat.id);
                  if (cat.subCategories.isEmpty) {
                    vm.setFormCategory(cat.id);
                  } else {
                    vm.setFormCategory(cat.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActiveParent ? base : base.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: isActiveParent && cat.subCategories.isNotEmpty
                        ? Border.all(color: base, width: 2)
                        : null,
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
                        Icon(Icons.chevron_right, size: 14,
                            color: isActiveParent ? Colors.white : base),
                      ],
                    ],
                  ),
                ),
              );
            }),
            _buildNewCategoryChip(vm, l10n),
          ],
        ),
        // Subcategory chips — shown when parent has subcategories
        if (selectedParent != null && selectedParent.subCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedParent.subCategories.map((sub) {
                final selected = vm.formCategoryId == sub.id;
                final base = _hexColor(sub.color.isNotEmpty ? sub.color : selectedParent.color);
                final subName = (locale.languageCode == 'he' && sub.nameHe?.isNotEmpty == true)
                    ? sub.nameHe!
                    : sub.name;
                return GestureDetector(
                  onTap: () => vm.setFormCategory(sub.id),
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
            ),
          ),
        ],
      ],
    );
  }

  String? _getCategoryDisplayName(ExpensesViewModel vm, String languageCode) {
    if (vm.formCategoryId == null) return null;
    for (final cat in vm.categories) {
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

  Widget _buildNewCategoryChip(ExpensesViewModel vm, AppLocalizations l10n) {
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

  void _openCreateCategorySheet(BuildContext context, WidgetRef ref, ExpensesViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCategorySheet(
        categoryType: 'expense',
        householdId: vm.householdId,
        onCreated: (cat) {
          vm.addCategory(cat);
          vm.setFormCategory(cat.id);
        },
      ),
    );
  }

  Widget _buildDateTimePicker(ExpensesViewModel vm) {
    final formatted =
        '${vm.formDateTime.year}-${vm.formDateTime.month.toString().padLeft(2, '0')}-'
        '${vm.formDateTime.day.toString().padLeft(2, '0')}  '
        '${vm.formDateTime.hour.toString().padLeft(2, '0')}:${vm.formDateTime.minute.toString().padLeft(2, '0')}';

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
            Text(formatted, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSegment(ExpensesViewModel vm, AppLocalizations l10n) {
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
                color: active ? const Color(0xFF667EEA) : const Color(0xFFF0F0F0),
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

  Widget _buildLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
        if (optional)
          Text(' ${AppLocalizations.of(context)!.commonOptional}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
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
        borderSide: const BorderSide(color: Color(0xFF667EEA), width: 1.5)),
  );

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}
