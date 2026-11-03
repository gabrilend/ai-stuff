# tui.lua

The screen library under the Lua menu, the input dialog and the verdict
viewer, and under neocities-modernization's and delta-version's own screens.
It keeps two screen buffers, marks what changed (whole screen, rows or single
cells), and `present()` sends only the marked cells.

## Panels (issue 048)

`tui.create_panel(row, col, width, height)` gives a rectangle with its own
row 1, column 1. Its `write_str`, `set_cell`, `clear`, `clear_row`,
`invalidate` and `invalidate_row` take panel coordinates and drop anything
outside the panel or the screen. Style calls are the global ones.
`to_screen` and `from_screen` convert positions. See
`issues/completed/048-tui-panels.md` for the decisions.

## Without a terminal

`tui.init_buffers(rows, cols)` sets up the buffers and leaves the terminal
alone; `tui.get_cell(row, col)` reads a cell back; `tui.set_output(fn)`
catches what `present()` would send. `tests/test_tui-panels.lua` uses all
three.
