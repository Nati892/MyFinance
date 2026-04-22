import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/screens/schedules/schedules_view_model.dart';
import 'package:household/utils/icon_helper.dart';

const _kScheduleColor = Color(0xFF1976D2);

class ExpenseScheduleFormSheet extends ConsumerStatefulWidget {
  const ExpenseScheduleFormSheet({super.key});

  @override
  ConsumerState<ExpenseScheduleFormSheet> createState() =>
      _ExpenseScheduleFormSheetState();
}

class _ExpenseScheduleFormSheetState
    extends ConsumerState<ExpenseScheduleFormSheet> {
  late TextEditingController _descCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;

  static const _paymentMethodKeys = [
    ('bank_transfer', '🏦', 'Transfer'),
    ('card', '💳', 'Card'),
    ('cash', '💵', 'Cash'),
  ];

  @override
  void initState() {
    super.initState();
    final vm = ref.read(schedulesViewModelProvider);
    _descCtrl   = TextEditingController(text: vm.formDescription);
    _amountCtrl = TextEditingController(
        text: vm.formAmount != null ? vm.formAmount.toString() : '');
    _noteCtrl   = TextEditingController(text: vm.formNote);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(schedulesViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final isEdit = vm.isEditMode;
    final dayLabels = [
      l10n.scheduleDaySun, l10n.scheduleDayMon, l10n.scheduleDayTue,
      l10n.scheduleDayWed, l10n.scheduleDayThu, l10n.scheduleDayFri,
      l10n.scheduleDaySat,
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
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
                      color: _kScheduleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule,
                        color: _kScheduleColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? l10n.scheduleEdit : l10n.scheduleNew,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
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
                  // Description (required)
                  _label(l10n.scheduleDescription),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _descCtrl,
                    hint: l10n.scheduleDescriptionHint,
                    onChanged: vm.setDescription,
                  ),

                  const SizedBox(height: 16),

                  // Category (required)
                  _label(l10n.scheduleCategory),
                  const SizedBox(height: 6),
                  _CategoryPicker(
                    categories: vm.expenseCategories,
                    selectedId: vm.formCategoryId,
                    selectedParentId: vm.selectedParentId,
                    onSelected: vm.setCategory,
                  ),

                  const SizedBox(height: 20),

                  // Days of week (required)
                  _label(l10n.scheduleDays),
                  const SizedBox(height: 4),
                  Text(
                    l10n.scheduleDaysHint,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _DaysPicker(
                    selected: vm.formDaysOfWeek,
                    dayLabels: dayLabels,
                    onToggle: vm.toggleDay,
                  ),

                  const SizedBox(height: 20),

                  // Amount (optional)
                  _label(l10n.scheduleAmount),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _amountCtrl,
                    hint: l10n.scheduleAmountHint,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    ],
                    onChanged: (v) => vm.setAmount(double.tryParse(v)),
                  ),

                  const SizedBox(height: 16),

                  // Payment method (optional)
                  _label(l10n.schedulePaymentMethod),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // "None" option
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => vm.setPaymentMethod(null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: !vm.formPaymentMethodSet
                                  ? _kScheduleColor.withValues(alpha: 0.2)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                              border: !vm.formPaymentMethodSet
                                  ? Border.all(
                                      color: _kScheduleColor, width: 1.5)
                                  : null,
                            ),
                            child: const Text('—',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16)),
                          ),
                        ),
                      ),
                      ..._paymentMethodKeys.map((entry) {
                        final (method, emoji, _) = entry;
                        final selected =
                            vm.formPaymentMethodSet &&
                            vm.formPaymentMethod == method;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => vm.setPaymentMethod(method),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _kScheduleColor.withValues(alpha: 0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: selected
                                    ? Border.all(
                                        color: _kScheduleColor, width: 1.5)
                                    : null,
                              ),
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Active toggle
                  Row(
                    children: [
                      _label(l10n.scheduleActive),
                      const Spacer(),
                      Switch(
                        value: vm.formIsActive,
                        onChanged: vm.setIsActive,
                        activeThumbColor: _kScheduleColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Note (optional)
                  _label(l10n.scheduleNote),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _noteCtrl,
                    hint: l10n.expensesNotePlaceholder,
                    maxLines: 3,
                    onChanged: vm.setNote,
                  ),

                  // Error
                  if (vm.formError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        vm.formError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: vm.formSaving ? null : vm.save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kScheduleColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: vm.formSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEdit ? l10n.scheduleSave : l10n.scheduleAdd,
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

  void _confirmDelete(BuildContext context, SchedulesViewModel vm) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: Text(l10n.scheduleDeleteConfirm,
            style: const TextStyle(color: Colors.white)),
        content: Text(l10n.scheduleDeleteMessage,
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
              Navigator.pop(context);
              vm.delete(vm.editingId!);
            },
            child: Text(l10n.commonDelete,
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
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

// ─── Days-of-week picker ──────────────────────────────────────────────────────

class _DaysPicker extends StatelessWidget {
  final List<int> selected;
  final List<String> dayLabels;
  final void Function(int) onToggle;

  const _DaysPicker({
    required this.selected,
    required this.dayLabels,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (dow) {
        final isOn = selected.contains(dow);
        return GestureDetector(
          onTap: () => onToggle(dow),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOn
                  ? _kScheduleColor.withValues(alpha: 0.25)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: isOn
                  ? Border.all(color: _kScheduleColor, width: 1.5)
                  : Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                dayLabels[dow].substring(0, 2),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isOn ? FontWeight.w700 : FontWeight.w400,
                  color: isOn ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Category picker ──────────────────────────────────────────────────────────

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
    final locale = Localizations.localeOf(context);
    final isHe = locale.languageCode == 'he';
    String catLabel(Category c) =>
        (isHe && c.nameHe?.isNotEmpty == true) ? c.nameHe! : c.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = cat.id == selectedParentId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(
                      cat.id, cat.subCategories.isEmpty ? null : null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kScheduleColor.withValues(alpha: 0.2)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: _kScheduleColor, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat.icon != null)
                          Icon(iconDataFromName(cat.icon!),
                              size: 16, color: Colors.white70),
                        if (cat.icon != null) const SizedBox(width: 6),
                        Text(
                          catLabel(cat),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
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
        if (selectedParentId != null) ...[
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final parent = categories.firstWhere(
              (c) => c.id == selectedParentId,
              orElse: () => categories.first,
            );
            if (parent.subCategories.isEmpty) return const SizedBox.shrink();
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _kScheduleColor.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: _kScheduleColor, width: 1)
                              : null,
                        ),
                        child: Text(
                          catLabel(sub),
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
