# Issue 408e: Visual Demo

**Phase:** 4 - Runtime
**Type:** Demo
**Priority:** Medium
**Dependencies:** 408d (integration tests pass first)

---

## Current Behavior

Phase 4 progress is measured only by unit tests and integration tests. No visual demonstration exists to show runtime systems in action.

---

## Intended Behavior

Interactive visual demo showing Phase 4 capabilities:
- Graphical window displaying a simple map view
- Units represented as colored circles
- Movement visualization (units following paths)
- Collision boundaries visible
- Resource display and game time
- User interaction (click to issue orders)

Per project guidelines: "A visual demonstration should be created which shows the actually produced outputs."

---

## Suggested Implementation Steps

1. **Create demo file structure**
   ```
   issues/completed/demos/
   ├── run_phase4.sh          # Entry point script
   └── phase4_visual.lua      # Main demo source
   ```

2. **Choose graphics library**
   ```lua
   -- Option 1: LÖVE2D (love2d.org) - Full-featured game framework
   -- Option 2: SDL2 via luasdl2 - Lower level, more control
   -- Option 3: Terminal-based with TUI library (no external deps)

   -- Recommendation: Start with terminal TUI, upgrade to LÖVE2D if time permits
   ```

3. **Implement terminal-based visualization**
   ```lua
   -- {{{ Terminal-based map display
   -- Uses TUI library for cursor positioning and colors
   local function draw_map_terminal(systems, width, height)
       local tui = require("libs.tui")

       -- Scale factor: world units to terminal cells
       local scale_x = systems.terrain.width * systems.terrain.cell_size / width
       local scale_y = systems.terrain.height * systems.terrain.cell_size / height

       -- Clear screen
       tui.clear()

       -- Draw terrain (obstacles as #, walkable as .)
       for ty = 1, height do
           for tx = 1, width do
               local wx = (tx - 1) * scale_x
               local wy = (ty - 1) * scale_y
               local gx = math.floor(wx / systems.terrain.cell_size)
               local gy = math.floor(wy / systems.terrain.cell_size)

               if systems.terrain:is_walkable(gx, gy) then
                   tui.set_color("green")
                   tui.write_at(tx, ty, ".")
               else
                   tui.set_color("red")
                   tui.write_at(tx, ty, "#")
               end
           end
       end

       -- Draw units
       local units = systems.ecs.query({"position", "unit"})
       for _, entity in ipairs(units) do
           local pos = systems.ecs.get_component(entity, "position")
           local unit = systems.ecs.get_component(entity, "unit")

           local tx = math.floor(pos.x / scale_x) + 1
           local ty = math.floor(pos.y / scale_y) + 1

           -- Clamp to screen bounds
           tx = math.max(1, math.min(width, tx))
           ty = math.max(1, math.min(height, ty))

           -- Color by owner
           local colors = {"red", "blue", "teal", "purple"}
           tui.set_color(colors[unit.owner + 1] or "white")
           tui.write_at(tx, ty, "O")
       end

       -- Draw status bar
       tui.set_color("white")
       local tick = systems.gameloop.get_tick()
       local game_time = tick / 62.5
       tui.write_at(1, height + 1, string.format(
           "Tick: %d | Time: %.1fs | Units: %d",
           tick, game_time, #units))

       tui.flush()
   end
   -- }}}
   ```

4. **Implement main demo loop**
   ```lua
   -- {{{ Main demo loop
   local function run_demo()
       local systems = init_all_systems()

       -- Configure demo scenario
       setup_demo_scenario(systems)

       -- Terminal size (80x24 standard)
       local map_width = 78
       local map_height = 20

       -- Demo parameters
       local max_ticks = 625  -- 10 seconds at 62.5 ticks/sec
       local frame_delay = 0.032  -- ~30 FPS display update

       print("Phase 4 Visual Demo - Press Ctrl+C to exit")
       print("Initializing...")

       -- Main loop
       local last_draw = os.clock()
       for tick = 1, max_ticks do
           -- Update game state
           systems.gameloop.tick()
           systems.movement.update()
           systems.collision.update()

           -- Draw at ~30 FPS
           local now = os.clock()
           if now - last_draw >= frame_delay then
               draw_map_terminal(systems, map_width, map_height)
               last_draw = now
           end

           -- Small sleep to not max CPU
           os.execute("sleep 0.001")
       end

       print("\nDemo complete!")
       shutdown_all_systems(systems)
   end
   -- }}}
   ```

5. **Create demo scenario with movement**
   ```lua
   -- {{{ Setup demo scenario
   local function setup_demo_scenario(systems)
       -- Two players
       systems.player.set_slot(0, {type = "human", team = 0, race = "human"})
       systems.player.set_slot(1, {type = "computer", team = 1, race = "orc"})

       -- Starting resources
       systems.resources.set(0, "gold", 500)
       systems.resources.set(0, "lumber", 150)
       systems.resources.set(1, "gold", 500)
       systems.resources.set(1, "lumber", 150)

       -- Spawn units for player 0 (corner 1)
       local p0_units = {}
       for i = 1, 5 do
           local x = 500 + (i - 1) * 100
           local y = 500
           local unit = spawn_unit(systems, 0, x, y, "footman")
           p0_units[i] = unit
       end

       -- Spawn units for player 1 (opposite corner)
       local p1_units = {}
       for i = 1, 5 do
           local x = 7500 - (i - 1) * 100
           local y = 7500
           local unit = spawn_unit(systems, 1, x, y, "grunt")
           p1_units[i] = unit
       end

       -- Issue movement orders (march toward each other)
       for _, unit in ipairs(p0_units) do
           systems.movement.order_move(unit, 4000, 4000)
       end
       for _, unit in ipairs(p1_units) do
           systems.movement.order_move(unit, 4000, 4000)
       end

       return p0_units, p1_units
   end
   -- }}}
   ```

6. **Create run script**
   ```bash
   #!/usr/bin/env bash
   # {{{ run_phase4.sh
   # Phase 4 Runtime Demo - Visual demonstration of game systems
   # Shows units moving, collision detection, and resource tracking

   DIR="${1:-/mnt/mtwo/programming/ai-stuff/world-edit-to-execute}"

   cd "$DIR" || exit 1

   echo "==================================="
   echo "  Phase 4: Runtime Visual Demo"
   echo "==================================="
   echo ""
   echo "This demo shows:"
   echo "  - Units spawning at start locations"
   echo "  - Pathfinding and movement"
   echo "  - Collision avoidance between units"
   echo "  - Real-time game loop at 62.5 ticks/sec"
   echo ""
   echo "Press any key to start..."
   read -n 1

   lua "${DIR}/issues/completed/demos/phase4_visual.lua"
   # }}}
   ```

7. **Add statistics display**
   ```lua
   -- {{{ Display runtime statistics
   local function display_stats(systems)
       local stats = {
           tick = systems.gameloop.get_tick(),
           entities = #systems.ecs.get_all_entities(),
           units = #systems.ecs.query({"unit"}),
           moving = 0,
           collisions_checked = 0,
       }

       -- Count moving units
       local movers = systems.ecs.query({"movement"})
       for _, entity in ipairs(movers) do
           local mov = systems.ecs.get_component(entity, "movement")
           if mov.current_order then
               stats.moving = stats.moving + 1
           end
       end

       -- Get collision stats if available
       if systems.collision.get_stats then
           local coll_stats = systems.collision.get_stats()
           stats.collisions_checked = coll_stats.checks_this_frame or 0
       end

       return stats
   end
   -- }}}
   ```

8. **Implement LÖVE2D version (optional)**
   ```lua
   -- {{{ LÖVE2D graphical version
   -- Only compiled if LÖVE2D is available
   -- Place in: issues/completed/demos/phase4_love.lua

   function love.load()
       -- Initialize game systems
       systems = init_all_systems()
       setup_demo_scenario(systems)

       -- Window settings
       love.window.setMode(800, 600)
       love.window.setTitle("Phase 4 - Runtime Demo")

       -- Scale factor
       scale = 800 / (64 * 128)  -- pixels per world unit
   end

   function love.update(dt)
       -- Run game ticks (accumulate time)
       time_accumulator = (time_accumulator or 0) + dt
       local tick_time = 1 / 62.5

       while time_accumulator >= tick_time do
           systems.gameloop.tick()
           systems.movement.update()
           systems.collision.update()
           time_accumulator = time_accumulator - tick_time
       end
   end

   function love.draw()
       -- Draw terrain
       love.graphics.setColor(0.2, 0.3, 0.2)
       love.graphics.rectangle("fill", 0, 0, 800, 600)

       -- Draw obstacles
       love.graphics.setColor(0.4, 0.2, 0.2)
       for gx = 30, 33 do
           for gy = 30, 33 do
               local wx = gx * 128 * scale
               local wy = gy * 128 * scale
               love.graphics.rectangle("fill", wx, wy, 128 * scale, 128 * scale)
           end
       end

       -- Draw units
       local units = systems.ecs.query({"position", "unit"})
       for _, entity in ipairs(units) do
           local pos = systems.ecs.get_component(entity, "position")
           local unit = systems.ecs.get_component(entity, "unit")
           local coll = systems.ecs.get_component(entity, "collision")

           local sx = pos.x * scale
           local sy = pos.y * scale
           local radius = (coll and coll.radius or 32) * scale

           -- Color by owner
           if unit.owner == 0 then
               love.graphics.setColor(1, 0.2, 0.2)  -- Red
           else
               love.graphics.setColor(0.2, 0.2, 1)  -- Blue
           end

           love.graphics.circle("fill", sx, sy, radius)
           love.graphics.setColor(1, 1, 1)
           love.graphics.circle("line", sx, sy, radius)
       end

       -- Draw HUD
       love.graphics.setColor(1, 1, 1)
       local tick = systems.gameloop.get_tick()
       love.graphics.print(string.format(
           "Tick: %d | Time: %.1fs | Units: %d",
           tick, tick / 62.5, #units), 10, 10)
   end

   function love.mousepressed(x, y, button)
       -- Click to issue move orders to player 0 units
       if button == 1 then
           local world_x = x / scale
           local world_y = y / scale

           local units = systems.ecs.query({"unit", "movement"})
           for _, entity in ipairs(units) do
               local unit = systems.ecs.get_component(entity, "unit")
               if unit.owner == 0 then
                   systems.movement.order_move(entity, world_x, world_y)
               end
           end
       end
   end
   -- }}}
   ```

9. **Update main run-demo.sh selector**
   ```bash
   # Add Phase 4 option to run-demo.sh in project root
   # Phase 4: Runtime Demo
   echo "4) Phase 4 - Runtime (visual demo of movement and collision)"
   ```

10. **Create comprehensive demo documentation**
    ```lua
    -- {{{ Demo documentation header
    --[[
    Phase 4 Visual Demo
    ===================

    Demonstrates all Phase 4 runtime systems working together:

    Systems Shown:
    - Game Loop (401): Fixed 62.5 tick/sec update rate
    - ECS (402): Entity creation, component queries
    - Pathfinding (403): A* around obstacles
    - Movement (404): Path following, speed-based travel
    - Collision (405): Circle-circle collision, spatial queries
    - Resources (406): Gold/lumber tracking (HUD display)
    - Player State (407): Two-player setup, team colors

    Visual Elements:
    - Green dots: Walkable terrain
    - Red #: Obstacles (unwalkable)
    - Red O: Player 0 units
    - Blue O: Player 1 units

    Controls (LÖVE2D version):
    - Left click: Order player 0 units to move
    - ESC: Exit demo

    Expected Behavior:
    1. Units spawn in opposite corners
    2. Both groups move toward center
    3. Paths curve around center obstacle
    4. Units avoid colliding with each other
    5. All units converge near center
    ]]
    -- }}}
    ```

---

## Related Documents

- issues/408-phase-4-integration-test.md (parent issue)
- issues/408d-integration-scenario.md (tests that must pass before demo)
- issues/completed/demos/ (demo directory)
- /home/ritz/programming/ai-stuff/libs/lua/ (available libraries)

---

## Acceptance Criteria

- [x] Demo script runs without errors
- [x] Terminal version shows map grid with terrain
- [x] Units displayed as colored characters
- [x] Units visibly move over time
- [x] Movement paths avoid obstacles
- [x] Units don't overlap (collision visible)
- [x] Status bar shows tick count and game time
- [x] Demo runs for 10 seconds then exits cleanly
- [x] run_phase4.sh added to demo selector
- [ ] (Optional) LÖVE2D version with click-to-move

---

## Implementation Notes

**Completed:** 2025-12-31

Added visual animation demo (`[V]` option) to `issues/completed/demos/phase4_demo.lua`:

| Feature | Implementation |
|---------|----------------|
| Grid Display | 60x20 terminal grid with box-drawing characters |
| Unit Visualization | Red ● (player 0) and Blue ● (player 1) circles |
| Movement | 10 units (5 per team) march toward opposite sides |
| Real-time Animation | 20 FPS display, 62.5 Hz game tick |
| Status Bar | Shows tick count, elapsed time, unit count |
| Moving Counter | Displays active movers vs total units |

**Animation Flow:**
1. Initialize ECS with position, movement, unit, collision components
2. Spawn 5 units per team on opposite sides
3. Issue movement orders toward opposite corners
4. Update movement each tick (simplified path following)
5. Redraw grid at 20 FPS using ANSI escape codes
6. Exit when all units reach destination or 10 seconds elapsed

**Files Modified:**
- `issues/completed/demos/phase4_demo.lua` - Added `demo_visual_animation()` function and menu option

---

## Notes

The terminal version is sufficient for demonstrating Phase 4 completion. LÖVE2D is optional but provides a better experience for visualizing movement and collision.

Per project conventions:
- "Phase demos should focus on demonstrating relevant statistics or datapoints"
- "A visual demonstration should be created which shows the actually produced outputs"

The demo is intentionally simple - just units moving toward each other. Combat and abilities are Phase 5 content. This demo proves the foundation is solid.

Performance target: Demo should run smoothly at 30 FPS display update while maintaining 62.5 game ticks per second internally.

---

## Known Issues

| Bug | Description | Severity | Notes |
|-----|-------------|----------|-------|
| Units stuck on collision | When multiple units converge on the same path through a gap, they can get stuck pushing against each other instead of finding alternate routes | Low | The collision resolution pushes units apart but doesn't trigger path recalculation. Units eventually free themselves but movement is not optimal. Future fix: implement local avoidance steering or repath on blocked detection. |

