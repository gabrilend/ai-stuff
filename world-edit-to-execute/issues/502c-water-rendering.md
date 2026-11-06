# Issue 502c: Water Rendering

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Medium
**Dependencies:** 502 (chunk meshes), 502e (which builds them)
**Re-cut:** 2026-09-26, from "Water Rendering"

---

## Current Behavior

No water is drawn. Only the demo script colours some tiles "water"
(`src/render/main.c`, around lines 974-983). The parser reads each
tilepoint's water level and water flag.

## Intended Behavior

Water surfaces at their level wherever a tilepoint is flagged as water, as
a second, translucent mesh per chunk, tinted by the map's water colour
(`war3map.w3i`), with shallow and deep water told apart by depth.

## Suggested Implementation Steps

1. Water mesh per chunk from the water flags and levels.
2. Tint from the map's water colour; depth shading.

## Acceptance Criteria

- [ ] Water shows where the map has it, at its level
- [ ] Shallow and deep water look different

## Status Note (2026-11-06)

The text above was written at the 2026-09-26 re-cut and not updated after
issue 517b (2026-09-29). `src/render/landscape.c` (scene viewer, `run-map`,
and the editor) already draws water; the vertical slice's `main.c` demo
colouring described above is unchanged.

Done (read from the code, 2026-11-06):

- Step 1: a water mesh per chunk, beside the land mesh. A tilepoint is wet
  where its water flag is set and the surface (`w3e.water_z`: stored level
  less 89.6) is above the ground; each wet cell's surface is level with
  its highest wet corner. Water is drawn in a second pass after the land.
- Depth shading: each cell mixes a shallow and a deep colour by depth
  (full deep at 256 units).

Left:

- The tint is two fixed colours. The map's own water colour is read by the
  w3i parser (`map.water_color`) but nothing uses it yet.
- The water is opaque (alpha 255), not translucent.
- The vertical slice (`terrain.c`, the page) has no water.

Boxes left unticked: 517 checked water by screenshot under Xvfb, but that
is not repeated here, and shallow against deep was not looked at on screen
in this pass.

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

Water data exists in W3E (water_level per tile) but is not rendered.

---

### Intended Behavior

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

### Suggested Implementation Steps

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

### Acceptance Criteria

- Water tiles render with blue color
- Water is semi-transparent (ground visible beneath)
- Deeper water appears darker
- Shallow water appears lighter
- Water renders above ground tiles
- Can toggle water visibility

---

### Notes

Water affects gameplay:
- Most ground units cannot cross deep water
- Some units (ships, amphibious) can traverse
- Shallow water may be passable

**WC3 water types:**
- Shallow water: wading units
- Deep water: ships only
- Different visual styles per tileset

---

### Related Documents

- issues/502a-core-terrain-renderer.md (renders before water)
- issues/502-implement-terrain-rendering.md (parent)
- src/runtime/systems/collision.lua (water affects pathing)
