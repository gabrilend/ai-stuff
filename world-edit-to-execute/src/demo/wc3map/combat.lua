--[[
Combat (Issue 519b)

Units and towers that fight, the way WC3's do:

  acquiring  a unit that isn't under a move order looks for the nearest
             hostile within its acquisition range (a few times a second);
             a unit that is struck turns on its attacker
  engaging   out of range it chases (unless holding position); in range it
             stops, turns to face its target, winds up (attack point),
             strikes, recovers (backswing) and waits out its cooldown,
             which runs from the start of one attack to the next
  striking   melee hits at once; ranged attacks fly as homing missiles and
             hit on arrival. Armour reduces damage by
             0.06 * armour / (1 + 0.06 * armour)
  camps      neutral hostile creeps defend the ground they stand on and go
             home once a chase takes them too far
  sides      players are hostile unless their force is allied; neutral
             hostile fights everyone; neutral passive fights no one and is
             never picked as a target

Stats come from the map's object data where it sets them (hit points,
damage dice, cooldown, range, acquisition range, armour, whether it
attacks at all); the rest are STAND-INS by archetype below, chosen to
play plausibly, not stock values.

    local combat = require("demo.wc3map.combat")
    combat.init(game)            -- fills in each unit's stats
    combat.update(game, dt)      -- one tick
]]

local loco = require("runtime.locomotion")
local behaviors = require("runtime.behaviors")

local combat = {}

combat.ARMOR_FACTOR = 0.06
combat.SCAN_EVERY = 0.25        -- seconds between looks for a target
combat.LEASH = 1200             -- how far creeps chase from home
combat.CORPSE_TIME = 8          -- seconds a fallen unit lies before it goes
combat.REPATH_EVERY = 0.6       -- seconds between re-planning a chase

-- {{{ Stand-in stats (see the header)
-- hp, damage (min, max), cooldown, range, acquisition, armour,
-- attack point, backswing, missile speed (0: melee)
local function row(hp, lo, hi, cd, range, acq, armor, point, back, missile)
    return { hp = hp, dmg_lo = lo, dmg_hi = hi, cooldown = cd, range = range, acquire = acq,
             armor = armor, attack_point = point, backswing = back, missile = missile }
end
combat.STANDINS = {
    infantry = row(420, 12, 13, 1.35, 90, 500, 2, 0.4, 0.5, 0),
    ranged   = row(310, 16, 18, 1.5, 500, 600, 0, 0.5, 0.4, 900),
    gunner   = row(505, 19, 23, 1.5, 400, 600, 0, 0.3, 0.5, 1800),
    caster   = row(290, 8, 9, 2.0, 600, 600, 0, 0.6, 0.5, 900),
    mounted  = row(800, 34, 42, 1.4, 100, 500, 5, 0.5, 0.5, 0),
    heavy    = row(1100, 30, 36, 1.9, 128, 500, 1, 0.5, 0.6, 0),
    beast    = row(550, 20, 24, 1.6, 100, 500, 1, 0.4, 0.5, 0),
    flyer    = row(575, 15, 20, 1.6, 450, 700, 1, 0.4, 0.4, 900),
    siege    = row(380, 60, 70, 3.5, 1100, 1100, 2, 0.8, 0.6, 700),
    ship     = row(900, 30, 40, 2.0, 600, 700, 2, 0.5, 0.5, 900),
    worker   = row(220, 5, 6, 2.0, 90, 200, 0, 0.4, 0.5, 0),
}
combat.BUILDING_HP = { small = 500, medium = 1200, hall = 1500, tower = 500, altar = 900, special = 1000 }
combat.TOWER = row(0, 20, 24, 0.9, 700, 700, 5, 0.3, 0.3, 1800)
-- }}}

-- {{{ combat.reduce
-- Damage after armour, WC3's formula (negative armour increases damage)
function combat.reduce(damage, armor)
    armor = armor or 0
    if armor >= 0 then
        return damage * (1 - combat.ARMOR_FACTOR * armor / (1 + combat.ARMOR_FACTOR * armor))
    end
    return damage * (2 - 0.94 ^ (-armor))
end
-- }}}

-- {{{ combat.init
-- Give a unit (or every unit) hit points and an attack (or none)
function combat.init_unit(u)
    local s
    if u.spec.design == "building" then
        s = u.spec.size == "tower" and combat.TOWER or nil
        u.hp_max = u.hp_max or combat.BUILDING_HP[u.spec.size or "medium"] or 1000
        u.armor = u.armor or 5
    else
        s = combat.STANDINS[u.spec.archetype or "infantry"] or combat.STANDINS.infantry
        u.hp_max = u.hp_max or (u.spec.hero and s.hp * 1.6 or s.hp)
        u.armor = u.armor or (u.spec.hero and s.armor + 2 or s.armor)
    end
    u.hp = u.hp_max
    u.alive = true
    if s and u.attacks ~= 0 then
        u.weapon = {
            dmg_lo = u.dmg_base and (u.dmg_base + (u.dmg_dice or 1)) or (u.spec.hero and s.dmg_lo + 10 or s.dmg_lo),
            dmg_hi = u.dmg_base and (u.dmg_base + (u.dmg_dice or 1) * (u.dmg_sides or 1))
                or (u.spec.hero and s.dmg_hi + 14 or s.dmg_hi),
            cooldown = u.cooldown_field or s.cooldown,
            range = u.range_field or s.range,
            acquire = u.acquire_field or s.acquire,
            attack_point = s.attack_point, backswing = s.backswing,
            missile = s.missile,
        }
        u.weapon.acquire = math.max(u.weapon.acquire, u.weapon.range)
    end
    u.cooldown = 0
    u.home = { x = u.x, y = u.y }
end

function combat.init(game)
    for _, u in ipairs(game.units) do combat.init_unit(u) end
    game.volley = behaviors.volley()
end
-- }}}

-- {{{ Sides
function combat.hostile(game, a, b)
    if a.player == b.player then return false end
    local pa, pb = a.player, b.player
    if pa >= 13 or pb >= 13 then return false end   -- neutral passive and others
    if pa == 12 or pb == 12 then return true end    -- neutral hostile
    if game.allied then return not game.allied(pa, pb) end   -- as a running script says
    return game.team_of(pa) ~= game.team_of(pb)
end
-- }}}

-- {{{ Spatial buckets (rebuilt each tick)
local BUCKET = 512

local function build_buckets(game)
    local b = {}
    for _, u in ipairs(game.units) do
        if u.alive then
            local k = math.floor(u.x / BUCKET) * 65536 + math.floor(u.y / BUCKET)
            local list = b[k]
            if not list then list = {}; b[k] = list end
            list[#list + 1] = u
        end
    end
    game.buckets = b
end

-- The nearest living hostile to u within r
local function nearest_hostile(game, u, r)
    local best, best_d = nil, r * r
    local bx0, bx1 = math.floor((u.x - r) / BUCKET), math.floor((u.x + r) / BUCKET)
    local by0, by1 = math.floor((u.y - r) / BUCKET), math.floor((u.y + r) / BUCKET)
    for bx = bx0, bx1 do
        for by = by0, by1 do
            local list = game.buckets[bx * 65536 + by]
            if list then
                for _, v in ipairs(list) do
                    if v.alive and not v.invulnerable and not v.hidden and combat.hostile(game, u, v) then
                        local d = (v.x - u.x) ^ 2 + (v.y - u.y) ^ 2
                        if d < best_d then best, best_d = v, d end
                    end
                end
            end
        end
    end
    return best
end
-- }}}

-- {{{ reach
-- Distance at which u can strike v: its range plus both bodies
local function body(u)
    if u.spec.design == "building" then
        return ({ small = 110, medium = 170, hall = 230, tower = 70, altar = 150, special = 150 })[u.spec.size] or 150
    end
    return u.spec.hero and 32 or 24
end

local function reach(u, v)
    return u.weapon.range + body(u) + body(v)
end
-- }}}

-- {{{ damage
function combat.kill(game, target, attacker)
    if not target.alive then return end
    target.hp = 0
    target.alive = false
    target.died_at = game.time
    target.order, target.route, target.target, target.swing = nil, nil, nil, nil
    game.deaths = (game.deaths or 0) + 1
    if target.spec.design == "building" then game.buildings_changed = true end
    if game.on_death then game.on_death(target, attacker) end
end

function combat.damage(game, attacker, target, amount)
    if not target.alive or target.invulnerable then return end
    target.hp = target.hp - combat.reduce(amount, target.armor)
    target.last_hit = game.time
    if target.hp <= 0 then
        combat.kill(game, target, attacker)
        return
    end
    -- struck: turn on the attacker if not already busy, and not told to move
    if target.weapon and not target.target and (not target.order or target.order.kind ~= "move")
        and attacker.alive and combat.hostile(game, target, attacker) then
        target.target = attacker
    end
end
-- }}}

-- {{{ strike
local function strike(game, u, t)
    local w = u.weapon
    local amount = w.dmg_lo + math.random() * (w.dmg_hi - w.dmg_lo)
    if w.missile > 0 then
        local a = game.volley:loose(u.x, u.y, u.z + 60, t, w.missile, 0.15, t.spec.design == "building" and 80 or 45)
        a.damage, a.source = amount, u
    else
        combat.damage(game, u, t, amount)
    end
    game.strikes = (game.strikes or 0) + 1
end
-- }}}

-- {{{ combat.update
-- Chooses targets and runs attacks; asks game.walk_to(u, x, y) to move
-- units into range
function combat.update(game, dt)
    build_buckets(game)
    for _, u in ipairs(game.units) do
        if u.alive and u.weapon and not u.paused then
            u.cooldown = math.max(0, u.cooldown - dt)
            local o = u.order
            local moving = o and o.kind == "move"
            local holding = o and o.kind == "hold"

            -- drop a target that died, turned friendly, or (creeps) led too far
            local t = u.target
            if t and (not t.alive or t.invulnerable or not combat.hostile(game, u, t)) then
                u.target, t = nil, nil
                if o and o.kind == "attack_unit" then u.order = nil end
            end
            if t and u.player == 12 and loco.distance(u, u.home) > combat.LEASH then
                u.target, t = nil, nil
                game.walk_to(u, u.home.x, u.home.y)
                u.order = { kind = "move", x = u.home.x, y = u.home.y }
            end

            -- look for one
            if not t and not moving then
                u.next_scan = (u.next_scan or 0) - dt
                if u.next_scan <= 0 then
                    u.next_scan = combat.SCAN_EVERY
                    t = nearest_hostile(game, u, u.weapon.acquire)
                    u.target = t
                end
            end

            if t then
                local d = loco.distance(u, t)
                if d > reach(u, t) then
                    -- chase (buildings and holders stay put and let go)
                    u.swing = nil
                    if holding or u.spec.design == "building" then
                        u.target = nil
                    elseif not u.chase_at or game.time - u.chase_at > combat.REPATH_EVERY then
                        u.chase_at = game.time
                        game.walk_to(u, t.x, t.y, true)
                    end
                else
                    u.route = nil
                    if u.mover then
                        u.mover.x, u.mover.y, u.mover.facing = u.x, u.y, u.facing
                        loco.turn_toward(u.mover, math.atan2(t.y - u.y, t.x - u.x), dt)
                        u.facing = u.mover.facing
                    end
                    local off = math.abs(loco.angle_diff(u.facing or 0, math.atan2(t.y - u.y, t.x - u.x)))
                    if u.swing then
                        u.swing = u.swing + dt
                        if u.swing >= u.weapon.attack_point and not u.struck then
                            strike(game, u, t)
                            u.struck = true
                        end
                        if u.swing >= u.weapon.attack_point + u.weapon.backswing then
                            u.swing, u.struck = nil, nil
                        end
                    elseif u.cooldown <= 0 and (off <= math.rad(20) or u.spec.design == "building") then
                        u.swing, u.struck = 0, false
                        u.cooldown = u.weapon.cooldown
                        if game.on_attack then game.on_attack(u, t) end
                    end
                end
            end
        end
    end

    local _, arrived = game.volley:update(dt)
    for _, a in ipairs(arrived) do
        combat.damage(game, a.source, a.target, a.damage or 0)
    end
end
-- }}}

return combat
