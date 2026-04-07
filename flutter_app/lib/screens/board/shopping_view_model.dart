import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/shopping_category.dart';
import 'package:household/models/shopping_item.dart';
import 'package:household/models/shopping_list.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_store.dart';
import 'package:household/repositories/shopping_repository.dart';
import 'package:household/services/household_service.dart';

final shoppingViewModelProvider =
    ChangeNotifierProvider.autoDispose<ShoppingViewModel>((ref) {
  return ShoppingViewModel(
    ref.read(shoppingRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

class ShoppingSelectedItem {
  final ShoppingItem item;
  double amount;
  String unit;
  ShoppingSelectedItem({required this.item, required this.amount, required this.unit});
}

class ShoppingViewModel extends ChangeNotifier {
  final ShoppingRepository _repo;
  final HouseholdService _householdService;

  ShoppingViewModel(this._repo, this._householdService) {
    loadAll();
  }

  // ── Loaded data ────────────────────────────────────────────────────────────

  List<ShoppingCategory> categories = [];
  List<ShoppingItem> items = [];
  List<ShoppingStore> stores = [];
  List<ShoppingList> lists = [];
  bool loading = false;

  // ── Form state ─────────────────────────────────────────────────────────────

  String formSessionName = '';
  String formSessionColor = '#fff9c4';
  int? formSourceListId; // null = new list
  String searchQuery = '';
  final List<ShoppingSelectedItem> _selectedItems = [];

  // New item creation sub-form
  bool showNewItemForm = false;
  String newItemName = '';
  String newItemNameHe = '';
  String newItemIcon = '';
  String newItemUnit = 'pcs';
  int? newItemCategoryId;

  // ── Saving state ───────────────────────────────────────────────────────────

  bool saving = false;
  String? saveError;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getCategories(hid),
        _repo.getItems(hid),
        _repo.getStores(hid),
        _repo.getLists(hid),
      ]);
      categories = results[0] as List<ShoppingCategory>;
      items = results[1] as List<ShoppingItem>;
      stores = results[2] as List<ShoppingStore>;
      lists = results[3] as List<ShoppingList>;
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  List<ShoppingItem> get filteredItems {
    if (searchQuery.isEmpty) return items;
    final q = searchQuery.toLowerCase();
    return items.where((i) {
      return i.name.toLowerCase().contains(q) ||
          (i.nameHe ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<ShoppingSelectedItem> get selectedItems => List.unmodifiable(_selectedItems);

  bool isSelected(int itemId) => _selectedItems.any((s) => s.item.id == itemId);

  void toggleItem(ShoppingItem item) {
    final idx = _selectedItems.indexWhere((s) => s.item.id == item.id);
    if (idx >= 0) {
      _selectedItems.removeAt(idx);
    } else {
      _selectedItems.add(ShoppingSelectedItem(
        item: item,
        amount: 1,
        unit: item.defaultUnit,
      ));
    }
    notifyListeners();
  }

  void setItemAmount(int itemId, double amount) {
    final idx = _selectedItems.indexWhere((s) => s.item.id == itemId);
    if (idx >= 0) {
      _selectedItems[idx].amount = amount;
      notifyListeners();
    }
  }

  void setItemUnit(int itemId, String unit) {
    final idx = _selectedItems.indexWhere((s) => s.item.id == itemId);
    if (idx >= 0) {
      _selectedItems[idx].unit = unit;
      notifyListeners();
    }
  }

  void setFormSessionName(String v) {
    formSessionName = v;
    notifyListeners();
  }

  void setFormSessionColor(String v) {
    formSessionColor = v;
    notifyListeners();
  }

  void setSourceList(int? listId) {
    formSourceListId = listId;
    // If a template is chosen, pre-populate selected items from it
    if (listId != null) {
      final list = lists.firstWhere((l) => l.id == listId, orElse: () => ShoppingList(id: -1, name: '', householdId: 0, createdBy: 0));
      if (list.id != -1) {
        _selectedItems.clear();
        for (final li in list.listItems) {
          if (li.item != null) {
            _selectedItems.add(ShoppingSelectedItem(
              item: li.item!,
              amount: li.amount,
              unit: li.unit,
            ));
          }
        }
      }
    }
    notifyListeners();
  }

  void setSearchQuery(String v) {
    searchQuery = v;
    notifyListeners();
  }

  void resetForm() {
    formSessionName = '';
    formSessionColor = '#fff9c4';
    formSourceListId = null;
    searchQuery = '';
    _selectedItems.clear();
    showNewItemForm = false;
    newItemName = '';
    newItemNameHe = '';
    newItemIcon = '';
    newItemUnit = 'pcs';
    newItemCategoryId = null;
    saving = false;
    saveError = null;
    notifyListeners();
  }

  // ── New item sub-form ──────────────────────────────────────────────────────

  void openNewItemForm() {
    showNewItemForm = true;
    newItemName = '';
    newItemNameHe = '';
    newItemIcon = '';
    newItemUnit = 'pcs';
    newItemCategoryId = null;
    notifyListeners();
  }

  void closeNewItemForm() {
    showNewItemForm = false;
    notifyListeners();
  }

  void setNewItemName(String v) { newItemName = v; notifyListeners(); }
  void setNewItemNameHe(String v) { newItemNameHe = v; notifyListeners(); }
  void setNewItemIcon(String v) { newItemIcon = v; notifyListeners(); }
  void setNewItemUnit(String v) { newItemUnit = v; notifyListeners(); }
  void setNewItemCategory(int? v) { newItemCategoryId = v; notifyListeners(); }

  Future<ShoppingItem?> saveNewItem() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null || newItemName.trim().isEmpty) return null;
    try {
      final item = await _repo.createItem({
        'name': newItemName.trim(),
        'nameHe': newItemNameHe.trim().isEmpty ? null : newItemNameHe.trim(),
        'icon': newItemIcon.isEmpty ? null : newItemIcon,
        'defaultUnit': newItemUnit,
        'categoryId': newItemCategoryId,
        'householdId': hid,
      });
      items = [...items, item];
      // Auto-select the new item
      _selectedItems.add(ShoppingSelectedItem(item: item, amount: 1, unit: item.defaultUnit));
      showNewItemForm = false;
      notifyListeners();
      return item;
    } catch (_) {
      return null;
    }
  }

  // ── Create store on the fly ────────────────────────────────────────────────

  Future<ShoppingStore?> createStore(String name) async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null || name.trim().isEmpty) return null;
    try {
      final store = await _repo.createStore({'name': name.trim(), 'householdId': hid});
      stores = [...stores, store];
      notifyListeners();
      return store;
    } catch (_) {
      return null;
    }
  }

  // ── Create category on the fly ────────────────────────────────────────────

  Future<ShoppingCategory?> createCategory(String name, String? nameHe) async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null || name.trim().isEmpty) return null;
    try {
      final cat = await _repo.createCategory({
        'name': name.trim(),
        'nameHe': nameHe?.trim().isEmpty == true ? null : nameHe?.trim(),
        'householdId': hid,
      });
      categories = [...categories, cat];
      notifyListeners();
      return cat;
    } catch (_) {
      return null;
    }
  }

  // ── Save session ──────────────────────────────────────────────────────────

  Future<ShoppingSession?> saveSession() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return null;

    if (formSessionName.trim().isEmpty) {
      saveError = 'Please enter a list name.';
      notifyListeners();
      return null;
    }
    if (_selectedItems.isEmpty) {
      saveError = 'Please add at least one item.';
      notifyListeners();
      return null;
    }

    saving = true;
    saveError = null;
    notifyListeners();

    try {
      final session = await _repo.createSession({
        'name': formSessionName.trim(),
        'listId': formSourceListId,
        'noteColor': formSessionColor,
        'householdId': hid,
        'items': _selectedItems.map((s) => {
          'itemId': s.item.id,
          'amount': s.amount,
          'unit': s.unit,
        }).toList(),
      });
      saving = false;
      notifyListeners();
      return session;
    } catch (_) {
      saving = false;
      saveError = 'Failed to save. Please try again.';
      notifyListeners();
      return null;
    }
  }
}
