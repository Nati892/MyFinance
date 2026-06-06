# Phase 1 — Header Pills With Wrap

## Goal
In `household/lib/widgets/transaction_timeline.dart`: extend `WeekGroup` and `DayGroup` with split totals, drop the embedded sum from their `label`, and re-render `_WeekGroupTile` + `_DayGroupTile` so they show the existing `_Pill` widgets inline with the label, hiding zero sides and wrapping to a second line at large font scales.

## Depends On
None — previous plan (`transactions_period_summary_redesign`) is complete and lives entirely upstream of this change.

## Parallel With
None.

## Steps

### 1. Extend data classes (lines ~197–225)
Add `totalIn` and `totalOut` to both `DayGroup` and `WeekGroup`. Keep the existing `total` field — it's read elsewhere; do not remove without checking.

```dart
class DayGroup {
  final String label;
  final String dateKey;
  final double total;
  final double totalIn;
  final double totalOut;
  final List<TimelineTx> transactions;
  bool collapsed;
  DayGroup({
    required this.label,
    required this.dateKey,
    required this.total,
    required this.totalIn,
    required this.totalOut,
    required this.transactions,
    this.collapsed = false,
  });
}

class WeekGroup {
  final int weekNumber;
  final String label;
  final double total;
  final double totalIn;
  final double totalOut;
  final List<DayGroup> dayGroups;
  bool collapsed;
  WeekGroup({
    required this.weekNumber,
    required this.label,
    required this.total,
    required this.totalIn,
    required this.totalOut,
    required this.dayGroups,
    this.collapsed = false,
  });
}
```

### 2. Compute split totals + drop sum from labels

**`_groupByDay` (around line ~474):**
- Compute `totalIn = sum where txType == 'income'`, `totalOut = sum where txType == 'expense'`.
- Drop `· ${formatNIS(total)}` from the label. New label: `buildDayLabel(date, locale: _locale)`.
- Pass `totalIn` and `totalOut` to the `DayGroup` constructor.

**`_buildMonthlyGroups` (around line ~425):**
- For each week, compute `totalIn` / `totalOut` over the week's transactions.
- Drop `· ${formatNIS(total)}` from the label. New label: `'$wk ${week.weekNumber} · ${week.label}'`.
- Pass split totals to `WeekGroup`.
- Empty-week branch (lines 427–430): pass `totalIn: 0, totalOut: 0`.

### 3. New `_HeaderPillRow` helper widget

Add near the bottom of the file, next to `_PeriodTotalsBadge` (~line 1871). Hides zero sides; reuses `_Pill` unchanged.

```dart
class _HeaderPillRow extends StatelessWidget {
  final double totalIn;
  final double totalOut;
  const _HeaderPillRow({required this.totalIn, required this.totalOut});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (totalIn > 0) {
      children.add(_Pill(icon: Icons.arrow_drop_up, color: const Color(0xFF2E7D32), amount: totalIn));
    }
    if (totalOut > 0) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 6));
      children.add(_Pill(icon: Icons.arrow_drop_down, color: const Color(0xFFC62828), amount: totalOut));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
```

Note: not reusing `_PeriodTotalsBadge` directly because the period badge always renders both pills — group headers must hide-zero.

### 4. Re-render `_WeekGroupTile` (around line ~787)

Replace the `Row` containing `[chevron, SizedBox, Text(label)]` with a `Wrap` so that label + pills flow to a second line at large font scales. Keep the chevron on the same line as the label visually by grouping them.

```dart
GestureDetector(
  onTap: () => setState(() => _collapsed = !_collapsed),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_collapsed ? Icons.expand_more : Icons.expand_less,
                size: 16, color: const Color(0xFF888888)),
            const SizedBox(width: 4),
            Text(widget.group.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555))),
          ],
        ),
        _HeaderPillRow(totalIn: widget.group.totalIn, totalOut: widget.group.totalOut),
      ],
    ),
  ),
),
```

### 5. Re-render `_DayGroupTile` (around line ~828)

Replace the single `Padding(child: Text(group.label, …))` header with a `Wrap` containing label + pill row.

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
  child: Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 2,
    children: [
      Text(group.label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFAAAAAA),
              fontWeight: FontWeight.w500)),
      _HeaderPillRow(totalIn: group.totalIn, totalOut: group.totalOut),
    ],
  ),
),
```

### 6. Verify no other consumers
`grep` for `\\.total[^I]` / `WeekGroup\\(` / `DayGroup\\(` to make sure nothing else constructs these or reads `.total` in a way that would break with the added fields. Adding new required constructor params will surface any other call sites at compile time.

## Execution Log
- 26050611 — Added `totalIn` / `totalOut` to `DayGroup` (line ~197) and `WeekGroup` (line ~213).
- 26050611 — `_buildMonthlyGroups` now computes income / expense splits and drops the trailing sum from week labels (label is now `Week N · range`); empty-week branch passes zeros.
- 26050611 — `_groupByDay` now computes day-level splits and drops the trailing sum from day labels.
- 26050611 — `_WeekGroupTile` header rewrapped in `Wrap` so chevron+label and pill row reflow at large font scales.
- 26050611 — `_DayGroupTile` header rewrapped in `Wrap` with the new pill row.
- 26050611 — Added `_HeaderPillRow` widget next to `_PeriodTotalsBadge`. Hides the side that is zero. Reuses `_Pill` unchanged.
- 26050611 — Verified via grep that `WeekGroup(` / `DayGroup(` are constructed only inside `transaction_timeline.dart` — no external call sites broken by the new required ctor params.

## Tests Run
- Framework: Flutter
- Existing test suite: only `test/widget_test.dart` placeholder (`test('placeholder', () => expect(true, isTrue))`). No real widget tests exist for this file.
- Result: no targeted tests added (per project convention — none exist for the timeline). Skipping `flutter test` as it would only run the placeholder.

## Build Analyzers Run
- `flutter analyze lib/widgets/transaction_timeline.dart` → **No issues found** (2.8s).
- `flutter analyze` (full project) → **No issues found** (7.9s).

## User Verification
Status: pending
Confirmed at: —
- Verify monthly view week headers show split pills with no embedded sum.
- Verify weekly view day headers show split pills.
- Verify day headers nested under expanded week headers also show pills.
- Verify income-only days show only ▲ green pill; expense-only days show only ▼ red pill.
- Verify Settings → Font Size → Large doesn't clip headers — pills should wrap to a second line on narrow screens.
- Verify RTL (Hebrew locale): pill order and label alignment look correct.

## Status
awaiting-user-test
