import 'package:flutter/material.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/utils/icon_helper.dart';

/// Narrow vertical sidebar with quick-add, filter, sub-category expand,
/// and long-press edit/delete actions.
class CategorySidebar extends StatefulWidget {
  final List<Category> categories;
  final List<Category> favoriteCategories;
  final int? filterCategoryId;
  final ValueChanged<int?> onFilterChanged;
  final ValueChanged<int> onCategoryQuickAdd;
  final void Function(Category)? onEditCategory;
  final void Function(Category)? onDeleteCategory;

  const CategorySidebar({
    super.key,
    required this.categories,
    required this.favoriteCategories,
    required this.filterCategoryId,
    required this.onFilterChanged,
    required this.onCategoryQuickAdd,
    this.onEditCategory,
    this.onDeleteCategory,
  });

  @override
  State<CategorySidebar> createState() => _CategorySidebarState();
}

class _CategorySidebarState extends State<CategorySidebar> {
  final Set<int> _expandedIds = {};

  String _catName(Category cat) {
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return isHe ? (cat.nameHe ?? cat.name) : cat.name;
  }

  void _toggleExpand(int id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _handleCategoryTap(Category cat) {
    if (cat.subCategories.isNotEmpty) {
      _toggleExpand(cat.id);
    } else {
      widget.onCategoryQuickAdd(cat.id);
    }
  }

  void _showActionSheet(BuildContext context, Category cat) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _catName(cat),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: l10n.categoryEdit,
                    color: const Color(0xFF667EEA),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEditCategory?.call(cat);
                    },
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: l10n.categoryDelete,
                    color: const Color(0xFFE53935),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDeleteCategory?.call(cat);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterCat = widget.filterCategoryId != null
        ? widget.categories
            .expand((c) => c.flatList)
            .where((c) => c.id == widget.filterCategoryId)
            .firstOrNull
        : null;

    return Container(
      width: 88,
      color: Colors.white,
      child: Column(
        children: [
          // ── Filter selector ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _showFilterSheet(context),
            child: _FilterTile(
              category: filterCat,
              categoryLabel: filterCat != null ? _catName(filterCat) : null,
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          // ── Quick-add tiles ──────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                ...widget.categories.expand((cat) {
                  final isExpanded = _expandedIds.contains(cat.id);
                  return [
                    _QuickAddTile(
                      label: _catName(cat),
                      color: cat.color,
                      icon: cat.icon,
                      hasSubCategories: cat.subCategories.isNotEmpty,
                      isExpanded: isExpanded,
                      onTap: () => _handleCategoryTap(cat),
                      onLongPress: (widget.onEditCategory != null ||
                              widget.onDeleteCategory != null)
                          ? () => _showActionSheet(context, cat)
                          : null,
                    ),
                    if (isExpanded)
                      ...cat.subCategories.map((sub) => _SubCategoryTile(
                            label: _catName(sub),
                            color: sub.color,
                            icon: sub.icon,
                            onTap: () => widget.onCategoryQuickAdd(sub.id),
                            onLongPress: (widget.onEditCategory != null ||
                                    widget.onDeleteCategory != null)
                                ? () => _showActionSheet(context, sub)
                                : null,
                          )),
                  ];
                }),
                if (widget.favoriteCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
                  ),
                  const Center(
                    child: Text('★',
                        style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                  ),
                  ...widget.favoriteCategories.map((cat) => _QuickAddTile(
                        label: _catName(cat),
                        color: cat.color,
                        icon: cat.icon,
                        hasSubCategories: false,
                        isExpanded: false,
                        onTap: () => widget.onCategoryQuickAdd(cat.id),
                        onLongPress: null,
                      )),
                ],
              ],
            ),
          ),
          // ── Search button ────────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          GestureDetector(
            onTap: () => _showSearchSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 20, color: Color(0xFF888888)),
                  const SizedBox(height: 3),
                  Text(
                    AppLocalizations.of(context)!.categorySearch,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    final allCats = widget.categories.expand((c) => c.flatList).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SearchSheet(
        categories: [...allCats, ...widget.favoriteCategories],
        onCategorySelected: (id) {
          Navigator.pop(context);
          widget.onCategoryQuickAdd(id);
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => _FilterSheet(
          categories: widget.categories,
          filterCategoryId: widget.filterCategoryId,
          scrollController: scrollController,
          onFilterChanged: (id) {
            Navigator.pop(context);
            widget.onFilterChanged(id);
          },
        ),
      ),
    );
  }
}

// ── Round action button ───────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter tile (top of sidebar) ─────────────────────────────────────────────

class _FilterTile extends StatelessWidget {
  final Category? category;
  final String? categoryLabel;
  const _FilterTile({this.category, this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF667EEA);
    final base = category != null ? _hexColor(category!.color) : indigo;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      padding: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            category != null
                ? iconDataFromName(category!.icon)
                : Icons.filter_list,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(height: 3),
          Text(
            categoryLabel ?? AppLocalizations.of(context)!.transactionsAll,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ── Quick-add tile ────────────────────────────────────────────────────────────

class _QuickAddTile extends StatelessWidget {
  final String label;
  final String color;
  final String? icon;
  final bool hasSubCategories;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickAddTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.hasSubCategories,
    required this.isExpanded,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final base = _hexColor(color);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(iconDataFromName(icon), size: 20, color: base),
                if (hasSubCategories)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 12,
                      color: base.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: base,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ── Sub-category tile ─────────────────────────────────────────────────────────

class _SubCategoryTile extends StatelessWidget {
  final String label;
  final String color;
  final String? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SubCategoryTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final base = _hexColor(color);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 6, bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: base.withValues(alpha: 0.4), width: 2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconDataFromName(icon), size: 16, color: base),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: base,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ── Search bottom sheet ───────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  final List<Category> categories;
  final ValueChanged<int> onCategorySelected;

  const _SearchSheet({required this.categories, required this.onCategorySelected});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final all = widget.categories.toSet().toList(); // dedup
    final filtered = _query.isEmpty
        ? all
        : all
            .where((c) =>
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                (c.nameHe ?? '').contains(_query))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.categorySearch,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: filtered.map((cat) {
                final color = _hexColor(cat.color);
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(iconDataFromName(cat.icon), size: 18, color: color),
                    ),
                  ),
                  title: Text(
                      isHe ? (cat.nameHe ?? cat.name) : cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => widget.onCategorySelected(cat.id),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final List<Category> categories;
  final int? filterCategoryId;
  final ValueChanged<int?> onFilterChanged;
  final ScrollController scrollController;

  const _FilterSheet({
    required this.categories,
    required this.filterCategoryId,
    required this.onFilterChanged,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.categoryFilterByCategory,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.select_all, size: 18, color: Color(0xFF6366F1)),
                  ),
                ),
                title: Text(AppLocalizations.of(context)!.transactionsAll,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: filterCategoryId == null
                    ? const Icon(Icons.check, color: Color(0xFF6366F1))
                    : null,
                onTap: () => onFilterChanged(null),
              ),
              ...categories.expand((cat) {
                final isHe = Localizations.localeOf(context).languageCode == 'he';
                final color = _hexColor(cat.color);
                final selected = filterCategoryId == cat.id;
                return [
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(iconDataFromName(cat.icon), size: 18, color: color),
                      ),
                    ),
                    title: Text(isHe ? (cat.nameHe ?? cat.name) : cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: selected ? Icon(Icons.check, color: color) : null,
                    onTap: () => onFilterChanged(cat.id),
                  ),
                  ...cat.subCategories.map((sub) {
                    final subColor = _hexColor(sub.color);
                    final subSelected = filterCategoryId == sub.id;
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 32, right: 16),
                      leading: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: subColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Icon(iconDataFromName(sub.icon),
                              size: 15, color: subColor),
                        ),
                      ),
                      title: Text(isHe ? (sub.nameHe ?? sub.name) : sub.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: subColor)),
                      trailing: subSelected
                          ? Icon(Icons.check, color: subColor, size: 18)
                          : null,
                      onTap: () => onFilterChanged(sub.id),
                    );
                  }),
                ];
              }),
            ],
          ),
        ),
      ],
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}
