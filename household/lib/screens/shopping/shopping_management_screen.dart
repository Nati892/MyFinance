import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/shopping_category.dart';
import 'package:household/models/shopping_item.dart';
import 'package:household/models/shopping_list.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/screens/board/board_view_model.dart';
import 'package:household/screens/shopping/shopping_management_viewmodel.dart';
import 'package:household/screens/shopping/shopping_session_panel.dart';
import 'package:household/utils/color_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shopping management screen — 3 tabs: Live | Templates | Products
// Pushed via root navigator (fullscreenDialog). Caller must wrap with
// UncontrolledProviderScope sharing the existing provider container.
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingManagementScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const ShoppingManagementScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ShoppingManagementScreen> createState() =>
      _ShoppingManagementScreenState();
}

class _ShoppingManagementScreenState
    extends ConsumerState<ShoppingManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(shoppingManagementViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Live'),
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Templates'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Products'),
          ],
        ),
      ),
      floatingActionButton: _tabCtrl.index == 1
          ? FloatingActionButton(
              onPressed: () => _createTemplate(context, vm),
              child: const Icon(Icons.add),
            )
          : _tabCtrl.index == 2
              ? FloatingActionButton(
                  onPressed: () => _showProductSheet(context, vm, null),
                  child: const Icon(Icons.add),
                )
              : null,
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(child: Text('Error: ${vm.error}'))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _LiveTab(vm: vm),
                    _TemplatesTab(
                      vm: vm,
                      onCreate: () => _createTemplate(context, vm),
                    ),
                    _ProductsTab(
                      vm: vm,
                      onCreate: () => _showProductSheet(context, vm, null),
                    ),
                  ],
                ),
    );
  }

  Future<void> _createTemplate(
      BuildContext context, ShoppingManagementViewModel vm) async {
    final nameCtrl = TextEditingController();
    final nameHeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name (English)',
                hintText: 'e.g. Weekly Groceries',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameHeCtrl,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'Name (Hebrew, optional)',
                hintText: 'שם בעברית',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final nameHe = nameHeCtrl.text.trim();
    nameCtrl.dispose();
    nameHeCtrl.dispose();
    if (ok == true && name.isNotEmpty) {
      await vm.createList(name, nameHe: nameHe.isEmpty ? null : nameHe);
    }
  }

  void _showProductSheet(
    BuildContext context,
    ShoppingManagementViewModel vm,
    ShoppingItem? item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductEditSheet(item: item, vm: vm),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live tab — active sessions
// ─────────────────────────────────────────────────────────────────────────────

class _LiveTab extends ConsumerWidget {
  final ShoppingManagementViewModel vm;

  const _LiveTab({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardVm = ref.watch(boardViewModelProvider);
    final live = boardVm.sessions.where((s) => !s.isCompleted).toList();

    if (live.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛒', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'No active shopping sessions.',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
            SizedBox(height: 4),
            Text(
              'Add one from the board.',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: live.length,
      itemBuilder: (ctx, i) => _SessionCard(session: live[i], vm: vm),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ShoppingSession session;
  final ShoppingManagementViewModel vm;

  const _SessionCard({required this.session, required this.vm});

  @override
  Widget build(BuildContext context) {
    final count = session.sessionItems.length;
    final done = session.completedItemCount;
    final total = session.actualTotal;
    final bg = hexColor(session.noteColor);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          child: const Icon(Icons.shopping_cart,
              color: Color(0xFF5D4037), size: 18),
        ),
        title: Text(session.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(count == 0
            ? 'Not started'
            : '$done/$count done · ₪${total.toStringAsFixed(2)}'),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF8D6E63)),
        onTap: () => _openPanel(context, session),
      ),
    );
  }

  void _openPanel(BuildContext context, ShoppingSession session) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        // onManage is null — "Manage" button hidden (already on management screen)
        child: ShoppingSessionPanel(sessionId: session.id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Templates tab
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatesTab extends StatelessWidget {
  final ShoppingManagementViewModel vm;
  final VoidCallback onCreate;

  const _TemplatesTab({required this.vm, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    if (vm.lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'No templates yet.',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: vm.lists.length,
      itemBuilder: (ctx, i) {
        final list = vm.lists[i];
        return ListTile(
          leading: const Icon(Icons.list_alt, color: Color(0xFF8D6E63)),
          title: Text(list.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            list.listItems.isEmpty
                ? 'No items'
                : '${list.listItems.length} item${list.listItems.length == 1 ? '' : 's'}',
          ),
          trailing:
              const Icon(Icons.chevron_right, color: Color(0xFF8D6E63)),
          onTap: () => _openDetail(ctx, list),
          onLongPress: () => _confirmDelete(ctx, list),
        );
      },
    );
  }

  void _openDetail(BuildContext context, ShoppingList list) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _TemplateDetailPage(list: list, vm: vm),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, ShoppingList list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete "${list.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (ok == true) await vm.deleteList(list.id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template detail page
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateDetailPage extends StatefulWidget {
  final ShoppingList list;
  final ShoppingManagementViewModel vm;

  const _TemplateDetailPage({required this.list, required this.vm});

  @override
  State<_TemplateDetailPage> createState() => _TemplateDetailPageState();
}

class _TemplateDetailPageState extends State<_TemplateDetailPage> {
  late ShoppingList _list;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
    if (_list.listItems.isEmpty) _loadFull();
  }

  Future<void> _loadFull() async {
    setState(() => _loading = true);
    final full = await widget.vm.getListFull(_list.id);
    if (mounted) {
      setState(() {
        _loading = false;
        if (full != null) _list = full;
      });
    }
  }

  Future<void> _addItem(int itemId, double amount, String unit) async {
    final ok = await widget.vm.addItemToList(_list.id, itemId, amount, unit);
    if (ok && mounted) {
      final refreshed = widget.vm.lists
          .where((l) => l.id == _list.id)
          .firstOrNull;
      if (refreshed != null) setState(() => _list = refreshed);
    }
  }

  Future<void> _removeItem(int listItemId) async {
    final ok = await widget.vm.removeItemFromList(_list.id, listItemId);
    if (ok && mounted) {
      final refreshed = widget.vm.lists
          .where((l) => l.id == _list.id)
          .firstOrNull;
      if (refreshed != null) setState(() => _list = refreshed);
    }
  }

  Future<void> _showProductPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        items: widget.vm.items,
        categories: widget.vm.categories,
        existingItemIds:
            _list.listItems.map((li) => li.itemId).toSet(),
      ),
    );
    if (result == null || !mounted) return;
    await _addItem(
      result['itemId'] as int,
      result['amount'] as double,
      result['unit'] as String,
    );
  }

  String _fmt(double a) =>
      a % 1 == 0 ? a.toInt().toString() : a.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_list.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductPicker(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.listItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📦', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text(
                        'No items yet. Tap + to add.',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF666666)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _list.listItems.length,
                  itemBuilder: (ctx, i) {
                    final li = _list.listItems[i];
                    final icon = li.item?.icon;
                    final name = li.item?.name ?? '?';
                    return ListTile(
                      leading: icon != null
                          ? Text(icon,
                              style: const TextStyle(fontSize: 24))
                          : const Icon(Icons.shopping_basket,
                              color: Color(0xFF8D6E63)),
                      title: Text(name),
                      subtitle:
                          Text('${_fmt(li.amount)} ${li.unit}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Color(0xFFE53935)),
                        onPressed: () => _removeItem(li.id),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product picker sheet (shown from template detail to pick a product)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final List<ShoppingItem> items;
  final List<ShoppingCategory> categories;
  final Set<int> existingItemIds;

  const _ProductPickerSheet({
    required this.items,
    required this.categories,
    required this.existingItemIds,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';
  ShoppingItem? _picked;
  double _amount = 1.0;
  String _unit = 'pcs';

  static const _units = ['pcs', 'kg', 'g', 'L', 'ml', 'lbs', 'pack', 'box'];

  @override
  Widget build(BuildContext context) {
    if (_picked == null) return _buildPickerList(context);
    return _buildAmountPicker(context);
  }

  Widget _buildPickerList(BuildContext context) {
    final filtered = widget.items.where((item) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          (item.nameHe ?? '').toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          _handle(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Pick a Product',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(10))),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No products found.',
                        style: TextStyle(color: Color(0xFF999999))))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final already =
                          widget.existingItemIds.contains(item.id);
                      return ListTile(
                        leading: item.icon != null
                            ? Text(item.icon!,
                                style:
                                    const TextStyle(fontSize: 22))
                            : const Icon(Icons.shopping_basket,
                                color: Color(0xFF8D6E63)),
                        title: Text(item.name),
                        subtitle: already
                            ? const Text('Already in list',
                                style: TextStyle(
                                    color: Color(0xFF8D6E63),
                                    fontSize: 12))
                            : (item.nameHe != null
                                ? Text(item.nameHe!,
                                    style: const TextStyle(
                                        fontSize: 12))
                                : null),
                        enabled: !already,
                        onTap: already
                            ? null
                            : () => setState(() {
                                  _picked = item;
                                  _unit = item.defaultUnit;
                                  _amount = 1.0;
                                }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPicker(BuildContext context) {
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
          _handle(),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _picked = null),
              ),
              Expanded(
                child: Text(
                  _picked!.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Amount:',
                  style: TextStyle(
                      color: Color(0xFF8D6E63),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _stepBtn(Icons.remove, () {
                final next = (_amount - 1).clamp(0.5, double.infinity);
                setState(() => _amount = next);
              }),
              const SizedBox(width: 10),
              Text(
                _amount % 1 == 0
                    ? _amount.toInt().toString()
                    : _amount.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              _stepBtn(Icons.add, () => setState(() => _amount += 1)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Unit:',
                  style: TextStyle(
                      color: Color(0xFF8D6E63),
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _unit,
                isDense: true,
                items: _units
                    .map((u) =>
                        DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop({
                'itemId': _picked!.id,
                'amount': _amount,
                'unit': _unit,
              }),
              child: const Text('Add to Template',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
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

// ─────────────────────────────────────────────────────────────────────────────
// Products tab
// ─────────────────────────────────────────────────────────────────────────────

class _ProductsTab extends StatefulWidget {
  final ShoppingManagementViewModel vm;
  final VoidCallback onCreate;

  const _ProductsTab({required this.vm, required this.onCreate});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = widget.vm.items;
    final filtered = _query.isEmpty
        ? all
        : all.where((item) {
            final q = _query.toLowerCase();
            return item.name.toLowerCase().contains(q) ||
                (item.nameHe ?? '').toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: all.isEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📦',
                                style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            const Text(
                              'No products yet.',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: widget.onCreate,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text('No results.',
                          style: TextStyle(color: Color(0xFF999999))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    return ListTile(
                      leading: item.icon != null
                          ? SizedBox(
                              width: 36,
                              child: Text(item.icon!,
                                  style:
                                      const TextStyle(fontSize: 24),
                                  textAlign: TextAlign.center),
                            )
                          : const CircleAvatar(
                              backgroundColor: Color(0xFFF5F0EC),
                              child: Icon(Icons.shopping_basket,
                                  color: Color(0xFF8D6E63), size: 18),
                            ),
                      title: Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: item.nameHe != null
                          ? Text(item.nameHe!,
                              textDirection: TextDirection.rtl)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.defaultUnit,
                              style: const TextStyle(
                                  color: Color(0xFF8D6E63),
                                  fontSize: 12)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: Color(0xFF8D6E63)),
                            onPressed: () =>
                                _showEditSheet(context, item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context, ShoppingItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductEditSheet(item: item, vm: widget.vm),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product edit/create sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ProductEditSheet extends StatefulWidget {
  final ShoppingItem? item; // null = create
  final ShoppingManagementViewModel vm;

  const _ProductEditSheet({this.item, required this.vm});

  @override
  State<_ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<_ProductEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nameHeCtrl;
  late TextEditingController _iconCtrl;
  late String _unit;
  late int? _categoryId;
  bool _saving = false;

  static const _units = ['pcs', 'kg', 'g', 'L', 'ml', 'lbs', 'pack', 'box'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _nameHeCtrl = TextEditingController(text: item?.nameHe ?? '');
    _iconCtrl = TextEditingController(text: item?.icon ?? '');
    _unit = item?.defaultUnit ?? 'pcs';
    _categoryId = item?.categoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameHeCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.item != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
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
            const SizedBox(height: 14),
            Text(
              isEdit ? 'Edit Product' : 'New Product',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            const Text('Icon (emoji)',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _iconCtrl,
              style: const TextStyle(fontSize: 22),
              maxLength: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. 🍎',
                counterText: '',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Name (English) *',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Apples',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Name (Hebrew, optional)',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameHeCtrl,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'שם בעברית',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Unit',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _unit,
                        isDense: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(10))),
                        ),
                        items: _units
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _unit = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        initialValue: _categoryId,
                        isDense: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(10))),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('None',
                                  overflow: TextOverflow.ellipsis)),
                          ...widget.vm.categories.map((c) =>
                              DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(c.nameHe ?? c.name,
                                      overflow:
                                          TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) =>
                            setState(() => _categoryId = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isEdit) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFE53935)),
                  label: const Text('Delete product',
                      style: TextStyle(color: Color(0xFFE53935))),
                  onPressed: _delete,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEdit ? 'Save Changes' : 'Create Product',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a product name.')),
      );
      return;
    }
    setState(() => _saving = true);
    if (widget.item != null) {
      await widget.vm.updateItem(widget.item!.id, {
        'name': name,
        'nameHe': _nameHeCtrl.text.trim().isEmpty
            ? null
            : _nameHeCtrl.text.trim(),
        'icon': _iconCtrl.text.trim().isEmpty
            ? null
            : _iconCtrl.text.trim(),
        'defaultUnit': _unit,
        'categoryId': _categoryId,
      });
    } else {
      await widget.vm.createItem(
        name: name,
        nameHe: _nameHeCtrl.text.trim().isEmpty
            ? null
            : _nameHeCtrl.text.trim(),
        icon: _iconCtrl.text.trim().isEmpty
            ? null
            : _iconCtrl.text.trim(),
        unit: _unit,
        categoryId: _categoryId,
      );
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final name = _nameCtrl.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
            'Delete "${name.isEmpty ? 'this product' : name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.vm.deleteItem(widget.item!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
