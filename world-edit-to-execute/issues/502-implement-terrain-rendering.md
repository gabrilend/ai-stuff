# Issue 502: Implement Terrain Rendering

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 501-create-abstract-render-interface, 105-parse-war3map-w3e

---

## Current Behavior

W3E terrain data is parsed (Issue 105) but not rendered. Terrain information exists as data structures with tile types, heights, and water levels, but there's no visual representation.

---

## Intended Behavior

Terrain rendering system that:
- Converts w3e data to renderable terrain mesh/tiles
- Displays ground textures (or placeholders)
- Renders water surfaces at correct heights
- Shows cliff faces and height variations
- Supports fog of war masking
- Works with the abstract render interface

**Visual Modes:**
```
1. Wireframe     - Grid lines showing tile boundaries
2. Flat Color    - Solid colors per tile type (grass=green, dirt=brown)
3. Textured      - Actual textures from asset packs
4. Height Map    - Grayscale showing elevation
5. Pathing       - Overlay showing walkable/blocked areas
```

---

## Suggested Implementation Steps

1. **Create terrain renderer module**
   ```lua
   -- src/render/terrain.lua
   local terrain_renderer = {}

   function terrain_renderer.init(w3e_data) end
   function terrain_renderer.draw(camera, renderer) end
   function terrain_renderer.set_mode(mode) end
   function terrain_renderer.get_tile_at(world_x, world_y) end
   ```

2. **Implement tile-based rendering**
   - Calculate visible tiles from camera bounds
   - Only render tiles in view (frustum culling)
   - Cache tile appearance data

3. **Handle height visualization**
   - Shade tiles based on height (lighter = higher)
   - Draw cliff indicators at height transitions
   - Optional contour lines

4. **Implement water rendering**
   - Water tiles rendered with transparency/animation
   - Water level affects unit pathing display
   - Optional wave/ripple effects

5. **Add fog of war support**
   - Unexplored = black
   - Explored but not visible = darkened
   - Visible = full brightness
   - Integrates with player visibility system

---

## Design Questions for User

1. **Rendering style preference?**
   - Realistic (textured, shaded)
   - Stylized (flat colors, clean lines)
   - Debug/Technical (grid, data overlay)

2. **Isometric vs Top-down?**
   - WC3-style isometric projection
   - Pure top-down (simpler)
   - Configurable

3. **Tile size on screen?**
   - Fixed pixels per tile
   - Zoom-dependent
   - Resolution-adaptive

4. **Water effects?**
   - Static (solid color)
   - Animated (waves, reflections)
   - Shader-based (if using GPU)

---

## Acceptance Criteria

- [ ] Terrain tiles render at correct positions
- [ ] Height differences are visually apparent
- [ ] Water tiles distinguished from land
- [ ] Multiple visual modes available
- [ ] Only visible tiles are rendered (culling)
- [ ] Performance acceptable for 256x256 maps

---

## Notes

Terrain is the foundation of the visual scene. Everything else (units, buildings, effects) renders on top of it.

**May need successor issues for:**
- Texture loading and management
- Cliff mesh generation (3D)
- Advanced water effects
- Fog of war integration

---

## Related Documents

- src/parsers/w3e.lua (terrain data parser)
- issues/501-*.md (render interface dependency)
- issues/503-*.md (sprites render on terrain)
