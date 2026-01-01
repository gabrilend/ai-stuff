--[[
Phase 4 Visual Demo - LÖVE2D Version
Pure visualization of engine systems: ECS, pathfinding, movement, collision

This demo ONLY renders engine state. All logic is handled by:
- runtime/systems/movement.lua   → Path following, speed, turning
- runtime/pathfinding/           → A* algorithm, coordinate conversion
- runtime/collision/             → Spatial queries, overlap resolution
- runtime/ecs/                   → Entity-component-system, system updates

The demo creates a synthetic pathing grid and entities, then lets the
engine run. We just draw what the engine computes.

Run with: love issues/completed/demos/phase4_love/
Or:       ./issues/completed/demos/run_phase4.sh -v
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ Engine modules
local ecs = require("runtime.ecs")
local gameloop = require("runtime.gameloop")
local pathfinding = require("runtime.pathfinding")
local collision = require("runtime.collision")
local movement_sys = require("runtime.systems.movement")
-- }}}

-- {{{ Demo constants (for grid creation and rendering)
local GRID_WIDTH = 40
local GRID_HEIGHT = 30
local CELL_SIZE = 20
local UNIT_RADIUS = 8
-- }}}

-- {{{ Demo state (rendering only)
local pathing_grid = nil
local unit_entities = {}  -- Just entity IDs for rendering

local world = {
    width = GRID_WIDTH * CELL_SIZE,
    height = GRID_HEIGHT * CELL_SIZE,
}

local stats = {
    paths_requested = 0,
    collisions_resolved = 0,
}

local paused = false
local show_grid = true
local show_collision = true
-- }}}

-- {{{ create_pathing_grid
-- Creates a synthetic pathing grid for demonstration.
-- In a real game, this would come from terrain data via pathfinding.build_grid()
local function create_pathing_grid()
    local grid = {
        width = GRID_WIDTH,
        height = GRID_HEIGHT,
        tile_size = CELL_SIZE,
        offset_x = 0,
        offset_y = 0,
        cells = {},
    }

    -- Initialize all cells as walkable
    for y = 0, GRID_HEIGHT - 1 do
        grid.cells[y] = {}
        for x = 0, GRID_WIDTH - 1 do
            grid.cells[y][x] = {
                walkable = true,
                flyable = true,
                buildable = true,
                water = false,
                cliff_level = 0,
            }
        end
    end

    -- Add obstacles - vertical wall with gaps
    for y = 0, GRID_HEIGHT - 1 do
        if y ~= 5 and y ~= 15 and y ~= 25 then
            grid.cells[y][20].walkable = false
        end
    end

    -- Horizontal walls
    for x = 5, 15 do grid.cells[8][x].walkable = false end
    for x = 25, 35 do grid.cells[22][x].walkable = false end

    -- L-shaped obstacle
    for x = 3, 8 do grid.cells[20][x].walkable = false end
    for y = 16, 20 do grid.cells[y][8].walkable = false end

    -- Box obstacle
    for x = 30, 35 do
        grid.cells[3][x].walkable = false
        grid.cells[7][x].walkable = false
    end
    for y = 3, 7 do
        grid.cells[y][30].walkable = false
        grid.cells[y][35].walkable = false
    end

    return grid
end
-- }}}

-- {{{ request_path
-- Uses engine pathfinding to calculate path and set it on entity via movement system
local function request_path(entity, target_gx, target_gy)
    local pos = ecs.get_component(entity, "position")
    if not pos then return false end

    -- Use engine coordinate conversion
    local start_gx, start_gy = pathfinding.world_to_grid(pos.x, pos.y)
    if not start_gx then return false end

    -- Use engine A* pathfinding
    local grid_path = pathfinding.find_path(
        pathing_grid,
        start_gx, start_gy,
        target_gx, target_gy,
        { diagonal = true }
    )

    if not grid_path then return false end

    -- Use engine coordinate conversion for path
    local world_path = pathfinding.path_to_world(grid_path)

    -- Use engine movement system to set path
    movement_sys.set_path(entity, world_path)
    stats.paths_requested = stats.paths_requested + 1

    return true
end
-- }}}

-- {{{ create_unit
-- Creates a unit entity using engine ECS and sets initial path
local function create_unit(owner, start_gx, start_gy, target_gx, target_gy)
    local entity = ecs.create_entity()

    -- Convert grid to world using engine function
    local start_wx, start_wy = pathfinding.grid_to_world(start_gx, start_gy)

    -- Add components via engine ECS
    ecs.add_component(entity, "position", {
        x = start_wx,
        y = start_wy,
        z = 0,
        facing = owner == 0 and 0 or math.pi,
    })

    ecs.add_component(entity, "unit", {
        owner = owner,
        type_id = owner == 0 and "hfoo" or "ogru",
        name = owner == 0 and "Footman" or "Grunt",
    })

    -- Movement component uses engine defaults from movement_sys
    ecs.add_component(entity, "movement", {
        speed = movement_sys.SPEED.NORMAL + owner * 50,
        pathing_type = movement_sys.PATHING_TYPE.FOOT,
    })

    -- Collision component for engine collision system
    ecs.add_component(entity, "collision", {
        shape = "circle",
        radius = UNIT_RADIUS,
        layer = "unit",
        mask = {"unit"},
        solid = true,
    })

    -- Request initial path via engine pathfinding
    request_path(entity, target_gx, target_gy)

    unit_entities[#unit_entities + 1] = entity
    return entity
end
-- }}}

-- {{{ love.load
function love.load()
    love.window.setTitle("Phase 4 - Engine Systems Demo")
    love.window.setMode(world.width, world.height)

    -- Reset engine systems
    gameloop.reset()
    ecs.reset()
    collision.reset()
    stats.paths_requested = 0
    stats.collisions_resolved = 0

    -- Register components if not already registered
    local function safe_register(name, defaults)
        if not ecs.get_component_defaults(name) then
            ecs.register_component(name, defaults)
        end
    end

    safe_register("position", {x = 0, y = 0, z = 0, facing = 0})
    safe_register("unit", {owner = 0, type_id = "unit", name = "Unit"})

    -- Initialize engine collision system
    collision.init(ecs)

    -- Create pathing grid and set as active for engine coordinate conversion
    pathing_grid = create_pathing_grid()
    pathfinding.set_grid(pathing_grid)

    -- Create units
    unit_entities = {}
    create_unit(0, 3, 3, 36, 26)
    create_unit(0, 3, 10, 36, 20)
    create_unit(0, 3, 26, 36, 5)
    create_unit(1, 36, 5, 3, 26)
    create_unit(1, 36, 15, 3, 15)
    create_unit(1, 36, 26, 3, 3)
end
-- }}}

-- {{{ love.update
function love.update(dt)
    if paused then return end

    -- Update engine gameloop (tick timing)
    gameloop.update(dt)

    -- Update engine collision spatial hash
    collision.update()

    -- Run engine ECS systems (includes movement system)
    -- The movement system handles: path following, speed, turning, collision slide
    ecs.update(dt)

    -- Resolve overlaps using engine collision system
    local before = stats.collisions_resolved
    collision.resolve_all_overlaps()
    -- Count how many were resolved this frame (approximate)
    for i = 1, #unit_entities do
        for j = i + 1, #unit_entities do
            local pos1 = ecs.get_component(unit_entities[i], "position")
            local pos2 = ecs.get_component(unit_entities[j], "position")
            local col1 = ecs.get_component(unit_entities[i], "collision")
            local col2 = ecs.get_component(unit_entities[j], "collision")
            if pos1 and pos2 and col1 and col2 then
                local dx = pos2.x - pos1.x
                local dy = pos2.y - pos1.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < col1.radius + col2.radius then
                    stats.collisions_resolved = stats.collisions_resolved + 1
                end
            end
        end
    end
end
-- }}}

-- ============================================================================
-- RENDERING (pure visualization of engine state)
-- ============================================================================

-- {{{ draw_grid
local function draw_grid()
    for y = 0, GRID_HEIGHT - 1 do
        for x = 0, GRID_WIDTH - 1 do
            local cell = pathing_grid.cells[y][x]
            local px = x * CELL_SIZE
            local py = y * CELL_SIZE

            if cell.walkable then
                love.graphics.setColor(0.15, 0.2, 0.15, 1)
                love.graphics.rectangle("fill", px, py, CELL_SIZE, CELL_SIZE)
                love.graphics.setColor(0.2, 0.25, 0.2, 1)
                love.graphics.rectangle("line", px, py, CELL_SIZE, CELL_SIZE)
            else
                love.graphics.setColor(0.4, 0.25, 0.2, 1)
                love.graphics.rectangle("fill", px, py, CELL_SIZE, CELL_SIZE)
                love.graphics.setColor(0.5, 0.3, 0.25, 1)
                love.graphics.rectangle("line", px, py, CELL_SIZE, CELL_SIZE)
            end
        end
    end
end
-- }}}

-- {{{ draw_paths
local function draw_paths()
    for _, entity in ipairs(unit_entities) do
        local pos = ecs.get_component(entity, "position")
        local mov = ecs.get_component(entity, "movement")
        local unit = ecs.get_component(entity, "unit")

        if pos and mov and mov.path and #mov.path > 0 then
            -- Path color by owner
            if unit and unit.owner == 0 then
                love.graphics.setColor(1, 0.4, 0.4, 0.6)
            else
                love.graphics.setColor(0.4, 0.6, 1, 0.6)
            end

            -- Draw from unit to current waypoint
            local idx = mov.path_index or 1
            if idx <= #mov.path then
                love.graphics.line(pos.x, pos.y, mov.path[idx].x, mov.path[idx].y)
            end

            -- Draw remaining path
            for i = idx, #mov.path - 1 do
                love.graphics.line(mov.path[i].x, mov.path[i].y,
                                   mov.path[i + 1].x, mov.path[i + 1].y)
            end

            -- Waypoint dots
            if unit and unit.owner == 0 then
                love.graphics.setColor(1, 0.6, 0.6, 0.8)
            else
                love.graphics.setColor(0.6, 0.8, 1, 0.8)
            end
            for i = idx, #mov.path do
                love.graphics.circle("fill", mov.path[i].x, mov.path[i].y, 3)
            end
        end
    end
end
-- }}}

-- {{{ draw_units
local function draw_units()
    for _, entity in ipairs(unit_entities) do
        local pos = ecs.get_component(entity, "position")
        local unit = ecs.get_component(entity, "unit")
        local coll = ecs.get_component(entity, "collision")

        if not pos then goto continue end

        local radius = coll and coll.radius or UNIT_RADIUS

        -- Collision radius visualization
        if show_collision then
            if unit and unit.owner == 0 then
                love.graphics.setColor(1, 0.5, 0.5, 0.3)
            else
                love.graphics.setColor(0.5, 0.7, 1, 0.3)
            end
            love.graphics.circle("fill", pos.x, pos.y, radius)
        end

        -- Unit core
        if unit and unit.owner == 0 then
            love.graphics.setColor(0.9, 0.2, 0.2)
        else
            love.graphics.setColor(0.2, 0.4, 0.9)
        end
        love.graphics.circle("fill", pos.x, pos.y, radius * 0.6)

        -- Collision boundary
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("line", pos.x, pos.y, radius)

        -- Facing direction (from engine position.facing)
        local fx = pos.x + math.cos(pos.facing) * radius * 1.3
        local fy = pos.y + math.sin(pos.facing) * radius * 1.3
        love.graphics.line(pos.x, pos.y, fx, fy)

        ::continue::
    end
end
-- }}}

-- {{{ draw_hud
local function draw_hud()
    -- Count moving units using engine movement system
    local moving_count = 0
    for _, entity in ipairs(unit_entities) do
        if movement_sys.is_moving(entity) then
            moving_count = moving_count + 1
        end
    end

    -- Stats panel
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 5, 5, 220, 130)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Phase 4: Engine Systems Demo", 10, 10)
    love.graphics.print(string.format("Tick: %d", gameloop.get_tick()), 10, 28)
    love.graphics.print(string.format("Time: %.1fs", gameloop.get_time()), 10, 44)
    love.graphics.print(string.format("Units: %d (%d moving)", #unit_entities, moving_count), 10, 60)
    love.graphics.print(string.format("Paths requested: %d", stats.paths_requested), 10, 76)
    love.graphics.setColor(1, 0.8, 0.4)
    love.graphics.print(string.format("Collision events: %d", stats.collisions_resolved), 10, 92)

    if paused then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("PAUSED", 10, 110)
    end

    -- Legend
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", world.width - 145, 5, 140, 75)

    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.circle("fill", world.width - 130, 20, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Footmen", world.width - 118, 13)

    love.graphics.setColor(0.2, 0.4, 0.9)
    love.graphics.circle("fill", world.width - 130, 40, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Grunts", world.width - 118, 33)

    love.graphics.setColor(0.4, 0.25, 0.2)
    love.graphics.rectangle("fill", world.width - 136, 54, 12, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Obstacle", world.width - 118, 53)

    -- Controls
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Space=Pause R=Reset G=Grid C=Collision Click=Move Esc=Quit", 10, world.height - 18)
end
-- }}}

-- {{{ love.draw
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.15, 0.1)
    love.graphics.clear()

    if show_grid then draw_grid() end
    draw_paths()
    draw_units()
    draw_hud()
end
-- }}}

-- {{{ love.keypressed
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        paused = not paused
    elseif key == "r" then
        love.load()
    elseif key == "g" then
        show_grid = not show_grid
    elseif key == "c" then
        show_collision = not show_collision
    end
end
-- }}}

-- {{{ love.mousepressed
function love.mousepressed(x, y, button)
    if button == 1 then
        -- Use engine coordinate conversion
        local target_gx, target_gy = pathfinding.world_to_grid_clamped(x, y)

        -- Find nearest walkable cell if clicking on obstacle
        local cell = pathing_grid.cells[target_gy] and pathing_grid.cells[target_gy][target_gx]
        if not cell or not cell.walkable then
            for r = 1, 5 do
                for dy = -r, r do
                    for dx = -r, r do
                        local nx, ny = target_gx + dx, target_gy + dy
                        if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT then
                            local nc = pathing_grid.cells[ny][nx]
                            if nc and nc.walkable then
                                target_gx, target_gy = nx, ny
                                goto found
                            end
                        end
                    end
                end
            end
            ::found::
        end

        -- Order player 0 units to move using engine pathfinding
        for _, entity in ipairs(unit_entities) do
            local unit = ecs.get_component(entity, "unit")
            if unit and unit.owner == 0 then
                request_path(entity, target_gx, target_gy)
            end
        end
    end
end
-- }}}
