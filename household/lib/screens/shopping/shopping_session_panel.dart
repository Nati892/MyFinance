import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/shopping_list.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_session_item.dart';
import 'package:household/models/shopping_store.dart';
import 'package:household/repositories/shopping_repository.dart';
import 'package:household/screens/board/board_view_model.dart';
import 'package:household/screens/board/shopping_view_model.dart';
import 'package:household/utils/color_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────

class ShoppingSessionPanel extends ConsumerStatefulWidget {
  final int sessionId;

  /// If null, the "Manage" button is hidden (e.g. when already inside the management screen).
  final void Function({int initialTab})? onManage;

  const ShoppingSessionPanel({
    super.key,
    required this.sessionId,
    this.onManage,
  });

  @override
  ConsumerState<ShoppingSessionPanel> createState() =>
      _ShoppingSessionPanelState();
}

class _ShoppingSessionPanelState extends ConsumerState<ShoppingSessionPanel> {
  bool _assigning = false;
  bool _completing = false;

  @override
  Widget build(BuildContext context) {
    final boardVm = ref.watch(boardViewModelProvider);
    final shoppingVm = ref.watch(shoppingViewModelProvider);

    final session = boardVm.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: _missingSession,
    );

    if (session.id == -1) return const SizedBox.shrink();

    final bg = hexColor(session.noteColor);
    final headerColor = darken(bg, 0.1);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(context, session, headerColor, boardVm),
            Expanded(
              child: session.sessionItems.isEmpty
                  ? _buildNotStarted(
                      context, session, shoppingVm, boardVm, scrollCtrl)
                  : _buildActive(
                      context, session, shoppingVm, boardVm, scrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  // ── Handle ────────────────────────────────────────────────────────────────

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ShoppingSession session,
      Color headerColor, BoardViewModel boardVm) {
    final count = session.sessionItems.length;
    final done = session.completedItemCount;
    final total = session.actualTotal;

    return Container(
      color: headerColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
      child: Row(
        children: [
          Icon(
            count == 0
                ? Icons.shopping_cart_outlined
                : Icons.shopping_cart,
            size: 22,
            color: const Color(0xFF5D4037),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5D4037),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  count == 0
                      ? 'No items — pick a list template to start'
                      : '₪${total.toStringAsFixed(2)}  ·  $done / $count done',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8D6E63)),
                ),
              ],
            ),
          ),
          if (widget.onManage != null)
            IconButton(
              icon: const Icon(Icons.manage_search,
                  color: Color(0xFF5D4037), size: 22),
              tooltip: 'Shopping management',
              onPressed: () => _openManagement(context),
            ),
          IconButton(
            icon: const Icon(Icons.close,
                color: Color(0xFF5D4037), size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Not started body ──────────────────────────────────────────────────────

  Widget _buildNotStarted(
    BuildContext context,
    ShoppingSession session,
    ShoppingViewModel shoppingVm,
    BoardViewModel boardVm,
    ScrollController scrollCtrl,
  ) {
    final templates = shoppingVm.lists;

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        const SizedBox(height: 12),
        const Center(
            child: Text('🛒', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Session not started yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Pick a shopping list template below,\nor manage your lists.',
            style: TextStyle(color: Color(0xFF8D6E63), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        if (shoppingVm.loading)
          const Center(child: CircularProgressIndicator())
        else if (templates.isEmpty)
          Column(
            children: [
              const Text(
                'No templates yet.',
                style: TextStyle(color: Color(0xFF8D6E63), fontSize: 14),
              ),
              if (widget.onManage != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _openManagement(context, initialTab: 1),
                  icon: const Icon(Icons.add),
                  label: const Text('Create a Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          )
        else ...[
          Text(
            'Templates (${templates.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8D6E63),
            ),
          ),
          const SizedBox(height: 10),
          ...templates.map((list) => _TemplateCard(
                list: list,
                assigning: _assigning,
                onAssign: () => _assignTemplate(context, list, boardVm),
              )),
          const SizedBox(height: 16),
          if (widget.onManage != null)
            OutlinedButton.icon(
              onPressed: () => _openManagement(context, initialTab: 1),
              icon: const Icon(Icons.list_alt, size: 16),
              label: const Text('Manage Templates'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5D4037),
                side: const BorderSide(color: Color(0xFF8D6E63)),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Active body ───────────────────────────────────────────────────────────

  Widget _buildActive(
    BuildContext context,
    ShoppingSession session,
    ShoppingViewModel shoppingVm,
    BoardViewModel boardVm,
    ScrollController scrollCtrl,
  ) {
    return Stack(
      children: [
        ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            _StorePicker(
              currentStoreId: session.storeId,
              stores: shoppingVm.stores,
              onChanged: (id) =>
                  boardVm.updateSessionStore(session.id, id),
              onCreateStore: shoppingVm.createStore,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 4),
            ...session.sessionItems.map((item) => _PanelItemRow(
                  key: ValueKey(item.id),
                  item: item,
                  stores: shoppingVm.stores,
                  onPatch: (patch) =>
                      boardVm.patchSessionItem(session.id, item.id, patch),
                  onCreateStore: shoppingVm.createStore,
                )),
            const SizedBox(height: 80),
          ],
        ),
        // Fixed complete bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _CompleteBar(
            session: session,
            expenseCategories: shoppingVm.expenseCategories,
            completing: _completing,
            onCompleting: (v) => setState(() => _completing = v),
            boardVm: boardVm,
          ),
        ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _assignTemplate(
    BuildContext context,
    ShoppingList list,
    BoardViewModel boardVm,
  ) async {
    if (_assigning) return;
    setState(() => _assigning = true);
    try {
      final repo = ref.read(shoppingRepositoryProvider);
      final full = list.listItems.isNotEmpty
          ? list
          : await repo.getListWithItems(list.id);
      await boardVm.assignListToSession(
        widget.sessionId,
        full.id,
        full.listItems
            .map((li) => {
                  'itemId': li.itemId,
                  'amount': li.amount,
                  'unit': li.unit,
                })
            .toList(),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  void _openManagement(BuildContext context, {int initialTab = 0}) {
    final cb = widget.onManage;
    Navigator.of(context).pop();
    cb?.call(initialTab: initialTab);
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
// Template card (not-started state)
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final ShoppingList list;
  final bool assigning;
  final VoidCallback onAssign;

  const _TemplateCard({
    required this.list,
    required this.assigning,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEE4D8)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.list_alt, color: Color(0xFF8D6E63), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  list.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5D4037),
                  ),
                ),
                if (list.listItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    child: Text(
                      '${list.listItems.length} item${list.listItems.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8D6E63)),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: assigning ? null : onAssign,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: assigning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Use this list',
                      style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Store picker (session-level)
// ─────────────────────────────────────────────────────────────────────────────

class _StorePicker extends StatefulWidget {
  final int? currentStoreId;
  final List<ShoppingStore> stores;
  final void Function(int? id) onChanged;
  final Future<ShoppingStore?> Function(String name) onCreateStore;

  const _StorePicker({
    required this.currentStoreId,
    required this.stores,
    required this.onChanged,
    required this.onCreateStore,
  });

  @override
  State<_StorePicker> createState() => _StorePickerState();
}

class _StorePickerState extends State<_StorePicker> {
  bool _adding = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.store, size: 18, color: Color(0xFF8D6E63)),
          const SizedBox(width: 8),
          const Text(
            'Where did I shop?',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8D6E63),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          if (_adding)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Store name',
                        hintStyle:
                            TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(8)),
                          borderSide:
                              BorderSide(color: Color(0xFFDDD5CB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(8)),
                          borderSide:
                              BorderSide(color: Color(0xFFDDD5CB)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      final name = _ctrl.text.trim();
                      if (name.isNotEmpty) {
                        final store = await widget.onCreateStore(name);
                        if (store != null) widget.onChanged(store.id);
                      }
                      setState(() => _adding = false);
                    },
                    child: const Icon(Icons.check,
                        size: 18, color: Color(0xFF4CAF50)),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _adding = false),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFFE53935)),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: widget.stores
                                .any((s) => s.id == widget.currentStoreId)
                            ? widget.currentStoreId
                            : null,
                        hint: const Text('Pick a store',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFFBBBBBB))),
                        isDense: true,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF333333)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No store',
                                style: TextStyle(fontSize: 13)),
                          ),
                          ...widget.stores.map((s) => DropdownMenuItem<int?>(
                                value: s.id,
                                child: Text(s.name,
                                    style:
                                        const TextStyle(fontSize: 13)),
                              )),
                        ],
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      setState(() => _adding = true);
                    },
                    child: const Icon(Icons.add_business,
                        size: 18, color: Color(0xFF8D6E63)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item row in active panel
// ─────────────────────────────────────────────────────────────────────────────

class _PanelItemRow extends StatefulWidget {
  final ShoppingSessionItem item;
  final List<ShoppingStore> stores;
  final void Function(Map<String, dynamic> patch) onPatch;
  final Future<ShoppingStore?> Function(String name) onCreateStore;

  const _PanelItemRow({
    required super.key,
    required this.item,
    required this.stores,
    required this.onPatch,
    required this.onCreateStore,
  });

  @override
  State<_PanelItemRow> createState() => _PanelItemRowState();
}

class _PanelItemRowState extends State<_PanelItemRow> {
  late ShoppingItemStatus _status;
  late double _actualAmount;
  late int? _storeId;
  late TextEditingController _priceCtrl;
  late TextEditingController _noteCtrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _actualAmount = widget.item.actualAmount ?? widget.item.amount;
    _storeId = widget.item.storeId;
    _priceCtrl = TextEditingController(
        text: widget.item.price != null
            ? widget.item.price!.toStringAsFixed(2)
            : '');
    _noteCtrl =
        TextEditingController(text: widget.item.note ?? '');
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _displayName {
    final item = widget.item.item;
    if (item == null) return '?';
    final locale =
        WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'he' &&
        item.nameHe != null &&
        item.nameHe!.isNotEmpty) {
      return item.nameHe!;
    }
    return item.name;
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

  void _cycleStatus() {
    setState(() {
      _status = switch (_status) {
        ShoppingItemStatus.pending => ShoppingItemStatus.got,
        ShoppingItemStatus.got => ShoppingItemStatus.partial,
        ShoppingItemStatus.partial => ShoppingItemStatus.notGot,
        ShoppingItemStatus.notGot => ShoppingItemStatus.pending,
      };
    });
    _commit();
  }

  void _commit() {
    widget.onPatch({
      'status': _status.wireValue,
      'actualAmount': _actualAmount,
      'price': _priceCtrl.text.isEmpty
          ? null
          : double.tryParse(_priceCtrl.text),
      'storeId': _storeId,
      'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEE4D8)),
      ),
      child: Column(
        children: [
          // Collapsed row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Status tap zone
                  GestureDetector(
                    onTap: _cycleStatus,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _status == ShoppingItemStatus.pending
                            ? const Color(0xFFF5F5F5)
                            : _statusColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _statusColor, width: 2),
                      ),
                      child: Icon(
                        _status == ShoppingItemStatus.got
                            ? Icons.check
                            : _status == ShoppingItemStatus.notGot
                                ? Icons.close
                                : _status == ShoppingItemStatus.partial
                                    ? Icons.remove
                                    : Icons.circle_outlined,
                        size: 18,
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
                                  style:
                                      const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                _displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                  decoration:
                                      _status == ShoppingItemStatus.got
                                          ? TextDecoration.lineThrough
                                          : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Planned: ${_fmtAmount(widget.item.amount)} ${widget.item.unit}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8D6E63)),
                        ),
                      ],
                    ),
                  ),
                  // Price badge
                  if (widget.item.price != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₪${widget.item.price!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF8D6E63),
                  ),
                ],
              ),
            ),
          ),
          // Expanded detail
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Status row
                  Row(
                    children: [
                      _StatusBtn(
                        label: '✓  Got',
                        active: _status == ShoppingItemStatus.got,
                        color: const Color(0xFF4CAF50),
                        onTap: () => setState(
                            () => _status = ShoppingItemStatus.got),
                      ),
                      const SizedBox(width: 6),
                      _StatusBtn(
                        label: '~  Partial',
                        active: _status == ShoppingItemStatus.partial,
                        color: const Color(0xFFFF9800),
                        onTap: () => setState(
                            () => _status = ShoppingItemStatus.partial),
                      ),
                      const SizedBox(width: 6),
                      _StatusBtn(
                        label: '✗  Skip',
                        active: _status == ShoppingItemStatus.notGot,
                        color: const Color(0xFFE53935),
                        onTap: () => setState(
                            () => _status = ShoppingItemStatus.notGot),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Actual amount stepper
                  Row(
                    children: [
                      const Text(
                        'Brought:',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8D6E63),
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      _AmountStepper(
                        value: _actualAmount,
                        unit: widget.item.unit,
                        plannedAmount: widget.item.amount,
                        onChanged: (v) =>
                            setState(() => _actualAmount = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price field
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: '₪ ',
                      prefixStyle: TextStyle(
                          color: Color(0xFF8D6E63), fontSize: 13),
                      hintText: '0.00  — how much did it cost?',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFFDDD5CB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFFDDD5CB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Note field
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Note (optional)',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFFDDD5CB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFFDDD5CB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _commit();
                        setState(() => _expanded = false);
                      },
                      child: const Text('Save',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmtAmount(double a) =>
      a % 1 == 0 ? a.toInt().toString() : a.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Amount stepper widget
// ─────────────────────────────────────────────────────────────────────────────

class _AmountStepper extends StatelessWidget {
  final double value;
  final String unit;
  final double plannedAmount;
  final void Function(double) onChanged;

  const _AmountStepper({
    required this.value,
    required this.unit,
    required this.plannedAmount,
    required this.onChanged,
  });

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  double get _step => unit == 'kg' || unit == 'L' ? 0.5 : 1.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(
          icon: Icons.remove,
          onTap: () {
            final next = (value - _step).clamp(0.0, double.infinity);
            onChanged(next);
          },
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_fmt(value)} $unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                ),
              ),
              if (value != plannedAmount)
                Text(
                  'planned: ${_fmt(plannedAmount)}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF8D6E63)),
                ),
            ],
          ),
        ),
        _Btn(
          icon: Icons.add,
          onTap: () => onChanged(value + _step),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDD5CB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF5D4037)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status button
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? color : color.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complete bar (fixed at bottom of active view)
// ─────────────────────────────────────────────────────────────────────────────

class _CompleteBar extends ConsumerStatefulWidget {
  final ShoppingSession session;
  final List<Category> expenseCategories;
  final bool completing;
  final void Function(bool) onCompleting;
  final BoardViewModel boardVm;

  const _CompleteBar({
    required this.session,
    required this.expenseCategories,
    required this.completing,
    required this.onCompleting,
    required this.boardVm,
  });

  @override
  ConsumerState<_CompleteBar> createState() => _CompleteBarState();
}

class _CompleteBarState extends ConsumerState<_CompleteBar> {
  @override
  Widget build(BuildContext context) {
    final total = widget.session.actualTotal;
    final isCompleted = widget.session.isCompleted;

    return Container(
      color: const Color(0xFFFFF8F0),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFF8D6E63))),
              Text(
                '₪${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5D4037),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (widget.completing || isCompleted)
                  ? null
                  : () => _openCompleteSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFFE53935),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: widget.completing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isCompleted
                      ? Icons.check_circle
                      : Icons.receipt_long),
              label: Text(
                isCompleted
                    ? 'Completed'
                    : 'Complete → Create Expense',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCompleteSheet(BuildContext context) async {
    final total = widget.session.actualTotal;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add prices to items before completing.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<_CompletePayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompleteExpenseSheet(
        initialAmount: total,
        initialCategoryId: widget.session.expenseCategoryId,
        sessionName: widget.session.name,
        expenseCategories: widget.expenseCategories,
      ),
    );

    if (result == null || !mounted) return;

    widget.onCompleting(true);
    final expense = await widget.boardVm.completeSessionAndCreateExpense(
      widget.session.id,
      {
        'actualAmount': result.amount,
        'dateTime': result.dateTime.toIso8601String(),
        'expenseCategoryId': result.categoryId,
        'paymentMethod': result.paymentMethod,
        'description': widget.session.name,
      },
    );
    if (!mounted) return;
    widget.onCompleting(false);

    if (expense != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Expense created: ₪${result.amount.toStringAsFixed(2)}'),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complete expense sheet (inline, reused here and in active_shopping_screen)
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
  State<_CompleteExpenseSheet> createState() =>
      _CompleteExpenseSheetState();
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
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
          const Text('Create Expense',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          Text(widget.sessionName,
              style: const TextStyle(
                  color: Color(0xFF8D6E63), fontSize: 13),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          const Text('Amount',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '₪ ',
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E0E0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E0E0))),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Category',
              style: TextStyle(
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
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E0E0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E0E0))),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
            items: widget.expenseCategories
                .expand((c) => [
                      DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.nameHe ?? c.name,
                              overflow: TextOverflow.ellipsis)),
                      ...c.subCategories.map((sub) =>
                          DropdownMenuItem<int?>(
                              value: sub.id,
                              child: Text('  ↳ ${sub.nameHe ?? sub.name}',
                                  overflow: TextOverflow.ellipsis))),
                    ])
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 14),
          const Text('Payment method',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _payBtn('card', '💳', 'Card'),
              const SizedBox(width: 6),
              _payBtn('cash', '💵', 'Cash'),
              const SizedBox(width: 6),
              _payBtn('bank_transfer', '🏦', 'Transfer'),
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
                    side:
                        const BorderSide(color: Color(0xFF8D6E63)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
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
                  child: const Text('Create Expense',
                      style:
                          TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payBtn(String key, String emoji, String label) {
    final active = _paymentMethod == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE53935)
                : const Color(0xFFF5F0EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        active ? Colors.white : const Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  )),
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
        const SnackBar(
            content: Text('Please fill in amount and category.')),
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
