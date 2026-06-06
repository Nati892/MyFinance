# Phase 1 — Note Detail Modal Widget

## Goal
Build a new self-contained widget (`NoteDetailModal`) that:
- Opens as a `showModalBottomSheet` covering ~85% of the screen
  (`isScrollControlled: true`, `DraggableScrollableSheet` with `initialChildSize: 0.85`,
  `minChildSize: 0.5`, `maxChildSize: 0.95`).
- Visually mirrors the underlying `BoardNote` — background = `noteColor`, darkened header
  bar with author username, body uses `textColor` / `textSize` / `isBold` / `isUnderline`
  / `textDirection`. For image notes, body shows the image scrollable / fitted; for heart
  notes, body shows a large `Icon(Icons.favorite)` in `heartColor`.
- Body is vertically scrollable (`SingleChildScrollView`) and shows the full content
  (no clipping).
- Tap on the text area enters edit mode: replaces the `Text` with a multi-line `TextField`
  bound to a controller. Commits content on close / on explicit done. Reuses the existing
  commit path through `BoardViewModel.updateNoteContent`.
- A floating settings bar is pinned to the bottom of the modal (overlaid via `Stack`),
  containing:
  - **Color picker** — opens a dialog with a comfortably scrollable `GridView` of large
    (44×44) swatches. Includes the existing `_kPalette` plus the rainbow swatch that
    opens the full `flutter_colorpicker`. Selecting a color calls
    `BoardViewModel.updateNoteStyle({'noteColor': hex})` and the modal preview re-renders
    via the same `vm.notes` watcher.
  - **Bold / Underline / Text size −/+ / Text direction** (text notes only) — wired to
    `updateNoteStyle`.
  - **Delete** (owner only, all types) — calls `vm.deleteNote(id)` and pops the modal.
- For non-owners (`currentUser.id != note.appUserId`), the settings bar is **hidden**
  (open question — see `_project.md`).

## Depends On
None.

## Parallel With
None.

## Steps

1. **Create `lib/screens/board/note_detail_modal.dart`** with:
   - `class NoteDetailModal extends ConsumerStatefulWidget` taking `noteId` only (it
     reads the latest `BoardNote` from `boardViewModelProvider` so live updates from
     style changes immediately re-render the preview).
   - `static Future<void> show(BuildContext context, int noteId)` helper that calls
     `showModalBottomSheet` with the right config (transparent background, root
     navigator, `isScrollControlled: true`, `DraggableScrollableSheet`).
   - State: `TextEditingController _contentCtrl`, `FocusNode _focusNode`, `bool _editing`.
   - On dispose: if `_editing` and the buffered content differs from the note, commit via
     `vm.updateNoteContent(noteId, _contentCtrl.text)`.
   - Build: a `DraggableScrollableSheet` whose builder returns a `Container` with rounded
     top corners and `noteColor` background, containing:
     - **Header row** (28–40px): author username on the leading side, close (X) and (if
       editing) check icon trailing. Header background = `darken(noteColor, 0.15)`.
     - **Scrollable body** — `Expanded` + `SingleChildScrollView` with padding. Body
       chooses its widget by `note.type`:
       - `text`: a `GestureDetector` that flips `_editing = true` and focuses the field
         on tap; renders `Text` (read mode) or `TextField` (edit mode) with the note's
         text styling, respecting `textDirection`.
       - `image`: `InteractiveViewer` wrapping `Image.memory` (data URL) or
         `Image.network` with an error placeholder.
       - `heart`: large centered `Icon(Icons.favorite, color: hexColor(heartColor), size: ...)`.
     - **Bottom padding** equal to the floating bar's height plus safe-area inset, so the
       last line of body content isn't covered.
   - **Floating settings bar** — `Positioned(left/right/bottom: 0)` containing a
     `Material(elevation: 8, borderRadius: ...)` row of icon buttons. Render only when
     `isOwner`. Buttons:
     - Color swatch (current color circle, tap → `_showColorGrid`)
     - Bold (text only)
     - Underline (text only)
     - A− (text only)
     - A+ (text only)
     - Direction (text only)
     - Delete (red trailing icon; `vm.deleteNote(id)` then `Navigator.pop`)
   - **`_showColorGrid` dialog**: a `Dialog` (not `AlertDialog`) sized to ~80% of the
     screen, with a title row, a comfortably scrollable `GridView.count` (5 columns,
     12px spacing, 44×44 swatch tiles) over the palette + a rainbow tile that opens the
     full `flutter_colorpicker`. Tapping a tile calls
     `vm.updateNoteStyle(noteId, {'noteColor': hex})` and pops the dialog. The modal
     preview re-renders because it watches `boardViewModelProvider`.

2. **Reuse existing palette constants** by lifting `_kPalette` from `board_screen.dart`
   into a small shared `lib/screens/board/board_palette.dart`, or import from
   `board_screen.dart` directly if practical (a `const` top-level list — fine to share).

3. **Re-render guarantee** — the modal `ConsumerState` does
   `final note = ref.watch(boardViewModelProvider).notes.firstWhere((n) => n.id == widget.noteId, orElse: () => null)`.
   If `note == null` (deleted), pop the modal automatically.

4. **Editing UX**:
   - Tap text → `setState(() => _editing = true)` and `_focusNode.requestFocus()`.
   - On close (drag-down dismiss, X tap, check tap, or `Navigator.pop`), if
     `_editing && _contentCtrl.text != note.content`, call
     `vm.updateNoteContent(noteId, _contentCtrl.text)` before popping.
   - Use the same `Directionality` wrapping that `CanvasNoteWidget` uses for `rtl`/`ltr`.

5. **Localization** — reuse existing keys (`boardNoteColor`, etc.) where possible. Don't
   add new ARB strings unless a new label is required (e.g., a "Delete note?" confirm).
   If a confirm is added, add `boardDeleteNote` / `boardDeleteNoteConfirm` to
   `app_en.arb` + `app_he.arb` and re-run codegen via `flutter gen-l10n` (or `flutter
   pub run build_runner build` if that's how the project generates).

## Execution Log
*(Agent appends here as work progresses.)*

## Tests Run
- Framework: TBD — likely `flutter test` (project has a Flutter `pubspec.yaml`)
- Result: pending
- Output: pending

## Build Analyzers Run
- `flutter analyze`: pending
- `dart format --set-exit-if-changed`: pending

## User Verification
Status: pending
Confirmed at: —

## Status
planned
