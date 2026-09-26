# Issue 502: Implement Terrain Rendering

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 508 (completed), 105 (terrain parser), 501 (the page format)
**Blocks:** 502b, 502c, 502d, 507, 507b
**Re-cut:** 2026-09-26, from "Implement Terrain Rendering"

---

## Current Behavior

The vertical slice draws a map's terrain as a flat grid of coloured tiles
(`src/render/terrain.c`, from 508d): one colour per ground texture, at the
right world positions, with a lookup from world point to tile. Heights,
cliffs, water and fog are not drawn, and each tile is its own draw call.

## Intended Behavior

Terrain is built **once, at map load**, and drawn every frame without
being rebuilt. The Lua terrain parser (105) reads `war3map.w3e`; C builds
meshes from it, one per chunk of tiles, and keeps them for the map (the
same pattern as models in 516). Each frame only what changes goes into the
page: which chunks are in view, and the fog texture. The sub-issues:

| ID | What | State |
|----|------|-------|
| 502a | the colour grid, culling, a grid-line view | colour grid built |
| 502b | heights and cliffs as a real mesh | open |
| 502c | water surfaces | open |
| 502d | fog of war | open; needs a visibility system in the runtime |
| 502e | one draw per chunk, culled by the camera | open |

Ground textures (the tileset's images) come later, read from the map or the
player's own install like models (516); until then, colours.

## Suggested Implementation Steps

1. 502e's chunking first, since every other part builds on chunk meshes.
2. 502b heights into those meshes; 502c water as a second mesh per chunk.
3. 502d fog when the runtime can say what each player sees.

## Acceptance Criteria

- [ ] A test map's terrain is built once at load and not rebuilt per frame
- [ ] Heights, cliffs and water show on the test maps
- [ ] Terrain costs a few draw calls per frame, not one per tile

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

W3E terrain data is parsed (Issue 105) but not rendered. Terrain information exists as data structures with tile types, heights, and water levels, but there's no visual representation.

---

### Intended Behavior

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

### Suggested Implementation Steps

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

### Design Questions for User

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

### Acceptance Criteria

- Terrain tiles render at correct positions
- Height differences are visually apparent
- Water tiles distinguished from land
- Multiple visual modes available
- Only visible tiles are rendered (culling)
- Performance acceptable for 256x256 maps

---

### Notes

Terrain is the foundation of the visual scene. Everything else (units, buildings, effects) renders on top of it.

**May need successor issues for:**
- Texture loading and management
- Cliff mesh generation (3D)
- Advanced water effects
- Fog of war integration

---

### Initial Analysis

**Analysis Date:** 2025-12-29

#### Recommendation: SPLIT

This issue contains 5 distinct rendering subsystems with clear technical boundaries:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 502a | core-terrain-renderer | 501 | Basic terrain module, tile grid display, coordinate mapping |
| 502b | height-visualization | 502a | Height shading, cliff indicators, contour lines |
| 502c | water-rendering | 502a | Water tiles, transparency, optional wave effects |
| 502d | fog-of-war-integration | 502a | Explored/unexplored/visible states, darkening overlays |
| 502e | terrain-optimization | 502a-d | View frustum culling, tile caching, performance tuning |

#### Rationale

1. **Distinct rendering techniques**: Height, water, and fog each use different visual approaches
2. **Fog of war complexity**: Integrates with player visibility system from Phase 4 - significant scope
3. **Optimization separate from features**: Culling and caching should come after features work
4. **Progressive enhancement**: Can ship basic terrain first, add polish later

#### Execution Order

```
502a (core) → 502b (height) ─────────────────┐
          └─→ 502c (water) ──────────────────┼→ 502e (optimization)
          └─→ 502d (fog of war) ─────────────┘
```

---

### Related Documents

- src/parsers/w3e.lua (terrain data parser)
- issues/501-*.md (render interface dependency)
- issues/503-*.md (sprites render on terrain)

---

### Generated Sub-Issues

*Auto-generated on 2025-12-29 19:39*

- 502a-core-terrain-renderer.md
- 502b-height-visualization.md
- 502c-water-rendering.md
- 502d-fog-of-war-integration.md
- 502e-terrain-optimization.md
