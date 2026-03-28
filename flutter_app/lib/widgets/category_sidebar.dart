import 'package:flutter/material.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/utils/icon_helper.dart';

/// Narrow vertical sidebar.
///
/// - Top tile: filter selector — shows the active filter category (or "All").
///   Tapping opens a bottom sheet to pick a filter.
/// - Below: quick-add tiles for every category. Tapping opens the add modal
///   with that category pre-selected (no filtering effect).
/// - Bottom section: favorites (if any), separated by a divider.
class CategorySidebar extends StatelessWidget {
  final List<Category> categories;
  final List<Category> favoriteCategories;
  final int? filterCategoryId;
  final ValueChanged<int?> onFilterChanged;
  final ValueChanged<int> onCategoryQuickAdd;

  const CategorySidebar({
    super.key,
    required this.categories,
    required this.favoriteCategories,
    required this.filterCategoryId,
    required this.onFilterChanged,
    required this.onCategoryQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final filterCat = filterCategoryId != null
        ? categories.where((c) => c.id == filterCategoryId).firstOrNull
        : null;

    return Container(
      width: 80,
      color: Colors.white,
      child: Column(
        children: [
          // ── Filter selector ────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _showFilterSheet(context),
            child: _FilterTile(category: filterCat),
          ),
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
          // ── Quick-add category tiles ───────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                ...categories.map((cat) => _QuickAddTile(
                  label: cat.name,
                  color: cat.color,
                  icon: cat.icon,
                  onTap: () => onCategoryQuickAdd(cat.id),
                )),
                if (favoriteCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
                  ),
                  const Center(
                    child: Text('★',
                        style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                  ),
                  ...favoriteCategories.map((cat) => _QuickAddTile(
                    label: cat.name,
                    color: cat.color,
                    icon: cat.icon,
                    onTap: () => onCategoryQuickAdd(cat.id),
                  )),
                ],
              ],
            ),
          ),
          // ── Search button (pinned at bottom) ──────────────────────────────
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SearchSheet(
        categories: [...categories, ...favoriteCategories],
        onCategorySelected: (id) {
          Navigator.pop(context);
          onCategoryQuickAdd(id);
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
          categories: categories,
          filterCategoryId: filterCategoryId,
          scrollController: scrollController,
          onFilterChanged: (id) {
            Navigator.pop(context);
            onFilterChanged(id);
          },
        ),
      ),
    );
  }
}

// ── Filter tile (top of sidebar) ─────────────────────────────────────────────

class _FilterTile extends StatelessWidget {
  final Category? category;
  const _FilterTile({this.category});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xffff0000);
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
            category?.name ?? AppLocalizations.of(context)!.transactionsAll,
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
  final VoidCallback onTap;

  const _QuickAddTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = _hexColor(color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconDataFromName(icon), size: 20, color: base),
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
    final filtered = _query.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
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
                  title: Text(cat.name,
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
        // Fixed header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(AppLocalizations.of(context)!.categoryFilterByCategory,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        // Scrollable list
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // "All" option
              ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.select_all, size: 18, color: Color(0xFF6366F1)),
                  ),
                ),
                title: Text(AppLocalizations.of(context)!.transactionsAll, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: filterCategoryId == null
                    ? const Icon(Icons.check, color: Color(0xFF6366F1))
                    : null,
                onTap: () => onFilterChanged(null),
              ),
              ...categories.map((cat) {
                final color = _hexColor(cat.color);
                final selected = filterCategoryId == cat.id;
                return ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(iconDataFromName(cat.icon), size: 18, color: color),
                    ),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: selected ? Icon(Icons.check, color: color) : null,
                  onTap: () => onFilterChanged(cat.id),
                );
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
