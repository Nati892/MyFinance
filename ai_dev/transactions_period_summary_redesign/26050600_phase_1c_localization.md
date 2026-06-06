# Phase 1c — Localization Strings

## Goal
Owns all changes in the l10n files: `app_en.arb`, `app_he.arb`, `app_localizations_en.dart`, `app_localizations_he.dart`, `app_localizations.dart`. Add the new strings consumed by Phase 1b (sidebar) and Phase 2 (summary popup).

## Depends On
None.

## Parallel With
Phase 1a and Phase 1b. Disjoint files.

## Contract (consumed by Phase 1b and Phase 2)
The following getters must exist on `AppLocalizations`:

| Key | English | Hebrew |
|---|---|---|
| `categorySummary` | "Summary" | "סיכום" |
| `summaryDialogTitle` | "Period summary" | "סיכום תקופה" |
| `summaryNet` | "Net" | "נטו" |
| `summaryTransactionCount` | "Transactions: {count}" | "תנועות: {count}" |
| `summaryOverBudgetTitle` | "Over budget" | "חריגה מתקציב" |
| `summaryNoOverBudget` | "No categories over budget" | "אין קטגוריות בחריגה" |

Plus, if not already present: `commonClose` ("Close" / "סגור") — check first with grep.

## Steps

1. **Check existing `commonClose`** before adding it:
   `grep -n commonClose household/lib/l10n/app_localizations.dart`. Skip the add for any key that already exists.

2. **Add to `app_en.arb`** (alphabetical or grouped near similar keys):
   ```json
   "categorySummary": "Summary",
   "summaryDialogTitle": "Period summary",
   "summaryNet": "Net",
   "summaryTransactionCount": "Transactions: {count}",
   "@summaryTransactionCount": {
     "placeholders": { "count": { "type": "int" } }
   },
   "summaryOverBudgetTitle": "Over budget",
   "summaryNoOverBudget": "No categories over budget",
   ```

3. **Add to `app_he.arb`** mirrored translations:
   ```json
   "categorySummary": "סיכום",
   "summaryDialogTitle": "סיכום תקופה",
   "summaryNet": "נטו",
   "summaryTransactionCount": "תנועות: {count}",
   "summaryOverBudgetTitle": "חריגה מתקציב",
   "summaryNoOverBudget": "אין קטגוריות בחריגה",
   ```

4. **Update the generated dart files manually** (this project maintains them by hand — confirm by inspection: `head app_localizations_en.dart`):
   - Add abstract getters (and `String summaryTransactionCount(int count)` method for the parameterized one) to `app_localizations.dart`.
   - Add concrete implementations to `app_localizations_en.dart` and `app_localizations_he.dart`, matching the style of nearby getters.

5. **If `l10n.yaml` exists at repo root or in `household/`**, prefer running `flutter gen-l10n` instead of hand-editing the dart files. Check first:
   `ls household/l10n.yaml household/lib/l10n.yaml 2>/dev/null`.

6. **Run analyzer** — `cd household && flutter analyze lib/l10n/`.

## Execution Log
*(Agent appends here as work progresses.)*

- 2026-05-06: Verified `commonClose` did not exist in any l10n file (grep returned nothing).
- 2026-05-06: Added 6 new keys + `commonClose` to `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb` at end of file (after `attachmentsCount`). Included `@summaryTransactionCount` metadata block declaring `count` as int placeholder (mirrored to he via the en template).
- 2026-05-06: Confirmed `household/l10n.yaml` exists, so used `flutter gen-l10n` rather than hand-editing the dart files. The command regenerated `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_he.dart` with the new abstract getters, the `String summaryTransactionCount(int count)` method, and the `AppLocalizationsHe` / `AppLocalizationsEn` concrete implementations.
- 2026-05-06: Ran `flutter analyze lib/l10n/` — `No issues found! (ran in 1.1s)`.

## Tests Run
- Framework: N/A (pure string additions)
- Result: N/A

## Build Analyzers Run
- `flutter analyze lib/l10n/`: No issues found! (ran in 1.1s)

## User Verification
Status: pending
Confirmed at: —

## Status
awaiting-user-test
