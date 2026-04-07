import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/shopping_category.dart';
import 'package:household/models/shopping_item.dart';
import 'package:household/models/shopping_list.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_session_item.dart';
import 'package:household/models/shopping_store.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(ref.read(dioProvider)),
);

class ShoppingRepository {
  final Dio _dio;
  ShoppingRepository(this._dio);

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<List<ShoppingCategory>> getCategories(int householdId) async {
    final res = await _dio.get('/app/shopping/categories',
        queryParameters: {'householdId': householdId});
    return (res.data['categories'] as List)
        .map((e) => ShoppingCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingCategory> createCategory(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/shopping/categories', data: body);
    return ShoppingCategory.fromJson(res.data['category'] as Map<String, dynamic>);
  }

  Future<ShoppingCategory> updateCategory(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/shopping/categories/$id', data: body);
    return ShoppingCategory.fromJson(res.data['category'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) => _dio.delete('/app/shopping/categories/$id');

  // ── Stores ─────────────────────────────────────────────────────────────────

  Future<List<ShoppingStore>> getStores(int householdId) async {
    final res = await _dio.get('/app/shopping/stores',
        queryParameters: {'householdId': householdId});
    return (res.data['stores'] as List)
        .map((e) => ShoppingStore.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingStore> createStore(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/shopping/stores', data: body);
    return ShoppingStore.fromJson(res.data['store'] as Map<String, dynamic>);
  }

  Future<void> deleteStore(int id) => _dio.delete('/app/shopping/stores/$id');

  // ── Items ──────────────────────────────────────────────────────────────────

  Future<List<ShoppingItem>> getItems(int householdId) async {
    final res = await _dio.get('/app/shopping/items',
        queryParameters: {'householdId': householdId});
    return (res.data['items'] as List)
        .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingItem> createItem(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/shopping/items', data: body);
    return ShoppingItem.fromJson(res.data['item'] as Map<String, dynamic>);
  }

  Future<ShoppingItem> updateItem(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/shopping/items/$id', data: body);
    return ShoppingItem.fromJson(res.data['item'] as Map<String, dynamic>);
  }

  Future<void> deleteItem(int id) => _dio.delete('/app/shopping/items/$id');

  // ── Lists (templates) ──────────────────────────────────────────────────────

  Future<List<ShoppingList>> getLists(int householdId) async {
    final res = await _dio.get('/app/shopping/lists',
        queryParameters: {'householdId': householdId});
    return (res.data['lists'] as List)
        .map((e) => ShoppingList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingList> createList(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/shopping/lists', data: body);
    return ShoppingList.fromJson(res.data['list'] as Map<String, dynamic>);
  }

  Future<ShoppingList> getListWithItems(int id) async {
    final res = await _dio.get('/app/shopping/lists/$id/items');
    return ShoppingList.fromJson(res.data['list'] as Map<String, dynamic>);
  }

  Future<void> addListItem(int listId, Map<String, dynamic> body) async {
    await _dio.post('/app/shopping/lists/$listId/items', data: body);
  }

  Future<void> deleteListItem(int listId, int listItemId) async {
    await _dio.delete('/app/shopping/lists/$listId/items/$listItemId');
  }

  Future<void> deleteList(int id) => _dio.delete('/app/shopping/lists/$id');

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<List<ShoppingSession>> getSessions(int householdId) async {
    final res = await _dio.get('/app/shopping/sessions',
        queryParameters: {'householdId': householdId});
    return (res.data['sessions'] as List)
        .map((e) => ShoppingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingSession> createSession(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/shopping/sessions', data: body);
    return ShoppingSession.fromJson(res.data['session'] as Map<String, dynamic>);
  }

  Future<void> updateSession(int id, Map<String, dynamic> body) async {
    await _dio.put('/app/shopping/sessions/$id', data: body);
  }

  Future<void> deleteSession(int id) => _dio.delete('/app/shopping/sessions/$id');

  Future<ShoppingSessionItem> patchSessionItem(
      int sessionId, int sessionItemId, Map<String, dynamic> body) async {
    final res = await _dio.patch(
        '/app/shopping/sessions/$sessionId/items/$sessionItemId',
        data: body);
    return ShoppingSessionItem.fromJson(
        res.data['sessionItem'] as Map<String, dynamic>);
  }

  Future<ShoppingSessionItem> addSessionItem(
      int sessionId, Map<String, dynamic> body) async {
    final res =
        await _dio.post('/app/shopping/sessions/$sessionId/items', data: body);
    return ShoppingSessionItem.fromJson(
        res.data['sessionItem'] as Map<String, dynamic>);
  }
}
