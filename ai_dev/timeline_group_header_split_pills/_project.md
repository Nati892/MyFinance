# Plan: Timeline Group Header Split Pills — Project Manager

## Goal
In `transaction_timeline.dart`, replace the single net-sum currently embedded into the week-group header (monthly view) and day-group header (weekly view + nested under expanded weeks) with the same ▲income / ▼expense pill split already used by the period badge at the top of the screen. Pills render inline next to the header label, hide the side that is zero, and wrap to a second line if the user's font scale makes them not fit. Scope is limited to widgets in `transaction_timeline.dart`; no broad font-scale audit.

## Motivation (in user's words)
> "I also wanted to change the individal day/week headers. they also have a sum, instewd of it spkit to incomed ans expenses … make sure also that texts all throughout grow in a [correct] way to fit the settings font size definition"

## Locked-in Understanding (Talmud round transcript)

### Round 1 — User input → Claude interpretation

| # | User sentence | Interpretation |
|---|---------------|----------------|
| 1 | "its complete" | Confirmation that the previous plan (`ai_dev/transactions_period_summary_redesign/`) is user-verified — that plan's phases were flipped to `complete`. |
| 2 | "I also wanted to change the individal day/week headers." | Scope is the per-group header rows inside `transaction_timeline.dart`: `_WeekGroupTile` (line ~791) and `_DayGroupTile` (line ~832). |
| 3 | "they also have a sum, instewd of it spkit to.incomed ans expenses" | Currently `_buildMonthlyGroups` (line ~441) embeds `formatNIS(total)` into the week label, and `_groupByDay` (line ~479) embeds it into the day label. Replace those with the same ▲green / ▼red pill split as `_PeriodTotalsBadge`, aggregated per week / per day. |
| 4 | "make sure also that texts all throughout grow in a [correct] way to fit the settings font size definition" | The app already wraps `MaterialApp` with `MediaQuery(textScaler: TextScaler.linear(fontScale))` (`main.dart:74`). For this change: no `TextScaler.noScaling` in new code, and use `Wrap` instead of fixed `Row` so label + pills flow to a second line at large font scales. |

### Decisions on clarifying questions

| # | Question | Decision |
|---|----------|----------|
| R1-Q1 | Layout — pills inline, trailing-aligned, or stacked? | Inline immediately after the label. |
| R1-Q2 | Day header pills inside an expanded week — show or only week? | Show on both levels. |
| R1-Q3 | If totalIn or totalOut is 0, render as ₪0 or hide? | Hide the zero side. (Diverges from the always-show behavior of the top period badge — applies only to day/week headers.) |
| R1-Q4 | Reuse existing `_Pill` size or slim variant? | Reuse `_Pill` unchanged; revisit only if it looks bad in practice. |
| R1-Q5 | Recurring group tile (line ~849) — include split? | Out of scope — already expense-only, split would be noise. |
| R2-Q1 | Wrap vs ellipsis when label + pills don't fit | Wrap to second line. |
| R2-Q2 | Font-scale audit scope | Only the widgets we're changing (`_WeekGroupTile`, `_DayGroupTile`, the new pill row). No broad app sweep. |

## Phase Index

| Date | Phase | Descriptor | Parallel Group | Status | File |
|------|-------|------------|----------------|--------|------|
| 26050611 | 1 | header_pills_with_wrap | — | awaiting-user-test | [link](26050611_phase_1_header_pills_with_wrap.md) |

Single phase: all changes are in one file (`transaction_timeline.dart`) and tightly coupled (data model fields + widget rendering must move together). No parallel split possible.

## Open Questions / Risks
- **Hide-zero pill** is a small behavior divergence from the top period badge (which always renders both). If the user later wants both consistent, the right move is probably to change the period badge to also hide-zero — flag this if it comes up.
- **Wrap behavior under RTL (Hebrew)** — `Wrap` should mirror correctly via `Directionality`, but pill layout in RTL needs a quick visual check.
- **Recurring group tile total** still shows a single `formatNIS(total)` (line ~913) — explicitly out of scope per Q5.

## History
- `26050611` — Plan created after a 2-round Talmud session.
