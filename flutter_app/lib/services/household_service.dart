import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/household.dart';

/// Global state for the currently selected household.
/// Any screen that needs householdId reads this.
final householdServiceProvider = ChangeNotifierProvider<HouseholdService>(
  (ref) => HouseholdService(),
);

class HouseholdService extends ChangeNotifier {
  Household? _selected;
  List<Household> households = [];

  Household? get selected => _selected;
  int? get currentHouseholdId => _selected?.householdId;

  void setHouseholds(List<Household> list) {
    households = list;
    // Auto-select first if nothing selected yet.
    if (_selected == null && list.isNotEmpty) {
      _selected = list.first;
    }
    notifyListeners();
  }

  void selectHousehold(Household h) {
    _selected = h;
    notifyListeners();
  }
}
