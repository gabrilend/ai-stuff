# Issue 507c: Unit Dots

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** High
**Dependencies:** 507a, 503

---

## Current Behavior

No unit markers on minimap. Players cannot see unit positions at a glance.

---

## Intended Behavior

Team-colored dots for units on minimap:

```lua
-- src/ui/minimap/unit_dots.lua
local unit_dots = {}

-- Dot sizes by unit type
local DOT_SIZES = {
    unit = 2,
    hero = 4,
    building = 6,
    resource = 3,
}

-- Team colors (same as sprite system)
local TEAM_COLORS = {
    [0] = {255, 3, 3, 255},       -- Red
    [1] = {0, 66, 255, 255},      -- Blue
    [2] = {28, 230, 185, 255},    -- Teal
    [3] = {84, 0, 129, 255},      -- Purple
    [4] = {255, 252, 1, 255},     -- Yellow
    [5] = {254, 138, 14, 255},    -- Orange
    [6] = {32, 192, 0, 255},      -- Green
    [7] = {229, 91, 176, 255},    -- Pink
    [8] = {149, 150, 151, 255},   -- Gray
    [9] = {126, 191, 241, 255},   -- Light Blue
    [10] = {16, 98, 70, 255},     -- Dark Green
    [11] = {78, 42, 4, 255},      -- Brown
    neutral = {255, 255, 255, 255}, -- White for neutral
    resource = {255, 215, 0, 255},  -- Gold for gold mines
    critter = {200, 200, 200, 128}, -- Semi-transparent grey
}

-- Collect visible units for minimap
function unit_dots.collect(ecs, player_id, fog_system)
    local dots = {}

    for entity in ecs.query("position", "unit_type") do
        local pos = ecs.get(entity, "position")
        local unit_type = ecs.get(entity, "unit_type")
        local owner = ecs.get(entity, "owner")

        -- Check visibility (fog of war)
        if fog_system:is_visible(pos.x, pos.y, player_id) then
            local dot = {
                x = pos.x,
                y = pos.y,
                size = DOT_SIZES[unit_type.category] or DOT_SIZES.unit,
                color = unit_dots.get_color(owner, unit_type),
                is_hero = unit_type.category == "hero",
                is_selected = ecs.has(entity, "selected"),
            }
            table.insert(dots, dot)
        end
    end

    return dots
end

function unit_dots.get_color(owner, unit_type)
    if unit_type.category == "resource" then
        return TEAM_COLORS.resource
    end

    if unit_type.category == "critter" then
        return TEAM_COLORS.critter
    end

    if owner then
        local player_slot = owner.player_slot or 0
        return TEAM_COLORS[player_slot] or TEAM_COLORS.neutral
    end

    return TEAM_COLORS.neutral
end

-- Draw dots on minimap
function unit_dots.draw(renderer, minimap, dots)
    for _, dot in ipairs(dots) do
        local mx, my = minimap:world_to_minimap(dot.x, dot.y)

        -- Selection highlight (white outline)
        if dot.is_selected then
            renderer:draw_circle(mx, my, dot.size + 1, {255, 255, 255, 255}, false)
        end

        -- Hero special indicator (diamond shape)
        if dot.is_hero then
            unit_dots.draw_hero_marker(renderer, mx, my, dot.size, dot.color)
        else
            renderer:draw_circle(mx, my, dot.size, dot.color, true)
        end
    end
end

function unit_dots.draw_hero_marker(renderer, x, y, size, color)
    -- Diamond shape for heroes (4 lines)
    local s = size * 1.5
    renderer:draw_line(x, y - s, x + s, y, color, 1)
    renderer:draw_line(x + s, y, x, y + s, color, 1)
    renderer:draw_line(x, y + s, x - s, y, color, 1)
    renderer:draw_line(x - s, y, x, y - s, color, 1)

    -- Fill with draw_rect approximation
    renderer:draw_rect(x - size/2, y - size/2, size, size, color, true)
end

-- Special markers
function unit_dots.draw_attack_alert(renderer, minimap, wx, wy)
    local mx, my = minimap:world_to_minimap(wx, wy)

    -- Flashing red circle
    local flash = math.abs(math.sin(os.clock() * 8))
    local color = {255, 0, 0, 128 + 127 * flash}

    renderer:draw_circle(mx, my, 8, color, false)
    renderer:draw_circle(mx, my, 6, color, false)
end

return unit_dots
```

---

## Suggested Implementation Steps

1. **Define dot sizes**
   - Small for regular units
   - Medium for heroes
   - Large for buildings
   - Distinct for resources

2. **Implement unit collection**
   - Query ECS for positioned units
   - Filter by fog of war visibility
   - Extract position, type, owner

3. **Apply team colors**
   - Use same palette as sprites (503)
   - Special colors for resources, neutrals
   - Support all 12 player colors

4. **Draw dots on minimap**
   - Convert world to minimap coords
   - Draw circles for units
   - Special shape for heroes

5. **Add selection indicator**
   - White outline for selected units
   - Visible at minimap scale

6. **Add alert indicators**
   - Flashing for attacks
   - Pulsing for events

---

## Acceptance Criteria

- [ ] Units appear as colored dots
- [ ] Team colors match player slots
- [ ] Heroes have distinct marker (diamond)
- [ ] Buildings larger than units
- [ ] Selected units highlighted
- [ ] Dots update with unit movement

---

## Notes

Dots must be visible against terrain but not overwhelming. Balance size and color.

**WC3 minimap markers:**
- Units: Small solid circles
- Heroes: Larger, sometimes with special marker
- Buildings: Square or larger dot
- Gold mines: Gold/yellow dot
- Trees: Dark green (often not shown)

**Performance:**
Collect and draw all visible units each frame. Should be fast since minimap is small.

---

## Related Documents

- issues/507a-minimap-module.md (parent component)
- issues/503c-team-colors-selection.md (color palette)
- issues/402-build-entity-component-system.md (ECS queries)
