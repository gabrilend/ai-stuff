--[[
Research (Issue 542)

Upgrades researched at buildings, as in WC3:

  what      a building researches the upgrades in its ures list; each
            upgrade has levels (glvl), and each level costs gold, lumber
            and time: base plus the increment for each level already had
            (gglb + gglm x (level - 1); lumber glmb / glmm; time gtib /
            gtim), and needs its requirements (greq)
  queue     a research takes a place in the building's queue like
            training; the same upgrade can't be queued past its last
            level; cancelling refunds it. RESEARCH_START / _CANCEL /
            _FINISH for the script (GetResearched)
  levels    are the player's (the script's SetPlayerTechResearched and
            GetPlayerTechCount see the same numbers), and count as
            requirements for training and building
  effects   each of an upgrade's four effects (gef1-4, with base gba1-4,
            increment gmo1-4 and ability code gco1-4) applies to the
            player's units whose upgrade list (upgr) names it, at
            base + increment x (level - 1), to units there now and those
            made later:
              rhpx  hit points        rhpo  hit points, a share
              rarm  armour            ratx  attack damage
              ratd  attack dice       ratr  attack range
              rats  attack speed (a share: cooldown / (1 + x))
              rmvx  move speed        rmnx  mana
              rhpr  hit point regen   rmnr  mana regen
              rlev  an ability's level (its code gco)
            Others are counted as unknown and left alone

The effect codes are FROM MEMORY; check them against the install's
UpgradeEffects.

    research.init(game)             -- after production and abilities
    game.researches(building)       -- the ids it researches
    game.research_level(player, id), game.set_research(player, id, level)
    game.upgrade_info(id, level)    -- { name, max, gold, lumber, time, requires, effects }
    game.can_research(b, id), game.research(b, id)
]]

local research = {}

research.STANDIN_TIME = 60

-- what applies where: code -> the unit field it changes
research.EFFECTS = {
    rhpx = "hp", rhpo = "hp_share", rarm = "armor", ratx = "damage", ratd = "dice", ratr = "range",
    rats = "attack_speed", rmvx = "speed", rmnx = "mana", rhpr = "hp_regen", rmnr = "mana_regen",
    rlev = "ability",
}

-- {{{ research.init
function research.init(g)
    local names = require("ui.wc3.names")

    local function list(id, code)
        local l = g.db.unit_list(id, code)
        if #l > 0 then return l end
        local D = g.data and g.data.units
        l = D and D.list and D:list(id, code) or {}
        if #l > 0 then return l end
        if code == "ures" and names.RESEARCHES then return names.RESEARCHES[id] or {} end
        return {}
    end

    -- {{{ levels
    local own = {}
    local function levels(player)
        local ps = g.script and g.script.players and g.script.players[player]
        if ps then
            ps.research = ps.research or {}
            return ps.research
        end
        own[player] = own[player] or {}
        return own[player]
    end
    function g.research_level(player, id) return levels(player)[id] or 0 end
    -- }}}

    -- {{{ an upgrade's data
    local U = function() return g.data.upgrades end
    local cache = {}
    function g.upgrade_info(id, level)
        level = math.max(1, level or 1)
        local key = id .. ":" .. level
        if cache[key] and cache[key].source == U() then return cache[key] end
        local D = U()
        local function v(code, lvl) return (D:value(id, code, lvl or level)) end
        local function n(code, def, lvl) return tonumber(v(code, lvl)) or def end
        local have = level - 1
        local info = {
            id = id, level = level,
            name = v("gnam") or (D.profile_field and D:profile_field(id, "Name")) or names.unit(id) or id,
            max = n("glvl", 1, 1),
            gold = n("gglb", 0, 1) + n("gglm", 0, 1) * have,
            lumber = n("glmb", 0, 1) + n("glmm", 0, 1) * have,
            time = n("gtib", research.STANDIN_TIME, 1) + n("gtim", 0, 1) * have,
            requires = {}, effects = {},
        }
        local req = v("greq")
        if type(req) == "string" then
            for r in req:gmatch("[^,%s]+") do if #r == 4 then info.requires[#info.requires + 1] = r end end
        end
        for k = 1, 4 do
            local code = v("gef" .. k, 1)
            if type(code) == "string" and code ~= "" and code ~= "_" then
                info.effects[#info.effects + 1] = {
                    code = code:lower(), base = n("gba" .. k, 0, 1), mod = n("gmo" .. k, 0, 1),
                    ability = v("gco" .. k, 1),
                }
            end
        end
        info.source = D
        cache[key] = info
        return info
    end
    -- }}}

    -- {{{ effects on units
    -- what a player's research gives a unit, summed over its upgrades
    local function bonuses(u)
        local b = { hp = 0, hp_share = 0, armor = 0, damage = 0, dice = 0, range = 0, attack_speed = 0,
                    speed = 0, mana = 0, hp_regen = 0, mana_regen = 0, abilities = {} }
        for _, id in ipairs(list(u.id, "upgr")) do
            local lvl = g.research_level(u.player, id)
            if lvl > 0 then
                for _, e in ipairs(g.upgrade_info(id, 1).effects) do
                    local what = research.EFFECTS[e.code]
                    local x = e.base + e.mod * (lvl - 1)
                    if what == "ability" then
                        if type(e.ability) == "string" and #e.ability == 4 then
                            b.abilities[e.ability] = math.max(b.abilities[e.ability] or 0, math.floor(x + 0.5))
                        end
                    elseif what then
                        b[what] = b[what] + x
                    else
                        g.research_unknown = g.research_unknown or {}
                        g.research_unknown[e.code] = true
                    end
                end
            end
        end
        return b
    end

    -- bring a unit up to its player's research (the change since last time)
    function g.apply_research(u)
        if not u or u.alive == false then return end
        local b = bonuses(u)
        local was = u.research_applied or { hp = 0, hp_share = 0, armor = 0, damage = 0, dice = 0, range = 0,
                                           attack_speed = 0, speed = 0, mana = 0, hp_regen = 0, mana_regen = 0,
                                           abilities = {} }
        if u.hp_max then
            local base_hp = (u.hp_max - was.hp) / (1 + was.hp_share)
            local new_max = (base_hp) * (1 + b.hp_share) + b.hp
            local gained = new_max - u.hp_max
            u.hp_max = new_max
            u.hp = math.min(new_max, (u.hp or new_max) + math.max(0, gained))
        end
        if u.armor then u.armor = u.armor + b.armor - was.armor end
        local w = u.weapon
        if w then
            local sides = u.dmg_sides or 1
            w.dmg_lo = w.dmg_lo + (b.damage - was.damage) + (b.dice - was.dice)
            w.dmg_hi = w.dmg_hi + (b.damage - was.damage) + (b.dice - was.dice) * sides
            w.range = w.range + b.range - was.range
            w.acquire = math.max(w.acquire or 0, w.range)
            w.base_cooldown = w.base_cooldown or w.cooldown
            w.cooldown = w.base_cooldown / (1 + b.attack_speed)
        end
        if u.speed or b.speed ~= 0 then u.speed = (u.speed or 270) + b.speed - was.speed end
        if u.mana_max or b.mana ~= 0 then u.mana_max = (u.mana_max or 0) + b.mana - was.mana end
        u.hp_regen = (u.hp_regen or 0) + b.hp_regen - was.hp_regen
        u.mana_regen = (u.mana_regen or 0) + b.mana_regen - was.mana_regen
        -- an ability the unit has goes up to the level its research gives
        for id, lvl in pairs(b.abilities) do
            if u.abilities and (u.abilities[id] or 0) > 0 then
                u.abilities[id] = math.max(u.abilities[id], lvl)
            end
        end
        u.research_applied = b
    end

    function g.set_research(player, id, level)
        levels(player)[id] = math.max(0, level or 0)
        for _, u in ipairs(g.units) do
            if u.player == player and u.alive ~= false then g.apply_research(u) end
        end
    end

    table.insert(g.spawn_listeners, function(u) g.apply_research(u) end)
    if g.morph_listeners then
        table.insert(g.morph_listeners, function(u) u.research_applied = nil; g.apply_research(u) end)
    end
    -- }}}

    -- {{{ researching
    function g.researches(b) return list(b.id, "ures") end

    -- the level id would reach next at b's player, counting what's queued
    local function next_level(player, id)
        local n = g.research_level(player, id)
        for _, u in ipairs(g.units) do
            if u.player == player and u.alive ~= false then
                for _, q in ipairs(u.queue or {}) do if q.research == id then n = n + 1 end end
            end
        end
        return n + 1
    end
    g.next_research_level = next_level

    function g.can_research(b, id)
        if not b or b.alive == false or b.removed or b.spec.design ~= "building" then return false, "can't" end
        if b.building_up then return false, "under construction" end
        if b.upgrading then return false, "upgrading" end
        local listed = false
        for _, r in ipairs(g.researches(b)) do if r == id then listed = true end end
        if not listed then return false, "doesn't research that" end
        if #(b.queue or {}) >= (require("demo.wc3map.production").QUEUE_MAX or 7) then return false, "queue full" end
        local lvl = next_level(b.player, id)
        local info = g.upgrade_info(id, lvl)
        if lvl > info.max then return false, "fully researched" end
        for _, r in ipairs(info.requires) do
            if not g.has_tech(b.player, r) then return false, "requires " .. r end
        end
        local s = g.state(b.player)
        if (s.gold or 0) < info.gold then return false, "not enough gold" end
        if (s.lumber or 0) < info.lumber then return false, "not enough lumber" end
        return true
    end

    function g.research(b, id)
        local ok, why = g.can_research(b, id)
        if not ok then return false, why end
        local lvl = next_level(b.player, id)
        local info = g.upgrade_info(id, lvl)
        local s = g.state(b.player)
        s.gold, s.lumber = s.gold - info.gold, s.lumber - info.lumber
        b.queue = b.queue or {}
        b.queue[#b.queue + 1] = { research = id, id = id, level = lvl, left = info.time, time = info.time,
                                  gold = info.gold, lumber = info.lumber, food = 0 }
        if g.script then g.script:unit_event("RESEARCH_START", b, { research = require("jass.vm").s2id(id) }) end
        return true
    end

    -- a research at the head of a queue is done (production.update asks)
    function g.research_done(b, q)
        g.set_research(b.player, q.research, math.max(g.research_level(b.player, q.research), q.level))
        g.researched = (g.researched or 0) + 1
        if g.script then g.script:unit_event("RESEARCH_FINISH", b, { research = require("jass.vm").s2id(q.research) }) end
    end
    function g.research_cancelled(b, q)
        if g.script then g.script:unit_event("RESEARCH_CANCEL", b, { research = require("jass.vm").s2id(q.research) }) end
    end

    -- the command card asks
    g.db.researches = function(b) return g.researches(b) end
    g.db.research_button = function(id)
        local info = g.upgrade_info(id, 1)
        local D = g.data.upgrades
        return { name = info.name, max = info.max, hotkey = (D:value(id, "ghk1")), tip = (D:value(id, "gtp1")),
                 x = tonumber((D:value(id, "gbpx"))), y = tonumber((D:value(id, "gbpy"))) }
    end
    g.db.can_research = function(b, id) return g.can_research(b, id) end
    g.db.next_research_level = function(b, id) return next_level(b.player, id) end
    -- }}}
end
-- }}}

return research
