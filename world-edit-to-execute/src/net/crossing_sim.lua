--[[
crossing_sim.lua - two armies swapping sides, as a game the server can run (issue 804)

What this is: the crossing-armies demo's game. It reads the map
(net/arenas/crossing.lua), packs both armies of mixed sizes round their
home points in a crowd (runtime/crowd.lua: round units that slide, orbit,
nudge and pack), sends each army as a group to the other's home, and
answers the server's questions (see net/server.lua):
  order   a move order for the player's own units is kept: they go there as
          a group; anything else is refused
  tick    the crowd's tick; when no unit is moving any more, every unit is
          sent back to where it started, and the crossing begins again
  visible every unit (no fog of war yet): position on the ground as x and z
          (the renderer's ground plane; y is up), velocity, facing,
          animation 1 walking or 0 standing, radius, and its player
  extras  a "paths" message with every path that changed since the last
          tick (the same message for every player)

Units: ids from 1, the west army first. Player 0 owns the west army,
player 1 the east.
]]

local messages = require("net.messages")
local crowd = require("runtime.crowd")

local crossing_sim = {}

-- {{{ function crossing_sim.map(map_module)
-- The map module and its walkable grid.
function crossing_sim.map(map_module)
    local map = require(map_module or "net.arenas.crossing")
    local grid = {}
    for y, row in ipairs(map.rows) do
        grid[y] = {}
        for x = 1, #row do grid[y][x] = row:sub(x, x) ~= "#" end
    end
    return map, grid
end
-- }}}

-- {{{ function crossing_sim.new(config)
-- config.map: the map module's name (optional). config.one_radius: true
-- to turn the larger pathing radius off (units steer round nobody before
-- touching; for comparing the two by eye). Returns the server's four
-- functions, plus `crowd` (the crowd itself), `crossings` (how many have
-- ended) and `gave_up_last` (how many gave up in the last one), for tests.
function crossing_sim.new(config)
    local map, grid = crossing_sim.map(config and config.map)
    local c = crowd.new(grid, map.cell)
    local one_radius = config and config.one_radius
    if one_radius then c.look_ahead = 0 end
    local sim = { crowd = c, crossings = 0, gave_up_last = 0 }
    local owner, army_ids = {}, { {}, {} }
    local id = 0
    for army = 1, 2 do
        local radii, speeds = {}, {}
        for _, kind in ipairs(map.army) do
            for _ = 1, kind.count do
                radii[#radii + 1] = kind.radius
                speeds[#speeds + 1] = kind.speed
            end
        end
        local home = map.homes[army]
        local places = c:pack(home[1], home[2], radii)
        for i, place in ipairs(places) do
            id = id + 1
            c:add(id, place[1], place[2], radii[i], speeds[i], army, one_radius and radii[i] or nil)
            owner[id] = army - 1
            army_ids[army][#army_ids[army] + 1] = id
        end
    end
    local count = id

    -- {{{ local function send_across(to_home)
    -- Each army, as one group, to the other's home point, or back to its own.
    local function send_across(to_home)
        for army = 1, 2 do
            local home = map.homes[to_home and army or (3 - army)]
            c:move_group(army_ids[army], home[1], home[2])
        end
    end
    -- }}}
    send_across(false)
    local across = true

    -- {{{ function sim.order(player, order, tick)
    function sim.order(player, order, tick)
        if order.kind ~= messages.order_kind.move then return false, messages.refusal.unreachable end
        local ids = {}
        for _, u in ipairs(order.units) do
            if not c.units[u.id] then return false, messages.refusal.unknown_unit end
            if owner[u.id] ~= player then return false, messages.refusal.not_yours end
            ids[#ids + 1] = u.id
        end
        c:move_group(ids, order.target_x, order.target_y)
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
            local gave_up = 0
            for i = 1, count do if c.units[i].gave_up then gave_up = gave_up + 1 end end
            sim.gave_up_last = gave_up
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
                facing = u.facing, anim = (u.vx ~= 0 or u.vy ~= 0) and 1 or 0,
                anim_phase = 0, radius = u.radius, team = owner[i],
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
