# Phase 1b — Sidebar: Disable Favorites, Add Summary Button

## Goal
Owns all changes in `lib/widgets/category_sidebar.dart`:
1. Comment out (do not delete) the bottom Favorites tile (lines ~185–217).
2. Add a new "Summary" tile in the same slot (above the Search button divider) that calls a parent-supplied `onSummaryTap` callback.

## Depends On
None.

## Parallel With
Phase 1a (transaction_timeline.dart) and Phase 1c (l10n). Disjoint files.

## Contract (consumed by Phase 2)
The screen will call this widget like:
```dart
CategorySidebar(
  ...existing props...,
  onSummaryTap: () => _showPeriodSummary(context, vm),
)
```
**Prop name must be exactly `onSummaryTap`, type `VoidCallback?`, optional, defaults to null.**

## Steps

1. **Add the new prop** to `CategorySidebar`:
   - `final VoidCallback? onSummaryTap;`
   - Add to constructor as optional.

2. **Comment out the Favorites tile block** (lines 185–217), preserving the code intact behind a comment header:
   ```dart
   // ── Favorites button (currently disabled — kept for future re-enable) ─────
   // if (widget.favoriteCategories.isNotEmpty && widget.onFavoritesToggle != null) ...[
   //   const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
   //   GestureDetector(
   //     onTap: widget.onFavoritesToggle,
   //     ...
   //   ),
   // ],
   ```
   Leave the `favoriteCategories`, `onFavoritesToggle`, `favoritesExpanded` fields and constructor params **untouched** — they remain for future re-enable.

3. **Insert the new Summary tile** in the same slot (above the Search button divider, around line 218):
   ```dart
   if (widget.onSummaryTap != null) ...[
     const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
     GestureDetector(
       onTap: widget.onSummaryTap,
       child: Padding(
         padding: const EdgeInsets.symmetric(vertical: 8),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.pie_chart_outline, size: 20, color: Color(0xFF888888)),
             const SizedBox(height: 3),
             Text(
               AppLocalizations.of(context)!.categorySummary,
               textAlign: TextAlign.center,
               style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
             ),
           ],
         ),
       ),
     ),
   ],
   ```
   The `categorySummary` localization key is added by Phase 1c — analyzer may complain until 1c lands; that's expected during parallel execution and resolves once all three branches merge.

4. **Run analyzer** — `cd household && flutter analyze lib/widgets/category_sidebar.dart`. The `categorySummary` getter may not yet exist; treat as expected if the only error is `Undefined name/getter 'categorySummary'`.

## Execution Log
*(Agent appends here as work progresses.)*
- Added optional `final VoidCallback? onSummaryTap;` field to `CategorySidebar` and a matching `this.onSummaryTap` constructor parameter (defaults to null). `favoriteCategories`, `onFavoritesToggle`, and `favoritesExpanded` left intact.
- Commented out the entire Favorites tile spread (the `if (widget.favoriteCategories.isNotEmpty && widget.onFavoritesToggle != null) ...[ ... ]` block) line-by-line behind `//`, with a header comment `// ── Favorites button (currently disabled — kept for future re-enable) ─────`.
- Inserted a new Summary tile in the same slot, just above the Search button divider: wrapped in `if (widget.onSummaryTap != null) ...[Divider, GestureDetector(...)]`, using `Icons.pie_chart_outline` (size 20, color `0xFF888888`) and `AppLocalizations.of(context)!.categorySummary` (fontSize 9, color `0xFF888888`) — mirrors the Search button's styling exactly.
- Ran `flutter analyze lib/widgets/category_sidebar.dart`: 1 issue — `error • The getter 'categorySummary' isn't defined for the type 'AppLocalizations' • lib/widgets/category_sidebar.dart:233:53 • undefined_getter`. This is the expected error pending Phase 1c (l10n).

## Tests Run
- Framework: Flutter widget tests (none specific)
- Result: not run (no widget tests for this widget)

## Build Analyzers Run
- `flutter analyze lib/widgets/category_sidebar.dart`: 1 expected error (`Undefined name 'categorySummary'`), waiting on Phase 1c.

## User Verification
Status: pending
Confirmed at: —

## Status
awaiting-user-test
