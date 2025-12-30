# Issue 501e: Create Render Events

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 501
**Priority:** Medium
**Dependencies:** 501a, 501b

---

## Current Behavior

No event hooks exist for the render pipeline. Systems cannot react to render lifecycle events.

---

## Intended Behavior

Event system for render lifecycle hooks:

```lua
-- src/render/events.lua
local events = require("runtime.events")

-- Pre-render: before any drawing starts
events.on("render.pre_frame", function(dt)
    -- Update animations
    -- Prepare draw lists
    -- Sort by z-order
end)

-- Post-render: after all drawing complete
events.on("render.post_frame", function(dt)
    -- Debug overlays
    -- Performance stats
    -- Screenshot capture
end)

-- Viewport changed: screen resize or zoom
events.on("render.viewport_changed", function(width, height, zoom)
    -- Recalculate UI positions
    -- Update camera bounds
    -- Adjust minimap
end)

-- Layer events
events.on("render.layer_start", function(layer_name)
    -- "terrain", "units", "effects", "ui"
end)

events.on("render.layer_end", function(layer_name)
    -- Post-layer effects
end)
```

**Render Order:**
```
1. render.pre_frame
2. render.layer_start("terrain")
3. ... terrain drawing ...
4. render.layer_end("terrain")
5. render.layer_start("units")
6. ... unit drawing ...
7. render.layer_end("units")
8. render.layer_start("effects")
9. ... effects ...
10. render.layer_end("effects")
11. render.layer_start("ui")
12. ... UI drawing ...
13. render.layer_end("ui")
14. render.post_frame
```

---

## Suggested Implementation Steps

1. **Define render event types**
   ```lua
   local RENDER_EVENTS = {
       "render.pre_frame",
       "render.post_frame",
       "render.viewport_changed",
       "render.layer_start",
       "render.layer_end",
   }
   ```

2. **Integrate with existing event system**
   - Use runtime/events.lua if available
   - Or create render-specific event dispatcher

3. **Add event emission to render loop**
   ```lua
   function render_frame(dt)
       events.emit("render.pre_frame", dt)

       for _, layer in ipairs(LAYERS) do
           events.emit("render.layer_start", layer)
           draw_layer(layer)
           events.emit("render.layer_end", layer)
       end

       events.emit("render.post_frame", dt)
   end
   ```

4. **Implement viewport change detection**
   - Track previous screen size
   - Emit on resize
   - Emit on zoom change

5. **Add priority/ordering support**
   - Some handlers must run before others
   - Support priority argument in on()

---

## Acceptance Criteria

- [ ] pre_frame fires before drawing
- [ ] post_frame fires after drawing
- [ ] viewport_changed fires on resize
- [ ] layer_start/end fire in correct order
- [ ] Multiple handlers can subscribe
- [ ] Handlers receive correct parameters
- [ ] Priority ordering works

---

## Notes

Render events enable:
- Animation systems updating before draw
- Debug overlays rendering last
- UI systems responding to resize
- Screenshot tools capturing after render
- Performance profiling per-layer

**Integration with Phase 4 events:**
The runtime already has an event system (issue 308). Render events should use the same dispatcher for consistency.

---

## Related Documents

- issues/501a-define-renderer-interface.md (renderer emits events)
- issues/501b-create-renderer-registry.md (active renderer fires events)
- src/runtime/events/ (Phase 4 event system)
- issues/308-build-event-dispatch-system.md (event foundation)
