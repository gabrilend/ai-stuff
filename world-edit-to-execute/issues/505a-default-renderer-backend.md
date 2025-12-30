# Issue 505a: Default Renderer Backend

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** Critical
**Dependencies:** 501a, 501b, 501c

---

## Current Behavior

Only the null renderer exists. No visual output is possible.

---

## Intended Behavior

A concrete renderer backend that produces actual visual output:

```lua
-- src/render/backends/love2d.lua (or raylib, SDL, etc.)
local Renderer = require("render.interface")
local Love2DRenderer = setmetatable({}, {__index = Renderer})

function Love2DRenderer:init(config)
    love.window.setMode(config.width or 800, config.height or 600)
    love.window.setTitle(config.title or "WC3 Engine")
    self.width = config.width
    self.height = config.height
    return true
end

function Love2DRenderer:begin_frame()
    love.graphics.clear(0, 0, 0)
end

function Love2DRenderer:end_frame()
    love.graphics.present()
end

function Love2DRenderer:draw_rect(x, y, w, h, color, filled)
    love.graphics.setColor(color[1]/255, color[2]/255, color[3]/255, color[4]/255)
    if filled then
        love.graphics.rectangle("fill", x, y, w, h)
    else
        love.graphics.rectangle("line", x, y, w, h)
    end
end

-- ... etc
```

**Backend Options:**
| Backend | Pros | Cons |
|---------|------|------|
| LÖVE2D | Easy Lua integration, batteries included | Requires LÖVE runtime |
| Raylib | Modern, simple API | Requires bindings |
| SDL2 | Low-level control, portable | More setup |
| Terminal | No dependencies | Limited visuals |

---

## Suggested Implementation Steps

1. **Choose primary backend**
   - LÖVE2D recommended for Lua projects
   - Or Raylib for standalone binary

2. **Implement interface methods**
   - All required methods from 501a
   - Handle color format conversion
   - Implement shape primitives

3. **Register with registry**
   ```lua
   local registry = require("render.registry")
   registry.register("love2d", Love2DRenderer)
   ```

4. **Create entry point**
   - main.lua for LÖVE
   - Or standalone Lua with FFI bindings

5. **Test with simple scene**
   - Draw colored rectangles
   - Verify coordinate system
   - Test all primitives

6. **Add window management**
   - Resize handling
   - Fullscreen toggle
   - Title updates

---

## Acceptance Criteria

- [ ] Renderer implements all interface methods
- [ ] Window opens at configured size
- [ ] Primitives draw correctly (rect, circle, line, text)
- [ ] Colors render correctly
- [ ] Registered in renderer registry
- [ ] Frame loop runs at target FPS

---

## Notes

This is where the engine becomes "real" - visual output appears. The backend choice affects deployment and dependencies.

**LÖVE2D recommendation:**
LÖVE2D is ideal because:
- Native Lua integration
- Cross-platform (Windows, Mac, Linux)
- Good performance
- Active community

---

## Related Documents

- issues/501a-define-renderer-interface.md (interface to implement)
- issues/501b-create-renderer-registry.md (registration)
- issues/505-implement-default-visual-mode.md (parent)
