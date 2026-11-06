# Issue 502e: Terrain Optimization

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Low
**Dependencies:** 502a, 501d (the camera's view rectangle)
**Blocks:** 502b, 502c (they build on chunk meshes)
**Re-cut:** 2026-09-26, from "Terrain Optimization"

---

## Current Behavior

Each terrain tile is drawn with its own call. The ceramic path's first real
frame (515b) measured drawing, not the engine, as the cost: about 1.3 ms of
a frame for 2,048 units drawn one call each. Terrain adds a call per tile on
top.

## Intended Behavior

Terrain is split into chunks (for example 16 by 16 tiles), each built once
into one mesh; a frame draws only the chunks in the camera's view, one call
each. The chunk list for the frame goes on the page. Measured before and
after on the test maps, with the profiler (511).

## Suggested Implementation Steps

1. Chunk meshes built at map load.
2. View culling by chunk.
3. Measure frame time and draw calls before and after.

## Acceptance Criteria

- [ ] Terrain draws in one call per visible chunk
- [ ] Frame time and draw calls, before and after, recorded in this issue

## Status Note (2026-11-06)

The text above was written at the 2026-09-26 re-cut and not updated after
issue 517b (2026-09-29), which built chunked terrain in a second render
path: `src/render/landscape.c`, used by the scene viewer (`run-map`) and
the editor. The vertical slice's `terrain.c` still draws a call per tile,
as described above.

Done (read from the code, 2026-11-06):

- Step 1: chunk meshes built once at map load (`render.land_build`), 32x32
  cells a chunk rather than 16x16: one land mesh, one water mesh, and since
  issue 526 up to 16 textured ground-layer meshes per chunk. Static
  doodads are baked into chunk meshes the same way (`render.geo_bake`, 16
  tiles a side).
- Step 2, partly: chunks are culled by distance from the camera's focus
  (a radius from the camera's distance), not by the camera's view
  rectangle (501d).

Left:

- Culling by the view rectangle, once 501d's camera model is in.
- A visible chunk costs one land call plus one per ground-texture layer it
  holds plus one for water, so "one call per visible chunk" holds only for
  untextured land.
- The chunk list does not go on the page; `landscape_draw` is called
  directly by the scene viewer.
- Step 3: no terrain before/after frame time or draw counts are recorded.
  517 recorded only the whole scene: DAoW 5.4b, 225 land chunks, 8-11 FPS
  under software GL in the container.

Boxes left unticked for the reasons above.

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

Basic terrain rendering works but may be slow on large maps (256x256 = 65536 tiles).

---

### Intended Behavior

Optimize terrain rendering for smooth performance:

```lua
-- View frustum culling (already basic in 502a, refine here)
function terrain.get_visible_tiles(camera)
    local bounds = camera.get_visible_bounds()
    -- Only return tiles within camera view
    -- Add small margin for edge tiles
end

-- Tile batching
function terrain.batch_tiles_by_type(visible_tiles)
    local batches = {}
    for tile in visible_tiles do
        local type = tile.ground_type
        batches[type] = batches[type] or {}
        table.insert(batches[type], tile)
    end
    return batches
end

-- Draw batched (fewer state changes)
function terrain.draw_batched(renderer, camera)
    local batches = terrain.batch_tiles_by_type(visible_tiles)
    for type, tiles in pairs(batches) do
        local color = TILE_COLORS[type]
        for _, tile in ipairs(tiles) do
            renderer:draw_rect(...)
        end
    end
end
```

**Optimization Targets:**
```
Target: 60 FPS on 256x256 map
Acceptable: 30 FPS minimum
```

---

### Suggested Implementation Steps

1. **Profile current performance**
   - Measure draw time for various map sizes
   - Identify bottlenecks (tile iteration, draw calls, etc.)

2. **Improve view culling**
   - Add margin to avoid popping at edges
   - Early-out for tiles completely off-screen
   - Use spatial hash if beneficial

3. **Implement tile batching**
   - Group tiles by type before drawing
   - Reduces color/state changes
   - Significant win for simple renderers

4. **Cache unchanging terrain**
   - Render terrain to texture once
   - Only re-render when camera moves significantly
   - Huge win if renderer supports textures

5. **LOD for zoomed-out views (optional)**
   - At low zoom, combine multiple tiles
   - Draw larger quads with average color
   - Reduces draw call count

6. **Dirty region updates**
   - Track which tiles changed
   - Only update changed regions
   - Useful for dynamic terrain (rare in WC3)

---

### Acceptance Criteria

- 60 FPS on 128x128 map
- 30+ FPS on 256x256 map
- Tile batching reduces draw calls
- View culling eliminates off-screen tiles
- No visual artifacts from optimization
- Performance metrics can be displayed

---

### Notes

Optimization should come after correctness. Get terrain rendering working first, then profile and optimize.

**Profiling approach:**
```lua
function terrain.draw_with_profiling(renderer, camera)
    local start = os.clock()
    terrain.draw(renderer, camera)
    local elapsed = os.clock() - start

    terrain.stats = {
        draw_time_ms = elapsed * 1000,
        tiles_drawn = tile_count,
        draw_calls = draw_call_count,
    }
end
```

**Common bottlenecks:**
1. Too many draw calls (batch to fix)
2. Drawing off-screen tiles (cull to fix)
3. Per-tile calculations (cache to fix)
4. Lua overhead (move hot paths to C if needed)

---

### Related Documents

- issues/502a-core-terrain-renderer.md (base to optimize)
- issues/502b-height-visualization.md (may need optimization)
- issues/502c-water-rendering.md (separate optimization pass)
- issues/502d-fog-of-war-integration.md (fog caching)
