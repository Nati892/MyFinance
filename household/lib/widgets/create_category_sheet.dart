import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/utils/icon_helper.dart';


// 18 preset colors for category picker
const _kCategoryColors = [
  '#E53935', '#FF5722', '#FF9800', '#FFC107', '#8BC34A', '#4CAF50',
  '#009688', '#00BCD4', '#2196F3', '#3F51B5', '#673AB7', '#9C27B0',
  '#E91E63', '#795548', '#607D8B', '#9E9E9E', '#FFF9C4', '#F8BBD0',
];

const _kIconSections = [
  (
    label: 'Food & Dining',
    icons: [
      'restaurant', 'coffee', 'fastfood', 'local_bar', 'cake',
      'local_grocery_store', 'wine_bar', 'local_pizza', 'ramen_dining',
      'bakery_dining', 'brunch_dining', 'dinner_dining', 'icecream',
      'liquor', 'tapas', 'set_meal',
    ],
  ),
  (
    label: 'Transport',
    icons: [
      'directions_car', 'flight', 'directions_bus', 'train',
      'directions_bike', 'local_taxi', 'electric_scooter', 'two_wheeler',
      'directions_boat', 'airport_shuttle', 'local_gas_station',
    ],
  ),
  (
    label: 'Home',
    icons: [
      'home', 'construction', 'electrical_services', 'plumbing',
      'cleaning_services', 'roofing', 'garage', 'chair', 'bathtub',
      'kitchen', 'bed', 'yard', 'water_drop',
    ],
  ),
  (
    label: 'Health & Wellness',
    icons: [
      'local_hospital', 'medical_services', 'medication', 'fitness_center',
      'spa', 'psychology', 'vaccines', 'monitor_heart', 'health_and_safety',
      'stethoscope', 'self_improvement',
    ],
  ),
  (
    label: 'Entertainment',
    icons: [
      'movie', 'music_note', 'sports_esports', 'sports_soccer', 'book',
      'sports_basketball', 'sports_tennis', 'theater_comedy', 'palette',
      'headphones', 'sports_golf', 'sports_baseball', 'surfing',
      'library_books', 'casino',
    ],
  ),
  (
    label: 'Shopping',
    icons: [
      'shopping_cart', 'store', 'local_mall', 'checkroom', 'diamond',
      'watch', 'redeem', 'storefront', 'sell',
    ],
  ),
  (
    label: 'Kids & Family',
    icons: [
      'child_care', 'toys', 'crib', 'school', 'family_restroom',
      'stroller', 'baby_changing_station', 'escalator_warning',
    ],
  ),
  (
    label: 'Tech & Devices',
    icons: [
      'computer', 'tv', 'phone', 'router', 'keyboard',
      'smart_toy', 'developer_mode', 'print', 'wifi', 'smartphone',
    ],
  ),
  (
    label: 'Finance',
    icons: [
      'attach_money', 'savings', 'credit_card', 'account_balance',
      'trending_up', 'trending_down', 'currency_exchange', 'receipt_long',
    ],
  ),
  (
    label: 'Nature & Travel',
    icons: [
      'forest', 'recycling', 'agriculture', 'beach_access', 'pool',
      'hotel', 'luggage', 'explore', 'hiking', 'park', 'eco', 'camping',
    ],
  ),
  (
    label: 'Work & Business',
    icons: [
      'work', 'business', 'meeting_room', 'inventory', 'local_shipping',
      'engineering', 'handshake', 'volunteer_activism', 'public',
      'manage_accounts',
    ],
  ),
  (
    label: 'Personal',
    icons: [
      'face', 'cut', 'dry_cleaning', 'person', 'sports',
      'celebration', 'sentiment_satisfied', 'pets', 'label',
    ],
  ),
];

class CreateCategorySheet extends ConsumerStatefulWidget {
  final String categoryType; // 'expense' or 'income'
  final int householdId;
  final void Function(Category) onCreated;

  /// If set, the sheet will be in edit mode for this category.
  final Category? existing;

  /// Top-level categories for the parent picker (when creating sub-categories).
  final List<Category>? topLevelCategories;

  /// Pre-selects a parent category when opening the sheet for "Add Subcategory".
  final int? preselectedParentId;

  const CreateCategorySheet({
    super.key,
    required this.categoryType,
    required this.householdId,
    required this.onCreated,
    this.existing,
    this.topLevelCategories,
    this.preselectedParentId,
  });

  @override
  ConsumerState<CreateCategorySheet> createState() =>
      _CreateCategorySheetState();
}

class _CreateCategorySheetState extends ConsumerState<CreateCategorySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _nameHeController;
  final _iconSearchController = TextEditingController();
  late String _selectedColor;
  String? _selectedIcon;
  int? _selectedParentId;
  bool _saving = false;
  bool _translating = false;
  String? _error;
  String _iconSearchQuery = '';
  Timer? _translateDebounce;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  TextEditingController? _suggestionTarget;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _nameHeController = TextEditingController(text: existing?.nameHe ?? '');
    _selectedColor = existing?.color ?? '#607D8B';
    _selectedIcon = existing?.icon;
    _selectedParentId = existing?.parentCategoryId ?? widget.preselectedParentId;

    // If creating a new sub-category with a preselected parent, inherit parent color/icon
    if (!_isEditMode && widget.preselectedParentId != null && widget.topLevelCategories != null) {
      final parent = widget.topLevelCategories!.where((c) => c.id == widget.preselectedParentId).firstOrNull;
      if (parent != null) {
        _selectedColor = parent.color;
        _selectedIcon = parent.icon;
      }
    }

    _iconSearchController.addListener(_onIconSearch);
  }

  void _onIconSearch() {
    setState(() => _iconSearchQuery = _iconSearchController.text.toLowerCase().trim());
  }

  Future<void> _translate() async {
    final heText = _nameHeController.text.trim();
    final enText = _nameController.text.trim();

    String from, to, sourceText;
    TextEditingController targetController;

    if (heText.isNotEmpty && enText.isEmpty) {
      from = 'he';
      to = 'en';
      sourceText = heText;
      targetController = _nameController;
    } else if (enText.isNotEmpty && heText.isEmpty) {
      from = 'en';
      to = 'he';
      sourceText = enText;
      targetController = _nameHeController;
    } else {
      return;
    }

    setState(() => _translating = true);
    try {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.mymemory.translated.net/get',
        queryParameters: {'q': sourceText, 'langpair': '$from|$to'},
      );
      final translated =
          response.data?['responseData']?['translatedText'] as String?;
      if (translated != null && mounted) {
        targetController.text = translated;
      }
    } catch (_) {
      // silently fail — user can type manually
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  void _startAutoTranslate(TextEditingController changedCtrl) {
    if (_showSuggestions) setState(() => _showSuggestions = false);
    _translateDebounce?.cancel();
    _translateDebounce = Timer(const Duration(milliseconds: 800), () => _autoTranslate(changedCtrl));
  }

  Future<void> _autoTranslate(TextEditingController changedCtrl) async {
    final text = changedCtrl.text.trim();
    if (text.isEmpty) return;

    final bool fromHe = changedCtrl == _nameHeController;
    final targetCtrl = fromHe ? _nameController : _nameHeController;
    final String from = fromHe ? 'he' : 'en';
    final String to = fromHe ? 'en' : 'he';

    setState(() => _translating = true);
    try {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.mymemory.translated.net/get',
        queryParameters: {'q': text, 'langpair': '$from|$to'},
      );

      final topTranslation = response.data?['responseData']?['translatedText'] as String?;
      final matchesList = response.data?['matches'] as List? ?? [];

      final seen = <String>{};
      final suggestions = <String>[];
      if (topTranslation != null && topTranslation.isNotEmpty && seen.add(topTranslation)) {
        suggestions.add(topTranslation);
      }
      for (final match in matchesList) {
        if (suggestions.length >= 3) break;
        final t = match?['translation'] as String?;
        if (t != null && t.isNotEmpty && seen.add(t)) suggestions.add(t);
      }

      if (mounted && suggestions.isNotEmpty) {
        targetCtrl.text = suggestions.first;
        setState(() {
          _suggestions = suggestions;
          _suggestionTarget = targetCtrl;
          _showSuggestions = true;
        });
      }
    } catch (_) {
      // silently fail
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  @override
  void dispose() {
    _translateDebounce?.cancel();
    _nameController.dispose();
    _nameHeController.dispose();
    _iconSearchController.dispose();
    super.dispose();
  }

  Color _hexColor(String hex) {
    try {
      final h = hex.trim().replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  void _openColorPicker(BuildContext context) {
    Color current = _hexColor(_selectedColor);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => current = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final hex = '#${current.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              setState(() => _selectedColor = hex);
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in _kIconSections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              section.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
            ),
          ),
          _buildIconWrap(section.icons),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    final allIcons = _kIconSections.expand((s) => s.icons).toList();
    final results = allIcons.where((n) => n.contains(_iconSearchQuery)).toList();
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No icons found', style: TextStyle(color: Color(0xFF888888)))),
      );
    }
    return _buildIconWrap(results);
  }

  Widget _buildIconWrap(List<String> iconNames) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in iconNames)
          GestureDetector(
            onTap: () => setState(() => _selectedIcon = _selectedIcon == name ? null : name),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedIcon == name ? _hexColor(_selectedColor) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconDataFromName(name),
                size: 20,
                color: _selectedIcon == name ? Colors.white : const Color(0xFF666666),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.categoryName);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final body = <String, dynamic>{
        'name': name,
        if (_nameHeController.text.trim().isNotEmpty)
          'nameHe': _nameHeController.text.trim()
        else
          'nameHe': null,
        'color': _selectedColor,
        'icon': _selectedIcon ?? 'label',
        if (_selectedParentId != null) 'parentCategoryId': _selectedParentId,
        if (!_isEditMode) 'householdId': widget.householdId,
      };

      final Category result;
      if (_isEditMode) {
        if (widget.categoryType == 'expense') {
          result = await repo.updateExpenseCategory(widget.existing!.id, body);
        } else {
          result = await repo.updateIncomeCategory(widget.existing!.id, body);
        }
      } else {
        if (widget.categoryType == 'expense') {
          result = await repo.createExpenseCategory(body);
        } else {
          result = await repo.createIncomeCategory(body);
        }
      }
      widget.onCreated(result);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context)!.categoryFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isExpense = widget.categoryType == 'expense';
    final accentColor =
        isExpense ? const Color(0xFF667EEA) : const Color(0xFF4CAF50);

    final isHebrew = Localizations.localeOf(context).languageCode == 'he';

    final title = _isEditMode
        ? l10n.categoryEdit
        : (isExpense ? l10n.categoryNewExpense : l10n.categoryNewIncome);

    final topLevelCats = widget.topLevelCategories ?? [];

    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            // Title bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                      _isEditMode
                          ? Icons.edit_outlined
                          : (isExpense
                              ? Icons.trending_down
                              : Icons.trending_up),
                      color: accentColor),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                          fontSize: 16)),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFB71C1C), fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            // Live category preview
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _hexColor(_selectedColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      iconDataFromName(_selectedIcon),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Preview',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Name fields — Hebrew first when app is in Hebrew mode
            if (isHebrew) ...[
              Text(l10n.categoryNameHe,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              TextField(
                controller: _nameHeController,
                textDirection: TextDirection.rtl,
                onChanged: (_) => _startAutoTranslate(_nameHeController),
                decoration: InputDecoration(
                  hintText: 'מכולת',
                  hintTextDirection: TextDirection.rtl,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  suffixIcon: _translating ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ) : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.categoryName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                onChanged: (_) => _startAutoTranslate(_nameController),
                decoration: InputDecoration(
                  hintText: l10n.categoryNamePlaceholder,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  suffixIcon: _translating ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ) : null,
                ),
              ),
            ] else ...[
              Text(l10n.categoryName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                onChanged: (_) => _startAutoTranslate(_nameController),
                decoration: InputDecoration(
                  hintText: l10n.categoryNamePlaceholder,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  suffixIcon: _translating ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ) : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.categoryNameHe,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              TextField(
                controller: _nameHeController,
                textDirection: TextDirection.rtl,
                onChanged: (_) => _startAutoTranslate(_nameHeController),
                decoration: InputDecoration(
                  hintText: 'מכולת',
                  hintTextDirection: TextDirection.rtl,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  suffixIcon: _translating ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ) : null,
                ),
              ),
            ],
            // Parent category picker (only when top-level cats are provided)
            if (topLevelCats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.categoryParent,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                initialValue: _selectedParentId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.commonOptional,
                        style:
                            const TextStyle(color: Color(0xFF888888))),
                  ),
                  ...topLevelCats.map((cat) => DropdownMenuItem<int?>(
                        value: cat.id,
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _hexColor(cat.color),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(iconDataFromName(cat.icon),
                                  size: 13, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(cat.name),
                          ],
                        ),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedParentId = v;
                    if (v != null && !_isEditMode) {
                      final parent = topLevelCats.firstWhere((c) => c.id == v, orElse: () => topLevelCats.first);
                      _selectedColor = parent.color;
                      _selectedIcon = parent.icon;
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 20),
            // Color picker
            Text(l10n.categoryColor,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF555555))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._kCategoryColors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _hexColor(hex),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black54, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                    color: Color(0x40000000), blurRadius: 4)
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }),
                // Rainbow gradient swatch — opens full HSV color picker
                GestureDetector(
                  onTap: () => _openColorPicker(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 3,
                            offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Icon picker
            Text(l10n.categoryIcon,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF555555))),
            const SizedBox(height: 8),
            TextField(
              controller: _iconSearchController,
              decoration: InputDecoration(
                hintText: l10n.categoryIconSearch,
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: SingleChildScrollView(
                child: _iconSearchQuery.isEmpty
                    ? _buildSections()
                    : _buildSearchResults(),
              ),
            ),
                    ],
                  ),
                ),
              ),
              // ── Buttons always visible ───────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPad),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () async {
                          final nav = Navigator.of(context);
                          final heText = _nameHeController.text.trim();
                          final enText = _nameController.text.trim();
                          final needsTranslate = (heText.isNotEmpty && enText.isEmpty) ||
                              (enText.isNotEmpty && heText.isEmpty);
                          if (needsTranslate) await _translate();
                          if (mounted) nav.pop();
                        },
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: Text(l10n.categoryCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                _isEditMode
                                    ? l10n.commonSave
                                    : l10n.categorySave,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Translation suggestions floating card ────────────────────────────
          if (_showSuggestions && _suggestions.isNotEmpty)
            Positioned(
              bottom: bottomPad + 80,
              left: 20,
              right: 20,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: Row(
                  children: [
                    for (int i = 0; i < _suggestions.length; i++) ...[
                      if (i > 0)
                        Container(width: 1, height: 36, color: const Color(0xFFEEEEEE)),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _suggestionTarget?.text = _suggestions[i];
                            setState(() => _showSuggestions = false);
                          },
                          child: Text(
                            _suggestions[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
