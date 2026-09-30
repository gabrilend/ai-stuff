--[[
Heroes (Issue 528)

Heroes as WC3 keeps them:

  level, xp     start at level 1; experience from kills near them raises
                it (the gameplay constants' tables and formulas: what a
                level needs, what a kill grants, the share a hero of each
                level takes, the range, the level cap)
  attributes    strength, agility, intelligence: the type's base plus its
                growth per level (ustr/uagi/uint + ustp/uagp/uinp), plus
                bonuses (tomes, the script's SetHeroStr ...). Strength
                gives hit points, intelligence mana, agility armour; the
                primary attribute adds to damage (StrHitPointBonus,
                IntManaBonus, AgiDefenseBonus)
  skills        a skill point at level 1 and each level after; a hero
                ability's next level needs hero level req + (level - 1) *
                skip (arlv, alsk; HeroAbilityLevelSkip), up to its levels
                (alev). Learned levels live in u.abilities (the ability
                system reads them, issue 529)
  death         a fallen hero stays (a corpse that doesn't decay) until
                revived at an altar (ReviveBaseFactor ... for the cost and
                time, HeroMaxReviveCostGold ...) or by the script
  limits        the player's hero limit (tech max for 'HERO', as
                MeleeStartingHeroLimit sets it), each type's own limit,
                and hero tokens (a free hero)

    heroes.init(game)                      -- after economy and production
    game.add_xp(hero, n), game.set_hero_level(hero, n)
    game.learn(hero, ability_id)           -- true, or false and why
    game.revive(altar, hero)               -- queued at the altar
    game.heroes(player)                    -- the player's heroes, living or not
]]

local heroes = {}

-- stand-ins for hero abilities the tables don't describe
heroes.ABILITY_LEVELS, heroes.ABILITY_REQ = 3, 1

-- {{{ Attributes and what they give
-- The hero's attributes at its level, and its hit points, mana, armour
-- and damage from them (keeping the share of hit points and mana it had)
function heroes.refresh(g, u)
    local h = u.hero
    if not h then return end
    local C = g.constants
    local lv = (u.level or 1) - 1
    u.str = math.floor(h.str + h.str_plus * lv + h.str_bonus)
    u.agi = math.floor(h.agi + h.agi_plus * lv + h.agi_bonus)
    u.int = math.floor(h.int + h.int_plus * lv + h.int_bonus)
    local hp_share = (u.hp and u.hp_max and u.hp_max > 0) and u.hp / u.hp_max or 1
    local mana_share = (u.mana and u.mana_max and u.mana_max > 0) and u.mana / u.mana_max or 1
    if h.hp_raw then u.hp_max = h.hp_raw + u.str * (C:get("StrHitPointBonus") or 25) end
    u.mana_max = (h.mana_raw or 0) + u.int * (C:get("IntManaBonus") or 15)
    if h.armor_raw then u.armor = h.armor_raw + u.agi * (C:get("AgiDefenseBonus") or 0.3) end
    local main = ({ STR = u.str, AGI = u.agi, INT = u.int })[h.primary]
    if h.dmg_raw and main then
        local base = h.dmg_raw + main * (C:get("StrAttackBonus") or 1)
        u.dmg_base = base
        u.damage = string.format("%d - %d", base + (u.dmg_dice or 1), base + (u.dmg_dice or 1) * (u.dmg_sides or 1))
        if u.weapon then
            u.weapon.dmg_lo = base + (u.dmg_dice or 1)
            u.weapon.dmg_hi = base + (u.dmg_dice or 1) * (u.dmg_sides or 1)
        end
    end
    if u.alive ~= false then
        u.hp = (u.hp_max or 0) * hp_share
        u.mana = u.mana_max * mana_share
    end
end

-- A new hero: its attributes' bases and growth, level 1, a skill point
function heroes.init_unit(g, u)
    if not u.spec.hero or u.hero then return end
    local D = g.data.units
    local function v(code, def) local x = D:value(u.id, code) return tonumber(x) or def end
    u.hero = {
        str = u.str_type or v("ustr", 0), agi = u.agi_type or v("uagi", 0), int = u.int_type or v("uint", 0),
        str_plus = v("ustp", 0), agi_plus = v("uagp", 0), int_plus = v("uinp", 0),
        str_bonus = 0, agi_bonus = 0, int_bonus = 0,
        primary = tostring(D:value(u.id, "upra") or ""):upper(),
        hp_raw = u.hp_raw, mana_raw = u.mana_raw, armor_raw = u.armor_raw, dmg_raw = u.dmg_raw,
    }
    -- heroes without attributes in any table (the map's own, no install)
    -- keep the stats they have
    local h = u.hero
    if h.str + h.agi + h.int == 0 then
        h.hp_raw, h.armor_raw, h.dmg_raw = nil, nil, nil
        h.mana_raw = u.mana_max
    end
    u.level = 1
    u.xp = 0
    u.skill_points = 1
    u.abilities = u.abilities or {}
    heroes.refresh(g, u)
    u.hp = u.hp_max or u.hp
    u.mana = u.mana_max
end
-- }}}

-- {{{ heroes.init
function heroes.init(g)
    local C = g.constants

    function g.refresh_hero(u) heroes.refresh(g, u) end

    function g.heroes(player)
        local list = {}
        for _, u in ipairs(g.units) do
            if u.player == player and u.spec.hero and not u.removed then list[#list + 1] = u end
        end
        return list
    end

    local function event(what, u, data)
        if g.script then g.script:unit_event(what, u, data) end
    end

    -- {{{ experience and levels
    function g.set_hero_level(u, level, quiet)
        if not u or not u.hero then return end
        level = math.max(1, math.min(level, C:get("MaxHeroLevel") or 10))
        local was = u.level or 1
        if level == was then return end
        u.level = level
        if level > was then
            u.skill_points = (u.skill_points or 0) + (level - was)
            if (u.xp or 0) < C:hero_xp_needed(level) then u.xp = C:hero_xp_needed(level) end
        else
            u.xp = math.min(u.xp or 0, C:hero_xp_needed(level))
            -- lost levels take their unspent points
            u.skill_points = math.max(0, (u.skill_points or 0) - (was - level))
        end
        heroes.refresh(g, u)
        if level > was then
            if g.on_hero_level then g.on_hero_level(u, level) end
            event("HERO_LEVEL", u)
        end
    end

    function g.add_xp(u, n)
        if not u or not u.hero or u.xp_suspended or n <= 0 then return end
        local max = C:get("MaxHeroLevel") or 10
        if (u.level or 1) >= max then return end
        u.xp = (u.xp or 0) + n
        local level = C:level_for_xp(u.xp)
        if level > (u.level or 1) then g.set_hero_level(u, level) end
    end

    function g.set_xp(u, xp)
        if not u or not u.hero then return end
        u.xp = math.max(0, xp)
        local level = C:level_for_xp(u.xp)
        if level ~= (u.level or 1) then g.set_hero_level(u, level) end
    end

    -- kills near heroes: the kill's experience shared among the killer's
    -- (and its allies') living heroes in range
    table.insert(g.death_listeners, function(victim, killer)
        if not killer or killer.player > 11 or victim.player == killer.player then return end
        if victim.spec.design == "building" and (C:get("BuildingKillsGiveExp") or 0) == 0 then return end
        local xp = C:kill_xp(victim.level or 1, victim.spec.hero)
        if victim.summoned then xp = xp * (C:get("SummonedKillFactor") or 0.5) end
        local range = C:get("HeroExpRange") or 1200
        local takers = {}
        for _, u in ipairs(g.units) do
            if u.hero and u.alive and not u.removed
                and (u.player == killer.player or (g.allied and g.allied(u.player, killer.player)))
                and (u.x - victim.x) ^ 2 + (u.y - victim.y) ^ 2 <= range * range then
                takers[#takers + 1] = u
            end
        end
        if #takers == 0 then return end
        local share = xp / #takers
        for _, u in ipairs(takers) do
            g.add_xp(u, math.floor(share * C:hero_factor(u.level or 1) + 0.5))
        end
    end)
    -- }}}

    -- {{{ skills
    -- a hero ability's levels, first required level and level skip
    function g.hero_ability_rules(id)
        local A = g.data.abilities
        local levels = tonumber((A:value(id, "alev"))) or heroes.ABILITY_LEVELS
        local req = tonumber((A:value(id, "arlv"))) or heroes.ABILITY_REQ
        local skip = tonumber((A:value(id, "alsk"))) or (C:get("HeroAbilityLevelSkip") or 2)
        return levels, req, skip
    end

    function g.hero_skills(u)
        local list = {}
        if not u then return list end
        for _, id in ipairs(g.db.unit_list(u.id, "uhab")) do list[#list + 1] = id end
        return list
    end

    function g.can_learn(u, id)
        if not u or not u.hero then return false, "not a hero" end
        if u.alive == false then return false, "dead" end
        if (u.skill_points or 0) <= 0 then return false, "no skill points" end
        local mine = false
        for _, a in ipairs(g.hero_skills(u)) do if a == id then mine = true end end
        if not mine then return false, "not one of its skills" end
        local have = u.abilities[id] or 0
        local levels, req, skip = g.hero_ability_rules(id)
        if have >= levels then return false, "fully learned" end
        local need = req + have * skip
        if (u.level or 1) < need then return false, "needs hero level " .. need end
        return true
    end

    function g.learn(u, id)
        local ok, why = g.can_learn(u, id)
        if not ok then return false, why end
        u.abilities[id] = (u.abilities[id] or 0) + 1
        u.skill_points = u.skill_points - 1
        if g.on_learn then g.on_learn(u, id, u.abilities[id]) end
        event("HERO_SKILL", u, { ability = require("jass.vm").s2id(id), learned_level = u.abilities[id] })
        return true
    end
    -- }}}

    -- {{{ revival
    function g.is_altar(b)
        if not b or b.spec.design ~= "building" or b.alive == false then return false end
        local r = g.data.units:value(b.id, "urev")
        if r ~= nil then return tonumber(r) == 1 or r == true end
        return b.spec.size == "altar"
    end

    function g.revive_cost(u)
        local c = g.unit_cost and g.unit_cost(u.id) or { gold = 0, lumber = 0, time = 0 }
        return C:revive(c.gold, c.lumber, c.time, u.level or 1)
    end

    -- the heroes an altar can bring back: its owner's fallen ones not
    -- already being revived
    function g.revivable(b)
        local list = {}
        if not g.is_altar(b) then return list end
        for _, u in ipairs(g.heroes(b.player)) do
            if u.alive == false and not u.reviving then list[#list + 1] = u end
        end
        return list
    end

    function g.revive(b, u)
        if not g.is_altar(b) then return false, "not an altar" end
        if not u or not u.hero or u.alive ~= false or u.removed then return false, "not a fallen hero" end
        if u.player ~= b.player then return false, "not yours" end
        if u.reviving then return false, "already being revived" end
        if #(b.queue or {}) >= 7 then return false, "queue full" end
        local gold, lumber, time = g.revive_cost(u)
        local s = g.state(b.player)
        if (s.gold or 0) < gold then return false, "not enough gold" end
        if (s.lumber or 0) < lumber then return false, "not enough lumber" end
        s.gold, s.lumber = s.gold - gold, s.lumber - lumber
        b.queue = b.queue or {}
        b.queue[#b.queue + 1] = { id = u.id, revive = u, left = time, time = time, food = 0, gold = gold, lumber = lumber }
        u.reviving = b
        event("HERO_REVIVE_START", u)
        return true
    end

    -- back on its feet at (x, y): full health, mana by HeroReviveManaFactor
    function g.revive_now(u, x, y)
        if not u or u.alive ~= false or u.removed then return false end
        u.alive, u.died_at, u.reviving = true, nil, nil
        u.hp = u.hp_max or 100
        local mf = C:get("HeroReviveManaFactor") or 0
        u.mana = (u.mana_max or 0) * mf
        u.x, u.y = x or u.x, y or u.y
        if g.ground_at then u.z = g.ground_at(u.x, u.y) end
        if u.mover then u.mover.x, u.mover.y = u.x, u.y end
        u.order, u.route, u.target, u.swing = nil, nil, nil, nil
        if g.on_revive then g.on_revive(u) end
        event("HERO_REVIVE_FINISH", u)
        return true
    end
    -- }}}

    -- {{{ limits
    -- tech max: the script's (SetPlayerTechMaxAllowed), else the game's
    g.tech_max = g.tech_max or {}
    function g.tech_limit(player, id)
        local ps = g.script and g.script.players[player]
        local t = ps and ps.tech_max or g.tech_max[player]
        local v = t and t[id]
        if v == nil or v < 0 then return nil end
        return v
    end

    -- how many of a type (or heroes, id "HERO") the player has or is making
    function g.tech_count(player, id)
        local n = 0
        for _, u in ipairs(g.units) do
            if u.player == player and not u.removed and (u.alive ~= false or u.spec.hero) then
                if (id == "HERO" and u.spec.hero) or u.id == id then n = n + 1 end
            end
            if u.player == player and u.queue then
                for _, q in ipairs(u.queue) do
                    if not q.revive and (q.id == id or (id == "HERO" and q.hero)) then n = n + 1 end
                end
            end
        end
        return n
    end
    -- }}}

    -- the command card asks these
    g.db.can_learn = function(u, id) return (g.can_learn(u, id)) end
    g.db.revivable = g.revivable

    for _, u in ipairs(g.units) do heroes.init_unit(g, u) end
    table.insert(g.spawn_listeners, function(u) heroes.init_unit(g, u) end)
end
-- }}}

return heroes
