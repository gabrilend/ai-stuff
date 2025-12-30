# Issue 501c: Implement Null Renderer

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 501
**Priority:** High
**Dependencies:** 501a

---

## Current Behavior

No renderer exists for headless operation. Testing and CI require visual output to be disabled.

---

## Intended Behavior

Null renderer that implements the interface but produces no output:

```lua
-- src/render/backends/null.lua
local Renderer = require("render.interface")
local NullRenderer = setmetatable({}, {__index = Renderer})
NullRenderer.__index = NullRenderer

function NullRenderer:new()
    return setmetatable({
        frame_count = 0,
        draw_calls = 0,
    }, self)
end

function NullRenderer:init(config)
    self.width = config.width or 800
    self.height = config.height or 600
    return true
end

function NullRenderer:begin_frame()
    self.frame_count = self.frame_count + 1
    self.draw_calls = 0
end

function NullRenderer:end_frame()
    -- No-op: nothing to present
end

-- All draw methods are no-ops but track call count
function NullRenderer:draw_rect(x, y, w, h, color, filled)
    self.draw_calls = self.draw_calls + 1
end

-- ... etc for all draw methods
```

**Use Cases:**
- Automated testing without display
- CI/CD pipelines
- Server-side game simulation
- Benchmarking game logic (no render overhead)
- Validating draw call counts

---

## Suggested Implementation Steps

1. **Create null renderer module**
   - Inherit from Renderer interface
   - Implement all required methods as no-ops

2. **Add instrumentation**
   - Track frame count
   - Track draw calls per frame
   - Track total draw calls
   - Optional: record draw call log for debugging

3. **Implement state queries**
   - get_screen_size() returns configured size
   - get_frame_time() returns simulated delta (1/60)
   - supports_feature() returns false for all

4. **Register with registry**
   - Auto-register as "null" on module load
   - Set as default if no other renderer available

5. **Add debug helpers**
   - get_stats() returns frame/draw metrics
   - reset_stats() clears counters
   - get_draw_log() returns recorded calls (if enabled)

---

## Acceptance Criteria

- [ ] NullRenderer implements all interface methods
- [ ] All draw methods are no-ops (no errors)
- [ ] Frame and draw call counting works
- [ ] Can run full game loop with null renderer
- [ ] Registered as "null" in registry
- [ ] Unit tests pass using null renderer

---

## Notes

The null renderer is essential for testing. Every test that doesn't need visual output should use it for speed.

**Stats tracking example:**
```lua
local null = registry.create("null", {width = 800, height = 600})
registry.set_active(null)

-- Run game frame
game.update()
game.render()

-- Check render stats
local stats = null:get_stats()
print("Draw calls:", stats.draw_calls)  -- e.g., 150
print("Frames:", stats.frame_count)      -- e.g., 1
```

---

## Related Documents

- issues/501a-define-renderer-interface.md (interface to implement)
- issues/501b-create-renderer-registry.md (registers with this)
- src/tests/ (will use null renderer)
