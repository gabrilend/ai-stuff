# Issue 038: TUI Panel Abstraction Layer

## Current Behavior

The `tui.lua` library now has hierarchical dirty tracking (Issue 037) with three levels:
- **Full screen**: `dirty_full` flag, `invalidate()`
- **Row level**: `dirty_rows[y]` table, `invalidate_row(y)`
- **Cell level**: `dirty_cells[y][x]` tables, auto-marked by `set_cell()`

However, there is no intermediate abstraction for logical UI regions. Applications like
`history-viewer.lua` manually calculate absolute screen positions for headers, content
areas, and footers. This leads to:
- Scattered coordinate calculations throughout application code
- No encapsulation of related UI regions
- Cannot easily say "update this panel" without knowing its absolute coordinates
- Difficult to implement scrollable sub-regions within a larger layout

## Intended Behavior

Add a **Panel** abstraction layer between cells/rows and the full screen:

```
┌────────────────────────────────────────────────────┐
│ Screen (dirty_full)                                 │
│  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │ Panel A (header)    │  │ Panel B (sidebar)   │  │
│  │  └─ rows (dirty_rows)│  │  └─ rows            │  │
│  │      └─ cells       │  │      └─ cells       │  │
│  └─────────────────────┘  └─────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │ Panel C (content area)                       │  │
│  │  └─ rows (dirty_rows within panel bounds)    │  │
│  │      └─ cells (dirty_cells within bounds)    │  │
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │ Panel D (footer/status bar)                  │  │
│  └──────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────┘
```

### Core Panel Features

1. **Panel Definition**: Create panels with screen position and dimensions
   ```lua
   local header = tui.create_panel(1, 1, cols, 3)  -- row, col, width, height
   local content = tui.create_panel(4, 1, cols, rows - 5)
   local footer = tui.create_panel(rows - 1, 1, cols, 2)
   ```

2. **Relative Coordinates**: Write to panel-local positions
   ```lua
   header:write_str(1, 1, "Title")     -- Row 1 within header = screen row 1
   content:write_str(1, 1, "Line 1")   -- Row 1 within content = screen row 4
   footer:write_str(1, 1, "Status")    -- Row 1 within footer = screen row (rows-1)
   ```

3. **Panel Invalidation**: Mark entire panel for redraw
   ```lua
   content:invalidate()  -- Marks all rows within panel bounds dirty
   ```

4. **Row-within-Panel Invalidation**: Mark specific row in panel
   ```lua
   content:invalidate_row(5)  -- Row 5 within panel = screen row 8
   ```

5. **Panel Bounds Checking**: Writes outside panel bounds are clipped/ignored
   ```lua
   header:write_str(10, 1, "text")  -- Ignored: row 10 is outside 3-row header
   ```

### API Design

```lua
-- Panel creation
local panel = tui.create_panel(screen_row, screen_col, width, height)

-- Panel properties (read-only)
panel.row     -- Screen row of top-left corner
panel.col     -- Screen column of top-left corner
panel.width   -- Panel width in columns
panel.height  -- Panel height in rows

-- Panel operations (mirror tui.* but with panel-relative coordinates)
panel:set_cell(row, col, char)       -- Panel-relative position
panel:write_str(row, col, str)       -- Panel-relative position
panel:clear()                        -- Clear entire panel
panel:clear_row(row)                 -- Clear row within panel
panel:invalidate()                   -- Mark entire panel dirty
panel:invalidate_row(row)            -- Mark row within panel dirty

-- Style operations (affect subsequent writes)
panel:set_fg(fg)
panel:set_bg(bg)
panel:set_attrs(attrs)
panel:reset_style()

-- Coordinate conversion (for advanced use)
panel:to_screen(panel_row, panel_col)   -- Returns screen_row, screen_col
panel:from_screen(screen_row, screen_col) -- Returns panel_row, panel_col, in_bounds
```

### Implementation Approach

Panels can be implemented as thin wrappers that translate coordinates:

```lua
-- Pseudocode for panel implementation
local Panel = {}
Panel.__index = Panel

function Panel:set_cell(row, col, char)
    -- Bounds check
    if row < 1 or row > self.height then return end
    if col < 1 or col > self.width then return end

    -- Convert to screen coordinates
    local screen_row = self.row + row - 1
    local screen_col = self.col + col - 1

    -- Delegate to main tui
    tui.set_cell(screen_row, screen_col, char)
end

function Panel:invalidate()
    -- Invalidate all rows in panel bounds
    for y = self.row, self.row + self.height - 1 do
        tui.invalidate_row(y)
    end
end
```

### Hierarchy Integration

Panels integrate with existing dirty tracking:
- `panel:set_cell()` calls `tui.set_cell()` which auto-marks dirty
- `panel:invalidate()` calls `tui.invalidate_row()` for each row in bounds
- `panel:invalidate_row()` calls `tui.invalidate_row()` with translated coordinate
- `tui.invalidate()` (full screen) supersedes all panel-level dirty state

## Suggested Implementation Steps

1. [ ] Create `Panel` class/metatable with position and dimension fields
2. [ ] Implement `tui.create_panel(row, col, width, height)` constructor
3. [ ] Implement `panel:set_cell()` with bounds checking and coordinate translation
4. [ ] Implement `panel:write_str()` delegating to `panel:set_cell()` per character
5. [ ] Implement `panel:clear()` and `panel:clear_row()` with translation
6. [ ] Implement `panel:invalidate()` and `panel:invalidate_row()`
7. [ ] Add style operations (delegate to global `tui.set_fg()` etc., or panel-local style)
8. [ ] Add coordinate conversion utilities for advanced use cases
9. [ ] Update history-viewer to use panels (header, content, footer)
10. [ ] Document API in code comments

## Acceptance Criteria

- [ ] Panels can be created with arbitrary screen positions
- [ ] Panel operations use relative coordinates
- [ ] Writes outside panel bounds are safely ignored
- [ ] Panel invalidation integrates with existing dirty tracking
- [ ] History-viewer can be refactored to use panels
- [ ] No regression in existing TUI functionality

## Design Questions (Future Considerations)

### Z-ordering / Overlapping Panels
Should panels support overlapping with explicit z-order? For now, NO:
- Keep it simple; panels don't occlude each other
- Applications manage non-overlapping layouts themselves
- Overlapping UI can be added later if needed (Issue XXX)

### Panel-Local Style State
Should each panel have its own fg/bg/attrs state? Options:
1. **Global only**: All style calls affect global state (current approach)
2. **Panel-local optional**: `panel:push_style()` / `panel:pop_style()`
3. **Panel-local required**: Each panel has independent style

Recommendation: Start with global only (option 1), add local style if needed.

### Panel Borders
Should panels have built-in border drawing? For now, NO:
- Applications can use existing `tui.draw_box_*` functions
- Keeps panel abstraction minimal
- Border support can be added as optional feature

## Dependencies

### Blocked By
- **Issue 037**: TUI Dirty Tracking Optimization (completed)
  - Panels rely on `invalidate_row()` for efficient updates

### Related Issues
- **Issue 036**: Commit History Viewer (first application to benefit)
- **Issue 004**: TUI Menu Incremental Rendering (could use panels)

## Metadata

- **Priority**: Medium (nice-to-have for code organization)
- **Complexity**: Medium (coordinate translation is straightforward)
- **Impact**: Improves TUI application code organization and maintainability
