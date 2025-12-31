# Issue 508f: Movement Orders

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 508e (input and selection)

---

## Current Behavior

Selection works but there's no way to command selected units. The order
system exists (404c) but isn't connected to input.

---

## Intended Behavior

- Right-click issues move order to selected units
- Units pathfind and move to destination
- Position updates flow to render slots
- Visual feedback for move target

---

## Suggested Implementation Steps

### 1. Right-Click Handler (C)

```c
/* {{{ process_right_click */
void process_right_click(void) {
    if (!g_input.right_clicked) return;
    if (g_selection.count == 0) return;

    // Get target position
    float tx = g_input.world_x;
    float tz = g_input.world_z;

    // Notify Lua of move command
    notify_lua_move_order(tx, tz);
}
/* }}} */

/* {{{ notify_lua_move_order */
void notify_lua_move_order(float x, float z) {
    lua_State* L = g_lua_state;

    lua_getglobal(L, "on_move_order");
    if (lua_isfunction(L, -1)) {
        lua_pushnumber(L, x);
        lua_pushnumber(L, z);
        lua_call(L, 2, 0);
    } else {
        lua_pop(L, 1);
    }
}
/* }}} */
```

### 2. Lua Order Handler

```lua
-- src/demo/input_handler.lua
-- {{{ input_handler

local render = require("render")
local orders = require("runtime.orders")
local ecs = require("runtime.ecs")

-- {{{ on_move_order
-- Called from C when right-click issued
function on_move_order(x, z)
    local selected = render.get_selection()

    if #selected == 0 then
        return
    end

    print(string.format("Move order to (%.1f, %.1f) for %d units", x, z, #selected))

    for _, entity_id in ipairs(selected) do
        -- Issue move order via existing order system
        orders.move(entity_id, x, 0, z)
    end

    -- Visual feedback at target
    render.show_move_marker(x, z)
end
-- }}}

-- {{{ Register global callback
_G.on_move_order = on_move_order
-- }}}
```

### 3. Movement System Update Hook

The existing movement system (404) needs to notify render when positions change:

```lua
-- In movement system update
local render = require("render")

-- After movement update
for entity_id, pos in ecs.query("position", "movement") do
    -- Sync to render
    render.move(entity_id, pos.x, pos.y, pos.z)
end
```

### 4. Move Target Marker (C)

```c
/* {{{ MoveMarker */
typedef struct move_marker {
    float x, z;
    float lifetime;
    bool active;
} MoveMarker;

MoveMarker g_move_marker;

void show_move_marker(float x, float z) {
    g_move_marker.x = x;
    g_move_marker.z = z;
    g_move_marker.lifetime = 1.0f;  // 1 second
    g_move_marker.active = true;
}

void update_move_marker(float dt) {
    if (!g_move_marker.active) return;

    g_move_marker.lifetime -= dt;
    if (g_move_marker.lifetime <= 0) {
        g_move_marker.active = false;
    }
}

void draw_move_marker(void) {
    if (!g_move_marker.active) return;

    // Pulsing green circle at target
    float alpha = g_move_marker.lifetime;
    float radius = 0.5f + (1.0f - g_move_marker.lifetime) * 0.5f;

    DrawCircle3D(
        (Vector3){g_move_marker.x, 0.1f, g_move_marker.z},
        radius,
        (Vector3){0, 1, 0}, 0,
        (Color){0, 255, 0, (unsigned char)(alpha * 255)}
    );
}
/* }}} */
```

### 5. Lua Bridge for Marker

```c
/* {{{ l_show_move_marker */
static int l_show_move_marker(lua_State* L) {
    float x = luaL_checknumber(L, 1);
    float z = luaL_checknumber(L, 2);
    show_move_marker(x, z);
    return 0;
}
/* }}} */
```

### 6. Main Loop Integration

```c
/* {{{ main loop update section */
while (!WindowShouldClose()) {
    float dt = GetFrameTime();

    // Process input
    process_input();
    process_right_click();

    // Update markers
    update_move_marker(dt);

    // Lua updates (movement system, etc.)
    lua_tick(dt);

    // Drawing
    BeginDrawing();
        // ... terrain, entities ...
        draw_move_marker();
        draw_selection_box();
    EndDrawing();
}
/* }}} */
```

---

## Files to Create/Modify

- `src/render/input.c` - Add right-click handling
- `src/render/marker.h` - Move marker struct
- `src/render/marker.c` - Marker rendering
- `src/demo/input_handler.lua` - Order issuing

---

## Acceptance Criteria

- [x] Right-click on ground issues move order
- [x] Selected units receive move order
- [ ] Units pathfind to destination (using 403) - Direct movement for demo
- [x] Units move along path (using 404) - Linear interpolation for demo
- [x] Position updates reflected in render slots
- [x] Green marker appears at move target
- [x] Marker fades out over 1 second
- [x] Multiple selected units all move

---

## Notes

This completes the input→order→movement→render loop:

1. User right-clicks
2. C detects click, calls Lua
3. Lua issues order via order system
4. Order system triggers movement
5. Movement system updates ECS positions
6. ECS hook syncs to render slots
7. Render shows unit at new position

The loop is the core of the game. Once this works, everything else builds on it.

---

## Related Documents

- `issues/508e-input-and-selection.md` - Selection this uses
- `src/runtime/orders/` - Order system
- `src/runtime/systems/movement.lua` - Movement system

---

## Implementation Notes

**Completed: 2025-12-31**

### Changes Made

1. **`src/render/input.h`** - Added move marker types and functions:
   - `MoveMarker` struct with position, lifetime, active state
   - `move_marker_show()`, `move_marker_update()`, `move_marker_draw()`, `move_marker_is_active()`
   - `process_movement_input()` for right-click handling
   - `l_show_move_marker()` Lua bridge function

2. **`src/render/input.c`** - Implemented movement order system:
   - Global `g_move_marker` state with 1.0s lifetime
   - `move_marker_draw()` renders expanding green circle with crosshair lines
   - `process_movement_input()` detects right-click, gets world position, calls Lua `on_move_order(x, z, entity_ids)`

3. **`src/render/bridge.c`** - Registered `show_move_marker` in render_funcs array

4. **`src/render/main.c`** - Integrated movement system:
   - Calls `process_movement_input()` and `move_marker_update()` in main loop
   - Calls `move_marker_draw()` during 3D rendering phase
   - Added Lua `on_move_order()` handler that stores targets in `_G.entity_targets`
   - Updated `update_lua_entities()` to interpolate positions toward targets at 5.0 units/sec
   - **Critical fix:** Restructured script to create demo entities BEFORE map loading (maps can consume 2000+ slots for doodads)

5. **`src/render/slots.h`** - Increased `MAX_SLOTS` from 1024 to 4096 to accommodate large maps with many doodads

### Demo Behavior

- 4 colored cubes (Red, Blue, Green, Yellow) spawn at demo start
- Left-click to select entities (shift+click to add, box select supported)
- Right-click to issue move orders
- Green pulsing marker with crosshair appears at target
- Selected units move toward target at 5.0 units/second
- Move marker expands and fades over 1 second

### Technical Notes

- Movement uses simple linear interpolation rather than full pathfinding (Issue 403)
- Entity targets stored in Lua global table `_G.entity_targets[entity_id] = {x, z}`
- Marker uses expanding circle (0.5 + 0.5 * progress) with fade-out alpha
- Crosshair lines provide visual precision for click location

### Lessons Learned

- **Slot exhaustion:** Maps with many doodads can exhaust render slots quickly. The demo map loaded 1000+ doodads, leaving no room for demo entities when MAX_SLOTS was 1024. Solution: create demo entities first, then load map, and increase MAX_SLOTS to 4096.
- **Entity creation order matters:** Lua script execution order determines which entities get slots when capacity is limited.
