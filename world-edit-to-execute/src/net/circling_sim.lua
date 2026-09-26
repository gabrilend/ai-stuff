--[[
circling_sim.lua - a stand-in game for the server to run until the real one is joined up (issue 803)

What this is: the smallest game that exercises every message. Its units
circle the centre on their own rings at their own speeds, bobbing, exactly
as the renderer's ceramic test units do (src/render/ceramic/host/
units-boxes.c, unit_place), so a renderer fed by this server draws the same
picture. Each unit belongs to one player (unit id modulo the player count).

It answers the server's three questions (see server.lua):
  order   kept when every unit named exists and is the player's; the units
          keep circling (a stand-in has nowhere to go)
  tick    the events planned for that tick (config.deaths: tick -> unit)
  visible every unit (no fog of war yet)

Unit ids start at 1: 0 means "no unit" in messages.
]]

local messages = require("net.messages")

local circling_sim = {}

-- {{{ local function unit_record(id, t)
-- Unit `id` at time `t` seconds: the same arithmetic as unit_place() in the
-- renderer's test units, where units are numbered from 0.
local function unit_record(id, t)
    local n = id - 1
    local ring = 4.0 + (n % 48) * 0.55
    local speed = 0.15 + 0.04 * (n % 7)
    local angle = t * speed + n * 2.39996
    local bob = t * 2.0 + n
    return {
        id = id,
        x = math.cos(angle) * ring, z = math.sin(angle) * ring, y = 0.35 + 0.25 * math.sin(bob),
        vx = -math.sin(angle) * ring * speed, vz = math.cos(angle) * ring * speed, vy = 0.5 * math.cos(bob),
        facing = angle + 1.5707963, anim = 1, anim_phase = bob % 6.2831853,
    }
end
-- }}}

-- {{{ function circling_sim.new(config)
-- config: units (how many), players (how many), deaths (optional: tick ->
-- unit id). Returns the three functions the server calls, plus `orders`,
-- the orders kept so far.
function circling_sim.new(config)
    local sim = { orders = {}, t = 0, dead = {} }
    local deaths = config.deaths or {}

    -- {{{ function sim.order(player, order, tick)
    function sim.order(player, order, tick)
        for _, u in ipairs(order.units) do
            if u.id < 1 or u.id > config.units or sim.dead[u.id] then return false, messages.refusal.unknown_unit end
            if (u.id - 1) % config.players ~= player then return false, messages.refusal.not_yours end
        end
        sim.orders[#sim.orders + 1] = { player = player, order_id = order.order_id, tick = tick }
        return true
    end
    -- }}}

    -- {{{ function sim.tick(tick)
    function sim.tick(tick)
        sim.t = tick / 62.5
        local unit = deaths[tick]
        if unit then
            sim.dead[unit] = true
            return { { kind = messages.event_kind.death, tick = tick, unit = unit, other = 0 } }
        end
        return {}
    end
    -- }}}

    -- {{{ function sim.visible(player)
    function sim.visible(player)
        local list = {}
        for id = 1, config.units do
            if not sim.dead[id] then list[#list + 1] = unit_record(id, sim.t) end
        end
        return list
    end
    -- }}}

    return sim
end
-- }}}

circling_sim.unit_record = unit_record

return circling_sim
