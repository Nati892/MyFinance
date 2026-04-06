import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/credit_card.dart';
import 'package:household/services/credit_card_service.dart';
import 'package:household/services/household_service.dart';

const _purple = Color(0xFF667EEA);

class CreditCardsScreen extends ConsumerStatefulWidget {
  const CreditCardsScreen({super.key});

  @override
  ConsumerState<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends ConsumerState<CreditCardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hid = ref.read(householdServiceProvider).currentHouseholdId;
      if (hid != null) ref.read(creditCardServiceProvider).load(hid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardService = ref.watch(creditCardServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cardsPageTitle),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: cardService.cards.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.credit_card, size: 64, color: Color(0xFFCCCCCC)),
                  const SizedBox(height: 12),
                  Text(
                    'No cards added yet.',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF888888)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: cardService.cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final card = cardService.cards[i];
                return _CardTile(
                  card: card,
                  onEdit: () => _showCardSheet(context, card: card),
                  onDelete: () => _confirmDelete(context, card),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCardSheet(context),
        backgroundColor: _purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCardSheet(BuildContext context, {CreditCard? card}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardFormSheet(card: card),
    );
  }

  void _confirmDelete(BuildContext context, CreditCard card) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(l10n.cardsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(creditCardServiceProvider).delete(card.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Card tile ─────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final CreditCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardTile({required this.card, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.credit_card, color: _purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.displayLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                ),
                if (card.bankName != null || card.cardType != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (card.bankName != null)
                        Text(card.bankName!, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      if (card.bankName != null && card.cardType != null)
                        const Text(' · ', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      if (card.cardType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF0FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            card.cardType![0].toUpperCase() + card.cardType!.substring(1),
                            style: const TextStyle(fontSize: 10, color: _purple, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF666666)),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFDD4444)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Card form sheet ───────────────────────────────────────────────────────────

class _CardFormSheet extends ConsumerStatefulWidget {
  final CreditCard? card;

  const _CardFormSheet({this.card});

  @override
  ConsumerState<_CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends ConsumerState<_CardFormSheet> {
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
      final service = ref.read(creditCardServiceProvider);
      if (widget.card == null) {
        await service.create(body);
      } else {
        await service.update(widget.card!.id, body);
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

          // Last 4 digits
          Text(l10n.cardsLastFour, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(
            controller: _lastFourCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('1234'),
          ),
          const SizedBox(height: 12),

          // Nickname
          Text(l10n.cardsNickname, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(controller: _nicknameCtrl, decoration: _inputDeco('e.g. My Visa')),
          const SizedBox(height: 12),

          // Bank name
          Text(l10n.cardsBankName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(controller: _bankCtrl, decoration: _inputDeco('e.g. Leumi')),
          const SizedBox(height: 12),

          // Card type
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
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
          color: active ? _purple : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _purple : const Color(0xFFDDDDDD)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : const Color(0xFF555555),
        )),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _purple, width: 1.5)),
  );
}
