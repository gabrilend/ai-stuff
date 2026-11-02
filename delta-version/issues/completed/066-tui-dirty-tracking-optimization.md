# Issue 066 (was 037): TUI Dirty Tracking Optimization

## Current Behavior (Before)
The tui.lua library compared every cell in back_buffer with front_buffer on each present() call, performing O(rows * cols) comparisons even when only a few cells changed. This was wasteful for operations like scrolling or updating headers where we know exactly what regions changed.

## Intended Behavior
Add hierarchical dirty tracking so that:
1. `set_cell()` automatically marks the cell as dirty
2. `present()` only iterates cells marked dirty, no comparison needed
3. Higher-level operations can mark entire rows or the full screen dirty
4. Operations like `clear_row()` and `clear_back_buffer()` properly mark dirty

## Suggested Implementation Steps
1. [x] Add dirty tracking state: `dirty_full`, `dirty_rows`, `dirty_cells`
2. [x] Modify `set_cell()` to auto-mark cells dirty
3. [x] Add `invalidate()` for full screen redraw
4. [x] Add `invalidate_row(row)` for row-level dirty
5. [x] Add `invalidate_region(row1, col1, row2, col2)` for regions
6. [x] Rewrite `present()` to iterate dirty entries instead of diffing
7. [x] Update `clear_row()` to mark row dirty
8. [x] Update `clear_back_buffer()` to call invalidate()
9. [x] Update `force_redraw()` to use invalidate()
10. [x] Update `resize()` to call invalidate() on size change

## Acceptance Criteria
- [x] `set_cell()` auto-marks dirty without explicit call
- [x] `present()` skips clean cells entirely
- [x] Row-level and full-screen invalidation supported
- [x] All existing functionality preserved
- [x] Syntax check passes
- [x] History-viewer still works

## Performance Notes
The optimization trades memory (dirty flags) for CPU cycles (cell comparisons).
- Best case: Single cell update -> O(1) instead of O(rows * cols)
- Worst case: Full redraw -> same as before
- Typical scrolling: O(rows) row checks + O(dirty_rows * cols) cell iterations

## Related Issues
- 036-commit-history-viewer.md (motivation for this optimization)
- **Blocks**: Issue 067 (TUI panel abstraction layer)

## Completion Notes
Implemented hierarchical dirty tracking in `/mnt/mtwo/programming/ai-stuff/scripts/libs/tui.lua`.
The design follows the user's suggestion: instead of checking "if different", we iterate
entries multiplied by their dirty flag (conceptually: 0 if clean, 1 if dirty).

---

## What Happened

**2026-11-02 — renumbered from 037 to 066.** Two different issues used
the number 037: this one and `completed/037-project-history-narrative-generator.md`. The import that grafted
delta-version's history gave both files the same first commit, but the
issues' own dates settle it. *Project History Narrative Generator* is in the progress record and
the TOC as 037, and it was finished before the TUI work began. The TUI
work followed the commit history viewer (036) in January 2026. The newer
issue, this one, took the next free number. A pointer is left at
`moved-037-tui-dirty-tracking-optimization.md`.
