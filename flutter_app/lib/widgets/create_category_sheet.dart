import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/repositories/category_repository.dart';

// 18 preset colors for category picker
const _kCategoryColors = [
  '#E53935', '#FF5722', '#FF9800', '#FFC107', '#8BC34A', '#4CAF50',
  '#009688', '#00BCD4', '#2196F3', '#3F51B5', '#673AB7', '#9C27B0',
  '#E91E63', '#795548', '#607D8B', '#9E9E9E', '#FFF9C4', '#F8BBD0',
];

// 48 icon name strings for the icon picker
const _kCategoryIcons = [
  'shopping_cart', 'restaurant', 'directions_car', 'home', 'local_hospital',
  'school', 'fitness_center', 'flight', 'hotel', 'attach_money',
  'savings', 'credit_card', 'phone', 'computer', 'tv',
  'movie', 'music_note', 'sports_soccer', 'pets', 'child_care',
  'face', 'work', 'business', 'store', 'local_gas_station',
  'local_grocery_store', 'coffee', 'fastfood', 'local_bar', 'cake',
  'spa', 'beach_access', 'pool', 'sports_esports', 'book',
  'library_books', 'science', 'medical_services', 'medication', 'cleaning_services',
  'construction', 'electrical_services', 'plumbing', 'agriculture', 'forest',
  'water_drop', 'recycling', 'label',
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
  String? _error;
  List<String> _filteredIcons = _kCategoryIcons;

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
    _iconSearchController.addListener(_filterIcons);
  }

  void _filterIcons() {
    final q = _iconSearchController.text.toLowerCase();
    setState(() {
      _filteredIcons = q.isEmpty
          ? _kCategoryIcons
          : _kCategoryIcons.where((i) => i.contains(q)).toList();
    });
  }

  @override
  void dispose() {
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

  IconData _iconFromName(String name) {
    const map = {
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'home': Icons.home,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'fitness_center': Icons.fitness_center,
      'flight': Icons.flight,
      'hotel': Icons.hotel,
      'attach_money': Icons.attach_money,
      'savings': Icons.savings,
      'credit_card': Icons.credit_card,
      'phone': Icons.phone,
      'computer': Icons.computer,
      'tv': Icons.tv,
      'movie': Icons.movie,
      'music_note': Icons.music_note,
      'sports_soccer': Icons.sports_soccer,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
      'face': Icons.face,
      'work': Icons.work,
      'business': Icons.business,
      'store': Icons.store,
      'local_gas_station': Icons.local_gas_station,
      'local_grocery_store': Icons.local_grocery_store,
      'coffee': Icons.coffee,
      'fastfood': Icons.fastfood,
      'local_bar': Icons.local_bar,
      'cake': Icons.cake,
      'spa': Icons.spa,
      'beach_access': Icons.beach_access,
      'pool': Icons.pool,
      'sports_esports': Icons.sports_esports,
      'book': Icons.book,
      'library_books': Icons.library_books,
      'science': Icons.science,
      'medical_services': Icons.medical_services,
      'medication': Icons.medication,
      'cleaning_services': Icons.cleaning_services,
      'construction': Icons.construction,
      'electrical_services': Icons.electrical_services,
      'plumbing': Icons.plumbing,
      'agriculture': Icons.agriculture,
      'forest': Icons.forest,
      'water_drop': Icons.water_drop,
      'recycling': Icons.recycling,
      'label': Icons.label,
    };
    return map[name] ?? Icons.category;
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

    final title = _isEditMode
        ? l10n.categoryEdit
        : (isExpense ? l10n.categoryNewExpense : l10n.categoryNewIncome);

    final topLevelCats = widget.topLevelCategories ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            const SizedBox(height: 20),
            // Name field
            Text(l10n.categoryName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF555555))),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.categoryNamePlaceholder,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // Hebrew name field
            Text(l10n.categoryNameHe,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF555555))),
            const SizedBox(height: 6),
            TextField(
              controller: _nameHeController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'מכולת',
                hintTextDirection: TextDirection.rtl,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
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
                value: _selectedParentId,
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
                        child: Text(cat.name),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedParentId = v),
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
              children: _kCategoryColors.map((hex) {
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
              }).toList(),
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
              height: 160,
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _filteredIcons.length,
                itemBuilder: (ctx, i) {
                  final iconName = _filteredIcons[i];
                  final isSelected = _selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _selectedIcon = isSelected ? null : iconName),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _hexColor(_selectedColor)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconFromName(iconName),
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF666666),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
          ],
        ),
      ),
    );
  }
}
