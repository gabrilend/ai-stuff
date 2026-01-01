--[[
Phase 4 Visual Demo - LÖVE2D Version
Demonstrates runtime systems: ECS, movement, game loop

Run with: love issues/completed/demos/phase4_love/
Or:       ./issues/completed/demos/run_phase4.sh -v
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ Module loading
local ecs = require("runtime.ecs")
local gameloop = require("runtime.gameloop")
-- }}}

-- {{{ Game state
local units = {}
local world = {
    width = 800,
    height = 600,
    scale = 0.1,  -- world units to pixels
}
local stats = {
    tick = 0,
    elapsed = 0,
    moving = 0,
}
local paused = false
-- }}}

-- {{{ love.load
function love.load()
    love.window.setTitle("Phase 4 - Runtime Visual Demo")
    love.window.setMode(world.width, world.height)

    -- Reset systems
    gameloop.reset()
    ecs.reset()

    -- Register components (only if not already registered)
    local function safe_register(name, defaults)
        if not ecs.get_component_defaults(name) then
            ecs.register_component(name, defaults)
        end
    end

    safe_register("position", {x = 0, y = 0, z = 0, facing = 0})
    safe_register("movement", {
        speed = 270,
        path = nil,
        path_index = 1,
        target = nil,
        speed_modifier = 1.0,
        last_x = 0,
        last_y = 0,
    })
    safe_register("unit", {
        owner = 0,
        type_id = "unit",
        name = "Unit",
    })
    safe_register("collision", {
        radius = 32,
        solid = true,
    })

    -- Create player 0 units (left side, red)
    for i = 1, 5 do
        local entity = ecs.create_entity()
        local start_x = 1000
        local start_y = 1500 + (i - 1) * 800
        local target_x = 7000
        local target_y = start_y

        ecs.add_component(entity, "position", {x = start_x, y = start_y, facing = 0})
        ecs.add_component(entity, "unit", {owner = 0, type_id = "hfoo", name = "Footman"})
        ecs.add_component(entity, "collision", {radius = 150, solid = true})
        ecs.add_component(entity, "movement", {
            speed = 200 + i * 30,
            path = {{x = target_x, y = target_y}},
            path_index = 1,
            target = {x = target_x, y = target_y},
            last_x = start_x,
            last_y = start_y,
        })

        units[#units + 1] = {entity = entity, owner = 0}
    end

    -- Create player 1 units (right side, blue)
    for i = 1, 5 do
        local entity = ecs.create_entity()
        local start_x = 7000
        local start_y = 1500 + (i - 1) * 800
        local target_x = 1000
        local target_y = start_y

        ecs.add_component(entity, "position", {x = start_x, y = start_y, facing = math.pi})
        ecs.add_component(entity, "unit", {owner = 1, type_id = "ogru", name = "Grunt"})
        ecs.add_component(entity, "collision", {radius = 180, solid = true})
        ecs.add_component(entity, "movement", {
            speed = 180 + i * 25,
            path = {{x = target_x, y = target_y}},
            path_index = 1,
            target = {x = target_x, y = target_y},
            last_x = start_x,
            last_y = start_y,
        })

        units[#units + 1] = {entity = entity, owner = 1}
    end
end
-- }}}

-- {{{ update_movement
-- Simplified movement update (from demo)
local function update_movement(dt)
    stats.moving = 0

    for entity, pos, mov in ecs.query("position", "movement") do
        mov.last_x = pos.x
        mov.last_y = pos.y

        if mov.path and mov.path_index <= #mov.path then
            stats.moving = stats.moving + 1

            local wp = mov.path[mov.path_index]
            local dx = wp.x - pos.x
            local dy = wp.y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 10 then
                mov.path_index = mov.path_index + 1
                if mov.path_index > #mov.path then
                    mov.path = nil
                end
            else
                local speed = mov.speed * mov.speed_modifier
                local move_dist = speed * dt
                if move_dist > dist then move_dist = dist end

                local ratio = move_dist / dist
                pos.x = pos.x + dx * ratio
                pos.y = pos.y + dy * ratio
                pos.facing = math.atan2(dy, dx)
            end
        end
    end
end
-- }}}

-- {{{ love.update
function love.update(dt)
    if paused then return end

    -- Update game loop
    gameloop.update(dt)
    stats.tick = gameloop.get_tick()
    stats.elapsed = gameloop.get_time()

    -- Update movement
    update_movement(dt)
end
-- }}}

-- {{{ love.draw
function love.draw()
    -- Background
    love.graphics.setBackgroundColor(0.1, 0.15, 0.1)
    love.graphics.clear()

    -- Draw grid lines
    love.graphics.setColor(0.2, 0.25, 0.2)
    for x = 0, world.width, 50 do
        love.graphics.line(x, 0, x, world.height)
    end
    for y = 0, world.height, 50 do
        love.graphics.line(0, y, world.width, y)
    end

    -- Draw units
    for entity, pos, unit in ecs.query("position", "unit") do
        local coll = ecs.get_component(entity, "collision")
        local mov = ecs.get_component(entity, "movement")

        -- Convert world coords to screen
        local sx = pos.x * world.scale
        local sy = pos.y * world.scale
        local radius = (coll and coll.radius or 100) * world.scale

        -- Color by owner
        if unit.owner == 0 then
            love.graphics.setColor(0.9, 0.2, 0.2)  -- Red
        else
            love.graphics.setColor(0.2, 0.4, 0.9)  -- Blue
        end

        -- Draw unit circle
        love.graphics.circle("fill", sx, sy, radius)

        -- White border
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("line", sx, sy, radius)

        -- Draw facing direction
        local fx = sx + math.cos(pos.facing) * radius * 1.5
        local fy = sy + math.sin(pos.facing) * radius * 1.5
        love.graphics.line(sx, sy, fx, fy)

        -- Draw path line if moving
        if mov and mov.path and mov.path_index <= #mov.path then
            love.graphics.setColor(1, 1, 0, 0.5)
            local wp = mov.path[mov.path_index]
            love.graphics.line(sx, sy, wp.x * world.scale, wp.y * world.scale)
        end
    end

    -- Draw HUD
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 5, 5, 250, 100)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Phase 4: Runtime Demo"), 10, 10)
    love.graphics.print(string.format("Tick: %d", stats.tick), 10, 30)
    love.graphics.print(string.format("Time: %.1fs", stats.elapsed), 10, 50)
    love.graphics.print(string.format("Units: %d (%d moving)", #units, stats.moving), 10, 70)

    if paused then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("PAUSED (Space to resume)", 10, 90)
    end

    -- Draw legend
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", world.width - 155, 5, 150, 60)

    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.circle("fill", world.width - 140, 20, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Player 0 (Footmen)", world.width - 125, 12)

    love.graphics.setColor(0.2, 0.4, 0.9)
    love.graphics.circle("fill", world.width - 140, 45, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Player 1 (Grunts)", world.width - 125, 37)

    -- Controls hint
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Space=Pause  R=Reset  Click=Move Red  Esc=Quit", 10, world.height - 20)
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
    end
end
-- }}}

-- {{{ love.mousepressed
function love.mousepressed(x, y, button)
    if button == 1 then  -- Left click
        -- Move player 0 units to clicked position
        local world_x = x / world.scale
        local world_y = y / world.scale

        for entity, pos, unit in ecs.query("position", "unit") do
            if unit.owner == 0 then
                local mov = ecs.get_component(entity, "movement")
                if mov then
                    mov.path = {{x = world_x, y = world_y}}
                    mov.path_index = 1
                    mov.target = {x = world_x, y = world_y}
                end
            end
        end
    end
end
-- }}}
