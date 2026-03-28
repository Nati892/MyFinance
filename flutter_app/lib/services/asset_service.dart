import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/asset.dart';
import 'package:household/repositories/asset_repository.dart';

final assetServiceProvider = ChangeNotifierProvider<AssetService>(
  (ref) => AssetService(ref.read(assetRepositoryProvider)),
);

class AssetService extends ChangeNotifier {
  final AssetRepository _repo;
  AssetService(this._repo);

  List<Asset> assets = [];
  Map<String, double> groupTotals = {};

  Future<void> loadAssets(int householdId) async {
    final result = await _repo.getAssets(householdId);
    assets = result.assets;
    groupTotals = result.groupTotals;
    notifyListeners();
  }

  Future<Asset> createAsset(Map<String, dynamic> body) async {
    final asset = await _repo.createAsset(body);
    assets = [...assets, asset];
    notifyListeners();
    return asset;
  }

  Future<Asset> updateAsset(int id, Map<String, dynamic> body) async {
    final updated = await _repo.updateAsset(id, body);
    assets = assets.map((a) => a.id == id ? updated : a).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deleteAsset(int id) async {
    await _repo.deleteAsset(id);
    assets = assets.where((a) => a.id != id).toList();
    notifyListeners();
  }
}
