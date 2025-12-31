# Issue 508c: Lua-C Bridge

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 508b (entity render slots)

---

## Current Behavior

All game logic is in Lua (ECS, movement, etc.). The renderer is in C. These
are completely separate with no communication.

---

## Intended Behavior

A bridge allowing Lua to:
- Create/destroy render entities
- Update entity positions and properties
- Query selection state
- Trigger render events

The bridge connects the Lua ECS to the C render slot system.

---

## Design Approach

Two options:

**Option A: LuaJIT FFI**
- Direct C function calls from Lua
- Very fast, no marshalling
- Requires LuaJIT specifically

**Option B: Lua C API**
- Works with any Lua
- More boilerplate
- Slightly slower

**Recommendation:** Start with Lua C API for compatibility. Add FFI later if needed.

---

## Suggested Implementation Steps

### 1. Create C API Functions

```c
/* {{{ render_create_entity */
// Lua: render.create_entity(entity_id, mesh_id, x, y, z)
// Returns: slot_index or -1
static int l_create_entity(lua_State* L) {
    int entity_id = luaL_checkinteger(L, 1);
    int mesh_id = luaL_checkinteger(L, 2);
    float x = luaL_checknumber(L, 3);
    float y = luaL_checknumber(L, 4);
    float z = luaL_checknumber(L, 5);

    int slot = slot_allocate(g_slots);
    if (slot >= 0) {
        ComponentSlot* cs = slot_get(g_slots, slot);
        cs->entity_id = entity_id;
        cs->in_use = true;

        RenderSlot* data = malloc(sizeof(RenderSlot));
        data->x = x;
        data->y = y;
        data->z = z;
        data->mesh_id = mesh_id;
        data->visible = true;
        data->selected = false;
        data->scale = 1.0f;
        data->r = 255; data->g = 255; data->b = 255; data->a = 255;
        data->team_id = -1;

        cs->set(cs, data);
    }

    lua_pushinteger(L, slot);
    return 1;
}
/* }}} */

/* {{{ render_destroy_entity */
// Lua: render.destroy_entity(slot_index)
static int l_destroy_entity(lua_State* L) {
    int slot = luaL_checkinteger(L, 1);
    slot_free(g_slots, slot);
    return 0;
}
/* }}} */

/* {{{ render_set_position */
// Lua: render.set_position(slot_index, x, y, z)
static int l_set_position(lua_State* L) {
    int slot = luaL_checkinteger(L, 1);
    float x = luaL_checknumber(L, 2);
    float y = luaL_checknumber(L, 3);
    float z = luaL_checknumber(L, 4);

    ComponentSlot* cs = slot_get(g_slots, slot);
    if (cs && cs->data) {
        // Note: This is simplified. Full implementation uses
        // worker thread to create new RenderSlot and swap.
        cs->data->x = x;
        cs->data->y = y;
        cs->data->z = z;
    }

    return 0;
}
/* }}} */

/* {{{ render_set_color */
// Lua: render.set_color(slot_index, r, g, b, a)
static int l_set_color(lua_State* L) {
    int slot = luaL_checkinteger(L, 1);
    int r = luaL_checkinteger(L, 2);
    int g = luaL_checkinteger(L, 3);
    int b = luaL_checkinteger(L, 4);
    int a = luaL_optinteger(L, 5, 255);

    ComponentSlot* cs = slot_get(g_slots, slot);
    if (cs && cs->data) {
        cs->data->r = r;
        cs->data->g = g;
        cs->data->b = b;
        cs->data->a = a;
    }

    return 0;
}
/* }}} */

/* {{{ render_set_selected */
// Lua: render.set_selected(slot_index, selected)
static int l_set_selected(lua_State* L) {
    int slot = luaL_checkinteger(L, 1);
    bool selected = lua_toboolean(L, 2);

    ComponentSlot* cs = slot_get(g_slots, slot);
    if (cs && cs->data) {
        cs->data->selected = selected;
    }

    return 0;
}
/* }}} */
```

### 2. Register Module

```c
/* {{{ luaopen_render */
static const luaL_Reg render_funcs[] = {
    {"create_entity", l_create_entity},
    {"destroy_entity", l_destroy_entity},
    {"set_position", l_set_position},
    {"set_color", l_set_color},
    {"set_selected", l_set_selected},
    {"set_visible", l_set_visible},
    {"set_scale", l_set_scale},
    {"set_team", l_set_team},
    {NULL, NULL}
};

int luaopen_render(lua_State* L) {
    luaL_newlib(L, render_funcs);
    return 1;
}
/* }}} */
```

### 3. Create Lua Wrapper Module

```lua
-- src/render.lua
-- {{{ render module
-- High-level rendering interface wrapping C API

local render_c = require("render_c")  -- C module

local render = {}

-- Entity tracking (entity_id -> slot_index)
local entity_slots = {}

-- {{{ render.create
function render.create(entity_id, mesh_type, x, y, z)
    local mesh_id = render.MESH_TYPES[mesh_type] or 0
    local slot = render_c.create_entity(entity_id, mesh_id, x, y, z)

    if slot >= 0 then
        entity_slots[entity_id] = slot
    end

    return slot
end
-- }}}

-- {{{ render.destroy
function render.destroy(entity_id)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.destroy_entity(slot)
        entity_slots[entity_id] = nil
    end
end
-- }}}

-- {{{ render.move
function render.move(entity_id, x, y, z)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_position(slot, x, y, z)
    end
end
-- }}}

-- {{{ render.select
function render.select(entity_id, selected)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_selected(slot, selected)
    end
end
-- }}}

-- Mesh type constants
render.MESH_TYPES = {
    circle = 0,
    cube = 1,
    triangle = 2,
    cylinder = 3,
}

-- Team colors
render.TEAM_COLORS = {
    [0] = {255, 0, 0},      -- Red
    [1] = {0, 0, 255},      -- Blue
    [2] = {0, 255, 255},    -- Teal
    [3] = {128, 0, 128},    -- Purple
}

return render
-- }}}
```

### 4. ECS Integration Hooks

```lua
-- In ECS system that updates positions
local render = require("render")

-- {{{ PositionRenderSync
-- System that syncs ECS positions to render slots
local PositionRenderSync = {
    priority = 100,  -- Run after movement

    update = function(self, dt, ecs)
        for entity_id, pos in ecs.query("position") do
            render.move(entity_id, pos.x, pos.y, pos.z)
        end
    end
}
-- }}}

-- On entity creation
ecs.on("entity_created", function(entity_id, components)
    if components.position and components.renderable then
        local pos = components.position
        local rend = components.renderable
        render.create(entity_id, rend.mesh or "circle", pos.x, pos.y, pos.z)

        if rend.team then
            render.set_team(entity_id, rend.team)
        end
    end
end)

-- On entity destruction
ecs.on("entity_destroyed", function(entity_id)
    render.destroy(entity_id)
end)
```

---

## Files to Create

- `src/render/bridge.h` - C API declarations
- `src/render/bridge.c` - C API implementations
- `src/render.lua` - Lua wrapper module

---

## Acceptance Criteria

- [x] C module exposes create/destroy/set functions
- [x] Lua can create render entities
- [x] Lua can update positions
- [x] Lua can set colors and selection state
- [x] Entity tracking maps entity_id to slot_index
- [ ] ECS hooks trigger render updates (deferred to 508d/508f)
- [x] Clean destruction (no orphaned slots)

---

## Notes

The bridge is intentionally simple - Lua calls C directly, no queuing.
This works because:

1. Lua runs in the "updater" context conceptually
2. Workers pull from input buffers, not Lua directly
3. The C API writes to input buffers, not render slots

In the full architecture, `set_position` would write to an input buffer
that workers consume. For 508, we simplify by writing directly.

---

## Related Documents

- `issues/508b-entity-render-slots.md` - Slot system this exposes
- `src/runtime/ecs/` - ECS to integrate with

---

## Implementation Notes

**Completed:** 2025-12-30

### Files Created

- `src/render/bridge.h` - C API declarations (12 Lua-callable functions)
- `src/render/bridge.c` - C API implementation with slot system integration
- `src/render.lua` - High-level Lua wrapper with entity tracking

### Key Implementation Details

1. **LuaJIT Compatibility**: Used `lua_objlen` instead of `lua_rawlen`, and manual
   module preloading instead of `luaL_requiref` (both are Lua 5.2+ only).

2. **Module Registration**: Bridge uses `package.preload["render"]` pattern for
   LuaJIT-compatible module registration.

3. **Bridge Initialization**: `bridge_init(SlotArray*)` must be called before any
   Lua code uses the render module. This passes the slot array reference.

4. **Thread Safety**: The C functions directly modify slot data. For the demo,
   this is safe because Lua runs in the main thread before worker threads consume
   data. Full thread safety via input buffers is deferred to future issues.

5. **Inline Test Script**: main.c includes an embedded Lua test that:
   - Creates 4 colored entities at cardinal directions
   - Applies rotation animation each frame
   - Demonstrates full bridge functionality

### Demo Output

```
[lua] Lua state created and render module registered
[lua] render module loaded, MAX_SLOTS = 1024
[lua] Created entity 100 at slot 1
[lua] Created entity 101 at slot 2
[lua] Created entity 102 at slot 3
[lua] Created entity 103 at slot 4
[lua] Slots: 5/1024 active
[lua] Bridge test complete: 4 entities created via Lua
```

### Deferred Work

- ECS hooks (entity_created/entity_destroyed events) deferred to 508d/508f
- Full thread-safe input buffer integration deferred to future issues
