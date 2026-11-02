# Issue 004: Fix TUI Menu Incremental Rendering

## Current Behavior

When navigating the menu with UP/DOWN keys, the incremental update renders menu items one row below their intended position. The bug manifests as:

- Item meant for row N appears at row N+1
- This causes visual corruption where items overwrite each other
- Full redraws work correctly; only incremental updates are affected

Debug observations:
- Row calculations in `menu_compute_item_row()` appear correct
- Test scripts (`debug/menu-render-repro.sh`, `debug/menu-render-repro-v2.sh`) with identical logic work correctly
- The bug is specific to `menu.sh` when sourced into `issue-splitter.sh`
- Writing debug markers to `/dev/tty` positions correctly, but content to stdout appears offset

## Intended Behavior

Incremental updates should:
1. Position cursor at exact row where item was rendered during full render
2. Clear that line and write unhighlighted content
3. Position cursor at new item's row
4. Clear that line and write highlighted content
5. No visual artifacts or off-by-one positioning

## Suggested Implementation Steps

1. [x] Use frame-by-frame debug logging to capture exact state at each step
2. [x] Compare full render item row cache vs computed row values
3. [x] Identify source of off-by-one: calculation, ANSI indexing, or terminal state
4. [x] Fix the root cause
5. [ ] Remove debug logging (marked deprecated)
6. [x] Verify with test scripts

## Debug Infrastructure

Frame-by-frame logging added to `libs/menu.sh`:
- Logs stored in: `scripts/debug/menu_frames/`
- `summary.log` - overview of all frames
- `frame_NNNN.txt` - detailed state for each render/update

**IMPORTANT**: Debug logging writes to disk on every navigation. Mark as deprecated and remove once issue is resolved to prevent SSD wear.

## Related Files

- `libs/menu.sh` - Main TUI menu library (contains bug)
- `libs/tui.sh` - Base TUI library
- `debug/menu-render-repro.sh` - Simple test (works correctly)
- `debug/menu-render-repro-v2.sh` - Complex test with sections (works correctly)
- `issue-splitter.sh` - Script using menu.sh (exhibits bug)

## Notes

- Test scripts work correctly with identical row calculation logic
- Suggests the issue may be environmental or related to how menu.sh integrates with the larger system
- User hypothesis: "the issue is not a matter of technology, but of logic"

## Related Work

- **delta-version Issue 037**: TUI Dirty Tracking Optimization (2025-01-05)
  - The Lua TUI library (`scripts/libs/tui.lua`) now has hierarchical dirty tracking
  - `set_cell()` auto-marks dirty, `present()` iterates only dirty entries
  - New APIs: `invalidate()`, `invalidate_row()`, `invalidate_region()`
  - This may simplify any future Lua-based reimplementation of menu functionality

---

## What Happened

Reproduced inside issue-splitter, found and fixed.

**Reproducing it.** issue-splitter no longer uses `menu.sh`: it sources
`lua-menu.sh` only, and without LuaJIT it has no menu at all. So the
reproduction ran a scratch copy of `issue-splitter.sh` with the bash
libraries sourced in its place. The eight functions `menu.sh` lacks
(content sources, dependencies, command preview, viewport) were stubbed as
no-ops. A fake `claude` that refuses was put first on PATH, and the menu was
quit before any run. It was driven in a 78 x 141 pretend terminal (`script`,
the size in the debug frames) with j, j.

The replay first showed nothing wrong, which is why the earlier attempt with a
standalone `menu.sh` harness could not reproduce it: `test-menu-screen-replay.lua`
did not scroll. Taught to behave as a terminal does at its edges (a line feed
on the bottom row scrolls the screen, a character past the last column wraps,
ESC [ K erases, control characters take no cell), it showed the bug exactly as
described. The header's top edge was gone, and the screen read
`1▸ Analyze / 1 Analyze / 2 Feedback / 3▸ Review / 5 Auto-Implement`: every
redrawn item was one row below where the full render had left it, written
over its neighbour.

**The cause.** Every `tui_box_*` helper in `tui.sh` ends with `echo`, a
newline, so that boxes print line after line. The menu's footer draws its
bottom edge on the screen's last row (`TUI_ROWS - 1`), and that newline
scrolled the whole screen up one row right after every full render. The row
cache and `menu_compute_item_row()` were right, as the debug frames showed:
the screen had moved under them. Small test scripts appeared to work because
nothing compared their screen with where the rows ought to be. Writing to
/dev/tty looked right because a debug marker is written after the scroll.

**The fix.** `menu_render_footer` prints the bottom edge without its newline
(`printf '%s' "$(tui_box_bottom ...)"`). The helpers keep their newlines,
since `test-tui.sh` and other box printers rely on them. With the fix, the
same issue-splitter run keeps the header and every item in place; without
it, the off-by-one is back. `git-history.sh -I`, the other user of
`menu.sh`, gets the same fix.

**Tests.** `libs/test-menu-screen.sh` gains a bash `menu.sh` scene: four
items, moved down twice, then down twice and back up once. Each item must
appear once, in order, with the cursor where it was sent (9 passed, 0
failed). Against the old `menu.sh`, the first check reads
`1▸Alpha|1 Alpha|2 Bravo|3▸Charlie|` and fails.

**Decisions.**

- The debug frame logging stays. It writes nothing unless `MENU_DEBUG=1` is
  set, so it causes no SSD wear by default, and it is what showed the row
  arithmetic was sound. The committed `debug/` captures and repro scripts
  stay as the record.
- A bash menu taller than the terminal still scrolls. `menu.sh` has no
  viewport, so an item list longer than the screen pushes rows past the
  bottom; seen at 40 rows with issue-splitter's full menu. That is a missing
  feature of the deprecated bash menu (the Lua menu has viewports, issue
  015), not this bug.

