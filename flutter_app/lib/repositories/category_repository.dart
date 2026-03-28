import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.read(dioProvider)),
);

class CategoryRepository {
  final Dio _dio;
  CategoryRepository(this._dio);

  Future<List<Category>> getExpenseCategories(int householdId) async {
    final res = await _dio.get('/app/expense-categories',
        queryParameters: {'householdId': householdId});
    return (res.data['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Category>> getIncomeCategories(int householdId) async {
    final res = await _dio.get('/app/income-categories',
        queryParameters: {'householdId': householdId});
    return (res.data['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Category>> getExpenseFavorites(int householdId) async {
    final res = await _dio.get('/app/expense-categories/favorites',
        queryParameters: {'householdId': householdId});
    return (res.data['favorites'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createExpenseCategory(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/expense-categories', data: body);
    return Category.fromJson(res.data['category'] as Map<String, dynamic>);
  }

  Future<Category> createIncomeCategory(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/income-categories', data: body);
    return Category.fromJson(res.data['category'] as Map<String, dynamic>);
  }
}
