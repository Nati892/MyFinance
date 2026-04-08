import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// null  = use device system text scale (default)
/// double = explicit override multiplier (0.75 – 1.5)
final fontScaleProvider = StateNotifierProvider<FontScaleNotifier, double?>((ref) {
  return FontScaleNotifier();
});

class FontScaleNotifier extends StateNotifier<double?> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'font_scale';

  FontScaleNotifier() : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _storage.read(key: _key);
    if (saved != null) {
      state = double.tryParse(saved);
    }
  }

  Future<void> setScale(double? scale) async {
    state = scale;
    if (scale == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: scale.toString());
    }
  }
}
