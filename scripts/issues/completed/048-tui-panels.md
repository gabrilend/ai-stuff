# Issue 048: Panels in tui.lua

## Status
- **Priority**: Medium
- **Type**: Feature
- **Status**: Completed
- **Created**: 2026-11-02
- **Routed from**: delta-version issue 067 (TUI Panel Abstraction Layer)
- **Renumbered**: filed as 039 at first; PR #114 had already taken 039 for
  the test runner, so this is 048

## Current Behavior

`libs/tui.lua` draws into one screen buffer addressed by screen row and
column. A program with a header, a list and a footer works out each screen
row by hand (`menu.lua`, `verdict-viewer.lua`, delta-version's
`history-viewer.lua`). Nothing stops a long line in one region from running
into the next, and "redraw the list" means knowing where the list sits.

delta-version issue 067 designed a panel layer for this. Its decision
(option A) is that the panels belong here, in the shared library, and that
delta-version moves its history viewer onto them afterwards as its own issue.

## Intended Behavior

A panel is a rectangle of the screen with its own row 1, column 1:

```lua
local header = tui.create_panel(1, 1, cols, 3)        -- row, col, width, height
local list   = tui.create_panel(4, 1, cols, rows - 5)
list:write_str(2, 1, "second line of the list")       -- screen row 5
list:invalidate_row(2)
```

The API is the one 067 laid out: fields `row`, `col`, `width`, `height`;
`set_cell`, `write_str`, `clear`, `clear_row`, `invalidate`,
`invalidate_row`; `set_fg`, `set_bg`, `set_attrs`, `reset_style`;
`to_screen` and `from_screen`. Anything outside the panel, or outside the
screen, is dropped.

## Suggested Implementation Steps

1. [x] A `Panel` metatable and `tui.create_panel(row, col, width, height)`.
2. [x] `set_cell` and `write_str` with bounds checks and translation.
3. [x] `clear` and `clear_row`.
4. [x] `invalidate` and `invalidate_row` through the existing dirty tracking.
5. [x] Style calls (global style).
6. [x] `to_screen` and `from_screen`.
7. [x] Tests that need no terminal.
8. [ ] Move delta-version's `history-viewer.lua` onto panels: left for a
       later PR, as 067 asks (its step 9).
9. [ ] Move `menu.lua` onto panels: filed as issue 059 (layout) and 046
       (sections and items).

## What Happened

**2026-11-02.** Built in `libs/tui.lua` under "Panels". Tests are in
`tests/test_tui-panels.lua` (44 checks, no terminal needed).

Decisions:

- **Style is global**, 067's recommended option 1. `panel:set_fg` is
  `tui.set_fg`. Panel-local style can come later if a screen needs it.
- **Invalidation marks only the panel's own cells.** 067's pseudocode marked
  whole screen rows; a panel narrower than the screen would then resend the
  cells beside it. `tui.invalidate_region` already marks whole rows when a
  panel is as wide as the screen and single cells otherwise, so panels use it.
- **Panels are clipped to the screen as well as to themselves.** A footer
  made at `rows - 1` on a small terminal can hang off the bottom. The panel
  is clipped before it reaches `invalidate_region`, which clamps
  out-of-range rows onto the last row and would otherwise mark the wrong row.
  A panel wholly off the screen sends nothing.
- **`clear` and `clear_row` leave the drawing style alone.** `tui.clear_row`
  resets it as a side effect; a blank cell is plain whatever the style, so
  the panel versions do not touch it.
- **Bad sizes are refused when the panel is made.** Width and height must be
  whole numbers of at least 1, and row and col whole numbers. The corner may
  lie off the screen.
- **Fields are plain fields, read but not changed.** To move or resize a panel
  (after a terminal resize), make a new one. No overlap, z-order or borders,
  as 067 decided.
- **Three small additions let the tests run without a terminal**:
  `tui.init_buffers(rows, cols)` makes the buffers at a given size and leaves
  the terminal alone, `tui.get_cell(row, col)` returns a copy of a cell, and
  `tui.set_output(fn)` sends what `present()` would write to `fn`. They are
  also usable by a program that wants a screen in memory.
