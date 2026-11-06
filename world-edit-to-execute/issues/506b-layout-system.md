# Issue 506b: Layout System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** High
**Dependencies:** 506a
**Blocks:** 506c, 506d
**Re-cut:** 2026-09-26, from "Layout System"

---

## Current Behavior

`src/render/ui.c` places its panels from the screen size each frame.

## Intended Behavior

Each element is anchored to a corner, edge or centre of its parent, with
offsets and a size; when the window changes size, anchors are resolved to
screen rectangles once and kept. WC3's console proportions (the bottom
console's fixed layout at 4:3, stretched sides on wider screens) are the
default layout.

## Suggested Implementation Steps

1. Anchors and offsets; resolution on resize.
2. The console's default layout.

## Acceptance Criteria

- [ ] Layout is recomputed on resize only
- [ ] The console keeps WC3's layout at 4:3 and at wide sizes

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No layout system. Components would need manual pixel positioning with no adaptation to screen size.

---

### Intended Behavior

Anchoring and positioning system for responsive UI:

```lua
-- src/ui/layout.lua
local layout = {}

-- Anchor points
layout.ANCHOR = {
    TOP_LEFT = {0, 0},
    TOP = {0.5, 0},
    TOP_RIGHT = {1, 0},
    LEFT = {0, 0.5},
    CENTER = {0.5, 0.5},
    RIGHT = {1, 0.5},
    BOTTOM_LEFT = {0, 1},
    BOTTOM = {0.5, 1},
    BOTTOM_RIGHT = {1, 1},
}

-- Layout component mixin
local LayoutMixin = {}

function LayoutMixin:set_anchor(anchor_point, offset_x, offset_y)
    self.anchor = anchor_point or layout.ANCHOR.TOP_LEFT
    self.anchor_offset = {offset_x or 0, offset_y or 0}
    self:invalidate_layout()
end

function LayoutMixin:set_size_mode(width_mode, height_mode)
    -- Modes: "fixed", "percent", "fill", "content"
    self.width_mode = width_mode or "fixed"
    self.height_mode = height_mode or "fixed"
    self:invalidate_layout()
end

function LayoutMixin:set_percent_size(width_pct, height_pct)
    self.width_percent = width_pct
    self.height_percent = height_pct
    self:invalidate_layout()
end

function LayoutMixin:invalidate_layout()
    self._layout_dirty = true
end

function LayoutMixin:calculate_layout()
    if not self._layout_dirty then return end

    local parent = self.parent
    local pw, ph = parent and parent.width or screen_width,
                   parent and parent.height or screen_height

    -- Calculate size
    if self.width_mode == "percent" then
        self.width = pw * (self.width_percent or 1)
    elseif self.width_mode == "fill" then
        self.width = pw - self.margin_left - self.margin_right
    end

    if self.height_mode == "percent" then
        self.height = ph * (self.height_percent or 1)
    elseif self.height_mode == "fill" then
        self.height = ph - self.margin_top - self.margin_bottom
    end

    -- Calculate position from anchor
    local ax, ay = self.anchor[1], self.anchor[2]
    local ox, oy = self.anchor_offset[1], self.anchor_offset[2]

    self.x = (pw * ax) - (self.width * ax) + ox
    self.y = (ph * ay) - (self.height * ay) + oy

    self._layout_dirty = false
end

-- Container layouts
layout.containers = {}

function layout.containers.horizontal(container, spacing)
    spacing = spacing or 0
    local x = 0
    for _, child in ipairs(container.children) do
        child.x = x
        child.y = 0
        x = x + child.width + spacing
    end
end

function layout.containers.vertical(container, spacing)
    spacing = spacing or 0
    local y = 0
    for _, child in ipairs(container.children) do
        child.x = 0
        child.y = y
        y = y + child.height + spacing
    end
end

function layout.containers.grid(container, cols, spacing)
    spacing = spacing or 0
    local col, row = 0, 0
    local cell_w = (container.width - (cols - 1) * spacing) / cols
    local cell_h = cell_w  -- Square cells by default

    for i, child in ipairs(container.children) do
        child.x = col * (cell_w + spacing)
        child.y = row * (cell_h + spacing)
        child.width = cell_w
        child.height = cell_h

        col = col + 1
        if col >= cols then
            col = 0
            row = row + 1
        end
    end
end

return layout
```

---

### Suggested Implementation Steps

1. **Define anchor points**
   - 9 standard anchors (corners, edges, center)
   - Custom anchor support

2. **Implement anchor positioning**
   - Calculate position from anchor + offset
   - Handle parent-relative anchoring

3. **Implement size modes**
   - Fixed (explicit pixel size)
   - Percent (fraction of parent)
   - Fill (expand to parent minus margins)
   - Content (shrink to fit children)

4. **Create layout mixin**
   - Add layout properties to components
   - Dirty flag for recalculation
   - Auto-recalc on resize

5. **Implement container layouts**
   - Horizontal (row)
   - Vertical (column)
   - Grid (rows x cols)

6. **Handle resize events**
   - Propagate resize through hierarchy
   - Recalculate affected layouts
   - Batch layout updates per frame

---

### Acceptance Criteria

- Anchor positioning works for all 9 points
- Percent sizing relative to parent
- Fill sizing respects margins
- Horizontal layout distributes children
- Vertical layout stacks children
- Grid layout arranges in rows/columns
- Screen resize updates all layouts

---

### Notes

Layout should be recalculated lazily, not every frame. Only recalc when dirty.

**WC3 UI layout:**
- Resource bar: top, full width
- Minimap: bottom-left, fixed size
- Unit info: bottom-center
- Command panel: bottom-right, fixed 3x4 grid
- Game view: fills remaining space

---

### Related Documents

- issues/506a-ui-component-system.md (base component)
- issues/506-build-ui-framework.md (parent issue)
- issues/505d-minimal-ui.md (layout example)

## Decisions (2026-11-05)

Made without the owner, and the owner's to overturn (Q-4: Lua; see 506).

1. **WC3's own model:** anchor points as FDF's SetPoint has them (nine
   points, each relative to a point of another frame, with an offset).
   One point plus a size places a frame; two points on an axis stretch
   it. This is `src/ui/anchor.lua`.
2. **Units:** offsets and sizes are in the 4:3 area's units, 960 by 720
   (WC3's 0.8 by 0.6 times 1200), with y going down like the rest of the
   code.
3. **Two roots:** `"screen"` (the window) and `"ui"` (the 4:3 area). The
   4:3 area is always the window's full height, centred. On a window
   narrower than 4:3 it is the whole window, scaled by the width, and
   the extra height lands between the top and the bottom. So whatever
   hangs from the 4:3 area's top and bottom always meets the bars at the
   window's edges.
4. **Resolved on resize only:** `anchor.cache(frames):get(w, h)` and
   `console_frames.cache():get(w, h)` work the layout out once per size.
5. **The console as data:** `src/ui/wc3/console_frames.lua`.
   - The top bar and the console bar stretch across the window.
   - Every part on them keeps its place in the 4:3 area (the minimap and
     command card included), as WC3 does on wide screens.
   - The sizes are `layout.lua`'s fitted into 960 across, so they are
     this project's, not measured from the game. The game's FDF files
     (on the owner's install) would give the real ones.
6. **Same shape as `layout.compute`:** `console_frames.compute(w, h)`
   returns the table `layout.compute(w, h)` returns, so the hud can take
   either. The test draws the hud that way and presses a command button.
   It is not switched on (see 506, decision 3).
7. **Rounding:** rectangles come out in whole pixels, each edge rounded on
   its own, so neighbours meet without gaps.

## What happened (2026-11-05)

- Added `src/ui/anchor.lua` and `src/ui/wc3/console_frames.lua`, with
  info pages.
- Added `src/tests/test_ui_framework.lua`. It checks anchors and their
  refusals, and the console at 4:3, 16:9, 21:9, 5:4 and 4K (on screen,
  parts apart, scaling at 4:3, 4:3 places kept on wide windows). It also
  checks the resize-only cache and the hud running on the anchored
  console.

**Left for the owner:** switching the hud to it, and the console's real
sizes from the game's FDF files. Acceptance criterion 2 ("WC3's layout")
is met for this project's sizes only.
