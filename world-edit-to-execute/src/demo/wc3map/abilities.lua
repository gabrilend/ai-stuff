--[[
Abilities (Issue 529)

Units' abilities, as WC3 runs them:

  on units    u.abilities[id] = level: units start with their type's list
              (uabi) at level 1; heroes learn their skills (heroes.lua);
              the script adds, removes and levels them
  what one is its values per level from the ability tables (the map's
              changes over the stock rows, gamedata/object_stock.lua):
              mana cost (amcs), cooldown (acdn), cast range (aran), area
              (aare), duration (adur; ahdu on heroes), and its own data
              fields. A custom ability behaves as the stock ability it
              copies (its "base": A001 made from AHtb is a Storm Bolt)
  casting     an order to cast walks the caster into range, turns it,
              then: SPELL_CHANNEL and SPELL_CAST (the script's events)
              when the cast begins; after the cast point, mana is spent,
              the cooldown starts, SPELL_EFFECT fires and the ability's
              effect happens; a channelled ability keeps going for its
              duration (its effect ticking); SPELL_FINISH when it
              completes and SPELL_ENDCAST when it ends either way (any
              other order, a stun or death interrupts it)
  effects     a starter set of the stock abilities below (BASES), by
              base: damage, heals, stuns, slows, summons, blinks, shields,
              auras, and attack passives (bash, critical strike). An
              ability whose base isn't here still casts: its events fire
              and its mana and cooldown are spent, which is all a
              trigger-made ability (most custom maps' spells, usually
              based on Channel, ANcl) needs
  vitals      hit points and mana regenerate (uhpr, umpr; heroes' from
              strength and intelligence: StrRegenBonus, IntRegenBonus;
              buffs add to it)

The data field codes and the numbers used when an ability's table
doesn't give them are FROM MEMORY and STAND-INS, not read from the
game's files here: each effect names the codes it reads and its
defaults.

    abilities.init(game)                  -- after heroes.init
    game.cast(unit, id, target_unit, x, y) -- true, or false and why
    game.ability_info(id, level)          -- mana, cooldown, range, area, duration, data(code)
    abilities.update(game, dt)
]]

local buffs = require("demo.wc3map.buffs")

local abilities = {}

abilities.CAST_POINT, abilities.BACKSWING = 0.3, 0.51
abilities.AURA_EVERY = 0.5

-- system abilities that aren't buttons of their own
abilities.HIDDEN = {}
for id in ("Amov Aatk Ahar Ahrl AInv Aalr Argd Arlm Awan Abdt Aloc Avul Apit Asud Aspa Abun Aneu Ane2 Arev ARal "
        .. "Agld Aegm Abgm Aall Afir Afih Afio Afin Afiu Adda Arng Asid Aslp Auns Aawa Adri Aeat Aenc Abds"):gmatch("%S+") do
    abilities.HIDDEN[id] = true
end
-- }}}

-- {{{ Helpers
local function dist2(a, x, y) return (a.x - x) ^ 2 + (a.y - y) ^ 2 end

local function units_in(g, x, y, r, test)
    local out = {}
    for _, u in ipairs(g.units) do
        if u.alive and not u.removed and not u.hidden and dist2(u, x, y) <= r * r and (not test or test(u)) then
            out[#out + 1] = u
        end
    end
    return out
end

local function enemy_of(g, a)
    return function(u)
        if u.player == a.player then return false end
        if g.allied then return not g.allied(a.player, u.player) end
        return true
    end
end

local function ally_of(g, a)
    return function(u)
        return u.player == a.player or (g.allied and g.allied(a.player, u.player)) or false
    end
end

local function is_undead(g, u)
    local race = g.data and g.data.units:value(u.id, "urac")
    return race == "undead"
end
-- }}}

-- {{{ The starter set of stock abilities, by base
-- target: "unit" | "point" | "unit_or_point" | "none" | "passive" | "aura"
-- allies / enemies: which units a unit target may be
-- order: the order string the script casts it with
-- effect(g, cast): what happens (cast.caster, .target, .x, .y, .info, .level)
-- tick(g, cast, dt): while channelling
local B = {}
abilities.BASES = B

B.AHtb = { target = "unit", enemies = true, order = "thunderbolt", missile = true,
    effect = function(g, c)
        local i = c.info
        g.spell_damage(c.caster, c.target, i.data("Htb1", 100))
        buffs.add(g, c.target, { id = "BPSE", source = c.caster, stun = true, duration = i.duration_for(c.target, 5, 3) })
    end }
B.AHtc = { target = "none", order = "thunderclap",
    effect = function(g, c)
        local i = c.info
        for _, u in ipairs(units_in(g, c.caster.x, c.caster.y, i.area or 250, enemy_of(g, c.caster))) do
            if u.spec.design ~= "building" and u.spec.archetype ~= "flyer" then
                g.spell_damage(c.caster, u, i.data("Htc1", 60))
                buffs.add(g, u, { id = "BHtc", source = c.caster, move = -i.data("Htc3", 0.5),
                                  attack = -i.data("Htc4", 0.5), duration = i.duration_for(u, 5, 3) })
            end
        end
    end }
B.AHbz = { target = "point", order = "blizzard", channel = true,
    channel_time = function(i) return i.data("Hbz1", 6) end,
    effect = function(g, c) c.wave_at, c.waves = 0, c.info.data("Hbz1", 6) end,
    tick = function(g, c, dt)
        c.wave_at = (c.wave_at or 0) - dt
        if c.wave_at <= 0 and (c.waves or 0) > 0 then
            c.waves = c.waves - 1
            c.wave_at = c.wave_at + 1
            -- its shards fall where the wave does (the ability's EffectArt)
            if g.play_art then
                local paths = g.ability_art(c.id, c.level, "effect")
                local r = (c.info.area or 200) * 0.6
                for k = 1, 3 do
                    local a, d = math.random() * math.pi * 2, math.random() * r
                    g.play_art(paths, { x = c.x + math.cos(a) * d, y = c.y + math.sin(a) * d }, 1.2, "effect")
                end
            end
            for _, u in ipairs(units_in(g, c.x, c.y, c.info.area or 200, enemy_of(g, c.caster))) do
                local dmg = c.info.data("Hbz2", 30)
                if u.spec.design == "building" then dmg = dmg * (1 - c.info.data("Hbz4", 0.5)) end
                g.spell_damage(c.caster, u, dmg)
            end
        end
    end }
B.AHwe = { target = "none", order = "waterelemental",
    effect = function(g, c)
        local i = c.info
        local kind = i.data("Hwe1", "hwat")
        if type(kind) ~= "string" or #kind ~= 4 then kind = "hwat" end
        for k = 1, i.data("Hwe2", 1) do
            local a = (c.caster.facing or 0) + k * 0.6
            local u = g.spawn(kind, c.caster.player, c.caster.x + math.cos(a) * 150, c.caster.y + math.sin(a) * 150, a)
            u.summoned = true
            local life = i.duration or 60
            buffs.add(g, u, { id = "BTLF", ends = g.time + life, on_end = function(gg, uu) gg.kill(uu, nil) end })
        end
    end }
B.AHhb = { target = "unit", allies = true, enemies = true, order = "holybolt",
    effect = function(g, c)
        local amount = c.info.data("Hhb1", 200)
        if is_undead(g, c.target) and enemy_of(g, c.caster)(c.target) then
            g.spell_damage(c.caster, c.target, amount / 2)
        else
            g.heal(c.target, amount)
        end
    end }
B.AHds = { target = "none", order = "divineshield",
    effect = function(g, c)
        buffs.add(g, c.caster, { id = "BHds", source = c.caster, invulnerable = true, duration = c.info.duration or 15 })
    end }
B.AHad = { target = "aura", allies = true,
    aura = function(g, src, i) return { id = "BHad", armor = i.data("Had1", 1.5) } end }
B.AHab = { target = "aura", allies = true,
    aura = function(g, src, i) return { id = "BHab", mana_regen = i.data("Hab1", 0.75) } end }
B.AOae = { target = "aura", allies = true,
    aura = function(g, src, i) return { id = "BOae", move = i.data("Oae1", 0.1), attack = i.data("Oae2", 0.05) } end }
B.AUau = { target = "aura", allies = true,
    aura = function(g, src, i) return { id = "BUau", move = i.data("Uau1", 0.1), hp_regen = i.data("Uau2", 0.5) } end }
B.AEah = { target = "aura", allies = true,
    aura = function(g, src, i) return { id = "BEah", thorns = i.data("Eah1", 0.1) } end }
B.AHbh = { target = "passive",
    on_strike = function(g, u, t, amount, i)
        if math.random() * 100 < i.data("Hbh1", 20) then
            buffs.add(g, t, { id = "BPSE", source = u, stun = true, duration = i.duration_for(t, 2, 1) })
            return amount + i.data("Hbh3", 25)
        end
        return amount
    end }
B.AOcr = { target = "passive",
    on_strike = function(g, u, t, amount, i)
        if math.random() * 100 < i.data("Ocr1", 15) then return amount * i.data("Ocr2", 2) + i.data("Ocr3", 0) end
        return amount
    end }
B.AOsh = { target = "point", order = "shockwave",
    effect = function(g, c)
        local i = c.info
        local sx, sy = c.caster.x, c.caster.y
        local dx, dy = c.x - sx, c.y - sy
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1 then dx, dy, len = math.cos(c.caster.facing or 0), math.sin(c.caster.facing or 0), 1 end
        dx, dy = dx / len, dy / len
        local reach, width = i.data("Osh3", 800), (i.area or 150)
        for _, u in ipairs(units_in(g, sx, sy, reach + width, enemy_of(g, c.caster))) do
            local along = (u.x - sx) * dx + (u.y - sy) * dy
            local off = math.abs((u.x - sx) * dy - (u.y - sy) * dx)
            if along >= 0 and along <= reach and off <= width and u.spec.design ~= "building" then
                g.spell_damage(c.caster, u, i.data("Osh1", 75))
            end
        end
    end }
B.AOwk = { target = "none", order = "windwalk",
    effect = function(g, c)
        local i = c.info
        buffs.add(g, c.caster, { id = "BOwk", source = c.caster, invisible = true, move = i.data("Owk2", 0.1),
                                 backstab = i.data("Owk3", 40), duration = i.duration or 20 })
    end }
B.AUdc = { target = "unit", allies = true, enemies = true, order = "deathcoil", missile = true,
    effect = function(g, c)
        local amount = c.info.data("Udc1", 100)
        if enemy_of(g, c.caster)(c.target) then
            g.spell_damage(c.caster, c.target, amount)
        elseif is_undead(g, c.target) then
            g.heal(c.target, amount * 2)
        end
    end }
B.AUfn = { target = "unit", enemies = true, order = "frostnova",
    effect = function(g, c)
        local i, t = c.info, c.target
        g.spell_damage(c.caster, t, i.data("Ufn2", 50))
        for _, u in ipairs(units_in(g, t.x, t.y, i.area or 200, enemy_of(g, c.caster))) do
            g.spell_damage(c.caster, u, i.data("Ufn1", 50))
            buffs.add(g, u, { id = "Bfro", source = c.caster, move = -0.5, attack = -0.25,
                              duration = i.duration_for(u, 8, 4) })
        end
    end }
B.AEbl = { target = "point", order = "blink",
    effect = function(g, c)
        local u = c.caster
        local dx, dy = c.x - u.x, c.y - u.y
        local d = math.sqrt(dx * dx + dy * dy)
        local max = c.info.data("Ebl1", 1000)
        if d > max then c.x, c.y = u.x + dx / d * max, u.y + dy / d * max end
        u.x, u.y = c.x, c.y
        if g.ground_at then u.z = g.ground_at(u.x, u.y) end
        if u.mover then u.mover.x, u.mover.y = u.x, u.y end
        u.route = nil
    end }
B.Aslo = { target = "unit", enemies = true, order = "slow",
    effect = function(g, c)
        buffs.add(g, c.target, { id = "Bslo", source = c.caster, move = -c.info.data("Slo1", 0.6),
                                 attack = -c.info.data("Slo2", 0.25), duration = c.info.duration_for(c.target, 60, 10) })
    end }
B.Ablo = { target = "unit", allies = true, order = "bloodlust",
    effect = function(g, c)
        buffs.add(g, c.target, { id = "Bblo", source = c.caster, attack = c.info.data("Blo1", 0.4),
                                 move = c.info.data("Blo2", 0.25), duration = c.info.duration or 60 })
    end }
B.Aroa = { target = "none", order = "roar",
    effect = function(g, c)
        for _, u in ipairs(units_in(g, c.caster.x, c.caster.y, c.info.area or 500, ally_of(g, c.caster))) do
            buffs.add(g, u, { id = "Broa", source = c.caster, damage = c.info.data("Roa1", 0.25),
                              duration = c.info.duration or 30 })
        end
    end }
-- Channel: an ability that does nothing but channel (its target kind and
-- time from its data), for triggers to give meaning
B.ANcl = { target = "none", channel = true,
    target_of = function(i)
        return ({ [0] = "none", "unit", "point", "unit_or_point" })[math.floor(i.data("Ncl2", 0))] or "none"
    end,
    channel_time = function(i) return i.data("Ncl1", 0) end,
    order_of = function(i) local o = i.data("Ncl6", "channel") return type(o) == "string" and o or "channel" end,
    allies = true, enemies = true }
-- }}}

-- {{{ abilities.init
function abilities.init(g)
    local C = g.constants
    local info_cache = {}

    -- {{{ g.ability_info
    function g.ability_base(id) return g.data.abilities:base(id) end

    function g.ability_info(id, level)
        level = math.max(1, level or 1)
        local key = id .. ":" .. level
        local i = info_cache[key]
        if i then return i end
        local A = g.data.abilities
        local function v(code) return (A:value(id, code, level)) end
        i = {
            id = id, level = level, base = A:base(id),
            mana = tonumber(v("amcs")) or 0,
            cooldown = tonumber(v("acdn")) or 0,
            range = tonumber(v("aran")),
            area = tonumber(v("aare")),
            duration = tonumber(v("adur")),
            hero_duration = tonumber(v("ahdu")),
            hero = tonumber((A:value(id, "aher"))) == 1,
            name = A:value(id, "anam"),
        }
        function i.data(code, default)
            local x = v(code)
            if x == nil then return default end
            if type(default) == "number" then return tonumber(x) or default end
            return x
        end
        -- a duration by target: heroes take the hero duration
        function i.duration_for(t, normal, hero)
            if t and t.spec and t.spec.hero then return i.hero_duration or i.duration or hero end
            return i.duration or normal
        end
        info_cache[key] = i
        return i
    end
    -- }}}

    -- {{{ what an ability on a unit is
    function g.ability_spec(id, level)
        local i = g.ability_info(id, level)
        local b = B[i.base] or B[id]
        local target = b and b.target or "none"
        if b and b.target_of then target = b.target_of(i) end
        return b, target, i
    end

    function g.ability_order(id, level)
        local b, _, i = g.ability_spec(id, level)
        if b and b.order_of then return b.order_of(i) end
        local o = g.data.abilities:value(id, "aord")
        if type(o) == "string" and o ~= "" then return o end
        return b and b.order or nil
    end

    -- the abilities a unit can use from its command card
    function g.castable(u)
        local out = {}
        for id, level in pairs(u.abilities or {}) do
            if level > 0 and not abilities.HIDDEN[g.ability_base(id)] and not abilities.HIDDEN[id] then
                local _, target = g.ability_spec(id, level)
                out[#out + 1] = { id = id, level = level, target = target }
            end
        end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end

    -- whether an ability can be cast now, and why not; with the share of
    -- its cooldown left
    function g.ability_ready(u, id)
        local level = u.abilities and u.abilities[id] or 0
        if level <= 0 then return false, "not learned", 0 end
        local _, target, i = g.ability_spec(id, level)
        local left = 0
        local ready_at = u.cooldowns and u.cooldowns[id]
        if ready_at and ready_at > g.time and i.cooldown > 0 then left = (ready_at - g.time) / i.cooldown end
        if target == "passive" or target == "aura" then return false, "passive", 0 end
        if left > 0 then return false, "not ready yet", left end
        if (u.mana or 0) < i.mana then return false, "not enough mana", 0 end
        if u.stunned then return false, "stunned", 0 end
        return true, nil, 0
    end
    -- }}}

    -- {{{ damage and healing by spells
    -- spell damage: armour doesn't count; the damage table's "spells" row
    -- does (heroes take less: DamageBonusSpells)
    function g.spell_damage(src, t, amount)
        if not t or t.alive == false then return end
        local armor_type = g.data.units:value(t.id, "udty") or (t.spec.hero and "hero" or "normal")
        local k = C:damage_factor("spells", armor_type)
        g.damage(src or t, t, amount * k, { spell = true })
    end
    function g.heal(t, amount)
        if not t or t.alive == false then return end
        t.hp = math.min(t.hp_max or t.hp, (t.hp or 0) + amount)
    end
    -- }}}

    -- {{{ events for the script
    local s2id = require("jass.vm").s2id
    local function spell_event(what, c)
        if not g.script then return end
        local data = { ability = s2id(c.id), target = c.target, spell_level = c.level }
        if c.x then data.point = { x = c.x, y = c.y } end
        g.script:unit_event(what, c.caster, data)
    end
    -- }}}

    -- {{{ g.cast
    function g.cast(u, id, target, x, y)
        if not u or u.alive == false then return false, "dead" end
        local ok, why = g.ability_ready(u, id)
        if not ok then return false, why end
        local level = u.abilities[id]
        local b, kind, i = g.ability_spec(id, level)
        if kind == "unit" and not target then return false, "needs a unit target" end
        if kind == "point" and not x then
            if target then x, y = target.x, target.y else return false, "needs a point" end
        end
        if kind == "unit_or_point" and not target and not x then return false, "needs a target" end
        if target and (kind == "unit" or kind == "unit_or_point") then
            local ok_t, why_t = abilities.target_ok(g, u, target, i, b)
            if not ok_t then return false, why_t end
        end
        if kind == "none" then target, x, y = nil, nil, nil end
        if kind == "point" then target = nil end
        -- any cast under way gives way
        abilities.interrupt(g, u)
        u.harvest = nil
        u.order = { kind = "cast", ability = id }
        u.target, u.swing = nil, nil
        u.casting = { caster = u, id = id, level = level, base = b, info = i, target = target,
                      x = x or (target and target.x), y = y or (target and target.y), phase = "approach" }
        abilities.step_cast(g, u, 0, true)
        return true
    end
    -- }}}

    -- {{{ on units
    local function init_unit(u)
        u.abilities = u.abilities or {}
        u.cooldowns = u.cooldowns or {}
        if not u.spec.hero then
            for _, id in ipairs(g.db.unit_list(u.id, "uabi")) do
                if u.abilities[id] == nil then u.abilities[id] = 1 end
            end
        else
            for _, id in ipairs(g.db.unit_list(u.id, "uabi")) do
                if u.abilities[id] == nil then u.abilities[id] = 1 end
            end
        end
        -- regeneration and starting mana
        local D = g.data.units
        u.hp_regen = tonumber((D:value(u.id, "uhpr"))) or (u.spec.design == "building" and 0 or 0.25)
        u.mana_regen = tonumber((D:value(u.id, "umpr"))) or 0
        local start = tonumber((D:value(u.id, "umpi")))
        if u.mana_max and not u.spec.hero then u.mana = start and math.min(start, u.mana_max) or u.mana_max end
        buffs.sum(u)
    end
    for _, u in ipairs(g.units) do init_unit(u) end
    table.insert(g.spawn_listeners, init_unit)

    -- attack passives (bash, critical strike, wind walk's backstab)
    function g.modify_strike(u, t, amount)
        for id, level in pairs(u.abilities or {}) do
            if level > 0 then
                local b, _, i = g.ability_spec(id, level)
                if b and b.on_strike then amount = b.on_strike(g, u, t, amount, i) end
            end
        end
        local ww = buffs.has(u, "BOwk")
        if ww then
            amount = amount + (ww.backstab or 0)
            buffs.remove(g, u, "BOwk")
        end
        return amount * (u.damage_mult or 1)
    end

    -- any order other than casting interrupts a cast
    local order = g.order
    function g.order(list, kind, ...)
        if kind ~= "cast" then
            for _, u in ipairs(list) do abilities.interrupt(g, u) end
        end
        return order(list, kind, ...)
    end
    table.insert(g.death_listeners, function(u) abilities.interrupt(g, u) end)
    g.spell_event = spell_event
    -- the command card asks these
    g.db.castable = g.castable
    g.db.ability_ready = g.ability_ready
    -- }}}
end
-- }}}

-- {{{ abilities.target_ok
-- Whether a unit may be a spell's target: the ability's "targets allowed"
-- (atar: air, ground, structure, ward, enemies, friend, allies, player,
-- neutral, self, notself, hero, nonhero, organic, mechanical, alive, dead,
-- invulnerable, vulnerable ...), else its base's enemies / allies.
-- Each group named in the list must match (any one of its flags)
local GROUPS = {
    kind = { air = true, ground = true, structure = true, ward = true, item = true, tree = true, debris = true,
             wall = true, decoration = true, bridge = true },
    side = { enemies = true, enemy = true, friend = true, allies = true, ally = true, player = true,
             neutral = true, self = true, notself = true },
    hero = { hero = true, nonhero = true },
    body = { organic = true, mechanical = true },
    life = { alive = true, dead = true },
    vuln = { invulnerable = true, vulnerable = true },
}

function abilities.target_ok(g, caster, t, i, b)
    local raw = i and (g.data.abilities:value(i.id, "atar", i.level))
    local flags = {}
    if type(raw) == "string" then
        for f in raw:lower():gmatch("[^,%s]+") do flags[f] = true end
    end
    local enemy = t.player ~= caster.player and enemy_of(g, caster)(t)
    local function has_group(name)
        for f in pairs(flags) do if GROUPS[name][f] then return true end end
        return false
    end
    -- alive unless the list says dead
    if has_group("life") then
        if t.alive ~= false and not flags.alive then return false, "must target a dead unit" end
        if t.alive == false and not flags.dead then return false, "target is dead" end
    elseif t.alive == false then
        return false, "target is dead"
    end
    if has_group("side") then
        local ok = (flags.enemies or flags.enemy) and enemy
            or ((flags.friend or flags.allies or flags.ally) and not enemy and t.player ~= caster.player)
            or (flags.player and t.player == caster.player)
            or (flags.neutral and t.player >= 12)
            or (flags.self and t == caster)
        if flags.friend and not enemy then ok = true end
        if flags.notself and t == caster then ok = false end
        if not ok then return false, enemy and "can't target an enemy" or "can't target an ally" end
    elseif b then
        if enemy and not b.enemies then return false, "can't target an enemy" end
        if not enemy and not b.allies then return false, "can't target an ally" end
    end
    if has_group("kind") then
        local building = t.spec.design == "building"
        local air = t.spec.archetype == "flyer"
        local ok = (flags.structure and building) or (flags.air and air and not building)
            or (flags.ground and not air and not building)
        if not ok then return false, building and "can't target a building" or (air and "can't target air" or "can't target ground") end
    end
    if has_group("hero") then
        if t.spec.hero and not flags.hero then return false, "can't target a hero" end
        if not t.spec.hero and not flags.nonhero then return false, "must target a hero" end
    end
    if has_group("vuln") then
        local inv = t.invulnerable or t.buff_invulnerable
        if inv and not flags.invulnerable then return false, "target is invulnerable" end
        if not inv and not flags.vulnerable then return false, "must target an invulnerable unit" end
    elseif t.invulnerable or t.buff_invulnerable then
        return false, "target is invulnerable"
    end
    return true
end
-- }}}

-- {{{ Casting, a step at a time
function abilities.interrupt(g, u)
    local c = u.casting
    if not c then return end
    u.casting = nil
    if u.order and u.order.kind == "cast" then u.order = nil end
    if c.phase == "channel" or c.phase == "point" then
        if g.spell_event then g.spell_event("SPELL_ENDCAST", c) end
    end
end

-- {{{ abilities.land
-- The spell happens: its art (issue 530), then its effect; a missile
-- spell's effect waits for its missile to arrive
function abilities.land(g, c)
    local u = c.caster
    local art = g.ability_art ~= nil
    if art then
        local paths, attach = g.ability_art(c.id, c.level, "caster")
        g.play_art(paths, { unit = u, attach = attach or "origin" }, 1.5, "caster")
    end
    local function arrive()
        if art then
            if c.target then
                local paths, attach = g.ability_art(c.id, c.level, "target")
                g.play_art(paths, { unit = c.target, attach = attach or "origin" }, 2, "target")
            end
            if c.x and not c.target then
                g.play_art((g.ability_art(c.id, c.level, "effect")), { x = c.x, y = c.y }, 2, "effect")
                g.play_art((g.ability_art(c.id, c.level, "area")), { x = c.x, y = c.y }, 2, "area")
            end
        end
        if c.base and c.base.effect then
            if not c.target or c.target.alive ~= false then c.base.effect(g, c) end
        end
    end
    local missile = art and (g.ability_art(c.id, c.level, "missile"))[1]
    if c.target and g.launch and (missile or (c.base and c.base.missile)) then
        c.in_flight = true
        g.launch(missile, u, { unit = c.target }, g.missile_speed(c.id, c.level), g.missile_arc(c.id, c.level),
            function() c.in_flight = nil; arrive() end)
    else
        arrive()
    end
end
-- }}}

local function finish(g, u, c)
    if g.spell_event then
        g.spell_event("SPELL_FINISH", c)
        g.spell_event("SPELL_ENDCAST", c)
    end
    u.casting = nil
    if u.order and u.order.kind == "cast" then u.order = nil end
end

function abilities.step_cast(g, u, dt, fresh)
    local c = u.casting
    if not c then return end
    if u.alive == false then abilities.interrupt(g, u) return end
    if u.stunned then abilities.interrupt(g, u) return end
    local i = c.info
    if c.target and c.target.alive == false and c.phase == "approach" then abilities.interrupt(g, u) return end
    if c.phase == "approach" then
        local tx, ty = c.x, c.y
        if c.target then tx, ty = c.target.x, c.target.y end
        local range = (i.range or 600) + 40
        if not tx or (u.x - tx) ^ 2 + (u.y - ty) ^ 2 <= range * range then
            u.route = nil
            if tx and (tx ~= u.x or ty ~= u.y) then u.facing = math.atan2(ty - u.y, tx - u.x) end
            if c.target then c.x, c.y = c.target.x, c.target.y end
            c.phase, c.left = "point", tonumber((g.data.units:value(u.id, "ucpt"))) or abilities.CAST_POINT
            g.spell_event("SPELL_CHANNEL", c)
            g.spell_event("SPELL_CAST", c)
            -- the script may have stopped it
            if u.casting ~= c then return end
        elseif fresh or not u.route then
            g.walk_to(u, tx, ty)
            return
        else
            return
        end
    end
    if c.phase == "point" then
        c.left = c.left - dt
        if c.left > 0 then return end
        -- the spell happens: mana, cooldown, the event, the effect
        u.mana = math.max(0, (u.mana or 0) - i.mana)
        u.cooldowns = u.cooldowns or {}
        u.cooldowns[c.id] = g.time + i.cooldown
        g.spell_event("SPELL_EFFECT", c)
        if u.casting ~= c then return end
        abilities.land(g, c)
        g.casts = (g.casts or 0) + 1
        local chan = c.base and c.base.channel and (c.base.channel_time and c.base.channel_time(i) or i.duration or 0) or 0
        if chan > 0 then
            c.phase, c.left = "channel", chan
        else
            finish(g, u, c)
        end
        return
    end
    if c.phase == "channel" then
        if c.base and c.base.tick then c.base.tick(g, c, dt) end
        c.left = c.left - dt
        if c.left <= 0 then finish(g, u, c) end
    end
end

function abilities.update(g, dt)
    -- auras: every half second, each aura's allies in range get its buff
    g.aura_clock = (g.aura_clock or 0) + dt
    local auras = g.aura_clock >= abilities.AURA_EVERY
    if auras then g.aura_clock = 0 end
    local C = g.constants
    for _, u in ipairs(g.units) do
        if u.alive and not u.removed then
            if u.casting then abilities.step_cast(g, u, dt, false) end
            -- regeneration
            local hpr = (u.hp_regen or 0) + (u.hp_regen_bonus or 0)
            local mpr = (u.mana_regen or 0) + (u.mana_regen_bonus or 0)
            if u.hero then
                hpr = hpr + (u.str or 0) * (C:get("StrRegenBonus") or 0.05)
                mpr = mpr + (u.int or 0) * (C:get("IntRegenBonus") or 0.05)
            end
            if hpr ~= 0 and u.hp and u.hp_max then u.hp = math.max(1, math.min(u.hp_max, u.hp + hpr * dt)) end
            if mpr ~= 0 and u.mana_max and u.mana_max > 0 then u.mana = math.min(u.mana_max, (u.mana or 0) + mpr * dt) end
            if auras and u.abilities then
                for id, level in pairs(u.abilities) do
                    if level > 0 then
                        local b, target, i = g.ability_spec(id, level)
                        if target == "aura" and b.aura then
                            local spec = b.aura(g, u, i)
                            spec.aura, spec.source = true, u
                            if g.ability_art then spec.art_paths, spec.art_attach = g.ability_art(id, level, "target") end
                            spec.ends = g.time + abilities.AURA_EVERY * 2.2
                            local test = b.enemies and enemy_of(g, u) or ally_of(g, u)
                            for _, v in ipairs(units_in(g, u.x, u.y, i.area or 900, test)) do
                                if v.spec.design ~= "building" then buffs.add(g, v, spec) end
                            end
                        end
                    end
                end
            end
        end
    end
    buffs.update(g, dt)
end
-- }}}

return abilities
