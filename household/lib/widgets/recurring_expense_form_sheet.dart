import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/screens/transactions/transactions_view_model.dart';
import 'package:household/utils/icon_helper.dart';

const _kRecurringColor = Color(0xFF9C27B0); // purple for recurring

class RecurringExpenseFormSheet extends ConsumerStatefulWidget {
  const RecurringExpenseFormSheet({super.key});

  @override
  ConsumerState<RecurringExpenseFormSheet> createState() =>
      _RecurringExpenseFormSheetState();
}

class _RecurringExpenseFormSheetState
    extends ConsumerState<RecurringExpenseFormSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _dayCtrl;
  int? _selectedParentId;

  static const _paymentMethodKeys = [
    ('bank_transfer', '🏦'),
    ('card',          '💳'),
    ('cash',          '💵'),
  ];

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final vm = ref.read(transactionsViewModelProvider);
    _amountCtrl = TextEditingController(
        text: vm.recurringFormAmount != null
            ? vm.recurringFormAmount.toString()
            : '');
    _descCtrl = TextEditingController(text: vm.recurringFormDescription);
    _noteCtrl = TextEditingController(text: vm.recurringFormNote);
    _dayCtrl  = TextEditingController(text: vm.recurringFormDayOfMonth.toString());

    if (vm.recurringFormCategoryId != null) {
      for (final cat in vm.expenseCategories) {
        if (cat.id == vm.recurringFormCategoryId) {
          _selectedParentId = cat.id;
          break;
        }
        for (final sub in cat.subCategories) {
          if (sub.id == vm.recurringFormCategoryId) {
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
    _dayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm   = ref.watch(transactionsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    final isEdit = vm.recurringIsEditMode;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Title bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kRecurringColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.repeat, color: _kRecurringColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? l10n.recurringEdit : l10n.recurringNew,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Delete button (edit mode only)
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, vm),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 20),

            // ── Scrollable body ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Amount
                  _label('Amount'),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _amountCtrl,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      vm.setRecurringFormAmount(parsed);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Category
                  _label(l10n.expensesCategory),
                  const SizedBox(height: 6),
                  _CategoryPicker(
                    categories: vm.expenseCategories,
                    selectedId: vm.recurringFormCategoryId,
                    selectedParentId: _selectedParentId,
                    onSelected: (parentId, subId) {
                      setState(() => _selectedParentId = parentId);
                      vm.setRecurringFormCategory(subId ?? parentId);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Payment method
                  _label(l10n.expensesPaymentMethod),
                  const SizedBox(height: 6),
                  Row(
                    children: _paymentMethodKeys.map((entry) {
                      final (method, emoji) = entry;
                      final selected = vm.recurringFormPaymentMethod == method;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => vm.setRecurringFormPayment(method),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _kRecurringColor.withValues(alpha: 0.2)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? Border.all(color: _kRecurringColor, width: 1.5)
                                  : null,
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Day of month
                  _label(l10n.recurringDayOfMonth),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _dayCtrl,
                    hint: '10',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) vm.setRecurringFormDay(parsed);
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1 – 28',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),

                  const SizedBox(height: 16),

                  // Starting month/year
                  _label(l10n.recurringStartMonth),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Month picker
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: vm.recurringFormStartMonth,
                          dropdownColor: const Color(0xFF2A2A3E),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(),
                          items: List.generate(12, (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_monthNames[i]),
                          )),
                          onChanged: (v) {
                            if (v != null) vm.setRecurringFormStartMonth(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Year picker
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: vm.recurringFormStartYear,
                          dropdownColor: const Color(0xFF2A2A3E),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(),
                          items: List.generate(5, (i) {
                            final yr = DateTime.now().year - 1 + i;
                            return DropdownMenuItem(value: yr, child: Text('$yr'));
                          }),
                          onChanged: (v) {
                            if (v != null) vm.setRecurringFormStartYear(v);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  _label(l10n.expensesDescription),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _descCtrl,
                    hint: l10n.expensesDescriptionPlaceholder,
                    onChanged: vm.setRecurringFormDescription,
                  ),

                  const SizedBox(height: 16),

                  // Note
                  _label(l10n.expensesNote),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _noteCtrl,
                    hint: l10n.expensesNotePlaceholder,
                    maxLines: 3,
                    onChanged: vm.setRecurringFormNote,
                  ),

                  const SizedBox(height: 8),

                  // Error
                  if (vm.recurringModalError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        vm.recurringModalError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: vm.recurringModalSaving ? null : vm.saveRecurring,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kRecurringColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: vm.recurringModalSaving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : Text(
                              isEdit ? l10n.recurringSave : l10n.recurringAdd,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TransactionsViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: Text(l10n.recurringDeleteConfirm,
            style: const TextStyle(color: Colors.white)),
        content: Text(l10n.recurringDeleteMessage,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // close sheet
              vm.deleteRecurring(vm.recurringEditingId!);
            },
            child: Text(l10n.recurringDelete,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white10,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: _inputDecoration(hint: hint),
        onChanged: onChanged,
      );
}

// ─── Category picker widget ───────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final int? selectedParentId;
  final void Function(int parentId, int? subId) onSelected;

  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.selectedParentId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = cat.id == selectedParentId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(cat.id, cat.subCategories.isEmpty ? null : null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF9C27B0).withValues(alpha: 0.2)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: const Color(0xFF9C27B0), width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconDataFromName(cat.icon), size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Sub-category row (if parent selected and has subs)
        if (selectedParentId != null) ...[
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final parent = categories.firstWhere(
              (c) => c.id == selectedParentId,
              orElse: () => categories.first,
            );
            if (parent.subCategories.isEmpty) {
              return const SizedBox.shrink();
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: parent.subCategories.map((sub) {
                  final isSelected = sub.id == selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onSelected(parent.id, sub.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF9C27B0).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF9C27B0), width: 1)
                              : null,
                        ),
                        child: Text(
                          sub.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ],
    );
  }
}
