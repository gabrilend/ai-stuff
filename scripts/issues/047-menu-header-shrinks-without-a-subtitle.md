# Issue 047: The menu header shrinks to 3 rows when there is no subtitle

## Status
- **Priority**: Low
- **Type**: Look change
- **Status**: Open (filed, not to be built yet: it moves every menu)
- **Created**: 2026-11-03
- **Follows**: issue 045 (the menu's frame on tui panels)

## Current Behavior

`menu.layout` always gives the header 4 rows: box top, title, subtitle,
separator. When a menu has no subtitle, row 3 is drawn as nothing at all,
not even the box's side lines, so the header has a gap in its frame and the
body starts a row lower than it needs to.

## Intended Behavior

With no subtitle the header is 3 rows (box top, title, separator) and the
body starts on row 4, one row more for items, description and preview. With
a subtitle nothing changes.

## Why it waits

Every menu without a subtitle moves its items up a row. Scripts and tests
that read the screen by row (`libs/test-menu-screen.sh`,
`tests/test-menu-layout.sh`, any screen checks in other projects) would need
to follow, and the owner may prefer the steadier look. Decide before
building.

## Suggested Implementation Steps

1. `menu.layout(rows, cols, opts)` takes `opts.has_subtitle`; the header is
   3 rows without it and the body starts right below.
2. `render_header` draws the separator on the header's last row instead of
   row 4.
3. `menu.render` passes `has_subtitle = state.subtitle ~= ""`.
4. Add layout checks for both header heights to `tests/test_menu-layout.lua`
   and a screen check to `tests/test-menu-layout.sh`.
