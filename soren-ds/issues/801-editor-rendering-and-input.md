# 801 — Editor: rendering and input

## Current behavior

The compositor (phase 6) can render surfaces and the radial-menu
chord input (506) produces characters. Nothing yet uses either
to draw text panels or accept text input as the editor needs.

## Intended behavior

The editor app's map renders four text panels — two per screen,
left and right — and accepts radial-menu chord input directed at
whichever panel currently has focus.

Per-panel rendering:

- 40 character columns by default, monospace, in a small bitmap
  font compiled into the kernel image.
- Each character cell is roughly 8 pixels wide by 12 pixels
  tall. Four panels at 40 × 30 lines fit the screen with room
  for the panel borders.
- A double-width mode toggles to 80 columns on one panel,
  hiding the other panel on that screen.
- A blinking cursor marks the focused cell. The cursor's color
  signals the current mode: bright when cursor-mode, dim when
  insert-mode.

Per-panel input:

- The radial-menu chord box (506) emits characters when the
  user strikes a D-pad-plus-face-button chord. Characters land
  in the focused panel at the cursor position.
- The vim-style mode model: pressing both triggers together
  (L1+R1 if right-handed, R1+L1 if left-handed) toggles between
  cursor mode (D-pad moves cursor, no characters insert) and
  insert mode (radial-menu chord inserts characters).
- Cursor-mode navigation: D-pad moves the cursor by one
  character cell per directional event. Sticks move by larger
  jumps (word, line, page) depending on the modifier mode held.

Focus among the four panels lives in the drawer system (608) —
opening a drawer reveals a "focus left panel" / "focus right
panel" option. Pressing it focuses the named panel and closes
the drawer. The user can also tap a panel on a touch screen to
focus it directly.

## Suggested implementation steps

1. The bitmap font (8x12, ASCII + a few extensions). Stored in
   `assets/fonts/` and compiled into the kernel image.
2. `editor_panel_render_box()` — paints one panel to its surface.
3. `editor_mode_state_box()` — atomic mode (cursor / insert)
   per panel.
4. `editor_text_buffer_box()` — the panel's text storage; insert
   and delete at cursor.
5. The vim L+R toggle wired against handedness via 507.

## Related documents

- `docs/004-input-model.md`.
- `docs/008-apps-overview.md` — the dual-pane editor section.
- `notes/vision/000-vision.md`.

## Blocked by

506, 601, 603, 608.

## Blocks

802, 804 (the programming env reuses these panels).
