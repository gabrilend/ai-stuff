--[[
Production (Issue 521a)

Buildings train units the way WC3's do: a queue of up to seven per
building, paid for when queued (and refunded if cancelled), the first in
line counting down its build time, the finished unit stepping out beside
the building and walking to the rally point if one is set.

What a unit costs comes from the map's object data where it says (gold
ugol, lumber ulum, build time ubld, food ufoo, requirements ureq); the
rest are STAND-INS by archetype below, chosen to play plausibly, not the
game's values. Which building trains what is db.unit_list(id, "utra")
(game.lua).

A player's gold, lumber and food are the economy's (demo/wc3map/economy.lua,
issue 527): the running script's player state when a script runs.

    production.init(game)             -- installs game.train and friends
    game.train(building, "hfoo")      -- true, or false and why not
    production.update(game, dt)       -- each tick
]]

local production = {}

production.QUEUE_MAX = 7

-- {{{ Stand-ins (see the header)
-- gold, lumber, seconds, food
production.STANDINS = {
    worker   = { 75, 0, 15, 1 },
    infantry = { 135, 0, 20, 2 },
    ranged   = { 205, 30, 26, 3 },
    gunner   = { 205, 30, 26, 3 },
    caster   = { 155, 20, 30, 2 },
    mounted  = { 245, 60, 45, 4 },
    heavy    = { 280, 80, 50, 5 },
    beast    = { 180, 20, 30, 3 },
    flyer    = { 280, 70, 45, 4 },
    siege    = { 220, 50, 40, 4 },
    ship     = { 250, 60, 45, 4 },
    hero     = { 425, 100, 55, 5 },
}
-- }}}

-- {{{ production.is_hero
function production.is_hero(g, id)
    -- a hero's type id starts with a capital letter (WC3's convention)
    return type(id) == "string" and id:sub(1, 1):match("%u") ~= nil
end
-- }}}

-- {{{ production.init
function production.init(g)
    local m = g.scene.map
    local units_table = m.object_data and m.object_data.units
    local function field(id, code)
        if not units_table or not units_table:has(id) then return nil end
        return units_table:get_modification(id, code)
    end

    local cost_cache = {}
    -- { gold, lumber, time, food, requires = {ids}, standin = bool }
    function g.unit_cost(id)
        local c = cost_cache[id]
        if c then return c end
        local spec_arch
        do
            local ok, map_scene = pcall(require, "demo.wc3map.scene")
            local spec = ok and map_scene.unit_spec(m, id) or {}
            spec_arch = spec.hero and "hero" or (spec.archetype or "infantry")
        end
        local s = production.STANDINS[spec_arch] or production.STANDINS.infantry
        local gold, lumber, time, food = field(id, "ugol"), field(id, "ulum"), field(id, "ubld"), field(id, "ufoo")
        c = { gold = gold or s[1], lumber = lumber or s[2], time = time or s[3], food = food or s[4],
              standin = gold == nil or time == nil, requires = {} }
        local req = field(id, "ureq")
        if type(req) == "string" then
            for r in req:gmatch("[^,%s]+") do if #r == 4 then c.requires[#c.requires + 1] = r end end
        end
        cost_cache[id] = c
        return c
    end

    -- {{{ requirements: a living unit (or finished research) of each id
    function g.has_tech(player, id)
        if g.research_level and g.research_level(player, id) > 0 then return true end
        local ps = g.script and g.script.players[player]
        if ps and ps.research and (ps.research[id] or 0) > 0 then return true end
        for _, u in ipairs(g.units) do
            if u.player == player and u.id == id and u.alive ~= false and not u.removed and not u.building_up then
                return true
            end
        end
        return false
    end
    -- }}}

    -- {{{ g.can_train
    function g.can_train(b, id)
        if not b or b.alive == false or b.removed then return false, "gone" end
        if b.spec.design ~= "building" then return false, "not a building" end
        local listed = false
        for _, t in ipairs(g.db.unit_list(b.id, "utra")) do if t == id then listed = true end end
        if not listed then return false, "doesn't train that" end
        if #(b.queue or {}) >= production.QUEUE_MAX then return false, "queue full" end
        -- limits: the type's (tech max), and heroes' (tech max of 'HERO',
        -- issue 528)
        if g.tech_limit then
            local max = g.tech_limit(b.player, id)
            if max == 0 then return false, "not allowed" end
            if max and g.tech_count(b.player, id) >= max then return false, "limit reached" end
            if production.is_hero(g, id) then
                local hmax = g.tech_limit(b.player, "HERO")
                if hmax and g.tech_count(b.player, "HERO") >= hmax then return false, "hero limit reached" end
            end
        else
            local ps = g.script and g.script.players[b.player]
            if ps and ps.tech_max[id] == 0 then return false, "not allowed" end
        end
        local c = g.unit_cost(id)
        for _, r in ipairs(c.requires) do
            if not g.has_tech(b.player, r) then return false, "requires " .. r end
        end
        local purse = g.purse(b.player)
        local free = production.is_hero(g, id) and (tonumber(purse.hero_tokens) or 0) > 0
        if not free and (purse.gold or 0) < c.gold then return false, "not enough gold" end
        if not free and (purse.lumber or 0) < c.lumber then return false, "not enough lumber" end
        local used, cap = g.food(b.player)
        if c.food > 0 and used + c.food > cap then return false, "not enough food" end
        return true
    end
    -- }}}

    -- {{{ g.train / g.cancel_train / g.set_rally
    function g.train(b, id)
        local ok, why = g.can_train(b, id)
        if not ok then return false, why end
        local c = g.unit_cost(id)
        local purse = g.purse(b.player)
        local hero = production.is_hero(g, id)
        local gold, lumber, token = c.gold, c.lumber, false
        -- a hero token pays for a hero
        if hero and (tonumber(purse.hero_tokens) or 0) > 0 then
            purse.hero_tokens = purse.hero_tokens - 1
            gold, lumber, token = 0, 0, true
        end
        purse.gold, purse.lumber = purse.gold - gold, purse.lumber - lumber
        b.queue = b.queue or {}
        b.queue[#b.queue + 1] = { id = id, left = c.time, time = c.time, food = c.food,
                                  gold = gold, lumber = lumber, hero = hero, token = token }
        if g.script then g.script:unit_event("TRAIN_START", b, { trained_type = require("jass.vm").s2id(id) }) end
        return true
    end

    -- the last in the queue (or slot k), refunded
    function g.cancel_train(b, k)
        if not b.queue or #b.queue == 0 then return false end
        local q = table.remove(b.queue, k or #b.queue)
        local purse = g.purse(b.player)
        purse.gold, purse.lumber = purse.gold + q.gold, purse.lumber + q.lumber
        if q.token then purse.hero_tokens = (tonumber(purse.hero_tokens) or 0) + 1 end
        if q.revive then q.revive.reviving = nil end
        if q.research and g.research_cancelled then g.research_cancelled(b, q) end
        return true
    end

    function g.set_rally(b, x, y) b.rally = { x = x, y = y } end
    -- }}}
end
-- }}}

-- {{{ production.update
function production.update(g, dt)
    for _, b in ipairs(g.units) do
        local q = b.queue
        if q and #q > 0 then
            if b.alive == false or b.removed then
                b.queue = nil   -- a fallen building's queue is lost (WC3 refunds nothing)
            else
                local head = q[1]
                head.left = head.left - dt
                if head.left <= 0 and head.research then
                    -- a research done (issue 542)
                    table.remove(q, 1)
                    if g.research_done then g.research_done(b, head) end
                elseif head.left <= 0 and head.revive then
                    -- a hero back from the altar (issue 528)
                    table.remove(q, 1)
                    local a = math.atan2(-1, 0)
                    local r = ({ small = 150, medium = 210, hall = 280, tower = 110, altar = 190 })[b.spec.size] or 200
                    if g.revive_now then g.revive_now(head.revive, b.x + math.cos(a) * r, b.y + math.sin(a) * r) end
                    if b.rally and head.revive.alive then g.order({ head.revive }, "move", b.rally.x, b.rally.y) end
                elseif head.left <= 0 then
                    table.remove(q, 1)
                    -- out beside the building, toward the rally point (else south)
                    local tx, ty = b.x, b.y - 1
                    if b.rally then tx, ty = b.rally.x, b.rally.y end
                    local a = math.atan2(ty - b.y, tx - b.x)
                    local r = ({ small = 150, medium = 210, hall = 280, tower = 110, altar = 190 })[b.spec.size] or 200
                    local u = g.spawn(head.id, b.player, b.x + math.cos(a) * r, b.y + math.sin(a) * r, a)
                    u.trained_by = b
                    if b.rally then g.order({ u }, "move", b.rally.x, b.rally.y) end
                    g.trained = (g.trained or 0) + 1
                    if g.made then g.made(u, "trained") end
                    if g.on_trained then g.on_trained(b, u) end
                end
            end
        end
    end
end
-- }}}

return production
