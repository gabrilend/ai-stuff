# Issue 506b: Layout System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** High
**Dependencies:** 506a

---

## Current Behavior

No layout system. Components would need manual pixel positioning with no adaptation to screen size.

---

## Intended Behavior

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

## Suggested Implementation Steps

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

## Acceptance Criteria

- [ ] Anchor positioning works for all 9 points
- [ ] Percent sizing relative to parent
- [ ] Fill sizing respects margins
- [ ] Horizontal layout distributes children
- [ ] Vertical layout stacks children
- [ ] Grid layout arranges in rows/columns
- [ ] Screen resize updates all layouts

---

## Notes

Layout should be recalculated lazily, not every frame. Only recalc when dirty.

**WC3 UI layout:**
- Resource bar: top, full width
- Minimap: bottom-left, fixed size
- Unit info: bottom-center
- Command panel: bottom-right, fixed 3x4 grid
- Game view: fills remaining space

---

## Related Documents

- issues/506a-ui-component-system.md (base component)
- issues/506-build-ui-framework.md (parent issue)
- issues/505d-minimal-ui.md (layout example)
