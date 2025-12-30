# Issue 501b: Create Renderer Registry

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 501
**Priority:** High
**Dependencies:** 501a

---

## Current Behavior

No way to register, discover, or switch between renderer implementations.

---

## Intended Behavior

Registry system for managing renderer backends:

```lua
-- src/render/registry.lua
local registry = {}

-- Register a renderer class
registry.register("null", NullRenderer)
registry.register("love2d", Love2DRenderer)
registry.register("terminal", TerminalRenderer)

-- Get available renderers
local available = registry.list()  -- {"null", "love2d", "terminal"}

-- Create renderer instance
local renderer = registry.create("love2d", config)

-- Get/set active renderer
registry.set_active(renderer)
local active = registry.get_active()

-- Hot-swap (if supported)
if registry.can_swap() then
    registry.swap("terminal")  -- Switches without restart
end
```

---

## Suggested Implementation Steps

1. **Create registry module**
   ```lua
   -- src/render/registry.lua
   local registry = {
       _renderers = {},      -- name -> class
       _active = nil,        -- current instance
       _config = {},         -- shared config
   }
   ```

2. **Implement register function**
   - Validate renderer implements interface
   - Store by name for lookup
   - Allow overwriting (for mods/plugins)

3. **Implement create function**
   - Instantiate renderer class
   - Pass config to init()
   - Return ready-to-use instance

4. **Implement active renderer tracking**
   - Single active renderer at a time
   - get_active() returns current
   - set_active() switches (calls shutdown on old)

5. **Implement discovery/listing**
   - list() returns registered names
   - info(name) returns metadata
   - supports(name, feature) checks capabilities

6. **Add swap support (optional)**
   - can_swap() checks if safe to switch
   - swap() transfers state if possible

---

## Acceptance Criteria

- [ ] `registry.register(name, class)` stores renderer classes
- [ ] `registry.create(name, config)` instantiates renderers
- [ ] `registry.list()` returns available renderer names
- [ ] `registry.set_active()` / `get_active()` manage current renderer
- [ ] Invalid renderer names produce clear errors
- [ ] Duplicate registration logs warning

---

## Notes

The registry enables:
- Runtime renderer selection (user preference)
- Fallback chains (GPU fails → software → terminal)
- Testing with null renderer
- Future plugin renderers

---

## Related Documents

- issues/501a-define-renderer-interface.md (interface to validate against)
- issues/501c-implement-null-renderer.md (first registered renderer)
- issues/505a-default-renderer-backend.md (default active renderer)
