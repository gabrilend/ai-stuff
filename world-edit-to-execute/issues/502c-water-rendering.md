# Issue 502c: Water Rendering

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Medium
**Dependencies:** 502a

---

## Current Behavior

Water data exists in W3E (water_level per tile) but is not rendered.

---

## Intended Behavior

Render water surfaces with distinct visuals:

```lua
-- Check if tile has water
function terrain.has_water(tile)
    return tile.water_level > tile.ground_height
end

-- Get water depth
function terrain.get_water_depth(tile)
    return tile.water_level - tile.ground_height
end

-- Draw water layer
function terrain.draw_water(renderer, camera)
    for each visible tile do
        if terrain.has_water(tile) then
            local depth = terrain.get_water_depth(tile)
            local water_color = get_water_color(depth)
            renderer:draw_rect(sx, sy, sw, sh, water_color, true)
        end
    end
end
```

**Water Depth Colors:**
```lua
local WATER_COLORS = {
    shallow = {64, 164, 223, 180},   -- Light blue, semi-transparent
    medium  = {30, 120, 180, 200},   -- Medium blue
    deep    = {20, 60, 120, 220},    -- Dark blue
}

function get_water_color(depth)
    if depth < 50 then return WATER_COLORS.shallow
    elseif depth < 150 then return WATER_COLORS.medium
    else return WATER_COLORS.deep
    end
end
```

---

## Suggested Implementation Steps

1. **Identify water tiles**
   - Scan for tiles where water_level > ground_height
   - Cache water tile list for performance

2. **Implement basic water drawing**
   - Draw water as semi-transparent blue overlay
   - Render after ground tiles (layering)

3. **Add depth-based coloring**
   - Deeper water = darker blue
   - Shallow water = lighter, more transparent

4. **Draw water edges**
   - Shoreline where water meets land
   - Optional: wave pattern at edges

5. **Implement animation (optional)**
   ```lua
   -- Simple wave animation
   function terrain.update_water(dt)
       water_offset = water_offset + dt * WAVE_SPEED
       water_alpha = 180 + math.sin(water_offset) * 20
   end
   ```

6. **Add water rendering toggle**
   - terrain.show_water = true/false
   - Useful for debugging pathing

---

## Acceptance Criteria

- [ ] Water tiles render with blue color
- [ ] Water is semi-transparent (ground visible beneath)
- [ ] Deeper water appears darker
- [ ] Shallow water appears lighter
- [ ] Water renders above ground tiles
- [ ] Can toggle water visibility

---

## Notes

Water affects gameplay:
- Most ground units cannot cross deep water
- Some units (ships, amphibious) can traverse
- Shallow water may be passable

**WC3 water types:**
- Shallow water: wading units
- Deep water: ships only
- Different visual styles per tileset

---

## Related Documents

- issues/502a-core-terrain-renderer.md (renders before water)
- issues/502-implement-terrain-rendering.md (parent)
- src/runtime/systems/collision.lua (water affects pathing)
