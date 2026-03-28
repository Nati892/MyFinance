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

  Future<({List<Asset> assets, Map<String, double> groupTotals})> getAssets(
      int householdId) async {
    final res = await _dio.get('/app/assets',
        queryParameters: {'householdId': householdId});
    final assets = (res.data['assets'] as List)
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList();
    final rawTotals = res.data['groupTotals'] as Map<String, dynamic>? ?? {};
    final groupTotals = rawTotals
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    return (assets: assets, groupTotals: groupTotals);
  }

  Future<Asset> createAsset(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/assets', data: body);
    return Asset.fromJson(res.data['asset'] as Map<String, dynamic>);
  }

  Future<Asset> updateAsset(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/assets/$id', data: body);
    return Asset.fromJson(res.data['asset'] as Map<String, dynamic>);
  }

  Future<void> deleteAsset(int id) => _dio.delete('/app/assets/$id');

  Future<void> reorderAssets(List<Map<String, dynamic>> order) =>
      _dio.put('/app/assets/reorder', data: {'order': order});
}
