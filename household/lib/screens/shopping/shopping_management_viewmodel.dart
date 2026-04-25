import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/shopping_category.dart';
import 'package:household/models/shopping_item.dart';
import 'package:household/models/shopping_list.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_store.dart';
import 'package:household/repositories/shopping_repository.dart';
import 'package:household/services/household_service.dart';

final shoppingManagementViewModelProvider =
    ChangeNotifierProvider.autoDispose<ShoppingManagementViewModel>((ref) {
  return ShoppingManagementViewModel(
    ref.read(shoppingRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

class ShoppingManagementViewModel extends ChangeNotifier {
  final ShoppingRepository _repo;
  final HouseholdService _householdService;

  ShoppingManagementViewModel(this._repo, this._householdService) {
    loadAll();
  }

  bool loading = false;
  String? error;

  List<ShoppingList> lists = [];
  List<ShoppingItem> items = [];
  List<ShoppingCategory> categories = [];
  List<ShoppingSession> liveSessions = [];
  List<ShoppingStore> stores = [];

  int get _hid => _householdService.currentHouseholdId ?? 0;

  Future<void> loadAll() async {
    if (_hid == 0) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getLists(_hid),
        _repo.getItems(_hid),
        _repo.getCategories(_hid),
        _repo.getSessions(_hid),
        _repo.getStores(_hid),
      ]);
      lists = results[0] as List<ShoppingList>;
      items = results[1] as List<ShoppingItem>;
      categories = results[2] as List<ShoppingCategory>;
      liveSessions = (results[3] as List<ShoppingSession>)
          .where((s) => !s.isCompleted)
          .toList();
      stores = results[4] as List<ShoppingStore>;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  // ── Templates (Lists) ────────────────────────────────────────────────────

  Future<ShoppingList?> createList(String name, {String? nameHe}) async {
    try {
      final l = await _repo.createList({
        'name': name.trim(),
        'nameHe': (nameHe?.trim().isEmpty ?? true) ? null : nameHe!.trim(),
        'householdId': _hid,
      });
      lists = [l, ...lists];
      notifyListeners();
      return l;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteList(int id) async {
    try {
      await _repo.deleteList(id);
      lists = lists.where((l) => l.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<ShoppingList?> getListFull(int id) async {
    try {
      return await _repo.getListWithItems(id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> addItemToList(
      int listId, int itemId, double amount, String unit) async {
    try {
      await _repo.addListItem(listId, {
        'itemId': itemId,
        'amount': amount,
        'unit': unit,
      });
      final refreshed = await _repo.getListWithItems(listId);
      lists = lists.map((l) => l.id == listId ? refreshed : l).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeItemFromList(int listId, int listItemId) async {
    try {
      await _repo.deleteListItem(listId, listItemId);
      final refreshed = await _repo.getListWithItems(listId);
      lists = lists.map((l) => l.id == listId ? refreshed : l).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Products (Items) ─────────────────────────────────────────────────────

  Future<ShoppingItem?> createItem({
    required String name,
    String? nameHe,
    String? icon,
    String unit = 'pcs',
    int? categoryId,
  }) async {
    try {
      final item = await _repo.createItem({
        'name': name.trim(),
        'nameHe': (nameHe?.trim().isEmpty ?? true) ? null : nameHe!.trim(),
        'icon': (icon?.trim().isEmpty ?? true) ? null : icon!.trim(),
        'defaultUnit': unit,
        'categoryId': categoryId,
        'householdId': _hid,
      });
      items = [item, ...items];
      notifyListeners();
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<ShoppingItem?> updateItem(int id, Map<String, dynamic> patch) async {
    try {
      final item = await _repo.updateItem(id, patch);
      items = items.map((i) => i.id == id ? item : i).toList();
      notifyListeners();
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _repo.deleteItem(id);
      items = items.where((i) => i.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  // ── Stores ────────────────────────────────────────────────────────────────

  Future<ShoppingStore?> createStore(String name) async {
    try {
      final s = await _repo.createStore({'name': name.trim(), 'householdId': _hid});
      stores = [s, ...stores];
      notifyListeners();
      return s;
    } catch (_) {
      return null;
    }
  }
}
