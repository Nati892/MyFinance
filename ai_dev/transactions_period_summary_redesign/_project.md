# Plan: Transactions Period Summary Redesign — Project Manager

## Goal
On the Transactions page, replace the existing single net-total figure under the period date label with a small inline component showing total income (▲ green) and total expense (▼ red) for the currently selected period. In the category sidebar, disable the bottom Favorites button (commented-out, not deleted) and replace it with a "Summary" button that opens a small popup showing a rich summary of the currently selected period: period label, totals, net, transaction count, and over-budget categories with overage amounts (over-budget list hidden for non-monthly views since budgets are monthly).

## Motivation (in user's words)
> "in the app in the transation page to add the following changes, on the top date range header on top of the list I want to remove the 'total sum', and that total + a green line with up symbol with the total in and a red down arrow with the total out, all those in their own small component … In the categories menu there is a bottom favoriets button, that buttons should be replaced with the month summary, remove the old favorites functionality for now, not in the server, only in the front end app … its should also be a month summary button that just opens a small window with the month summary."

## Locked-in Understanding (Talmud round transcript)

### Round 1 — User input → Claude interpretation

| # | User sentence | Interpretation |
|---|---------------|----------------|
| 1 | "in the app in the transation page to add the following changes" | Scope is the Transactions page (`screens/transactions/transactions_screen.dart` + the `TransactionTimeline` widget that owns the date-range header). |
| 2 | "on the top date range header on top of the list I want to remove the 'total sum'" | In `transaction_timeline.dart` `_buildNavRow`, remove the existing single line that shows `formatNIS(grandTotal)` colored green/red beneath the period label. |
| 3 | "and that total + a green line with up symbol with the total in and a red down arrow with the total out" | Replace it with a small two-segment widget: ▲ (green) total income for the period · ▼ (red) total expense for the period. **No net inside the badge** (per Round 2 Q1). |
| 4 | "all those in their own small component, what compoent?" | New private widget in `transaction_timeline.dart` (e.g. `_PeriodTotalsBadge`), inline in the nav row where the old total used to be. Single Row with two pill segments: green up-triangle + amount, red down-triangle + amount. |
| 5 | "In the categories menu there is a bottom favoriets button, that buttons should be replaced with the month summary" | Replace the Favorites tile in `category_sidebar.dart` (lines ~185–217) with a "Summary" tile in the same slot. |
| 6 | "remove the old favorites functionality for now, not in the server, only in the front end app" | Disable, do not delete (per Round 2 Q5/Q4). Comment out the favorites tile in `category_sidebar.dart` and the `_favoritesExpanded` overlay block in `transactions_screen.dart`. The `CategorySidebar` props and `vm.favoriteCategories` getter stay, with a comment noting they're currently unused. Backend untouched. |
| 7 | "its should also be a month summary button that just opens a small window with the month summary" | New sidebar tile opens a small popup (`showDialog`) showing the summary for the **currently selected period** (follows chevron navigation: monthly/weekly/daily). Contents: period label, total incomes, total expenses, net, transaction count, and over-budget categories with overage (hidden for weekly/daily). |

### Decisions on clarifying questions

| # | Question | Decision |
|---|----------|----------|
| R2-Q1 | Net total in badge — labeled and where? | No net in badge. Net is shown in the popup summary only. |
| R2-Q2 | Up/down icon style | Simple triangle arrows (`Icons.arrow_drop_up` / `Icons.arrow_drop_down`). |
| R2-Q3 | Popup scope — current month vs selected period? | Selected period (follows chevrons). |
| R2-Q4 | Popup contents | Period label + totals + net + transaction count + over-budget categories with overage. |
| R2-Q5 | Favorites removal aggressiveness | Comment out, don't delete. |
| R3-Q1 | Budget data | Read & invoke `BudgetService` for the relevant month. |
| R3-Q2 | "Over budget" for non-monthly periods | Hidden — only show in monthly view. |
| R3-Q3 | Sidebar tile label/icon | `Icons.pie_chart_outline` / "Summary" / "סיכום" — accepted. |
| R3-Q4 | `vm.favoriteCategories` getter | Leave intact; add comment noting it's currently not in use. |

## Phase Index

| Date | Phase | Descriptor | Parallel Group | Status | File |
|------|-------|------------|----------------|--------|------|
| 26050600 | 1a | timeline_badge_and_callback | group 1 | complete | [link](26050600_phase_1a_timeline_badge_and_callback.md) |
| 26050600 | 1b | sidebar_summary_button | group 1 | complete | [link](26050600_phase_1b_sidebar_summary_button.md) |
| 26050600 | 1c | localization | group 1 | complete | [link](26050600_phase_1c_localization.md) |
| 26050600 | 2 | screen_integration | — | complete | [link](26050600_phase_2_screen_integration.md) |

Phases 1a/1b/1c run **in parallel** (single message, multiple Agent calls) — they touch disjoint files: `transaction_timeline.dart` / `category_sidebar.dart` / l10n files. Each defines a contract (prop names, type signatures, l10n keys) consumed by Phase 2.

Phase 2 runs **sequentially after** group 1 completes — it integrates everything in `transactions_screen.dart` (single shared file that all three contracts feed into) and adds a NOTE comment to `transactions_view_model.dart`.

## Open Questions / Risks
- `_buildNavRow` is hard-coded to a fixed height; the new two-pill badge must fit in roughly the same vertical space (it currently shows a 12px font total — replacing with two small pills should still fit but verify visually).
- `BudgetService.getMonthlyBudget` likely fires a network request; the popup should handle the loading state gracefully (skeleton or spinner).
- `TransactionTimeline` exposes the active period internally (`_period`) but doesn't currently surface it to its parent; the over-budget query needs the period's year/month, which we can compute inside the timeline (where the popup is being built) or pass via callback.
- Dark mode / RTL: triangle direction is the same in RTL, so safe; verify alignment of pills under RTL.

## History
- `26050523` — Plan created after Talmud rounds 1–3 (4 sequential phases).
- `26050600` — Plan re-sliced into 3 parallel + 1 sequential phase (file-ownership boundaries) per user request.
- `26050611` — User confirmed all phases complete ("its complete").
