# Issue 502e: Terrain Optimization

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Low
**Dependencies:** 502a, 502b, 502c, 502d

---

## Current Behavior

Basic terrain rendering works but may be slow on large maps (256x256 = 65536 tiles).

---

## Intended Behavior

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

## Suggested Implementation Steps

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

## Acceptance Criteria

- [ ] 60 FPS on 128x128 map
- [ ] 30+ FPS on 256x256 map
- [ ] Tile batching reduces draw calls
- [ ] View culling eliminates off-screen tiles
- [ ] No visual artifacts from optimization
- [ ] Performance metrics can be displayed

---

## Notes

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

## Related Documents

- issues/502a-core-terrain-renderer.md (base to optimize)
- issues/502b-height-visualization.md (may need optimization)
- issues/502c-water-rendering.md (separate optimization pass)
- issues/502d-fog-of-war-integration.md (fog caching)
