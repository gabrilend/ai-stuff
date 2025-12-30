# Issue 502b: Height Visualization

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Medium
**Dependencies:** 502a

---

## Current Behavior

Terrain renders flat. Height data exists in W3E but is not visualized.

---

## Intended Behavior

Visualize terrain height differences:

```lua
-- Height-based shading
function terrain.draw_tile_with_height(renderer, camera, x, y, tile)
    local base_color = TILE_COLORS[tile.ground_type]
    local height = tile.ground_height

    -- Lighten higher terrain, darken lower
    local height_factor = (height - min_height) / (max_height - min_height)
    local shaded_color = shade_color(base_color, height_factor)

    renderer:draw_rect(sx, sy, sw, sh, shaded_color, true)
end

-- Cliff edge indicators
function terrain.draw_cliff_edge(renderer, camera, x, y, tile, neighbor)
    if math.abs(tile.ground_height - neighbor.ground_height) > CLIFF_THRESHOLD then
        -- Draw dark line at cliff edge
        renderer:draw_line(x1, y1, x2, y2, CLIFF_COLOR, 2)
    end
end

-- Optional contour lines
function terrain.draw_contours(renderer, camera, interval)
    for each contour_level do
        -- Draw lines where height crosses interval
    end
end
```

**Visualization Modes:**
```
1. Height shading - lighter = higher, darker = lower
2. Cliff edges - dark lines at sharp height changes
3. Contour lines - elevation bands like topographic maps
4. Gradient overlay - smooth color gradient by height
```

---

## Suggested Implementation Steps

1. **Calculate height range**
   - Find min/max height in map
   - Normalize heights to 0-1 range
   - Cache for performance

2. **Implement height shading**
   ```lua
   function shade_by_height(color, height_normalized)
       local factor = 0.5 + (height_normalized * 0.5)  -- 0.5 to 1.0
       return {
           color[1] * factor,
           color[2] * factor,
           color[3] * factor,
           color[4]
       }
   end
   ```

3. **Detect cliff edges**
   - Compare each tile to neighbors
   - If height diff > threshold, mark as cliff
   - Threshold: typically 2+ height levels

4. **Draw cliff indicators**
   - Draw dark line on cliff edge
   - Direction indicates which side is higher
   - Optional shadow effect

5. **Implement contour lines (optional)**
   - Divide height range into intervals
   - Draw lines where height crosses intervals
   - Different line styles per interval

6. **Add toggle for modes**
   - terrain.set_height_mode("shading" | "contours" | "none")
   - Can combine modes

---

## Acceptance Criteria

- [ ] Higher terrain appears lighter
- [ ] Lower terrain appears darker
- [ ] Cliff edges have visible indicators
- [ ] Height shading can be toggled
- [ ] Height differences are clearly visible
- [ ] Performance acceptable (large maps)

---

## Notes

Height visualization helps players understand terrain without 3D. Critical for gameplay since height affects combat.

**WC3 height behavior:**
- Units on high ground have vision advantage
- Ranged attacks from low to high ground can miss
- Cliffs block movement

---

## Related Documents

- issues/502a-core-terrain-renderer.md (base rendering)
- issues/502-implement-terrain-rendering.md (parent)
- src/parsers/w3e.lua (height data format)
