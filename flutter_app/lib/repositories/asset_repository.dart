import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/asset.dart';

final assetRepositoryProvider = Provider<AssetRepository>(
  (ref) => AssetRepository(ref.read(dioProvider)),
);

class AssetRepository {
  final Dio _dio;
  AssetRepository(this._dio);

  Future<List<Asset>> getAssets(int householdId) async {
    final res = await _dio.get('/app/assets',
        queryParameters: {'householdId': householdId});
    return (res.data['assets'] as List)
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAsset(Map<String, dynamic> body) =>
      _dio.post('/app/assets', data: body);

  Future<void> updateAsset(int id, Map<String, dynamic> body) =>
      _dio.put('/app/assets/$id', data: body);

  Future<void> deleteAsset(int id) =>
      _dio.delete('/app/assets/$id');

  Future<void> reorderAssets(List<Map<String, dynamic>> order) =>
      _dio.put('/app/assets/reorder', data: {'order': order});
}
