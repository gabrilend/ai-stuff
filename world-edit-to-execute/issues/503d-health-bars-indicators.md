# Issue 503d: Health Bars and Indicators

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** High
**Dependencies:** 501 (the page format)
**Re-cut:** 2026-09-26, from "Health Bars and Indicators"

---

## Current Behavior

Hit points show only as text and a bar in the bottom panel for the
selected unit (`src/render/ui.c`, 508g). Render slots carry no hit points,
so nothing can be drawn over units in the world.

## Intended Behavior

Each unit's page item carries its hit-point fraction and, when it has mana,
its mana fraction. The renderer draws a bar over the unit, facing the
camera, coloured green to red by the fraction as WC3 does, and a mana bar
beneath it. Shown the way WC3 shows them: for selected and hovered units,
and for all units while the "show bars" key is held.

## Suggested Implementation Steps

1. Hit-point and mana fractions on the unit item.
2. Bars drawn above the unit's height (its model's bounds, or the
   placeholder's).
3. Which units show bars: selected, hovered, or all while the key is held.

## Acceptance Criteria

- [ ] Bars show over selected and hovered units, and over all while the key is held
- [ ] The bar's colour follows the fraction

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No health bars or status indicators above units. Players cannot see unit health without selecting.

---

### Intended Behavior

Health bars and status indicators:

```lua
-- src/render/health_bars.lua
local health_bars = {}

-- Bar dimensions
local BAR_WIDTH = 32
local BAR_HEIGHT = 4
local BAR_OFFSET_Y = -20  -- Above unit

-- Draw health bar
function health_bars.draw(renderer, x, y, current, max, color)
    local bar_x = x - BAR_WIDTH / 2
    local bar_y = y + BAR_OFFSET_Y

    -- Background (dark)
    renderer:draw_rect(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT,
                      {40, 40, 40, 255}, true)

    -- Health fill
    local fill_width = (current / max) * BAR_WIDTH
    renderer:draw_rect(bar_x, bar_y, fill_width, BAR_HEIGHT, color, true)

    -- Border
    renderer:draw_rect(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT,
                      {0, 0, 0, 255}, false)
end

-- Color based on health percentage
function health_bars.get_color(current, max)
    local pct = current / max
    if pct > 0.5 then
        return {0, 255, 0, 255}    -- Green
    elseif pct > 0.25 then
        return {255, 255, 0, 255}  -- Yellow
    else
        return {255, 0, 0, 255}    -- Red
    end
end

-- Draw mana bar (for heroes/casters)
function health_bars.draw_mana(renderer, x, y, current, max)
    local bar_x = x - BAR_WIDTH / 2
    local bar_y = y + BAR_OFFSET_Y + BAR_HEIGHT + 1

    local fill_width = (current / max) * BAR_WIDTH
    renderer:draw_rect(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT,
                      {40, 40, 40, 255}, true)
    renderer:draw_rect(bar_x, bar_y, fill_width, BAR_HEIGHT,
                      {0, 128, 255, 255}, true)  -- Blue
end
```

---

### Suggested Implementation Steps

1. **Create health bar module**
   - Define bar dimensions as constants
   - Create draw function for single bar

2. **Implement color gradient**
   - Green (>50%), Yellow (25-50%), Red (<25%)
   - Smooth gradient optional

3. **Position above units**
   - Offset from unit center
   - Scale with zoom (optional)
   - Avoid overlapping

4. **Add mana bars**
   - Displayed below health
   - Blue color
   - Only for units with mana

5. **Implement display modes**
   ```lua
   health_bars.mode = "always"  -- "always", "selected", "damaged", "hover"

   function health_bars.should_draw(entity)
       if health_bars.mode == "always" then return true end
       if health_bars.mode == "selected" then return is_selected(entity) end
       if health_bars.mode == "damaged" then return current < max end
       return false
   end
   ```

6. **Add status icons (future)**
   - Small icons for buffs/debuffs
   - Positioned near health bar

---

### Acceptance Criteria

- Health bars draw above units
- Color reflects health percentage
- Bars scale with current/max health
- Mana bars appear for casters
- Display modes work (always, selected, damaged)
- Bars are readable at normal zoom

---

### Notes

Health bars are critical UI feedback. Players constantly check unit health during combat.

**WC3 behavior:**
- Health bars always visible for selected units
- Show on hover for other units
- Option to always show all health bars

**Performance:**
Drawing bars for hundreds of units can be expensive. Consider:
- Only draw for visible units
- Batch bar drawing
- Skip bars below certain size when zoomed out

---

### Related Documents

- issues/503a-core-sprite-system.md (draws after sprites)
- issues/503c-team-colors-selection.md (selection affects display)
- src/runtime/ecs/ (health component)
