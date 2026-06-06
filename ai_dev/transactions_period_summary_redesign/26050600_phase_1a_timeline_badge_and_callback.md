# Phase 1a — Timeline: Totals Badge + Period Callback

## Goal
Owns all changes in `lib/widgets/transaction_timeline.dart`:
1. Replace the single `formatNIS(grandTotal)` line under the period label with a small two-pill badge: ▲ (green) total income · ▼ (red) total expense for the currently selected period.
2. Surface the active period to the parent via a new `onPeriodChanged` callback prop, so the parent (transactions_screen) can build a summary popup that follows chevron navigation.

## Depends On
None.

## Parallel With
Phase 1b (category_sidebar.dart) and Phase 1c (l10n). All three touch disjoint files.

## Contract (consumed by Phase 2)
The screen will call this widget like:
```dart
TransactionTimeline(
  ...existing props...,
  onPeriodChanged: (info) => setState(() => _periodInfo = info),
)
```
where `TimelinePeriodInfo` is exported from this file with the exact shape:
```dart
class TimelinePeriodInfo {
  final String view;        // 'monthly' | 'weekly' | 'daily'
  final String label;       // human-readable, matches _navLabel
  final int year;           // financial month year (used for budget lookup)
  final int month;          // financial month 1-12 (used for budget lookup)
  final double totalIn;
  final double totalOut;
  final int transactionCount;
  const TimelinePeriodInfo({...});
}
```
**Do not change these field names without updating Phase 2.**

## Steps

1. **Add `TimelinePeriodInfo` data class** at the top of `transaction_timeline.dart` (or near the existing top-of-file data classes). All fields `final`, `const` constructor.

2. **Add the new prop** to `TransactionTimeline`:
   - `final ValueChanged<TimelinePeriodInfo>? onPeriodChanged;`
   - Optional, default null.

3. **Compute the two totals in `build()`** (around line 464):
   - `final totalIn = widget.transactions.where((t) => t.txType == 'income').fold(0.0, (s, t) => s + t.amount);`
   - `final totalOut = widget.transactions.where((t) => t.txType == 'expense').fold(0.0, (s, t) => s + t.amount);`
   - Drop the old `grandTotal` variable.

4. **Update `_buildNavRow`** (lines ~515–553):
   - Change signature to `_buildNavRow(double totalIn, double totalOut)`.
   - Remove the second `Text(formatNIS(total), ...)` under the period label.
   - In its place, render a `_PeriodTotalsBadge(totalIn: totalIn, totalOut: totalOut)`.

5. **Add `_PeriodTotalsBadge` and `_Pill` private widgets** (at the bottom of the file):
   ```dart
   class _PeriodTotalsBadge extends StatelessWidget {
     final double totalIn;
     final double totalOut;
     const _PeriodTotalsBadge({required this.totalIn, required this.totalOut});

     @override
     Widget build(BuildContext context) {
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           _Pill(icon: Icons.arrow_drop_up, color: const Color(0xFF2E7D32), amount: totalIn),
           const SizedBox(width: 8),
           _Pill(icon: Icons.arrow_drop_down, color: const Color(0xFFC62828), amount: totalOut),
         ],
       );
     }
   }

   class _Pill extends StatelessWidget {
     final IconData icon;
     final Color color;
     final double amount;
     const _Pill({required this.icon, required this.color, required this.amount});

     @override
     Widget build(BuildContext context) {
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
         decoration: BoxDecoration(
           color: color.withValues(alpha: 0.10),
           borderRadius: BorderRadius.circular(10),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Icon(icon, size: 16, color: color),
             const SizedBox(width: 2),
             Text(formatNIS(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
           ],
         ),
       );
     }
   }
   ```

6. **Fire `onPeriodChanged`** whenever the displayed period changes:
   - In `build()` after computing totals, schedule a post-frame call to `widget.onPeriodChanged?.call(...)`. Use `WidgetsBinding.instance.addPostFrameCallback` to avoid setState-during-build issues.
   - Compute `year`/`month` from `_period` (the `FinancialPeriod`). The existing `getFinancialPeriod` returns a struct with start date — derive `year` and `month` from that. (Inspect existing imports: `getFinancialPeriod`, `FinancialPeriod` are already imported.)
   - Build the `TimelinePeriodInfo` and call the callback.
   - Guard against duplicate fires: keep a `TimelinePeriodInfo? _lastEmitted` field and only call when meaningfully different (compare year/month/view/label/transaction count).

7. **Run analyzer** — `cd household && flutter analyze lib/widgets/transaction_timeline.dart`.

## Execution Log
- Added public `TimelinePeriodInfo` data class at the top of `transaction_timeline.dart` with all required fields (`view`, `label`, `year`, `month`, `totalIn`, `totalOut`, `transactionCount`) and a `const` constructor.
- Added optional `final ValueChanged<TimelinePeriodInfo>? onPeriodChanged;` prop to `TransactionTimeline`.
- Added `_lastEmitted` field on the state class for change-guarded emission.
- Replaced `grandTotal` in `build()` with separate `totalIn` (income fold) and `totalOut` (expense fold) calculations.
- Added `_maybeEmitPeriod` helper that derives `year`/`month` from `_activeDate` for daily view and from `_period.start` for weekly/monthly, builds a `TimelinePeriodInfo`, and schedules `onPeriodChanged` via `WidgetsBinding.instance.addPostFrameCallback` when meaningful fields differ from `_lastEmitted` (compares view, label, year, month, transactionCount, totalIn, totalOut).
- Updated `_buildNavRow` signature to `(double totalIn, double totalOut)` and replaced the colored net-total `Text` with `_PeriodTotalsBadge`.
- Added private `_PeriodTotalsBadge` and `_Pill` widgets at the end of the file using `Icons.arrow_drop_up` (0xFF2E7D32) and `Icons.arrow_drop_down` (0xFFC62828), `formatNIS(amount)` formatting.

## Tests Run
- Framework: Flutter widget tests (none specific to this file)
- Result: not run (out of scope per phase instructions)

## Build Analyzers Run
- `flutter analyze lib/widgets/transaction_timeline.dart`: `No issues found! (ran in 2.1s)`

## User Verification
Status: pending
Confirmed at: —

## Status
awaiting-user-test
