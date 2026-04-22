import 'package:flutter/material.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_session_item.dart';
import 'package:household/models/shopping_store.dart';
import 'package:household/utils/color_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────

class CanvasShoppingSessionWidget extends StatefulWidget {
  final ShoppingSession session;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(double scale, double baseW, double baseH) onScaleUpdate;
  final VoidCallback onScaleEnd;
  final void Function(double rotation) onRotateUpdate;
  final VoidCallback onRotateEnd;
  final VoidCallback onDelete;
  final VoidCallback onPlay;
  final void Function(int sessionItemId, Map<String, dynamic> patch) onPatchItem;
  final List<ShoppingStore> stores;
  final Future<ShoppingStore?> Function(String name) onCreateStore;

  const CanvasShoppingSessionWidget({
    required super.key,
    required this.session,
    required this.isSelected,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onRotateUpdate,
    required this.onRotateEnd,
    required this.onDelete,
    required this.onPlay,
    required this.onPatchItem,
    required this.stores,
    required this.onCreateStore,
  });

  @override
  State<CanvasShoppingSessionWidget> createState() =>
      _CanvasShoppingSessionWidgetState();
}

class _CanvasShoppingSessionWidgetState
    extends State<CanvasShoppingSessionWidget> {
  double _baseWidth = 0;
  double _baseHeight = 0;
  double _rotation = 0;
  int? _expandedItemId;

  @override
  void initState() {
    super.initState();
    _rotation = widget.session.rotation;
  }

  @override
  void didUpdateWidget(CanvasShoppingSessionWidget old) {
    super.didUpdateWidget(old);
    if (old.session.rotation != widget.session.rotation) {
      _rotation = widget.session.rotation;
    }
  }

  Color get _headerColor => darken(hexColor(widget.session.noteColor), 0.1);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final w = session.width.toDouble();
    final h = session.height.toDouble();
    final bgColor = hexColor(session.noteColor);

    return Transform.rotate(
      angle: _rotation,
      child: Opacity(
        opacity: session.isCompleted ? 0.7 : 1.0,
        child: GestureDetector(
          onTap: widget.onTap,
          onScaleStart: (d) {
            _baseWidth = w;
            _baseHeight = h;
          },
          onScaleUpdate: (d) {
            if (d.pointerCount == 1) {
              widget.onDragUpdate(d.focalPointDelta);
            } else {
              widget.onScaleUpdate(d.scale, _baseWidth, _baseHeight);
              if (d.rotation != 0) {
                setState(() => _rotation += d.rotation);
                widget.onRotateUpdate(_rotation);
              }
            }
          },
          onScaleEnd: (_) {
            widget.onDragEnd();
            widget.onScaleEnd();
            widget.onRotateEnd();
          },
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? const Color(0x66667EEA)
                      : const Color(0x26000000),
                  blurRadius: widget.isSelected ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: widget.isSelected
                  ? Border.all(color: const Color(0xFF667EEA), width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(session),
                  Expanded(child: _buildBody(session)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ShoppingSession session) {
    final total = session.actualTotal;
    final done = session.completedItemCount;
    final count = session.sessionItems.length;

    return Container(
      color: _headerColor,
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                session.isCompleted
                    ? Icons.check_circle
                    : (session.isPlanned
                        ? Icons.event_note
                        : Icons.shopping_cart),
                size: 12,
                color: const Color(0xFF5D4037),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5D4037),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!session.isCompleted)
                _HeaderBtn(
                  icon: Icons.play_arrow_rounded,
                  tooltip: session.isPlanned ? 'Start shopping' : 'Open shopping',
                  onTap: widget.onPlay,
                ),
              _HeaderBtn(
                icon: Icons.close,
                tooltip: 'Delete',
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
          if (session.isPlanned)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _plannedLabel(session),
                style: const TextStyle(fontSize: 10, color: Color(0xFF5D4037)),
              ),
            )
          else if (!session.isCompleted && count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '₪${total.toStringAsFixed(2)} · $done/$count',
                style: const TextStyle(fontSize: 10, color: Color(0xFF5D4037)),
              ),
            )
          else if (session.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '₪${total.toStringAsFixed(2)} · completed',
                style: const TextStyle(fontSize: 10, color: Color(0xFF5D4037)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ShoppingSession session) {
    if (session.isPlanned) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_note, size: 28, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 8),
              Text(
                _plannedRangeLabel(session),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (session.sessionItems.isNotEmpty)
                Text(
                  '${session.sessionItems.length} items pre-picked',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                )
              else
                const Text(
                  'Tap ▶ to start shopping',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: session.sessionItems.length,
      itemBuilder: (ctx, i) {
        final item = session.sessionItems[i];
        return _ShoppingSessionItemRow(
          key: ValueKey(item.id),
          item: item,
          isExpanded: _expandedItemId == item.id,
          onToggleExpand: () {
            setState(() {
              _expandedItemId = _expandedItemId == item.id ? null : item.id;
            });
          },
          stores: widget.stores,
          onPatch: (patch) => widget.onPatchItem(item.id, patch),
          onCreateStore: widget.onCreateStore,
        );
      },
    );
  }

  String _plannedLabel(ShoppingSession s) {
    final month = s.plannedMonth != null ? _monthName(s.plannedMonth!) : '—';
    final year = s.plannedYear ?? '';
    final week = s.plannedWeekOfMonth != null ? ', W${s.plannedWeekOfMonth}' : '';
    return 'Planned · $month $year$week';
  }

  String _plannedRangeLabel(ShoppingSession s) {
    if (s.plannedMinPrice == null && s.plannedMaxPrice == null) return '—';
    final min = s.plannedMinPrice?.toStringAsFixed(0) ?? '0';
    final max = s.plannedMaxPrice?.toStringAsFixed(0) ?? '0';
    return '~₪$min–$max';
  }

  String _monthName(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (m < 1 || m > 12) return '—';
    return names[m - 1];
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete this list?'),
        content: Text('This will remove "${widget.session.name}" from the board.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dctx).pop();
              widget.onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(icon, size: 16, color: const Color(0xFF5D4037)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ShoppingSessionItemRow extends StatefulWidget {
  final ShoppingSessionItem item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final List<ShoppingStore> stores;
  final void Function(Map<String, dynamic> patch) onPatch;
  final Future<ShoppingStore?> Function(String name) onCreateStore;

  const _ShoppingSessionItemRow({
    required super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.stores,
    required this.onPatch,
    required this.onCreateStore,
  });

  @override
  State<_ShoppingSessionItemRow> createState() =>
      _ShoppingSessionItemRowState();
}

class _ShoppingSessionItemRowState extends State<_ShoppingSessionItemRow> {
  late ShoppingItemStatus _status;
  late int? _storeId;
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _storeId = widget.item.storeId;
    _priceCtrl.text = widget.item.price?.toString() ?? '';
    _noteCtrl.text = widget.item.note ?? '';
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
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

  String get _displayName {
    final item = widget.item.item;
    if (item == null) return '?';
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale.languageCode == 'he' && item.nameHe != null && item.nameHe!.isNotEmpty) {
      return item.nameHe!;
    }
    return item.name;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.onToggleExpand,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                if (widget.item.item?.icon != null) ...[
                  Text(widget.item.item!.icon!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    _displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF333333),
                      decoration: _status == ShoppingItemStatus.got
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${widget.item.amount % 1 == 0 ? widget.item.amount.toInt() : widget.item.amount} ${widget.item.unit}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: const Color(0xFF888888),
                ),
              ],
            ),
          ),
        ),
        if (widget.isExpanded)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _StatusBtn(
                      label: '✓',
                      active: _status == ShoppingItemStatus.got,
                      color: const Color(0xFF4CAF50),
                      onTap: () => _setStatus(ShoppingItemStatus.got),
                    ),
                    const SizedBox(width: 4),
                    _StatusBtn(
                      label: '~',
                      active: _status == ShoppingItemStatus.partial,
                      color: const Color(0xFFFF9800),
                      onTap: () => _setStatus(ShoppingItemStatus.partial),
                    ),
                    const SizedBox(width: 4),
                    _StatusBtn(
                      label: '✗',
                      active: _status == ShoppingItemStatus.notGot,
                      color: const Color(0xFFE53935),
                      onTap: () => _setStatus(ShoppingItemStatus.notGot),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    hintText: 'Price (₪)',
                    hintStyle: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _StorePicker(
                  stores: widget.stores,
                  selectedId: _storeId,
                  onSelected: (id) => setState(() => _storeId = id),
                  onCreateStore: widget.onCreateStore,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    hintText: 'Note',
                    hintStyle: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 26,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _confirm,
                    child: const Text('OK', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _setStatus(ShoppingItemStatus status) {
    setState(() => _status = status);
  }

  void _confirm() {
    widget.onPatch({
      'status': _status.wireValue,
      'price': _priceCtrl.text.isEmpty ? null : double.tryParse(_priceCtrl.text),
      'storeId': _storeId,
      'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    });
    widget.onToggleExpand();
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 28,
        height: 22,
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.white : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StorePicker extends StatefulWidget {
  final List<ShoppingStore> stores;
  final int? selectedId;
  final void Function(int? id) onSelected;
  final Future<ShoppingStore?> Function(String name) onCreateStore;

  const _StorePicker({
    required this.stores,
    required this.selectedId,
    required this.onSelected,
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
    if (_adding) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                hintText: 'Store name',
                hintStyle: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: Color(0xFFDDD5CB)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              final store = await widget.onCreateStore(_ctrl.text);
              if (store != null) {
                widget.onSelected(store.id);
              }
              setState(() => _adding = false);
            },
            child: const Icon(Icons.check, size: 16, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => setState(() => _adding = false),
            child: const Icon(Icons.close, size: 16, color: Color(0xFFE53935)),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: widget.selectedId,
              hint: const Text('Store', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
              isDense: true,
              style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No store', style: TextStyle(fontSize: 11)),
                ),
                ...widget.stores.map((s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name, style: const TextStyle(fontSize: 11)),
                    )),
              ],
              onChanged: widget.onSelected,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() { _adding = true; _ctrl.clear(); }),
          child: const Icon(Icons.add, size: 14, color: Color(0xFF888888)),
        ),
      ],
    );
  }
}
