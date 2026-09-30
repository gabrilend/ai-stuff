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
  sight      with fog of war (demo/wc3map/vision.lua), only what a unit's
             player can see is picked, and a target lost in the fog is
             let go, unless it struck the unit in the last two seconds
             (Issue 524)

Stats come from the map's object data where it sets them, else the
stock tables from the owner's install (hit points, damage dice,
cooldown, range, acquisition range, armour, attack point, backswing,
missile speed, weapon type, whether it attacks at all: Issue 525); only
what neither gives falls to the STAND-INS by archetype below, chosen to
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
            attack_point = u.attack_point_field or s.attack_point,
            backswing = u.backswing_field or s.backswing,
            missile = u.missile_field or s.missile,
        }
        -- a "normal" weapon strikes at once (melee); the others fly
        if u.weapon_type == "normal" or u.weapon_type == "instant" then u.weapon.missile = 0 end
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
                    if v.alive and not v.invulnerable and not v.buff_invulnerable and not v.hidden and combat.hostile(game, u, v)
                        and (not game.vision or game.vision:sees(u.player, v, true)) then
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
    for _, f in ipairs(game.death_listeners or {}) do f(target, attacker) end
    if game.on_death then game.on_death(target, attacker) end
end

-- opts.spell: a spell's damage (armour doesn't reduce it; the caller has
-- applied the damage table)
function combat.damage(game, attacker, target, amount, opts)
    if not target.alive or target.invulnerable or target.buff_invulnerable then return end
    local dealt = amount
    if not (opts and opts.spell) then
        dealt = combat.reduce(amount, (target.armor or 0) + (target.armor_bonus or 0))
    end
    target.hp = target.hp - dealt
    for _, f in ipairs(game.damage_listeners or {}) do f(target, attacker, dealt) end
    if game.on_damaged then game.on_damaged(target, attacker, dealt) end
    target.last_hit = game.time
    target.last_attacker = attacker
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
    -- attack passives and damage buffs (issue 529)
    if game.modify_strike then amount = game.modify_strike(u, t, amount) end
    if w.missile > 0 then
        local a = game.volley:loose(u.x, u.y, u.z + 60, t, w.missile, 0.15, t.spec.design == "building" and 80 or 45)
        a.damage, a.source = amount, u
        -- its missile's model (the unit's missile art, ua1m: issue 530)
        if game.data and game.data.units then
            local art = game.data.units:value(u.id, "ua1m")
            if type(art) == "string" and art ~= "" then a.art = art:match("^[^,]+") end
        end
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
        if u.alive and u.weapon and not u.paused and not u.stunned and not u.casting then
            u.cooldown = math.max(0, u.cooldown - dt)
            local o = u.order
            local moving = o and o.kind == "move"
            local holding = o and o.kind == "hold"

            -- drop a target that died, turned friendly, or (creeps) led too far
            local t = u.target
            local lost = t and game.vision and not game.vision:sees(u.player, t, true)
                and not (u.last_attacker == t and game.time - (u.last_hit or -99) < 2)
            if t and (not t.alive or t.invulnerable or t.buff_invulnerable or not combat.hostile(game, u, t) or lost) then
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
                        u.cooldown = u.weapon.cooldown / (u.attack_mult or 1)
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
