import 'package:flutter/widgets.dart';
// symbols_map.dart import is required — it forces references to all icons so
// Flutter's tree-shaker doesn't strip the glyphs from the bundled font.
// ignore: unused_import
import 'package:material_symbols_icons/symbols_map.dart';
import 'package:material_symbols_icons/get.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Converts a Material Symbols name string (as stored in the DB) to [IconData].
/// Font is bundled — renders instantly, no network requests.
IconData iconDataFromName(String? name) {
  if (name == null || name.trim().isEmpty) return Symbols.label;
  return SymbolsGet.get(name.trim(), SymbolStyle.outlined);
}
