# Issue 503c: Team Colors and Selection

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** High
**Dependencies:** 503a

---

## Current Behavior

No team color system. Units cannot be visually distinguished by owner. No selection indicators.

---

## Intended Behavior

Team colors and selection visuals:

```lua
-- src/render/team_colors.lua
local team_colors = {}

-- WC3 player colors (12 players + neutral)
local COLORS = {
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
    neutral = {180, 180, 180, 255}, -- Neutral/creeps
}

function team_colors.get(player_id)
    return COLORS[player_id] or COLORS.neutral
end

-- Selection ring
function team_colors.draw_selection(renderer, x, y, radius, selected)
    if selected then
        -- Green selection ring
        renderer:draw_circle(x, y, radius + 4, {0, 255, 0, 255}, false)
        renderer:draw_circle(x, y, radius + 3, {0, 255, 0, 128}, false)
    end
end

-- Multiple selection support
function team_colors.draw_multi_selection(renderer, entities, camera)
    for entity in entities do
        local pos = ecs.get_component(entity, "position")
        local sx, sy = camera.world_to_screen(pos.x, pos.y)
        team_colors.draw_selection(renderer, sx, sy, 16, true)
    end
end
```

---

## Suggested Implementation Steps

1. **Define team color palette**
   - Match WC3 colors exactly
   - 12 player slots + neutral
   - Store as RGBA

2. **Integrate with sprite drawing**
   ```lua
   function sprites.draw_entity_with_color(renderer, camera, entity)
       local owner = ecs.get_component(entity, "owner")
       local color = team_colors.get(owner and owner.player_id)

       -- Use team color for unit fill
       local config = get_visual_config(entity)
       config.color = color
       sprites.draw_shape(renderer, sx, sy, config)
   end
   ```

3. **Implement selection ring**
   - Green circle around selected units
   - Slightly larger than unit
   - Animated pulse (optional)

4. **Support multi-selection**
   - Selection state stored in UI/input system
   - Draw rings for all selected

5. **Add color-blind options**
   - Alternative palette
   - Shape variation per team
   - Patterns instead of just color

6. **Handle neutral/creeps**
   - Gray for neutral hostile
   - White for neutral passive
   - Different indicator for allied

---

## Acceptance Criteria

- [ ] All 12 player colors defined
- [ ] Units show owner's color
- [ ] Selected units have green ring
- [ ] Multi-selection works
- [ ] Neutral units show gray
- [ ] Colors match WC3 palette

---

## Notes

Team colors are essential for gameplay clarity. Players must instantly recognize unit ownership.

**Selection state:**
The sprite system reads selection state from somewhere (input system, UI system, or dedicated selection component). This issue defines the rendering, not the selection logic itself.

**Color application:**
For placeholder shapes, team color is the fill. For real sprites, team color would be applied to specific texture regions.

---

## Related Documents

- issues/503a-core-sprite-system.md (base rendering)
- issues/505e-input-commands.md (selection logic)
- issues/407-create-player-state-management.md (player ownership)
