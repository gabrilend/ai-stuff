# Issue 501: Create Abstract Render Interface

**Phase:** 5 - Rendering
**Type:** Architecture
**Priority:** Critical
**Dependencies:** Phase 4 complete

---

## Current Behavior

No rendering system exists. The runtime can simulate games but produces no visual output. All Phase 4 systems work headlessly.

---

## Intended Behavior

Abstract rendering interface that:
- Decouples game logic from specific rendering backends
- Allows multiple renderer implementations (terminal, SDL, OpenGL, LÖVE2D)
- Defines clear contracts for what needs to be rendered
- Supports hot-swapping renderers without game restart
- Enables "headless" mode for testing/simulation

**Core Abstraction:**
```lua
-- Renderer interface contract
local Renderer = {}

function Renderer:init(config) end           -- Initialize renderer
function Renderer:begin_frame() end          -- Start frame
function Renderer:end_frame() end            -- Present frame
function Renderer:shutdown() end             -- Cleanup

-- Primitives
function Renderer:draw_sprite(x, y, sprite, options) end
function Renderer:draw_rect(x, y, w, h, color) end
function Renderer:draw_circle(x, y, radius, color) end
function Renderer:draw_line(x1, y1, x2, y2, color) end
function Renderer:draw_text(x, y, text, font, color) end

-- Terrain
function Renderer:draw_terrain(terrain_data, camera) end

-- Camera
function Renderer:set_camera(x, y, zoom) end
function Renderer:world_to_screen(wx, wy) end
function Renderer:screen_to_world(sx, sy) end

-- Queries
function Renderer:get_screen_size() end
function Renderer:supports_feature(feature) end
```

---

## Suggested Implementation Steps

1. **Define renderer interface in `src/render/interface.lua`**
   - Document all required methods
   - Define optional methods with feature flags
   - Create base class with default/stub implementations

2. **Create renderer registry**
   - `render.register(name, renderer_class)`
   - `render.get(name)` - get renderer by name
   - `render.set_active(name)` - switch active renderer

3. **Implement null renderer**
   - Does nothing, for headless/testing mode
   - All methods are no-ops
   - Useful for CI and automated testing

4. **Define rendering events**
   - `pre_render` - before frame starts
   - `post_render` - after frame ends
   - `viewport_changed` - screen resize

5. **Create camera system**
   - World-to-screen coordinate conversion
   - Zoom levels (strategic to closeup)
   - Camera bounds (map edges)
   - Smooth camera movement

---

## Design Questions for User

These should be discussed before implementation:

1. **Primary renderer target?**
   - Terminal (TUI) - no dependencies, works everywhere
   - LÖVE2D - batteries-included game framework
   - SDL2 - lower level, more control
   - Raylib - simple, modern

2. **Coordinate system?**
   - WC3-style (Y increases up, isometric projection)
   - Standard screen (Y increases down, top-down)

3. **Resolution handling?**
   - Fixed resolution with scaling
   - Responsive/adaptive
   - User-configurable

4. **Layer system?**
   - Fixed layers (terrain, units, effects, UI)
   - Dynamic z-ordering
   - Hybrid approach

---

## Acceptance Criteria

- [ ] Renderer interface defined and documented
- [ ] Null renderer implemented for headless mode
- [ ] Renderer registry allows switching implementations
- [ ] Camera system handles coordinate conversion
- [ ] At least one working renderer backend
- [ ] Unit tests for coordinate math

---

## Notes

This is the foundation for all visual output. Getting the abstraction right is critical - it affects every subsequent rendering issue.

**Architecture Reference:** See `docs/render-architecture.md` for the threading model:
- Worker threads compute GPU-ready data (transforms, culling done here)
- Sync thread swaps pointers (near-zero work)
- Draw thread iterates and dispatches (near-zero work)
- ComponentSlot pattern with mise en place (setter owns cleanup)

**May need successor issues for:**
- Each renderer backend (terminal, SDL, LÖVE2D)
- Advanced camera features (smooth follow, shake)
- Render optimization (culling, batching)

---

## Initial Analysis

**Analysis Date:** 2025-12-29

### Recommendation: SPLIT

This issue contains 5 distinct work streams that are independently testable and have clear boundaries:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 501a | define-renderer-interface | None | Define the abstract renderer interface contract with all required/optional methods |
| 501b | create-renderer-registry | 501a | Implement registry for registering, getting, and switching renderer backends |
| 501c | implement-null-renderer | 501a | Create no-op renderer for headless/testing mode |
| 501d | implement-camera-system | 501a | World-to-screen conversion, zoom, bounds, smooth movement |
| 501e | create-render-events | 501a, 501b | Define pre_render, post_render, viewport_changed events |

### Rationale

1. **Distinct work streams**: The interface definition, registry system, and camera are fundamentally different concerns
2. **Testability**: Each sub-issue can be unit tested independently
3. **Camera complexity**: The camera system alone has 4 aspects (coordinate conversion, zoom levels, bounds, smooth movement)
4. **Foundation importance**: This is critical infrastructure - getting each piece right matters

### Execution Order

```
501a (interface) → 501b (registry) ──────────────────┐
                └─→ 501c (null renderer) ─────────────┼→ 501e (events)
                └─→ 501d (camera) ────────────────────┘
```

---

## Related Documents

- docs/roadmap.md (Phase 5 overview)
- issues/502-*.md (terrain rendering depends on this)
- issues/506-*.md (UI framework depends on this)

---

## Generated Sub-Issues

*Auto-generated on 2025-12-29 19:39*

- 501a-define-renderer-interface.md
- 501b-create-renderer-registry.md
- 501c-implement-null-renderer.md
- 501d-implement-camera-system.md
- 501e-create-render-events.md
