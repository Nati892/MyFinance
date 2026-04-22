import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_session_item.dart';
import 'package:household/screens/board/board_view_model.dart';
import 'package:household/screens/board/shopping_view_model.dart';
import 'package:household/utils/color_utils.dart';

class ActiveShoppingScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const ActiveShoppingScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ActiveShoppingScreen> createState() =>
      _ActiveShoppingScreenState();
}

class _ActiveShoppingScreenState extends ConsumerState<ActiveShoppingScreen> {
  bool _completing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final boardVm = ref.watch(boardViewModelProvider);
    final shoppingVm = ref.watch(shoppingViewModelProvider);

    final session = boardVm.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => _missingSession(),
    );
    if (session.id == -1) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.commonError)),
      );
    }

    final bg = hexColor(session.noteColor);
    final total = session.actualTotal;
    final count = session.sessionItems.length;
    final done = session.completedItemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: darken(bg, 0.05),
        foregroundColor: const Color(0xFF5D4037),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${l10n.shoppingTotalSoFar}: ₪${total.toStringAsFixed(2)} · $done/$count',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
            ),
          ],
        ),
      ),
      body: session.sessionItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.shoppingNoItems,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 14),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: session.sessionItems.length,
              itemBuilder: (ctx, i) {
                final item = session.sessionItems[i];
                return _ActiveShoppingRow(
                  key: ValueKey(item.id),
                  item: item,
                  onPatch: (patch) =>
                      boardVm.patchSessionItem(session.id, item.id, patch),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _completing ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5D4037),
                    side: const BorderSide(color: Color(0xFF8D6E63)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.shoppingSaveAndExit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _completing
                      ? null
                      : () => _openCompleteSheet(
                          context, session, shoppingVm, boardVm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _completing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          l10n.shoppingDoneCreateExpense,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCompleteSheet(
    BuildContext context,
    ShoppingSession session,
    ShoppingViewModel shoppingVm,
    BoardViewModel boardVm,
  ) async {
    final total = session.actualTotal;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.shoppingNoTotalYet),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_CompletePayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompleteExpenseSheet(
        initialAmount: total,
        initialCategoryId: session.expenseCategoryId,
        sessionName: session.name,
        expenseCategories: shoppingVm.expenseCategories,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _completing = true);
    final expense = await boardVm.completeSessionAndCreateExpense(
      session.id,
      {
        'actualAmount': result.amount,
        'dateTime': result.dateTime.toIso8601String(),
        'expenseCategoryId': result.categoryId,
        'paymentMethod': result.paymentMethod,
        'description': session.name,
      },
    );
    if (!mounted) return;
    setState(() => _completing = false);
    if (!context.mounted) return;

    if (expense == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.shoppingCompleteFailed)),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context)!.shoppingExpenseCreated}: ₪${result.amount.toStringAsFixed(2)}',
        ),
      ),
    );
  }

  ShoppingSession _missingSession() => ShoppingSession(
        id: -1,
        name: '',
        posX: 0,
        posY: 0,
        zIndex: 0,
        rotation: 0,
        width: 0,
        height: 0,
        noteColor: '#ffffff',
        householdId: 0,
        createdBy: 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActiveShoppingRow extends StatefulWidget {
  final ShoppingSessionItem item;
  final void Function(Map<String, dynamic> patch) onPatch;

  const _ActiveShoppingRow({
    required super.key,
    required this.item,
    required this.onPatch,
  });

  @override
  State<_ActiveShoppingRow> createState() => _ActiveShoppingRowState();
}

class _ActiveShoppingRowState extends State<_ActiveShoppingRow> {
  late ShoppingItemStatus _status;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _priceCtrl = TextEditingController(
      text: widget.item.price != null
          ? widget.item.price!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void didUpdateWidget(_ActiveShoppingRow old) {
    super.didUpdateWidget(old);
    if (old.item.status != widget.item.status) {
      _status = widget.item.status;
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (_status) {
      case ShoppingItemStatus.got:
        return const Color(0xFF4CAF50);
      case ShoppingItemStatus.notGot:
        return const Color(0xFFE53935);
      case ShoppingItemStatus.partial:
        return const Color(0xFFFF9800);
      case ShoppingItemStatus.pending:
        return const Color(0xFFBBBBBB);
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case ShoppingItemStatus.got:
        return Icons.check;
      case ShoppingItemStatus.notGot:
        return Icons.close;
      case ShoppingItemStatus.partial:
        return Icons.remove;
      case ShoppingItemStatus.pending:
        return Icons.circle_outlined;
    }
  }

  void _cycleStatus() {
    final next = switch (_status) {
      ShoppingItemStatus.pending => ShoppingItemStatus.got,
      ShoppingItemStatus.got => ShoppingItemStatus.partial,
      ShoppingItemStatus.partial => ShoppingItemStatus.notGot,
      ShoppingItemStatus.notGot => ShoppingItemStatus.pending,
    };
    setState(() => _status = next);
    widget.onPatch({'status': next.wireValue});
  }

  void _submitPrice(String v) {
    final parsed = v.isEmpty ? null : double.tryParse(v);
    widget.onPatch({'price': parsed, 'status': _status.wireValue});
  }

  String get _displayName {
    final item = widget.item.item;
    if (item == null) return '?';
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'he' &&
        item.nameHe != null &&
        item.nameHe!.isNotEmpty) {
      return item.nameHe!;
    }
    return item.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEE4D8)),
      ),
      child: Row(
        children: [
          // Status button
          GestureDetector(
            onTap: _cycleStatus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _status == ShoppingItemStatus.pending
                    ? const Color(0xFFF5F5F5)
                    : _statusColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusColor,
                  width: 2,
                ),
              ),
              child: Icon(
                _statusIcon,
                size: 22,
                color: _status == ShoppingItemStatus.pending
                    ? _statusColor
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (widget.item.item?.icon != null) ...[
                      Text(widget.item.item!.icon!,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        _displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                          decoration: _status == ShoppingItemStatus.got
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.item.amount % 1 == 0 ? widget.item.amount.toInt() : widget.item.amount} ${widget.item.unit}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
          // Price field
          SizedBox(
            width: 90,
            child: TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                isDense: true,
                prefixText: '₪ ',
                prefixStyle:
                    TextStyle(color: Color(0xFF8D6E63), fontSize: 14),
                hintText: '0.00',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                ),
              ),
              onSubmitted: _submitPrice,
              onEditingComplete: () {
                _submitPrice(_priceCtrl.text);
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CompletePayload {
  final double amount;
  final DateTime dateTime;
  final int categoryId;
  final String paymentMethod;

  _CompletePayload({
    required this.amount,
    required this.dateTime,
    required this.categoryId,
    required this.paymentMethod,
  });
}

class _CompleteExpenseSheet extends StatefulWidget {
  final double initialAmount;
  final int? initialCategoryId;
  final String sessionName;
  final List<Category> expenseCategories;

  const _CompleteExpenseSheet({
    required this.initialAmount,
    required this.initialCategoryId,
    required this.sessionName,
    required this.expenseCategories,
  });

  @override
  State<_CompleteExpenseSheet> createState() => _CompleteExpenseSheetState();
}

class _CompleteExpenseSheetState extends State<_CompleteExpenseSheet> {
  late TextEditingController _amountCtrl;
  late int? _categoryId;
  late DateTime _dateTime;
  String _paymentMethod = 'card';

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.initialAmount.toStringAsFixed(2));
    _categoryId = widget.initialCategoryId;
    _dateTime = DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 16),
          Text(
            l10n.shoppingCreateExpense,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            widget.sessionName,
            style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Text(l10n.shoppingAmount,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '₪ ',
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.expensesCategory,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
            items: widget.expenseCategories
                .expand((c) => [
                      DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.nameHe ?? c.name,
                            overflow: TextOverflow.ellipsis),
                      ),
                      ...c.subCategories.map(
                        (sub) => DropdownMenuItem<int?>(
                          value: sub.id,
                          child: Text('  ↳ ${sub.nameHe ?? sub.name}',
                              overflow: TextOverflow.ellipsis),
                        ),
                      )
                    ])
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          Text(l10n.expensesPaymentMethod,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _paymentBtn('card', '💳', l10n.paymentCard),
              const SizedBox(width: 6),
              _paymentBtn('cash', '💵', l10n.paymentCash),
              const SizedBox(width: 6),
              _paymentBtn('bank_transfer', '🏦', l10n.paymentTransfer),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8D6E63),
                    side: const BorderSide(color: Color(0xFF8D6E63)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    l10n.shoppingConfirmCreateExpense,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentBtn(String key, String emoji, String label) {
    final active = _paymentMethod == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE53935) : const Color(0xFFF5F0EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.white : const Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0 || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.shoppingMissingFields),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_CompletePayload(
      amount: amount,
      dateTime: _dateTime,
      categoryId: _categoryId!,
      paymentMethod: _paymentMethod,
    ));
  }
}
