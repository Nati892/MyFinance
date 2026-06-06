# Phase 2 — Screen Integration

## Goal
Integrate the three parallel branches in the screen layer. Owns:
- `lib/screens/transactions/transactions_screen.dart` — wire `CategorySidebar.onSummaryTap`, build `_PeriodSummaryDialog`, store `TimelinePeriodInfo` from the new timeline callback, comment out the favorites overlay.
- `lib/screens/transactions/transactions_view_model.dart` — add a NOTE comment above `favoriteCategories`.

## Depends On
Phases 1a, 1b, 1c — must all be complete before this runs.

## Parallel With
None (this is the integration phase).

## Steps

1. **Verify the three contracts from 1a/1b/1c exist:**
   - `TimelinePeriodInfo` and `onPeriodChanged` in `transaction_timeline.dart`.
   - `onSummaryTap` prop on `CategorySidebar`.
   - All l10n getters from Phase 1c.
   If any are missing or named differently, fix the producing file (don't work around it).

2. **Add state to `_TransactionsScreenState`:**
   - `TimelinePeriodInfo? _periodInfo;`

3. **Wire `TransactionTimeline.onPeriodChanged`** at the existing call site (around the timeline construction):
   ```dart
   onPeriodChanged: (info) {
     if (mounted) setState(() => _periodInfo = info);
   },
   ```

4. **Wire `CategorySidebar.onSummaryTap`** at the existing call site (~line 105):
   ```dart
   onSummaryTap: () => _showPeriodSummary(context, vm),
   ```

5. **Implement `_showPeriodSummary`** in the same state class:
   ```dart
   void _showPeriodSummary(BuildContext context, TransactionsViewModel vm) {
     final info = _periodInfo;
     if (info == null) return;
     showDialog<void>(
       context: context,
       builder: (_) => _PeriodSummaryDialog(info: info),
     );
   }
   ```

6. **Add `_PeriodSummaryDialog`** as a `ConsumerStatefulWidget` at the bottom of the file:
   - Constructor takes `TimelinePeriodInfo info`.
   - In `initState`, if `info.view == 'monthly'`, call `ref.read(budgetServiceProvider).getMonthlyBudget(year: info.year, month: info.month)` and store result in state.
   - Build:
     - `AlertDialog` with rounded shape, padding 20, max width 360.
     - Title: `l10n.summaryDialogTitle` + small subtitle showing `info.label` and a view-mode chip.
     - Body sections (each separated by `Divider(height: 1)`):
       - Row: `l10n.navIncomes` → `formatNIS(info.totalIn)` (green).
       - Row: `l10n.navExpenses` → `formatNIS(info.totalOut)` (red).
       - Row: `l10n.summaryNet` → signed `formatNIS(info.totalIn - info.totalOut)` colored by sign.
       - Row: `l10n.summaryTransactionCount(info.transactionCount)`.
       - **Only if `info.view == 'monthly'`**: Section header `l10n.summaryOverBudgetTitle`. While loading: `CircularProgressIndicator`. When loaded:
         - Filter `rows.where((r) => (r.result ?? 0) > 0).toList()..sort((a,b) => b.result!.compareTo(a.result!));`
         - If empty: `Text(l10n.summaryNoOverBudget)` greyed.
         - Else: list of rows, each: color dot (parse `row.color` hex), category name (`nameHe ?? name` based on locale), `+formatNIS(row.result!)` in red.
     - Actions: single `TextButton(child: Text(l10n.commonClose), onPressed: () => Navigator.pop(context))`.

7. **Comment out the favorites overlay block** (around line 238–270, the `if (_favoritesExpanded) ...[ ... ]`):
   ```dart
   // ── Favorites overlay (currently disabled — kept for future re-enable) ─────
   // if (_favoritesExpanded) ...[ ... ],
   ```
   Also comment out:
   - The `_favoritesExpanded` field declaration (line 33).
   - `favoriteCategories: vm.favoriteCategories` line in the CategorySidebar invocation (line 77).
   - `favoritesExpanded: _favoritesExpanded` line (line 105).
   - `onFavoritesToggle: () => setState(() => _favoritesExpanded = !_favoritesExpanded)` line (line 106).
   Leave a single comment line above each commented block: `// disabled — see ai_dev/transactions_period_summary_redesign/`.

8. **Add NOTE comment in `transactions_view_model.dart`** above `favoriteCategories` (find with `grep -n favoriteCategories household/lib/screens/transactions/transactions_view_model.dart`):
   ```dart
   // NOTE: favoriteCategories is currently not in use in the UI (Favorites
   // button replaced by Summary popup). Kept here so re-enabling is trivial.
   ```

9. **Color-dot parser helper** (inline in the dialog file):
   ```dart
   Color _parseHexColor(String hex) {
     final clean = hex.replaceFirst('#', '');
     return Color(int.parse('FF$clean', radix: 16));
   }
   ```
   Check first whether a similar helper already exists somewhere central (`grep -rn "parseHex\|fromHex" household/lib/utils/`); reuse if so.

10. **Run analyzer + smoke build:**
    - `cd household && flutter analyze`
    - `cd household && flutter pub get && flutter analyze` (full pass, all files)
    - Optionally `flutter build apk --debug` if reasonable in CI time.

## Execution Log
- Verified contracts from Phase 1a (TimelinePeriodInfo + onPeriodChanged), Phase 1b (CategorySidebar.onSummaryTap + Summary tile + commented favorites), and Phase 1c (commonClose, categorySummary, summaryDialogTitle, summaryNet, summaryTransactionCount, summaryOverBudgetTitle, summaryNoOverBudget). All present.
- Contract drift discovered: `transactions_screen.dart` does NOT use the `CategorySidebar` widget from `lib/widgets/category_sidebar.dart`. It defines its own internal `_TransactionsSidebar` (StatefulWidget at line ~534) with its own favorites tile. Resolved by mirroring the Phase 1b changes inside `_TransactionsSidebar`: added `onSummaryTap` field + constructor param, commented out the favorites tile in `build()`, added a Summary tile in its place using the same `Icons.pie_chart_outline` + `categorySummary` label.
- `lib/screens/transactions/transactions_screen.dart`:
  - Added imports: `utils/financial_calendar.dart` (formatNIS), `models/budget.dart` (MonthBudgetRow), `services/budget_service.dart` (budgetServiceProvider).
  - Added `TimelinePeriodInfo? _periodInfo;` field on `_TransactionsScreenState`.
  - Commented out `_favoritesExpanded` field.
  - Commented out `_hexColor` helper (only consumer was the favorites overlay).
  - Commented out `favoriteCategories: vm.favoriteCategories`, `favoritesExpanded`, `onFavoritesToggle` props in `_TransactionsSidebar` invocation; added `onSummaryTap: () => _showPeriodSummary(context, vm)`.
  - Wired `onPeriodChanged: (info) { if (mounted) setState(() => _periodInfo = info); }` into `TransactionTimeline(...)` invocation.
  - Commented out the entire `if (_favoritesExpanded) ...[ ... ]` overlay block (~63 lines) in the Stack children.
  - In `_TransactionsSidebar`: commented out `final List<Category> favoriteCategories;`, `final VoidCallback? onFavoritesToggle;`, `final bool favoritesExpanded;` fields; added `final VoidCallback? onSummaryTap;` field. Updated constructor to match. Commented favorites usage in `_showSearchSheet` (`...widget.favoriteCategories`).
  - Commented out the favorites tile inside `_TransactionsSidebar.build()` and added a Summary tile (Icons.pie_chart_outline + l10n.categorySummary).
  - Added `_showPeriodSummary(BuildContext, TransactionsViewModel)` method that returns early if `_periodInfo == null` and otherwise opens `_PeriodSummaryDialog`.
  - Added `_PeriodSummaryDialog` (ConsumerStatefulWidget) at the bottom of the file. In `initState`, if `widget.info.view == 'monthly'`, calls `ref.read(budgetServiceProvider).getMonthlyBudget(year, month)` via `Future.microtask` and stores the result with a loading flag. Build returns an `AlertDialog` (rounded 16, max width 360, primary 0xFF222222, secondary 0xFF888888) with a title block (summaryDialogTitle + period label + view-mode chip), four summary rows separated by `Divider(height: 1)` (Incomes green 0xFF2E7D32, Expenses red 0xFFC62828, Net signed-color, transaction-count line), and (only for monthly view) an over-budget section: spinner while loading; `summaryNoOverBudget` greyed if empty or on error; otherwise filtered + sorted-by-overage rows with color dot, `nameHe ?? name` per locale, `+formatNIS(result)` in red. Single `commonClose` action button. Helper `_parseHexColor` inlined (no existing util found by grep).
  - Added a private `_SummaryRow` StatelessWidget for the row layout.
- `lib/screens/transactions/transactions_view_model.dart`:
  - Added a NOTE comment above `favoriteCategories` getter explaining it is currently unused but kept for easy re-enabling.

## Tests Run
- Framework: Flutter widget tests
- Result: not run (no widget tests exist for these screens; manual verification pending)

## Build Analyzers Run
- `flutter analyze lib/screens/transactions/`: clean — `No issues found!`
- `flutter analyze` (full pass): clean — `No issues found!`

## User Verification
Status: awaiting-user-test
Confirmed at: —

## Status
awaiting-user-test
