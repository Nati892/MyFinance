# Plan: Board Note Detail Modal — Project Manager

## Goal
Replace the board page's "tap-note → select-with-inline-toolbar" UX with a tap-to-open
modal that fills ~85% of the screen, visually mirrors the note (same color, header, text
styling), is vertically scrollable for long content, lets the user edit by tapping the
text, and pins a floating settings bar to the bottom of the modal containing color, bold,
underline, text size, direction, and delete. The new color picker must use clearly visible,
large, comfortably scrollable swatches and apply changes live (re-rendering both the modal
preview and the canvas note) and persist via the existing PUT endpoint.

## Motivation (in user's words)
> "I want to fix the board page, the page that has the notes and images. I want to fix the
> notes for now. when a note is clicked then a note fragment 85% of screen space modal
> pops up and looks like the note itself, only scrollable and showing more text. also on
> the bottom I want a floating board with different settings including color (only this
> time make the colors work)."

## Locked-in Understanding (Talmud round transcript)

### User input → Claude interpretation

| # | User sentence | Interpretation |
|---|---------------|----------------|
| 1 | "fix the board page... notes and images" | Target: `lib/screens/board/` — board screen + note widgets |
| 2 | "fix the notes for now" | Scope: notes only (text/image/heart). Shopping sessions out of scope |
| 3 | "note clicked → 85% modal pops up" | Single-tap on canvas opens ~85% modal. **Replaces** today's select-and-inline-toolbar flow |
| 4 | "looks like the note itself, only scrollable, showing more text" | Modal mirrors the note's appearance (color, header, text styling), is large + vertically scrollable, and tapping the text enters edit mode (saved on close) |
| 5 | "floating board on bottom with different settings including color" | Floating bar pinned to bottom of modal: color, bold, underline, text size, direction, delete. Per-type: text → all; image → color + delete; heart → color + delete |
| 6 | "this time make the colors work" | Prior color picker swatches didn't appear / were hard to scroll. Fix: visible, large swatches, comfortably scrollable, live-applied to note + modal preview, persisted via PUT |
| 7 | "also I'd like to add an image to the note. but don't do it. just do your current assignment" | Out of scope — noted but not implemented this round |

### Decisions on clarifying questions

| # | Question | Decision |
|---|----------|----------|
| 1 | Tap behavior on canvas | Single-tap opens modal; replaces the inline-toolbar-on-select flow |
| 2 | Modal editable? | Yes — tap text inside modal enters edit mode; save on close/dismiss |
| 3 | Applies to which note types | All types — text, image, heart |
| 5 | Color bug nature | Swatches were missing or hard to scroll. Fix: large visible swatches in a comfortably scrollable grid, live-applied to UI, persisted via PUT |
| 6a | Non-owners | Modal still opens for them |
| 6b | Settings bar visibility for non-owners | **Default: hidden / view-only** (see Open Questions — confirm if this should change) |

## Phase Index

| Date | Phase | Descriptor | Parallel Group | Status | File |
|------|-------|------------|----------------|--------|------|
| 26050800 | 1 | note_detail_modal_widget | — | planned | [phase_1](26050800_phase_1_note_detail_modal.md) |
| 26050800 | 2 | wire_board_screen_and_remove_inline_toolbar | — | planned | [phase_2](26050800_phase_2_wire_board_screen.md) |

## Open Questions / Risks
- **Non-owner settings bar**: defaulted to "hidden / view-only" since the user said only
  "modal still opens" without specifying the bar. If they want non-owners to be able to
  recolor/restyle others' notes, flip the `isOwner` gate in phase 1.
- **Edit-on-tap UX inside modal**: tapping the text starts editing. Need to decide whether
  to commit on every keystroke or only on close — current canvas widget commits on focus
  loss; the modal will mirror that (commit on close + on explicit "done" tap).
- **Image notes inside modal**: image notes have content as a base64 data URL or remote
  URL. The modal will show them in a scrollable / zoomable container; no edit affordance
  beyond color + delete (since editing image content is out of scope for this round).
- **Heart notes inside modal**: hearts have no text content, so the modal mostly previews
  a large heart and exposes color + delete.
- **Removing the inline toolbar**: tap-to-edit on canvas is being removed. Drag, pinch
  scale, and rotate gestures must continue to work on the canvas note widget — only the
  selection-driven toolbar / inline edit field is going away.

## History
- `26050800` — plan written after Talmud round; user approved with "ready to plan and
  write your plan for us to continue tomorrow" + "write persistently on disk".
