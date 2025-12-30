# Issue 501a: Define Renderer Interface

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 501
**Priority:** Critical
**Dependencies:** None

---

## Current Behavior

No rendering abstraction exists. The runtime operates headlessly with no visual output capability.

---

## Intended Behavior

Define the abstract renderer interface contract that all renderer backends must implement:

```lua
-- src/render/interface.lua
local Renderer = {}
Renderer.__index = Renderer

-- Lifecycle methods
function Renderer:init(config) end           -- Initialize with screen size, title, etc.
function Renderer:begin_frame() end          -- Start frame (clear buffers)
function Renderer:end_frame() end            -- Present frame (swap buffers)
function Renderer:shutdown() end             -- Cleanup resources

-- Primitive drawing
function Renderer:draw_rect(x, y, w, h, color, filled) end
function Renderer:draw_circle(x, y, radius, color, filled) end
function Renderer:draw_line(x1, y1, x2, y2, color, thickness) end
function Renderer:draw_text(x, y, text, font_size, color) end

-- Sprite drawing (placeholder or asset-backed)
function Renderer:draw_sprite(x, y, sprite_id, options) end

-- Terrain drawing (delegated to terrain renderer)
function Renderer:draw_terrain(terrain_data, camera) end

-- State queries
function Renderer:get_screen_size() end      -- Returns width, height
function Renderer:get_frame_time() end       -- Returns delta time
function Renderer:supports_feature(name) end -- Check optional features

-- Optional features (may return false from supports_feature)
function Renderer:set_clip_rect(x, y, w, h) end
function Renderer:clear_clip_rect() end
function Renderer:draw_to_texture(texture, fn) end
```

**Color Format:**
```lua
-- Colors as tables with r, g, b, a (0-255)
local red = {r = 255, g = 0, b = 0, a = 255}
-- Or shorthand
local green = {0, 255, 0, 255}
```

---

## Suggested Implementation Steps

1. **Create interface module**
   ```lua
   -- src/render/interface.lua
   local Renderer = {}
   Renderer.__index = Renderer

   function Renderer:new()
       return setmetatable({}, self)
   end
   ```

2. **Define required methods with stubs**
   - Each method should error if not overridden
   - Document parameters and return values

3. **Define optional methods with defaults**
   - Return false/nil for unsupported features
   - Log warnings when optional features used but unsupported

4. **Create helper constructors**
   - `Renderer.create_color(r, g, b, a)`
   - `Renderer.create_rect(x, y, w, h)`

5. **Document feature flags**
   - `"clip_rect"` - scissor/clipping support
   - `"textures"` - render-to-texture support
   - `"shaders"` - custom shader support
   - `"batching"` - draw call batching

---

## Acceptance Criteria

- [ ] Renderer interface defined in `src/render/interface.lua`
- [ ] All required methods documented with parameters
- [ ] Optional methods have sensible defaults
- [ ] Feature query system implemented
- [ ] Color and rect helper functions work
- [ ] Interface can be inherited by concrete renderers

---

## Notes

This is the foundation for all rendering. The interface should be stable - changing it later affects all backends.

**Design decisions:**
- Y-axis: Follow screen convention (0 at top, increases downward)
- Coordinates: Float for sub-pixel positioning
- Colors: 0-255 range for familiarity

---

## Related Documents

- issues/501-create-abstract-render-interface.md (parent)
- issues/501b-create-renderer-registry.md (uses this interface)
- issues/501c-implement-null-renderer.md (implements this interface)
