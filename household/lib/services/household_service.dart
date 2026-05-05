import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/household.dart';
import 'package:household/repositories/household_repository.dart';

/// Global state for the currently selected household.
/// Any screen that needs householdId reads this.
final householdServiceProvider = ChangeNotifierProvider<HouseholdService>(
  (ref) => HouseholdService(ref.read(householdRepositoryProvider)),
);

class HouseholdService extends ChangeNotifier {
  final HouseholdRepository _repo;
  HouseholdService(this._repo);

  Household? _selected;
  List<Household> households = [];

  Household? get selected => _selected;
  int? get currentHouseholdId => _selected?.householdId;
  int get currentStartDay => _selected?.financialMonthStartDay ?? 10;

  void setHouseholds(List<Household> list) {
    households = list;
    // Auto-select first if nothing selected yet.
    if (_selected == null && list.isNotEmpty) {
      _selected = list.first;
    } else if (_selected != null) {
      // Keep selection in sync with refreshed payload (e.g., updated start day).
      final refreshed = list.where((h) => h.householdId == _selected!.householdId);
      if (refreshed.isNotEmpty) _selected = refreshed.first;
    }
    notifyListeners();
  }

  void selectHousehold(Household h) {
    _selected = h;
    notifyListeners();
  }

  Future<void> updateFinancialMonthStartDay(int day) async {
    final id = _selected?.householdId;
    if (id == null) return;
    final updated = await _repo.updateSettings(
      householdId: id,
      financialMonthStartDay: day,
    );
    // Server response only includes basic fields; preserve role from current selection.
    _selected = _selected!.copyWith(
      financialMonthStartDay: updated.financialMonthStartDay,
    );
    households = households
        .map((h) => h.householdId == id ? _selected! : h)
        .toList();
    notifyListeners();
  }
}
