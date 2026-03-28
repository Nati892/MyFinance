import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_locale';

  LocaleNotifier() : super(const Locale('en')) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _storage.read(key: _key);
    if (saved == 'he') {
      state = const Locale('he');
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _storage.write(key: _key, value: locale.languageCode);
  }

  Future<void> toggle() async {
    await setLocale(
        state.languageCode == 'en' ? const Locale('he') : const Locale('en'));
  }
}
