--[[
Phase 4 Visual Demo - LÖVE2D Version
Demonstrates A* pathfinding with obstacles AND collision detection

The demo visualizes the engine's pathfinding and collision systems:
- Creates a pathing grid with obstacles
- Units use A* to find paths around obstacles
- Collision system prevents units from overlapping
- Units push each other apart when they collide

Run with: love issues/completed/demos/phase4_love/
Or:       ./issues/completed/demos/run_phase4.sh -v
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ Module loading
local ecs = require("runtime.ecs")
local gameloop = require("runtime.gameloop")
local pathfinding = require("runtime.pathfinding")
local collision = require("runtime.collision")
-- }}}

-- {{{ Constants
local GRID_WIDTH = 40    -- Grid cells horizontal
local GRID_HEIGHT = 30   -- Grid cells vertical
local CELL_SIZE = 20     -- Pixels per cell
local UNIT_RADIUS = 8    -- Unit display radius in pixels
-- }}}

-- {{{ Game state
local pathing_grid = nil  -- The pathfinding grid
local units = {}
local obstacles = {}      -- Track obstacle positions for visualization

local world = {
    width = GRID_WIDTH * CELL_SIZE,
    height = GRID_HEIGHT * CELL_SIZE,
}

local stats = {
    tick = 0,
    elapsed = 0,
    moving = 0,
    paths_calculated = 0,
    collisions_resolved = 0,
}

local paused = false
local show_grid = true    -- Toggle grid visualization
local show_collision = true  -- Toggle collision radius visualization
-- }}}

-- {{{ create_pathing_grid
-- Creates a synthetic pathing grid with obstacles for demonstration.
-- This simulates what would normally come from terrain data.
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

    -- Add obstacles (walls)
    obstacles = {}

    -- Vertical wall in the middle with gaps
    local wall_x = 20
    for y = 0, GRID_HEIGHT - 1 do
        -- Leave gaps at y=5, y=15, y=25
        if y ~= 5 and y ~= 15 and y ~= 25 then
            grid.cells[y][wall_x].walkable = false
            obstacles[#obstacles + 1] = {x = wall_x, y = y}
        end
    end

    -- Horizontal wall near top
    for x = 5, 15 do
        grid.cells[8][x].walkable = false
        obstacles[#obstacles + 1] = {x = x, y = 8}
    end

    -- Horizontal wall near bottom
    for x = 25, 35 do
        grid.cells[22][x].walkable = false
        obstacles[#obstacles + 1] = {x = x, y = 22}
    end

    -- L-shaped obstacle bottom-left
    for x = 3, 8 do
        grid.cells[20][x].walkable = false
        obstacles[#obstacles + 1] = {x = x, y = 20}
    end
    for y = 16, 20 do
        grid.cells[y][8].walkable = false
        obstacles[#obstacles + 1] = {x = 8, y = y}
    end

    -- Box obstacle top-right
    for x = 30, 35 do
        grid.cells[3][x].walkable = false
        grid.cells[7][x].walkable = false
        obstacles[#obstacles + 1] = {x = x, y = 3}
        obstacles[#obstacles + 1] = {x = x, y = 7}
    end
    for y = 3, 7 do
        grid.cells[y][30].walkable = false
        grid.cells[y][35].walkable = false
        obstacles[#obstacles + 1] = {x = 30, y = y}
        obstacles[#obstacles + 1] = {x = 35, y = y}
    end

    return grid
end
-- }}}

-- {{{ grid_to_world
-- Converts grid coordinates to world (pixel) coordinates.
local function grid_to_world(gx, gy)
    return gx * CELL_SIZE + CELL_SIZE / 2, gy * CELL_SIZE + CELL_SIZE / 2
end
-- }}}

-- {{{ world_to_grid
-- Converts world (pixel) coordinates to grid coordinates.
local function world_to_grid(wx, wy)
    return math.floor(wx / CELL_SIZE), math.floor(wy / CELL_SIZE)
end
-- }}}

-- {{{ find_path_for_unit
-- Uses the engine's A* pathfinding to find a path from unit position to target.
-- Returns an array of world-coordinate waypoints.
local function find_path_for_unit(start_gx, start_gy, goal_gx, goal_gy)
    -- Use the engine's A* algorithm
    local path, cost = pathfinding.find_path(
        pathing_grid,
        start_gx, start_gy,
        goal_gx, goal_gy,
        {
            diagonal = true,  -- Allow diagonal movement
        }
    )

    if not path then
        return nil
    end

    -- Convert grid path to world coordinates
    local world_path = {}
    for i, node in ipairs(path) do
        local wx, wy = grid_to_world(node.x, node.y)
        world_path[i] = {x = wx, y = wy}
    end

    stats.paths_calculated = stats.paths_calculated + 1
    return world_path
end
-- }}}

-- {{{ create_unit
-- Creates a unit entity at the given grid position with a target.
local function create_unit(owner, start_gx, start_gy, target_gx, target_gy)
    local entity = ecs.create_entity()
    local start_wx, start_wy = grid_to_world(start_gx, start_gy)

    ecs.add_component(entity, "position", {x = start_wx, y = start_wy, facing = 0})
    ecs.add_component(entity, "unit", {
        owner = owner,
        type_id = owner == 0 and "hfoo" or "ogru",
        name = owner == 0 and "Footman" or "Grunt",
    })
    -- Collision component with proper layer/mask for unit-unit collision
    ecs.add_component(entity, "collision", {
        shape = "circle",
        radius = UNIT_RADIUS,
        layer = "unit",
        mask = {"unit"},  -- Collide with other units
        solid = true,
    })

    -- Calculate initial path using A*
    local path = find_path_for_unit(start_gx, start_gy, target_gx, target_gy)

    ecs.add_component(entity, "movement", {
        speed = 60 + owner * 10,  -- pixels per second
        path = path,
        path_index = 1,
        target_gx = target_gx,
        target_gy = target_gy,
        speed_modifier = 1.0,
    })

    units[#units + 1] = {entity = entity, owner = owner}
    return entity
end
-- }}}

-- {{{ love.load
function love.load()
    love.window.setTitle("Phase 4 - A* Pathfinding + Collision Demo")
    love.window.setMode(world.width, world.height)

    -- Reset systems
    gameloop.reset()
    ecs.reset()
    collision.reset()
    stats.paths_calculated = 0
    stats.collisions_resolved = 0

    -- Register components (only if not already registered)
    local function safe_register(name, defaults)
        if not ecs.get_component_defaults(name) then
            ecs.register_component(name, defaults)
        end
    end

    safe_register("position", {x = 0, y = 0, z = 0, facing = 0})
    safe_register("movement", {
        speed = 60,
        path = nil,
        path_index = 1,
        target_gx = nil,
        target_gy = nil,
        speed_modifier = 1.0,
    })
    safe_register("unit", {
        owner = 0,
        type_id = "unit",
        name = "Unit",
    })
    safe_register("collision", {
        shape = "circle",
        radius = UNIT_RADIUS,
        layer = "unit",
        mask = {"unit"},
        solid = true,
    })

    -- Initialize collision system with ECS
    collision.init(ecs)

    -- Create pathing grid with obstacles
    pathing_grid = create_pathing_grid()

    -- Clear units
    units = {}

    -- Create player 0 units (left side, red) - target right side
    create_unit(0, 3, 3, 36, 26)
    create_unit(0, 3, 10, 36, 20)
    create_unit(0, 3, 26, 36, 5)

    -- Create player 1 units (right side, blue) - target left side
    create_unit(1, 36, 5, 3, 26)
    create_unit(1, 36, 15, 3, 15)
    create_unit(1, 36, 26, 3, 3)
end
-- }}}

-- {{{ update_movement
-- Updates unit movement along their A* calculated paths.
-- Uses collision system to prevent overlapping.
local function update_movement(dt)
    stats.moving = 0

    for entity, pos, mov in ecs.query("position", "movement") do
        if mov.path and mov.path_index <= #mov.path then
            stats.moving = stats.moving + 1

            local wp = mov.path[mov.path_index]
            local dx = wp.x - pos.x
            local dy = wp.y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)

            -- Reached waypoint? Move to next
            local arrival_dist = CELL_SIZE * 0.3
            if dist < arrival_dist then
                mov.path_index = mov.path_index + 1
                if mov.path_index > #mov.path then
                    -- Reached destination
                    mov.path = nil
                end
            else
                -- Calculate desired position
                local speed = mov.speed * mov.speed_modifier
                local move_dist = speed * dt
                if move_dist > dist then move_dist = dist end

                local ratio = move_dist / dist
                local desired_x = pos.x + dx * ratio
                local desired_y = pos.y + dy * ratio

                -- Use collision system to check if move is valid
                -- slide_move returns actual position (may be blocked)
                local actual_x, actual_y = collision.slide_move(entity, desired_x, desired_y)

                pos.x = actual_x
                pos.y = actual_y
                pos.facing = math.atan2(dy, dx)
            end
        end
    end
end
-- }}}

-- {{{ resolve_collisions
-- Resolves any overlapping units after movement.
local function resolve_collisions()
    -- Update spatial hash for collision queries
    collision.update()

    -- Get all entities with collision
    local entities = {}
    for entity in ecs.query_single("collision") do
        local col = ecs.get_component(entity, "collision")
        if col and col.solid then
            entities[#entities + 1] = entity
        end
    end

    -- Check all pairs for overlap and resolve
    local resolved = 0
    for i = 1, #entities do
        for j = i + 1, #entities do
            local e1, e2 = entities[i], entities[j]
            local pos1 = ecs.get_component(e1, "position")
            local pos2 = ecs.get_component(e2, "position")
            local col1 = ecs.get_component(e1, "collision")
            local col2 = ecs.get_component(e2, "collision")

            if pos1 and pos2 and col1 and col2 then
                -- Check if circles overlap
                local dx = pos2.x - pos1.x
                local dy = pos2.y - pos1.y
                local dist = math.sqrt(dx * dx + dy * dy)
                local min_dist = col1.radius + col2.radius

                if dist < min_dist and dist > 0.001 then
                    -- Push apart
                    local overlap = min_dist - dist
                    local push = overlap / 2 + 0.5  -- Extra margin

                    local nx = dx / dist
                    local ny = dy / dist

                    pos1.x = pos1.x - nx * push
                    pos1.y = pos1.y - ny * push
                    pos2.x = pos2.x + nx * push
                    pos2.y = pos2.y + ny * push

                    resolved = resolved + 1
                end
            end
        end
    end

    stats.collisions_resolved = stats.collisions_resolved + resolved
end
-- }}}

-- {{{ love.update
function love.update(dt)
    if paused then return end

    -- Update game loop
    gameloop.update(dt)
    stats.tick = gameloop.get_tick()
    stats.elapsed = gameloop.get_time()

    -- Update collision spatial hash first
    collision.update()

    -- Update movement (uses collision.slide_move internally)
    update_movement(dt)

    -- Resolve any remaining overlaps
    resolve_collisions()
end
-- }}}

-- {{{ draw_grid
-- Draws the pathing grid showing walkable and blocked cells.
local function draw_grid()
    for y = 0, GRID_HEIGHT - 1 do
        for x = 0, GRID_WIDTH - 1 do
            local cell = pathing_grid.cells[y][x]
            local px = x * CELL_SIZE
            local py = y * CELL_SIZE

            if cell.walkable then
                -- Walkable cells - subtle grid
                love.graphics.setColor(0.15, 0.2, 0.15, 1)
                love.graphics.rectangle("fill", px, py, CELL_SIZE, CELL_SIZE)
                love.graphics.setColor(0.2, 0.25, 0.2, 1)
                love.graphics.rectangle("line", px, py, CELL_SIZE, CELL_SIZE)
            else
                -- Obstacles - solid color
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
-- Draws the full A* calculated paths for all units.
local function draw_paths()
    for entity, pos, mov, unit in ecs.query("position", "movement", "unit") do
        if mov.path and #mov.path > 0 then
            -- Path color based on owner
            if unit.owner == 0 then
                love.graphics.setColor(1, 0.4, 0.4, 0.6)  -- Red path
            else
                love.graphics.setColor(0.4, 0.6, 1, 0.6)  -- Blue path
            end

            -- Draw line from unit to first waypoint
            local start_idx = mov.path_index
            if start_idx <= #mov.path then
                love.graphics.line(pos.x, pos.y, mov.path[start_idx].x, mov.path[start_idx].y)
            end

            -- Draw remaining path segments
            for i = start_idx, #mov.path - 1 do
                local wp1 = mov.path[i]
                local wp2 = mov.path[i + 1]
                love.graphics.line(wp1.x, wp1.y, wp2.x, wp2.y)
            end

            -- Draw waypoint dots
            if unit.owner == 0 then
                love.graphics.setColor(1, 0.6, 0.6, 0.8)
            else
                love.graphics.setColor(0.6, 0.8, 1, 0.8)
            end
            for i = start_idx, #mov.path do
                local wp = mov.path[i]
                love.graphics.circle("fill", wp.x, wp.y, 3)
            end
        end
    end
end
-- }}}

-- {{{ draw_units
-- Draws all units with their facing direction and collision radius.
local function draw_units()
    for entity, pos, unit in ecs.query("position", "unit") do
        local coll = ecs.get_component(entity, "collision")
        local radius = coll and coll.radius or UNIT_RADIUS

        -- Draw collision circle first (if enabled)
        if show_collision then
            if unit.owner == 0 then
                love.graphics.setColor(1, 0.5, 0.5, 0.3)  -- Red tint
            else
                love.graphics.setColor(0.5, 0.7, 1, 0.3)  -- Blue tint
            end
            love.graphics.circle("fill", pos.x, pos.y, radius)
        end

        -- Draw unit core (smaller inner circle)
        local core_radius = radius * 0.6
        if unit.owner == 0 then
            love.graphics.setColor(0.9, 0.2, 0.2)  -- Red
        else
            love.graphics.setColor(0.2, 0.4, 0.9)  -- Blue
        end
        love.graphics.circle("fill", pos.x, pos.y, core_radius)

        -- Collision boundary circle
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("line", pos.x, pos.y, radius)

        -- Draw facing direction
        local fx = pos.x + math.cos(pos.facing) * radius * 1.3
        local fy = pos.y + math.sin(pos.facing) * radius * 1.3
        love.graphics.line(pos.x, pos.y, fx, fy)
    end
end
-- }}}

-- {{{ draw_hud
-- Draws the heads-up display with stats and legend.
local function draw_hud()
    -- Stats panel
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 5, 5, 210, 128)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Phase 4: Pathfinding + Collision", 10, 10)
    love.graphics.print(string.format("Tick: %d", stats.tick), 10, 28)
    love.graphics.print(string.format("Time: %.1fs", stats.elapsed), 10, 44)
    love.graphics.print(string.format("Units: %d (%d moving)", #units, stats.moving), 10, 60)
    love.graphics.print(string.format("Paths calculated: %d", stats.paths_calculated), 10, 76)
    love.graphics.setColor(1, 0.8, 0.4)
    love.graphics.print(string.format("Collisions resolved: %d", stats.collisions_resolved), 10, 92)

    if paused then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("PAUSED", 10, 110)
    end

    -- Legend panel
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

    -- Controls hint
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Space=Pause R=Reset G=Grid C=Collision Click=Move Esc=Quit", 10, world.height - 18)
end
-- }}}

-- {{{ love.draw
function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.15, 0.1)
    love.graphics.clear()

    -- Draw pathing grid
    if show_grid then
        draw_grid()
    end

    -- Draw paths before units (so units appear on top)
    draw_paths()

    -- Draw units
    draw_units()

    -- Draw HUD
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
        love.load()  -- Reset
    elseif key == "g" then
        show_grid = not show_grid
    elseif key == "c" then
        show_collision = not show_collision
    end
end
-- }}}

-- {{{ love.mousepressed
function love.mousepressed(x, y, button)
    if button == 1 then  -- Left click
        -- Calculate target grid position
        local target_gx, target_gy = world_to_grid(x, y)

        -- Clamp to grid bounds
        target_gx = math.max(0, math.min(GRID_WIDTH - 1, target_gx))
        target_gy = math.max(0, math.min(GRID_HEIGHT - 1, target_gy))

        -- Check if target is walkable
        local cell = pathing_grid.cells[target_gy][target_gx]
        if not cell or not cell.walkable then
            -- Find nearest walkable cell
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

        -- Order player 0 units to move to clicked position
        for entity, pos, unit in ecs.query("position", "unit") do
            if unit.owner == 0 then
                local mov = ecs.get_component(entity, "movement")
                if mov then
                    local start_gx, start_gy = world_to_grid(pos.x, pos.y)
                    local path = find_path_for_unit(start_gx, start_gy, target_gx, target_gy)

                    if path then
                        mov.path = path
                        mov.path_index = 1
                        mov.target_gx = target_gx
                        mov.target_gy = target_gy
                    end
                end
            end
        end
    end
end
-- }}}
