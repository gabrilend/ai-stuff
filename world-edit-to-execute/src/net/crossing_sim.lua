--[[
crossing_sim.lua - two armies swapping sides, as a game the server can run (issue 804)

What this is: the crossing-armies demo's game. It reads the map
(net/arenas/crossing.lua), puts both armies into a crowd (runtime/crowd.lua,
where units path around each other), sends each army across, and answers
the server's questions (see net/server.lua):
  order   a move order for the player's own units is kept: they go there as
          a group; anything else is refused
  tick    the crowd's tick; when no unit is moving any more, every unit is
          sent back to where it started, and the crossing begins again
  visible every unit (no fog of war yet): position on the ground as x and z
          (the renderer's ground plane; y is up), velocity, facing,
          animation 1 walking or 0 standing
  extras  a "paths" message with every path that changed since the last
          tick (the same message for every player)

Units: ids from 1, the west army first. Player 0 owns the west army,
player 1 the east.
]]

local messages = require("net.messages")
local crowd = require("runtime.crowd")

local crossing_sim = {}

-- {{{ function crossing_sim.map(map_module)
-- The map's walkable grid and the starting cells of both armies.
function crossing_sim.map(map_module)
    local map = require(map_module or "net.arenas.crossing")
    local grid, west, east = {}, {}, {}
    for y, row in ipairs(map.rows) do
        grid[y] = {}
        for x = 1, #row do
            local ch = row:sub(x, x)
            grid[y][x] = ch ~= "#"
            if ch == "w" then west[#west + 1] = { x, y } end
            if ch == "e" then east[#east + 1] = { x, y } end
        end
    end
    return map, grid, west, east
end
-- }}}

-- {{{ function crossing_sim.new(config)
-- config.map: the map module's name (optional). Returns the server's four
-- functions and `crowd`, the crowd itself (for tests).
function crossing_sim.new(config)
    local map, grid, west, east = crossing_sim.map(config and config.map)
    local c = crowd.new(grid, map.cell)
    local width = #map.rows[1]
    local sim = { crowd = c, crossings = 0 }
    local home, owner = {}, {}
    local id = 0
    for army, starts in ipairs({ west, east }) do
        for _, cell in ipairs(starts) do
            id = id + 1
            local x, y = c:centre_of(cell[1], cell[2])
            c:add(id, x, y, map.unit_radius, map.unit_speed)
            home[id] = { x, y }
            owner[id] = army - 1
        end
    end
    local count = id

    -- {{{ local function send_across(to_home)
    -- Every unit to the mirror of its starting cell, or back home.
    local function send_across(to_home)
        local orders = {}
        for i = 1, count do
            local hx, hy = home[i][1], home[i][2]
            local x = to_home and hx or (width * map.cell - hx)
            orders[#orders + 1] = { i, x, hy }
        end
        c:move_group(orders)
    end
    -- }}}
    send_across(false)
    local across = true

    -- {{{ function sim.order(player, order, tick)
    function sim.order(player, order, tick)
        if order.kind ~= messages.order_kind.move then return false, messages.refusal.unreachable end
        local orders = {}
        for _, u in ipairs(order.units) do
            if not c.units[u.id] then return false, messages.refusal.unknown_unit end
            if owner[u.id] ~= player then return false, messages.refusal.not_yours end
            orders[#orders + 1] = { u.id, order.target_x, order.target_y }
        end
        c:move_group(orders)
        return true
    end
    -- }}}

    -- {{{ local function changed_paths()
    -- The paths message for every path changed since the last one, or nil;
    -- clears the crowd's changed marks.
    local function changed_paths()
        local stopped, points = {}, {}
        for i = 1, count do
            local u = c.units[i]
            if u.path_changed then
                u.path_changed = false
                if u.path then
                    for k = u.step, #u.path do points[#points + 1] = { id = i, x = u.path[k].x, y = u.path[k].y } end
                else
                    stopped[#stopped + 1] = { id = i }
                end
            end
        end
        if #stopped == 0 and #points == 0 then return nil end
        return { tick = c.tick_count, stopped = stopped, points = points }
    end
    -- }}}

    -- {{{ function sim.tick(tick)
    function sim.tick(tick)
        c:tick(1 / 62.5)
        local any_moving = false
        for i = 1, count do if c.units[i].moving then any_moving = true; break end end
        -- Two paths: someone still moving -> carry on; everyone stopped ->
        -- the crossing is over, send them all the other way
        if not any_moving then
            across = not across
            sim.crossings = sim.crossings + 1
            send_across(not across)
        end
        sim.paths = changed_paths()
        return {}
    end
    -- }}}

    -- {{{ function sim.visible(player)
    function sim.visible(player)
        local list = {}
        for i = 1, count do
            local u = c.units[i]
            list[i] = {
                id = i, x = u.x, y = 0, z = u.y, vx = u.vx, vy = 0, vz = u.vy,
                facing = u.facing, anim = u.moving and (u.vx ~= 0 or u.vy ~= 0) and 1 or 0,
                anim_phase = 0,
            }
        end
        return list
    end
    -- }}}

    -- {{{ function sim.extras(player)
    -- The same paths message for every player: it is worked out once a
    -- tick, in sim.tick.
    function sim.extras(player)
        if sim.paths then return { { "paths", sim.paths } } end
        return {}
    end
    -- }}}

    return sim
end
-- }}}

return crossing_sim
