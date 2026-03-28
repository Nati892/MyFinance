import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/asset.dart';
import 'package:household/services/asset_service.dart';
import 'package:household/services/household_service.dart';

final assetsViewModelProvider =
    ChangeNotifierProvider.autoDispose<AssetsViewModel>((ref) {
  return AssetsViewModel(
    ref.read(assetServiceProvider),
    ref.read(householdServiceProvider),
  );
});

enum AssetsLoadState { idle, loading, error }

/// A named group of assets sharing the same name, with totals.
class AssetGroup {
  final String name;
  final List<Asset> assets;
  final double frontendTotal;
  final double? backendTotal;
  final bool mismatch;

  const AssetGroup({
    required this.name,
    required this.assets,
    required this.frontendTotal,
    this.backendTotal,
    required this.mismatch,
  });
}

class AssetsViewModel extends ChangeNotifier {
  final AssetService _assetService;
  final HouseholdService _householdService;

  AssetsViewModel(this._assetService, this._householdService) {
    load();
  }

  // ── State ──────────────────────────────────────────────────────────────────
  AssetsLoadState state = AssetsLoadState.loading;
  String? errorMessage;

  // ── Modal ──────────────────────────────────────────────────────────────────
  bool modalOpen = false;
  bool modalSaving = false;
  String? modalError;
  bool isEditMode = false;
  int? editingId;

  // Form fields – basic
  String formName = '';
  double formValue = 0;
  String formLiquidity = 'medium';
  String formDescription = '';
  String formDate = '';

  // Form fields – exit
  String formExitType = 'none'; // 'none' | 'single' | 'series'
  DateTime? formExitDate;
  DateTime? formExitSeriesStart;
  int? formExitSeriesInterval;
  String formExitSeriesUnit = 'months';

  // Form fields – repetitive income
  bool formIsRepetitive = false;
  double? formRepetitiveAmount;
  int? formRepetitiveInterval;
  String formRepetitiveUnit = 'months';

  bool get noHousehold => _householdService.currentHouseholdId == null;

  List<Asset> get assets => _assetService.assets;
  Map<String, double> get groupTotals => _assetService.groupTotals;

  // ── Computed summaries ─────────────────────────────────────────────────────

  double get totalValue =>
      assets.fold(0, (sum, a) => sum + a.value);

  double get liquidValue =>
      assets.where((a) => a.liquidity == 'high').fold(0, (sum, a) => sum + a.value);

  double get semiLiquidValue =>
      assets.where((a) => a.liquidity == 'medium').fold(0, (sum, a) => sum + a.value);

  double get illiquidValue =>
      assets.where((a) => a.liquidity == 'low').fold(0, (sum, a) => sum + a.value);

  // ── Asset groups ───────────────────────────────────────────────────────────

  List<AssetGroup> get assetGroups {
    final map = <String, List<Asset>>{};
    for (final a in assets) {
      final key = a.name.trim();
      map.putIfAbsent(key, () => []).add(a);
    }
    return map.entries.map((entry) {
      final name = entry.key;
      final sorted = [...entry.value]..sort((a, b) {
          if (a.date == null && b.date == null) return 0;
          if (a.date == null) return 1;
          if (b.date == null) return -1;
          return a.date!.compareTo(b.date!);
        });
      final frontendTotal = double.parse(
        sorted.fold(0.0, (sum, a) => sum + a.value).toStringAsFixed(2),
      );
      final backendTotal = groupTotals[name];
      final mismatch = backendTotal != null &&
          (backendTotal - frontendTotal).abs() > 0.01;
      return AssetGroup(
        name: name,
        assets: sorted,
        frontendTotal: frontendTotal,
        backendTotal: backendTotal,
        mismatch: mismatch,
      );
    }).toList();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) {
      state = AssetsLoadState.idle;
      notifyListeners();
      return;
    }
    state = AssetsLoadState.loading;
    notifyListeners();
    try {
      await _assetService.loadAssets(hid);
      state = AssetsLoadState.idle;
    } catch (e) {
      state = AssetsLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Modal ──────────────────────────────────────────────────────────────────

  void openAddModal() {
    isEditMode = false;
    editingId = null;
    modalError = null;
    formName = '';
    formValue = 0;
    formLiquidity = 'medium';
    formDescription = '';
    formDate = DateTime.now().toIso8601String().split('T')[0];
    // Exit defaults
    formExitType = 'none';
    formExitDate = null;
    formExitSeriesStart = null;
    formExitSeriesInterval = null;
    formExitSeriesUnit = 'months';
    // Repetitive defaults
    formIsRepetitive = false;
    formRepetitiveAmount = null;
    formRepetitiveInterval = null;
    formRepetitiveUnit = 'months';
    modalOpen = true;
    notifyListeners();
  }

  void openEditModal(Asset asset) {
    isEditMode = true;
    editingId = asset.id;
    modalError = null;
    formName = asset.name;
    formValue = asset.value;
    formLiquidity = asset.liquidity;
    formDescription = asset.description ?? '';
    formDate = asset.date ?? DateTime.now().toIso8601String().split('T')[0];
    // Exit fields
    formExitType = asset.exitType;
    formExitDate = asset.exitDate;
    formExitSeriesStart = asset.exitSeriesStart;
    formExitSeriesInterval = asset.exitSeriesInterval;
    formExitSeriesUnit = asset.exitSeriesUnit ?? 'months';
    // Repetitive fields
    formIsRepetitive = asset.isRepetitive;
    formRepetitiveAmount = asset.repetitiveAmount;
    formRepetitiveInterval = asset.repetitiveInterval;
    formRepetitiveUnit = asset.repetitiveUnit ?? 'months';
    modalOpen = true;
    notifyListeners();
  }

  void closeModal() {
    modalOpen = false;
    modalError = null;
    notifyListeners();
  }

  void setFormName(String v) {
    formName = v;
    notifyListeners();
  }

  void setFormValue(double v) {
    formValue = v;
    notifyListeners();
  }

  void setFormLiquidity(String v) {
    formLiquidity = v;
    notifyListeners();
  }

  void setFormDescription(String v) {
    formDescription = v;
    notifyListeners();
  }

  void setFormDate(String v) {
    formDate = v;
    notifyListeners();
  }

  // Exit setters
  void setFormExitType(String v) {
    formExitType = v;
    notifyListeners();
  }

  void setFormExitDate(DateTime? v) {
    formExitDate = v;
    notifyListeners();
  }

  void setFormExitSeriesStart(DateTime? v) {
    formExitSeriesStart = v;
    notifyListeners();
  }

  void setFormExitSeriesInterval(int? v) {
    formExitSeriesInterval = v;
    notifyListeners();
  }

  void setFormExitSeriesUnit(String v) {
    formExitSeriesUnit = v;
    notifyListeners();
  }

  // Repetitive setters
  void setFormIsRepetitive(bool v) {
    formIsRepetitive = v;
    notifyListeners();
  }

  void setFormRepetitiveAmount(double? v) {
    formRepetitiveAmount = v;
    notifyListeners();
  }

  void setFormRepetitiveInterval(int? v) {
    formRepetitiveInterval = v;
    notifyListeners();
  }

  void setFormRepetitiveUnit(String v) {
    formRepetitiveUnit = v;
    notifyListeners();
  }

  Future<void> saveAsset() async {
    if (formName.trim().isEmpty) {
      modalError = 'Please enter a name.';
      notifyListeners();
      return;
    }

    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;

    modalSaving = true;
    modalError = null;
    notifyListeners();

    try {
      String dateToStr(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final body = <String, dynamic>{
        'name': formName.trim(),
        'value': formValue,
        'liquidity': formLiquidity,
        'description': formDescription,
        'householdId': hid,
        'date': formDate,
        'sortOrder': isEditMode
            ? (assets.firstWhere((a) => a.id == editingId!).sortOrder)
            : (assets.fold(0, (m, a) => m > a.sortOrder ? m : a.sortOrder) + 1),
        // Exit fields
        'exit_type': formExitType,
        if (formExitType == 'single' && formExitDate != null)
          'exit_date': dateToStr(formExitDate!),
        if (formExitType == 'series' && formExitSeriesStart != null)
          'exit_series_start': dateToStr(formExitSeriesStart!),
        if (formExitType == 'series' && formExitSeriesInterval != null)
          'exit_series_interval': formExitSeriesInterval,
        if (formExitType == 'series') 'exit_series_unit': formExitSeriesUnit,
        // Repetitive income fields
        'is_repetitive': formIsRepetitive,
        if (formIsRepetitive && formRepetitiveAmount != null)
          'repetitive_amount': formRepetitiveAmount,
        if (formIsRepetitive && formRepetitiveInterval != null)
          'repetitive_interval': formRepetitiveInterval,
        if (formIsRepetitive) 'repetitive_unit': formRepetitiveUnit,
      };

      if (!isEditMode) {
        await _assetService.createAsset(body);
      } else {
        await _assetService.updateAsset(editingId!, body);
      }

      modalSaving = false;
      modalOpen = false;
      notifyListeners();
    } catch (e) {
      modalSaving = false;
      modalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  Future<void> deleteAsset(Asset asset) async {
    try {
      await _assetService.deleteAsset(asset.id);
    } catch (_) {}
  }

  // ── Inline update (from row tap) ───────────────────────────────────────────

  Future<void> patchAsset(Asset asset, Map<String, dynamic> changes) async {
    try {
      final body = {
        'name': asset.name,
        'value': asset.value,
        'liquidity': asset.liquidity,
        'description': asset.description ?? '',
        'date': asset.date ?? '',
        'sortOrder': asset.sortOrder,
        'householdId': asset.householdId,
        ...changes,
      };
      await _assetService.updateAsset(asset.id, body);
    } catch (_) {
      // Reload on failure
      await load();
    }
  }
}
