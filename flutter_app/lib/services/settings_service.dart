import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// null  = use device system text scale (default)
/// double = explicit override multiplier (0.75 – 1.5)
final fontScaleProvider = StateNotifierProvider<FontScaleNotifier, double?>((ref) {
  return FontScaleNotifier();
});

class FontScaleNotifier extends StateNotifier<double?> {
  static const _key = 'font_scale';

  FontScaleNotifier() : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = double.tryParse(saved);
    }
  }

  Future<void> setScale(double? scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    if (scale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, scale.toString());
    }
  }
}
