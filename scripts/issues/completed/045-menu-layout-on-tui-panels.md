# Issue 045: The menu's hand-placed layout moves onto tui panels

## Status
- **Priority**: Medium
- **Type**: Refactor (with one visible fix)
- **Status**: Completed
- **Created**: 2026-11-03
- **Follows**: issue 048 (panels in tui.lua), its step 9
- **Follow-up**: issue 046 (sections and items draw through the body panel)

## Current Behavior

`libs/menu.lua` works out every screen row by hand. The header draws on rows
1-4; the footer starts at `state.rows - 2` when there are shortcut keys to
list and at `state.rows - 1` when there are not; and the description and
preview stop where `footer_rows = 3` and `state.rows - 3` say, whatever the
footer's real height.

So the numbers disagree. Without shortcut keys the footer is 2 rows, but the
body still stops as if it were 3, and the row above the footer stays empty:
a preview loses a line it had room for. A long title is drawn from a column
left of the screen edge, and titles are centred by their length in bytes, so
a title with box characters or accents sits off centre.

## Intended Behavior

One function splits the screen into three tui panels, and every part of the
render asks its panel where it is:

```lua
local l = menu.layout(rows, cols, { has_shortcuts = true })
-- l.header: rows 1-4; l.footer: the last 2 or 3 rows; l.body: between
```

The body runs right down to the footer's top line, whatever the footer's
height. Header and footer text is clipped to its panel and centred by its
width on screen.

## Suggested Implementation Steps

1. [x] `menu.layout(rows, cols, opts)`: pure arithmetic over the screen
       size, so it can be tested without a terminal.
2. [x] `menu.render` lays the screen out once per redraw, after working out
       whether this redraw shows a shortcuts line.
3. [x] Header and footer draw through their panels.
4. [x] The description and preview stop at the body's last row instead of
       `state.rows - 3`.
5. [x] Tests: the layout arithmetic, and a real menu in a pretend terminal.
6. [ ] Sections and items draw through the body panel: issue 046, after
       PR #93 (the dropdown work) lands, since it rewrites `render_item`.

## What Happened

**2026-11-03.** Built in `libs/menu.lua` on branch `claude/menu-on-panels`,
which is stacked on `claude/tui-panels` (PR #151, issue 048), because it
needs `tui.create_panel`.

- `menu.layout` returns `header`, `body` and `footer` panels.
  `render_header` and `render_footer` draw through them; a small
  `footer_text` helper, split out of `render_footer`, tells `menu.render`
  whether the footer is 2 rows or 3 before anything is drawn.
- `render_description` and `render_content_source` stop at the body's last
  row, so a preview now reaches the footer. With shortcut keys the body ends
  where the old code's last preview row was; without them it gains a row.
- Titles, the help line and the shortcuts line are centred with the new
  `tui.display_width` and clipped to their panel.

Two additions to `libs/tui.lua`, asked for by delta-version's history viewer
(PR #189), which uses the same panels:

- `Panel:fill(char)` puts a character (a space by default) in every visible
  cell in the current style, so a panel can be a coloured block.
  `Panel:clear` still leaves plain blanks.
- `tui.display_width(str)` and `tui.char_width(ch)`: the terminal columns a
  UTF-8 string or character takes (0 for control, combining and zero-width
  characters, 2 for wide ones, 1 otherwise), for centring and padding.

Decisions:

- **Only the frame moves now; the sections stay on screen rows.** PR #93
  rewrites `render_item`, `render_section` and the description; moving them
  too would make the two PRs fight over the same lines. They become issue 046.
- **The body fills to the footer's top line.** The old empty row above the
  footer came from the hard-coded 3, not from a wish for a gap; the footer's
  own separator line already divides the two.
- **The header stays 4 rows when there is no subtitle.** Shrinking it would
  move every item up a row in every menu; that is a look change, filed as
  issue 047.
- **On a screen too short for all three, the panels overlap** and the body
  keeps one row; the tui drops whatever lands off the screen. The menu was
  never usable that small, and refusing to draw would be worse.
- **`display_width` measures; it does not change drawing.** The screen grid
  holds one character per cell, so a wide character still pushes the rest of
  its row right. Making cells two columns wide is a bigger change to tui.lua.
- **`test-menu-screen-replay.lua` takes a fourth argument, `all`,** that
  prints blank rows too, so line N of its output is screen row N. Without it
  the output is as before, so `test-menu-screen.sh` is unchanged.

Tests:

- `tests/test_menu-layout.lua` (16 checks, no terminal): footer heights, body
  bounds, screen-row conversion, tiny and zero-width screens.
- `tests/test-menu-layout.sh` (9 checks): two real 24x80 menus with a 100-line
  preview, with and without a shortcut key; the title, the header and footer
  rows, and the last preview line sitting right above the footer. Against the
  old `menu.lua` the check "last preview line sits right above the footer"
  fails for the menu without a shortcut key, which is the bug fixed.
- `tests/test_tui-panels.lua` gains 14 checks for `fill` and
  `display_width` (58 in all).
- `libs/test-menu-screen.sh` still passes 7/0.
