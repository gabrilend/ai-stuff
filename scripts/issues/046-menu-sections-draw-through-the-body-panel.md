# Issue 046: Menu sections and items draw through the body panel

## Status
- **Priority**: Low
- **Type**: Refactor
- **Status**: Open
- **Created**: 2026-11-03
- **Follows**: issue 045 (the menu's frame on tui panels)
- **Waits on**: PR #93 (`claude/menu-dropdown`), which rewrites `render_item`

## Current Behavior

Since issue 045 the menu's header, footer and body are tui panels, and the
description and preview stop at the body's last row. The sections and items
inside the body still draw on screen rows: `render_section` and
`render_item` take a screen row, call `tui.write_str(row, ...)` directly,
and do not check that they stay inside the body. A menu with more items than
the body holds relies on each section's `max_visible` to stay clear of the
footer.

## Intended Behavior

`render_section` and `render_item` write through `state.layout.body` in body
coordinates, so a long label stops at the body's edge and an item past the
body's last row draws nothing instead of overwriting the footer.

## Suggested Implementation Steps

1. Once #93 has landed, change `render_item(row, ...)` to take a body row and
   write with `body:write_str` / `body:set_cell`.
2. Do the same in `render_section`, its scrollbar, and the command-preview
   lines (`wrap_command_to_lines` widths come from `body.width`).
3. Work out each section's visible count from the body's height where
   `max_visible` is not set.
4. Extend `tests/test-menu-layout.sh` with a menu taller than the screen.
