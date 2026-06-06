import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/models/credit_card.dart';
import 'package:household/screens/transactions/transactions_view_model.dart';
import 'package:household/services/household_service.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:household/widgets/create_category_sheet.dart';
import 'package:household/widgets/transaction_timeline.dart' show AuthImage;
import 'package:image_picker/image_picker.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const kExpensePurple = Color(0xFF667EEA);

// ─── Expense form sheet ────────────────────────────────────────────────────────

class ExpenseFormSheet extends ConsumerStatefulWidget {
  const ExpenseFormSheet({super.key});

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _noteCtrl;
  final FocusNode _amountFocus = FocusNode();
  int? _selectedParentId;

  static const int _initialFavoritesCount = 8;
  static const int _moreRevealStep = 10;
  int _extraRevealed = 0;

  static const _paymentMethodKeys = [
    ('card',          '💳'),
    ('cash',          '💵'),
    ('bank_transfer', '🏦'),
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
      for (final cat in vm.expenseCategories) {
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
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(transactionsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final locale = Localizations.localeOf(context);
    final selectedCategoryName = _getExpenseCategoryName(vm, locale.languageCode);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHandle(),
                  const SizedBox(height: 16),
                  _buildHeader(vm, l10n.transactionsExpenseLabel, kExpensePurple, l10n, vm.expenseCategories, selectedCategoryName),
                  if (vm.modalError != null) _buildError(vm),
                  const SizedBox(height: 16),
                  _buildAmountField(vm),
                  _buildFrequentAmounts(vm, isExpense: true),
                  const SizedBox(height: 16),
                  _buildLabel(l10n.expensesCategory),
                  const SizedBox(height: 8),
                  _buildCategoryChips(vm, vm.expenseCategories, l10n),
                  const SizedBox(height: 16),
                  // Recurring toggle
                  _buildLabel(l10n.recurringTitle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: vm.formIsRecurring,
                        onChanged: vm.isEditMode ? null : vm.setFormIsRecurring,
                        activeThumbColor: const Color(0xFF9C27B0),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        vm.formIsRecurring ? l10n.recurringBadge : l10n.expensesDate,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                      ),
                      if (vm.isEditMode && vm.formIsRecurring) ...[
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await vm.deleteRecurringFromExpenseForm();
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!vm.formIsRecurring) ...[
                    _buildLabel(l10n.expensesDate),
                    const SizedBox(height: 8),
                    _buildDateTimePicker(vm),
                    const SizedBox(height: 16),
                  ],
                  if (vm.formIsRecurring) ...[
                    _buildLabel(l10n.recurringDayOfMonth),
                    const SizedBox(height: 8),
                    _buildDayOfMonthField(vm),
                    const SizedBox(height: 16),
                    _buildLabel(l10n.recurringStartMonth),
                    const SizedBox(height: 8),
                    _buildStartMonthRow(vm),
                    const SizedBox(height: 16),
                  ],
                  _buildLabel(l10n.expensesPaymentMethod),
                  const SizedBox(height: 8),
                  _buildPaymentSegment(vm, kExpensePurple, l10n),
                  const SizedBox(height: 16),
                  _buildLabel(l10n.expensesDescription, optional: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    onChanged: vm.setFormDescription,
                    decoration: _inputDeco(l10n.expensesDescriptionPlaceholder, kExpensePurple),
                    maxLength: 200,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel(l10n.expensesNote, optional: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    onChanged: vm.setFormNote,
                    decoration: _inputDeco(l10n.expensesNotePlaceholder, kExpensePurple),
                    maxLines: 3,
                    maxLength: 500,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                  const SizedBox(height: 16),
                  _buildAttachmentsSection(vm, l10n),
                  if (!vm.formIsRecurring) ...[
                    const SizedBox(height: 16),
                    _buildInstallmentsRow(vm),
                  ],
                ],
              ),
            ),
          ),
          // ── Save button always visible ───────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPad),
            child: _buildSaveButton(
              vm: vm,
              color: kExpensePurple,
              editLabel: l10n.expensesSave,
              addLabel: l10n.expensesAdd,
              onSave: () => _handleSave(context, vm),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(BuildContext context, TransactionsViewModel vm) async {
    if (!vm.shouldAskInstallmentScope) {
      return vm.saveExpense();
    }

    final scope = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InstallmentScopeSheet(),
    );

    if (scope == null) return; // cancelled
    return vm.saveExpenseWithScope(scope);
  }

  Widget _buildDayOfMonthField(TransactionsViewModel vm) {
    final ctrl = TextEditingController(text: vm.formDayOfMonth.toString());
    ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length));
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: _inputDeco('1–28', kExpensePurple),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null) vm.setFormDayOfMonth(parsed);
      },
    );
  }

  Widget _buildStartMonthRow(TransactionsViewModel vm) {
    final now = DateTime.now();
    final years = List.generate(5, (i) => now.year + i - 1);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFAFAFA),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: vm.formDayOfMonthStartMonth,
                isExpanded: true,
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_monthNames[i]),
                )),
                onChanged: (v) { if (v != null) vm.setFormDayOfMonthStartMonth(v); },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFAFAFA),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: vm.formDayOfMonthStartYear,
                isExpanded: true,
                items: years.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text('$y'),
                )).toList(),
                onChanged: (v) { if (v != null) vm.setFormDayOfMonthStartYear(v); },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentsRow(TransactionsViewModel vm) {
    final total = vm.formInstallmentTotal;
    final current = vm.formInstallmentCurrent;
    return Row(
      children: [
        const Text('תשלומים', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
        const Spacer(),
        if (vm.isEditMode && total > 1) ...[
          // In edit mode with installments: show current stepper
          _installmentStepper(
            label: '$current',
            onMinus: () => vm.setFormInstallmentCurrent(current - 1),
            onPlus: () => vm.setFormInstallmentCurrent(current + 1),
            minusEnabled: current > 1,
            plusEnabled: current < total,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('/', style: TextStyle(fontSize: 16, color: Color(0xFF888888))),
          ),
        ],
        _installmentStepper(
          label: '$total',
          onMinus: () {
            vm.setFormInstallmentTotal(total - 1);
          },
          onPlus: () => vm.setFormInstallmentTotal(total + 1),
          minusEnabled: total > 1,
          plusEnabled: total < 99,
        ),
      ],
    );
  }

  Widget _installmentStepper({
    required String label,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required bool minusEnabled,
    required bool plusEnabled,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: minusEnabled ? onMinus : null,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: minusEnabled ? kExpensePurple.withValues(alpha: 0.1) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.remove, size: 16,
                color: minusEnabled ? kExpensePurple : const Color(0xFFCCCCCC)),
          ),
        ),
        Container(
          width: 36,
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
        ),
        GestureDetector(
          onTap: plusEnabled ? onPlus : null,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: plusEnabled ? kExpensePurple.withValues(alpha: 0.1) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.add, size: 16,
                color: plusEnabled ? kExpensePurple : const Color(0xFFCCCCCC)),
          ),
        ),
      ],
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
          child: GestureDetector(
            onTap: () => _amountFocus.requestFocus(),
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
                        focusNode: _amountFocus,
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
    // When no parent is selected, show top favorites first, then any "more…"-revealed
    // extras. The rest is hidden behind the more chip.
    List<Category> visibleParents;
    int hiddenCount = 0;
    if (_selectedParentId != null) {
      visibleParents = cats.where((c) => c.id == _selectedParentId).toList();
    } else {
      final catIds = cats.map((c) => c.id).toSet();
      final favIds = <int>{};
      final favs = <Category>[];
      for (final f in vm.favoriteCategories) {
        if (favs.length >= _initialFavoritesCount) break;
        if (!catIds.contains(f.id) || favIds.contains(f.id)) continue;
        final match = cats.firstWhere((c) => c.id == f.id, orElse: () => f);
        favs.add(match);
        favIds.add(f.id);
      }
      final rest = cats.where((c) => !favIds.contains(c.id)).toList();
      final revealed = _extraRevealed.clamp(0, rest.length);
      visibleParents = [...favs, ...rest.take(revealed)];
      hiddenCount = rest.length - revealed;
    }

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
                    // Deselect: show all parents again
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
            if (hiddenCount > 0) _buildMoreChip(l10n, hiddenCount),
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
                        // Revert to parent level
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

  Widget _buildMoreChip(AppLocalizations l10n, int hiddenCount) {
    return GestureDetector(
      onTap: () => setState(() => _extraRevealed += _moreRevealStep),
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
            const Icon(Icons.more_horiz, size: 16, color: Color(0xFF666666)),
            const SizedBox(width: 4),
            Text(l10n.commonMore,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ],
        ),
      ),
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

  // ── Attachments ────────────────────────────────────────────────────────────

  Widget _buildAttachmentsSection(TransactionsViewModel vm, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(l10n.attachments, optional: true),
        const SizedBox(height: 8),
        // Add buttons row
        Row(
          children: [
            _buildAttachButton(
              icon: Icons.camera_alt_outlined,
              label: l10n.attachmentsAddCamera,
              onTap: () => _pickCamera(vm),
            ),
            const SizedBox(width: 8),
            _buildAttachButton(
              icon: Icons.attach_file,
              label: l10n.attachmentsAddFiles,
              onTap: () => _pickFiles(vm),
            ),
          ],
        ),
        // Existing saved attachments (edit mode)
        if (vm.existingAttachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...vm.existingAttachments.map((att) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  att.isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AuthImage(
                            url: '$kBaseUrl/app/attachments/${att.id}/thumb',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kExpensePurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.insert_drive_file, size: 22, color: kExpensePurple),
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      att.filename,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF444444)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF888888)),
                    onPressed: () => vm.removeExistingAttachment(att.id),
                    tooltip: l10n.attachmentsRemove,
                  ),
                ],
              ),
            );
          }),
        ],
        // Newly picked attachments (not yet uploaded)
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
                            color: kExpensePurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.insert_drive_file, size: 22, color: kExpensePurple),
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      onChanged: (v) => vm.renamePendingAttachment(idx, v),
                      decoration: _inputDeco(l10n.attachmentsName, kExpensePurple),
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kExpensePurple.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kExpensePurple.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: kExpensePurple),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kExpensePurple)),
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

  String? _getExpenseCategoryName(TransactionsViewModel vm, String languageCode) {
    if (vm.formCategoryId == null) return null;
    for (final cat in vm.expenseCategories) {
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

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ── Card chip ─────────────────────────────────────────────────────────────────

class TxCardChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const TxCardChip({super.key, required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : const Color(0xFFDDDDDD),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? Colors.white : const Color(0xFF333333),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Card form sheet ───────────────────────────────────────────────────────────

class TxCardFormSheet extends ConsumerStatefulWidget {
  final CreditCard? card;
  final TransactionsViewModel vm;
  final Color activeColor;

  const TxCardFormSheet({super.key, this.card, required this.vm, required this.activeColor});

  @override
  ConsumerState<TxCardFormSheet> createState() => _TxCardFormSheetState();
}

class _TxCardFormSheetState extends ConsumerState<TxCardFormSheet> {
  late TextEditingController _lastFourCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _bankCtrl;
  String? _cardType;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lastFourCtrl = TextEditingController(text: widget.card?.lastFourDigits ?? '');
    _nicknameCtrl = TextEditingController(text: widget.card?.nickname ?? '');
    _bankCtrl     = TextEditingController(text: widget.card?.bankName ?? '');
    _cardType     = widget.card?.cardType;
  }

  @override
  void dispose() {
    _lastFourCtrl.dispose();
    _nicknameCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _lastFourCtrl.text.trim();
    if (digits.length != 4 || !RegExp(r'^\d{4}$').hasMatch(digits)) {
      setState(() => _error = 'Enter exactly 4 digits.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final hid = ref.read(householdServiceProvider).currentHouseholdId;
    if (hid == null) { setState(() => _saving = false); return; }

    final body = <String, dynamic>{
      'lastFourDigits': digits,
      if (_nicknameCtrl.text.trim().isNotEmpty) 'nickname': _nicknameCtrl.text.trim(),
      if (_bankCtrl.text.trim().isNotEmpty) 'bankName': _bankCtrl.text.trim(),
      if (_cardType != null) 'cardType': _cardType,
      'householdId': hid,
    };

    try {
      if (widget.card == null) {
        await widget.vm.createCard(body);
      } else {
        await widget.vm.updateCard(widget.card!.id, body);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _saving = false; _error = 'Failed to save. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.card != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEdit ? l10n.cardsEditCard : l10n.cardsAddCard,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(l10n.cardsLastFour, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(
            controller: _lastFourCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('1234', widget.activeColor),
          ),
          const SizedBox(height: 12),
          Text('${l10n.cardsNickname} ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(controller: _nicknameCtrl, decoration: _inputDeco('e.g. My Visa', widget.activeColor)),
          const SizedBox(height: 12),
          Text('${l10n.cardsBankName} ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(controller: _bankCtrl, decoration: _inputDeco('e.g. Leumi', widget.activeColor)),
          const SizedBox(height: 12),
          Row(
            children: [
              _typeBtn(l10n.cardsTypeCredit, 'credit'),
              const SizedBox(width: 8),
              _typeBtn(l10n.cardsTypeDebit, 'debit'),
              const SizedBox(width: 8),
              _typeBtn('—', null),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.activeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(String label, String? type) {
    final active = _cardType == type;
    return GestureDetector(
      onTap: () => setState(() => _cardType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? widget.activeColor : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? widget.activeColor : const Color(0xFFDDDDDD)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : const Color(0xFF555555),
        )),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, Color focusColor) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: focusColor, width: 1.5)),
  );
}

// ─── Installment scope picker ─────────────────────────────────────────────────

class _InstallmentScopeSheet extends StatelessWidget {
  const _InstallmentScopeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Update installment amount',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Which payments should be updated?',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
          ),
          const SizedBox(height: 16),
          _option(context, 'all',     Icons.all_inclusive,        'All payments',        'Change every payment in this series'),
          _option(context, 'forward', Icons.arrow_forward,        'This and forward',    'Change this payment and all future ones'),
          _option(context, 'this',    Icons.looks_one_outlined,   'Only this one',       'Change only this single payment'),
          const Divider(height: 1),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Cancel', style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String scope, IconData icon, String title, String subtitle) {
    return InkWell(
      onTap: () => Navigator.pop(context, scope),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: kExpensePurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: kExpensePurple),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
