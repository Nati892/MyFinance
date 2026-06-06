# Phase 2 — Wire Board Screen and Remove Inline Toolbar

## Goal
Replace the canvas note's tap-to-select-and-show-inline-toolbar behavior with
tap-to-open-modal. The on-canvas note should keep drag, pinch-scale, and rotate
gestures, but should no longer render the toolbar nor flip into inline edit mode.
Selection visuals (the blue glow / border) can stay since they're harmless feedback,
but selection is no longer required for any interaction.

## Depends On
Phase 1 (`NoteDetailModal` must exist).

## Parallel With
None.

## Steps

1. **Edit `lib/screens/board/board_screen.dart`**
   - Add import: `import 'package:household/screens/board/note_detail_modal.dart';`
   - In `_buildCanvas`, change the `_DraggableNoteItem`'s `onTap` from
     `() => vm.bringToFront(note.id)` to:
     ```dart
     onTap: () {
       vm.bringToFront(note.id);
       NoteDetailModal.show(context, note.id);
     }
     ```
     Keeping `bringToFront` so tapping a stack of notes raises the tapped one.
   - Remove the `onColorChange`, `onBoldChange`, `onUnderlineChange`, `onTextSizeChange`,
     `onDirectionChange`, `onContentChange`, `onDelete` callbacks from the
     `_DraggableNoteItem` constructor in this file (they're moving into the modal). Keep
     the resize / rotate / position callbacks — those are canvas-level gestures.

2. **Edit `lib/screens/board/canvas_note_widget.dart`**
   - Remove the inline edit mode (`_isEditing`, `_textController`, `_focusNode`,
     `_handleTap`, `_commitEdit`, `_onFocusChange`). Tap is now a passthrough to the
     parent's `onTap`.
   - Remove the toolbar (`_buildToolbar`, `_ToolbarBtn`, `_kNoteColors`,
     `_showColorDialog`). The widget should no longer extend its height for a toolbar
     (drop `toolbarExtraH`).
   - Drop the constructor parameters that are no longer used:
     `onColorChange`, `onBoldChange`, `onUnderlineChange`, `onTextSizeChange`,
     `onDirectionChange`, `onContentChange`. Keep `onDelete` only if still used for
     hearts on canvas — since the user wants delete in the modal, **remove `onDelete`
     too** and remove the heart-corner X button. Selection state still controls the
     glow/border but no longer reveals UI.
   - The text body now always renders as `Text` (no `TextField` branch).

3. **Edit `_DraggableNoteItem` in `board_screen.dart`** to drop the removed callback
   parameters and pass through only what `CanvasNoteWidget` still needs.

4. **Edit `lib/screens/board/board_view_model.dart`** — keep the existing methods
   (`updateNoteStyle`, `updateNoteContent`, `deleteNote`, etc.); they're now called from
   the modal instead of the inline toolbar. No model changes required.

5. **Sanity check the `flutter_colorpicker` dependency** — `board_screen.dart` already
   imports `package:flutter_colorpicker/flutter_colorpicker.dart`; the modal will reuse
   it. Confirm `pubspec.yaml` lists it (it does as of the current branch — verify
   nothing changed).

6. **Test pass**:
   - Run `flutter analyze` and fix any warnings.
   - Run `flutter test` (if the project has Flutter widget tests).
   - Manual smoke test (developer machine): tap a text note → modal opens; tap text → can
     edit; pick a color → background changes immediately on modal and on canvas after
     close; close → text persists; delete works; image notes show enlarged image; heart
     notes show large heart with color toggle.

## Execution Log
*(Agent appends here as work progresses.)*

## Tests Run
- Framework: `flutter test`
- Result: pending
- Output: pending

## Build Analyzers Run
- `flutter analyze`: pending

## User Verification
Status: pending
Confirmed at: —

## Status
planned
