# Issue 508h: Integration Test

**Phase:** 5 - Rendering
**Type:** Test / Demo
**Priority:** High
**Dependencies:** 508a-508g (all prior sub-issues)

---

## Current Behavior

Individual components exist but haven't been tested together.

---

## Intended Behavior

A complete demo that:
1. Loads a real WC3 map
2. Displays terrain and placed objects
3. Allows unit selection
4. Allows movement commands
5. Shows UI with game state
6. Runs at stable framerate

This is the **vertical slice proof** - the whole stack working together.

---

## Suggested Implementation Steps

### 1. Demo Entry Script

```lua
-- src/demo/testing_room.lua
-- {{{ testing_room
-- Complete vertical slice demo

local Map = require("data")
local ecs = require("runtime.ecs")
local gameloop = require("runtime.gameloop")
local movement = require("runtime.systems.movement")
local orders = require("runtime.orders")
local resources = require("runtime.resources")
local player = require("runtime.player")

local map_renderer = require("demo.map_renderer")
local input_handler = require("demo.input_handler")
local ui_updater = require("demo.ui_updater")
local render = require("render")

local testing_room = {}

-- {{{ testing_room.init
function testing_room.init(map_path)
    print("=== Testing Room - Vertical Slice Demo ===")
    print("")

    -- Load map
    print("[1/5] Loading map: " .. map_path)
    local map = Map.load(map_path)
    if not map then
        error("Failed to load map: " .. map_path)
    end
    print("      Map: " .. (map.info.name or "unnamed"))
    print("      Size: " .. map.terrain.width .. "x" .. map.terrain.height)

    -- Initialize systems
    print("[2/5] Initializing ECS...")
    ecs.init()

    print("[3/5] Initializing player...")
    player.init_from_w3i(map.info)
    local local_player = player.get_slot(0)
    resources.init_player(local_player)
    resources.set(local_player, "gold", 500)
    resources.set(local_player, "lumber", 200)
    resources.set(local_player, "food_cap", 12)
    resources.set(local_player, "food_used", 0)

    -- Register ECS systems
    print("[4/5] Registering systems...")
    ecs.register_system(movement)
    ecs.register_system(orders.system)

    -- Load into renderer
    print("[5/5] Loading into renderer...")
    map_renderer.load(map, ecs)

    -- Spawn test units if map has none
    local units = map.registry:get_all_units()
    if #units == 0 then
        print("      No units in map, spawning test units...")
        testing_room.spawn_test_units(map)
    end

    testing_room.map = map
    testing_room.local_player = local_player
    testing_room.game_time = 0

    print("")
    print("=== Ready! ===")
    print("Controls:")
    print("  Left-click: Select unit")
    print("  Shift+click: Add to selection")
    print("  Drag: Box select")
    print("  Right-click: Move selected units")
    print("  ESC: Exit")
    print("")
end
-- }}}

-- {{{ testing_room.spawn_test_units
function testing_room.spawn_test_units(map)
    local center_x = map.terrain.width / 2
    local center_z = map.terrain.height / 2

    -- Spawn 5 test units in a line
    for i = 1, 5 do
        local entity_id = ecs.create()

        ecs.add(entity_id, "position", {
            x = center_x + (i - 3) * 2,
            y = 0,
            z = center_z
        })

        ecs.add(entity_id, "renderable", {
            mesh = "circle",
            team = 0
        })

        ecs.add(entity_id, "movement", {
            speed = 5.0,
            turn_rate = 180
        })

        ecs.add(entity_id, "unit_type", {
            type_id = "hfoo"  -- Footman
        })

        ecs.add(entity_id, "stats", {
            hp = 420,
            hp_max = 420
        })

        ecs.add(entity_id, "owner", {
            player_id = testing_room.local_player
        })

        resources.add(testing_room.local_player, "food_used", 2)

        print("      Spawned test unit " .. i .. " (entity " .. entity_id .. ")")
    end
end
-- }}}

-- {{{ testing_room.update
function testing_room.update(dt)
    testing_room.game_time = testing_room.game_time + dt

    -- Update game systems
    gameloop.tick(dt)
    ecs.update(dt)

    -- Update UI
    ui_updater.update(testing_room.local_player, testing_room.game_time)
    ui_updater.update_selection()
end
-- }}}

-- {{{ testing_room.run
function testing_room.run(map_path)
    testing_room.init(map_path)

    -- Main loop handled by C render thread
    -- Lua update called each frame via render.set_update_callback

    render.set_update_callback(testing_room.update)
end
-- }}}

return testing_room
-- }}}
```

### 2. C Main Integration

```c
/* {{{ main - complete demo */
int main(int argc, char** argv) {
    const char* map_path = "test_maps/DAoW-2.1.w3x";
    if (argc > 1) {
        map_path = argv[1];
    }

    printf("=== WC3 Engine - Testing Room ===\n\n");

    // Initialize Lua
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    g_lua_state = L;

    // Register C modules
    luaopen_render(L);

    // Initialize render system
    printf("Initializing render system...\n");
    init_threading();
    init_slots();
    init_terrain();
    init_input();
    init_ui();

    // Initialize raylib
    InitWindow(1280, 720, "WC3 Engine - Testing Room");
    SetTargetFPS(60);

    // Set up camera (top-down view)
    Camera3D camera = {0};
    camera.position = (Vector3){50.0f, 80.0f, 50.0f};
    camera.target = (Vector3){50.0f, 0.0f, 50.0f};
    camera.up = (Vector3){0.0f, 1.0f, 0.0f};
    camera.fovy = 45.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    // Run Lua init
    printf("Running Lua init...\n");
    luaL_dostring(L,
        "package.path = package.path .. ';src/?.lua;src/?/init.lua'\n"
        "local testing_room = require('demo.testing_room')\n"
        "testing_room.run('" map_path "')\n"
    );

    printf("Entering main loop...\n\n");

    // Main loop
    while (!WindowShouldClose()) {
        float dt = GetFrameTime();

        // Input
        process_input();
        process_right_click();

        // Lua update
        lua_update(L, dt);

        // Update markers
        update_move_marker(dt);

        // Update workers (threading)
        sync_slots();

        // Render
        BeginDrawing();
            ClearBackground(BLACK);

            BeginMode3D(camera);
                draw_terrain();
                draw_slots();
                draw_move_marker();
            EndMode3D();

            draw_selection_box();
            draw_ui();

        EndDrawing();
    }

    // Cleanup
    CloseWindow();
    shutdown_threading();
    lua_close(L);

    printf("\n=== Shutdown complete ===\n");
    return 0;
}
/* }}} */
```

### 3. Build Script Update

```bash
#!/bin/bash
# src/render/run - Updated for full demo

PROJECT_NAME="testing_room"
DIR="${1:-/mnt/mtwo/programming/ai-stuff/world-edit-to-execute}"

PROJECT_PATH="${DIR}/src/render"
RAYLIB_PATH="/home/ritz/programming/c/libs/raylib/src"
LUA_PATH="/home/ritz/programming/c/libs/lua"  # or luajit

# Source files
SOURCES="main.c threading.c slots.c bridge.c terrain.c input.c ui.c marker.c"

echo "=== Building ${PROJECT_NAME} ==="
echo "Project: ${PROJECT_PATH}"
echo ""

cd "${PROJECT_PATH}"

gcc -pthread -Wall -g -O2 \
    -o "${PROJECT_NAME}" ${SOURCES} \
    -I"${RAYLIB_PATH}" -I"${LUA_PATH}/src" \
    -L"${RAYLIB_PATH}" -L"${LUA_PATH}/src" \
    -lraylib -llua -lm -lpthread -ldl -lrt -lX11 -lGL \
    2>&1 | tee compiler-log

if [ "$?" = 0 ]; then
    echo ""
    echo "=== Running demo ==="
    echo ""
    ./"${PROJECT_NAME}" "$2"
    rm -f "${PROJECT_NAME}"
else
    echo ""
    echo "=== Build failed ==="
fi

cd - > /dev/null
```

---

## Test Scenarios

### Scenario 1: Basic Load
1. Run demo with default map
2. Verify terrain displays
3. Verify units visible
4. Verify UI shows resources

### Scenario 2: Selection
1. Click on a unit
2. Verify selection ring appears
3. Verify UI shows unit info
4. Shift+click another unit
5. Verify both selected

### Scenario 3: Movement
1. Select unit(s)
2. Right-click on terrain
3. Verify move marker appears
4. Verify units move toward target
5. Verify units stop at destination

### Scenario 4: Performance
1. Load map with many doodads
2. Verify stable 60 FPS
3. Select and move multiple units
4. Verify no stuttering

---

## Acceptance Criteria

- [ ] Demo compiles without errors
- [ ] Demo runs without crashes
- [ ] Real map loads and displays
- [ ] Test units spawn if map empty
- [ ] Terrain grid visible with colors
- [ ] Units render as colored shapes
- [ ] Selection works (click, box, shift)
- [ ] Movement works (right-click)
- [ ] UI displays resources
- [ ] UI displays selection info
- [ ] Stable 60 FPS
- [ ] Clean exit on ESC

---

## Files

- `src/render/main.c` - Complete demo main
- `src/render/run` - Updated build script
- `src/demo/testing_room.lua` - Lua orchestration

---

## Notes

This is the milestone that proves the architecture. Once this works, we have:
- Threading model validated
- Lua-C bridge working
- ECS→render pipeline established
- Input→order→movement→render loop complete

From here, everything is incremental improvement.

---

## Related Documents

- All 508a-508g issues (dependencies)
- `docs/render-architecture.md` - Architecture being validated
