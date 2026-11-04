# Issue 055: the bash menu scrolls a tall list inside its box

## Current Behavior

`libs/menu.sh`, the pure-bash menu used where LuaJIT is missing, draws every
section and item at a fixed row below the header, however many there are. A
menu taller than the screen runs off the bottom. The terminal clamps cursor
moves to its last row, so the items past the bottom are drawn on top of each
other there. The description area and footer are drawn over the lower items,
and a later section can't be seen at all, even with the cursor on it. In a
40-row terminal, a menu of 30 letters and 10 numbers shows L01–L30 with the
footer over the last of them. Pressing G puts the cursor on N10, which never
appears.

## Intended Behavior

A list taller than its room scrolls inside the box: the header, description
area and footer stay where they are, the list shows a window around the
cursor, and a scrollbar shows where that window is. A menu that fits draws
exactly as before.

## Suggested Implementation Steps

1. Work out the rows the list has: the screen less the header, footer,
   description lines and the separator above them.
2. Count the list in lines (title, underline, items and a blank line per
   section) and keep a scroll offset that moves just enough to keep the
   cursor's line in the window.
3. Draw only the lines inside the window, and cache screen rows only for the
   items drawn, so incremental updates fall back to a full redraw when the
   cursor leaves the window.
4. Draw a scrollbar in the last column while the list scrolls.
5. Test it with the screen replay at 40 rows.

## Decisions

- **Minimal scrolling, like the Lua menu's section viewports (015).** The
  window moves only when the cursor would leave it, and by as little as
  possible: stepping past the last row scrolls one line. The one exception is
  moving up into a section. If the section's title and the cursor's item fit
  in the window together, the window shows the title too, so a section is not
  left without its heading when that can be avoided.
- **A scrolling list stops at its last item.** The blank line after the last
  section is left out of the scroll range, so G puts the last item on the last
  row and the scrollbar's thumb reaches the bottom.
- **The scrollbar is in the screen's last column**, a dim `│` track with a `█`
  thumb sized to the share of the list shown, as the Lua menu draws it. The
  incremental update's `ESC[K` clears to the end of the line, so it redraws
  the scrollbar after drawing its two rows.
- **Item numbers are counted for hidden items too**, so `1`–`9` and the jump
  keys mean the same item wherever the window is.
- **The whole list scrolls, not each section.** The bash menu has no
  per-section viewport setting, unlike `menu_set_section_max_visible` in the
  Lua menu, and one window is the smallest change that fixes the overflow.
- **Stacked on issue 004's branch** (`claude/issue-004-menu-render`). Both
  change `menu.sh` and the bash-menu scenes in `test-menu-screen.sh`, and the
  viewport test depends on 004's footer fix. Without it the screen scrolls
  and every row is off by one.

## What Happened

Built on branch `claude/bash-menu-viewport`, stacked on
`claude/issue-004-menu-render`.

- `libs/menu.sh`:
  - New `menu_update_viewport`, `menu_screen_row` and
    `menu_render_scrollbar`, with new globals `MENU_SCROLL_OFFSET`,
    `MENU_BODY_ROWS`, `MENU_LIST_LINES` and `MENU_SCROLLING`. The offset
    resets in `menu_init`.
  - `menu_render` clears the row caches on each full draw, works out the
    window, places the description area after the window when the list
    scrolls, and draws the scrollbar.
  - `menu_render_section` counts in list lines and skips the lines outside
    the window.
  - The incremental update redraws the scrollbar.
- `libs/test-menu-screen.sh`:
  - `run_menu` takes `ROWS` (default 30) and `KEY_DELAY` (default 1).
  - A tall bash menu (30 letters and 10 numbers, 46 list lines against 28 rows
    of room at 40 rows) is checked at its start, after 26 steps down, after G,
    and after G then g. The checks cover the window size, which items show and
    where the cursor is, the section titles, the order of description and
    footer, and the scrollbar thumb at top and bottom.
  - The small bash menu is checked to draw no scrollbar.
  - 20 passed, 0 failed. Against the old `menu.sh`, 9 of the 11 new checks
    fail.
- The `menu.sh` row of the README table mentions the scrolling.

## Renumbered

**2026-11-04:** this issue was 041, a number main gave a different issue in
the 2026-11-03 push, so it moved to the next free number, 055.
