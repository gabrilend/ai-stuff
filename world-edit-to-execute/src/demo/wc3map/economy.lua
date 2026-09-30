--[[
Economy (Issue 527)

The players' side of the game, as WC3 keeps it:

  state      one table per player (the running script's player when a
             script runs, so SetPlayerState and the game agree): gold,
             lumber, food ceiling, whether it gives bounty, what it has
             gathered, and score counters
  food       used (living units and queued ones) against made (farms,
             halls), capped by the ceiling (the gameplay constant
             FoodCeiling, or the script's FOOD_CAP_CEILING)
  upkeep     gold (and lumber) brought back is taxed by the tier the
             player's food use is in (UpkeepUsage / UpkeepGoldTax: DAoW
             switches it off)
  gathering  workers mine gold (one at a time inside a mine; the mine
             runs dry) and cut lumber from trees (a tree falls when its
             lumber is gone), and carry it to the nearest building that
             takes it back (the unit field urtm, else town halls)
  bounty     killing a unit of a player that gives bounty (neutral
             hostile, unless the script says otherwise) pays its bounty
             (ubba + ubdi dice of ubsi) to the killer's owner
  scores     units and buildings made, killed and lost, heroes, gold and
             lumber gathered and lost to upkeep: GetPlayerScore's

Harvest numbers are STAND-INS (not read yet from the harvest
abilities): 10 gold a trip after 1 second in the mine, 1 lumber a chop,
a chop a second, 10 lumber a trip, 50 lumber a tree, 12500 gold in a
mine the script doesn't fill.

    economy.init(game)                  -- before production.init
    game.state(p), game.food(p), game.upkeep(p)
    game.gather(worker, mine_or_nil, x, y)
    economy.update(game, dt)
]]

local economy = {}

economy.GOLD_TRIP, economy.MINE_TIME = 10, 1.0
economy.LUMBER_TRIP, economy.CHOP_EVERY, economy.CHOP = 10, 1.0, 1
economy.TREE_LUMBER, economy.MINE_GOLD = 50, 12500
economy.MINE_REACH, economy.TREE_REACH = 60, 100

-- score counters (GetPlayerScore's)
economy.SCORES = { "units_trained", "units_killed", "units_lost", "structures_built", "structures_razed",
                   "structures_lost", "heroes_hired", "heroes_killed", "heroes_lost", "gold_gathered",
                   "lumber_gathered", "gold_upkeep_lost", "lumber_upkeep_lost", "gold_bounty" }

-- {{{ Helpers
local function body(u)
    if u.spec.design ~= "building" then return 24 end
    return ({ small = 110, medium = 170, hall = 230, tower = 70, altar = 150, special = 150 })[u.spec.size] or 150
end

local function dist(a, x, y) return math.sqrt((a.x - x) ^ 2 + (a.y - y) ^ 2) end

function economy.is_mine(g, u)
    if not u or u.spec.design ~= "building" and u.id ~= "ngol" then return false end
    if u.id == "ngol" or u.id == "ugol" or u.gold then return true end
    local ab = g.data and g.data.units:list(u.id, "uabi") or {}
    for _, a in ipairs(ab) do if a == "Agld" or a == "Aegm" or a == "Abgm" then return true end end
    return false
end

function economy.is_worker(u)
    return u and u.alive and u.spec.archetype == "worker" and u.spec.design == "unit"
end
-- }}}

-- {{{ economy.init
function economy.init(g)

    function g.is_mine(u) return economy.is_mine(g, u) end

    -- {{{ state
    g.purses = g.purses or {}
    local function fill(s, player)
        if s._economy then return s end
        s._economy = true
        s.gold = s.gold or (g.start_resources.gold or 500)
        s.lumber = s.lumber or (g.start_resources.lumber or 150)
        -- neutral hostile gives bounty unless told otherwise
        if s.bounty == nil then s.bounty = player == 12 and 1 or 0 end
        s.gold_gathered, s.lumber_gathered = s.gold_gathered or 0, s.lumber_gathered or 0
        s.score = s.score or {}
        for _, k in ipairs(economy.SCORES) do s.score[k] = s.score[k] or 0 end
        return s
    end
    function g.state(player)
        if g.script then
            local p = g.script:player(player)
            -- the script's player starts with no gold field set by us: a
            -- script that sets its own keeps it
            if not p._economy then
                p.gold = p.gold or 0
                p.lumber = p.lumber or 0
            end
            return fill(p, player)
        end
        local p = g.purses[player]
        if not p then
            p = {}
            g.purses[player] = p
        end
        return fill(p, player)
    end
    g.purse = g.state

    function g.score(player, key, n)
        local s = g.state(player)
        s.score[key] = (s.score[key] or 0) + (n or 1)
    end
    -- }}}

    -- {{{ food and upkeep
    function g.food_ceiling(player)
        local s = g.state(player)
        local ceiling = tonumber(s.food_max)
        if not ceiling or ceiling <= 0 then ceiling = g.constants:get("FoodCeiling") or 100 end
        return ceiling
    end

    function g.food(player)
        local used, cap = 0, 0
        for _, u in ipairs(g.units) do
            if u.player == player and u.alive ~= false and not u.removed then
                used = used + (u.food or 0)
                if not u.building_up then cap = cap + (u.food_made or 0) end
                for _, q in ipairs(u.queue or {}) do used = used + (q.food or 0) end
            end
        end
        local s = g.state(player)
        if (tonumber(s.food_cap) or 0) > 0 then cap = math.max(cap, s.food_cap) end
        return used, math.min(g.food_ceiling(player), cap)
    end

    -- tier (0 none), gold tax, lumber tax
    function g.upkeep(player)
        local used = g.food(player)
        return g.constants:upkeep(used)
    end

    -- Resources brought in (gathered): upkeep taken off, counted
    function g.income(player, kind, amount)
        local s = g.state(player)
        local _, gtax, ltax = g.upkeep(player)
        local tax = kind == "gold" and gtax or ltax
        local kept = math.floor(amount * (1 - tax) + 0.5)
        s[kind] = (s[kind] or 0) + kept
        s[kind .. "_gathered"] = (s[kind .. "_gathered"] or 0) + kept
        g.score(player, kind .. "_gathered", kept)
        g.score(player, kind .. "_upkeep_lost", amount - kept)
        if g.script and g.script.player_state_changed then g.script:player_state_changed(player, kind) end
        return kept
    end
    -- }}}

    -- {{{ trees
    -- the map's trees as lumber: made when first needed
    function g.trees()
        if g._trees then return g._trees end
        local list, buckets = {}, {}
        for _, d in ipairs(g.scene.doodads or {}) do
            if d.spec and d.spec.design == "tree" then
                local t = { x = d.x, y = d.y, lumber = economy.TREE_LUMBER, doodad = d }
                list[#list + 1] = t
                local k = math.floor(t.x / 512) * 65536 + math.floor(t.y / 512)
                buckets[k] = buckets[k] or {}
                table.insert(buckets[k], t)
            end
        end
        g._trees, g._tree_buckets = list, buckets
        return list
    end

    function g.nearest_tree(x, y, r)
        g.trees()
        local best, bd = nil, (r or 1200) ^ 2
        local b0, b1 = math.floor((x - (r or 1200)) / 512), math.floor((x + (r or 1200)) / 512)
        local c0, c1 = math.floor((y - (r or 1200)) / 512), math.floor((y + (r or 1200)) / 512)
        for bx = b0, b1 do
            for by = c0, c1 do
                for _, t in ipairs(g._tree_buckets[bx * 65536 + by] or {}) do
                    if t.lumber > 0 then
                        local d = (t.x - x) ^ 2 + (t.y - y) ^ 2
                        if d < bd then best, bd = t, d end
                    end
                end
            end
        end
        return best
    end
    -- }}}

    -- {{{ drop-off
    -- does building b take kind back
    function g.takes(b, kind)
        if b.spec.design ~= "building" or b.alive == false or b.building_up then return false end
        local r = g.data and g.data.units:value(b.id, "urtm")
        if type(r) == "string" and r ~= "" then return r:lower():find(kind, 1, true) ~= nil end
        return b.spec.size == "hall"
    end

    function g.dropoff(u, kind)
        local best, bd = nil, math.huge
        for _, b in ipairs(g.units) do
            if b.player == u.player and g.takes(b, kind) then
                local d = dist(b, u.x, u.y)
                if d < bd then best, bd = b, d end
            end
        end
        return best
    end
    -- }}}

    -- {{{ g.gather
    -- Send a worker to gather: from a gold mine, or the tree nearest
    -- (x, y) (or its own spot). false and why when it can't
    function g.gather(u, target, x, y)
        if not economy.is_worker(u) then return false, "not a worker" end
        local h
        if target and economy.is_mine(g, target) then
            h = { kind = "gold", mine = target }
        else
            local tree = g.nearest_tree(x or u.x, y or u.y, 800)
            if not tree then return false, "no trees near" end
            h = { kind = "lumber", tree = tree }
        end
        h.carry = (u.harvest and u.harvest.kind == h.kind) and u.harvest.carry or 0
        h.phase = h.carry >= (h.kind == "gold" and economy.GOLD_TRIP or economy.LUMBER_TRIP) and "to_drop" or "to_source"
        u.harvest = h
        u.order = { kind = "gather" }
        u.target, u.swing = nil, nil
        economy.step_worker(g, u, 0, true)
        return true
    end
    -- }}}

    -- {{{ bounty and scores on death
    g.death_listeners = g.death_listeners or {}
    table.insert(g.death_listeners, function(u, killer)
        local building = u.spec.design == "building"
        g.score(u.player, building and "structures_lost" or (u.spec.hero and "heroes_lost" or "units_lost"))
        if not killer or killer.player == u.player or killer.player > 11 then return end
        g.score(killer.player, building and "structures_razed" or (u.spec.hero and "heroes_killed" or "units_killed"))
        local vs = g.state(u.player)
        if (tonumber(vs.bounty) or 0) ~= 0 and g.data then
            local base = g.data.units:value(u.id, "ubba")
            if base then
                local dice = g.data.units:value(u.id, "ubdi") or 0
                local sides = g.data.units:value(u.id, "ubsi") or 0
                local gold = base
                for _ = 1, dice do gold = gold + (sides > 0 and math.random(1, sides) or 0) end
                local ks = g.state(killer.player)
                ks.gold = (ks.gold or 0) + gold
                g.score(killer.player, "gold_bounty", gold)
                if g.on_bounty then g.on_bounty(killer, u, gold) end
            end
        end
    end)
    g.made_listeners = g.made_listeners or {}
    table.insert(g.made_listeners, function(u, how)
        if how == "trained" then
            g.score(u.player, u.spec.hero and "heroes_hired" or "units_trained")
        elseif how == "built" then
            g.score(u.player, "structures_built")
        end
    end)
    -- }}}
end
-- }}}

-- {{{ Workers
-- One worker's gathering, a step: walk, mine or chop, carry back
function economy.step_worker(g, u, dt, fresh)
    local h = u.harvest
    if not h or not u.alive or not u.order or u.order.kind ~= "gather" then
        u.harvest = nil
        return
    end
    local trip = h.kind == "gold" and economy.GOLD_TRIP or economy.LUMBER_TRIP
    if h.phase == "to_source" then
        local src = h.mine or h.tree
        if h.kind == "gold" and (not h.mine.alive or (h.mine.gold or economy.MINE_GOLD) <= 0) then
            u.harvest, u.order = nil, nil
            return
        end
        if h.kind == "lumber" and h.tree.lumber <= 0 then
            h.tree = g.nearest_tree(h.tree.x, h.tree.y, 800)
            if not h.tree then u.harvest, u.order = nil, nil return end
            src = h.tree
            fresh = true
        end
        -- a mine: from its footprint's edge (issue 541); a tree: its middle
        local near
        if h.kind == "gold" then
            near = require("demo.wc3map.footprint").gap(g, h.mine, u.x, u.y) <= economy.MINE_REACH
        else
            near = dist(u, src.x, src.y) <= economy.TREE_REACH
        end
        if near then
            u.route = nil
            if h.kind == "gold" then
                -- one worker in a mine at a time
                local m = h.mine
                if not m.miner or not m.miner.alive or m.miner.harvest == nil or m.miner.harvest.phase ~= "mining" then
                    m.miner = u
                    h.phase, h.left = "mining", economy.MINE_TIME
                    u.hidden_in_mine = true
                end
            else
                h.phase, h.left = "chopping", economy.CHOP_EVERY
            end
        elseif fresh or not u.route then
            g.walk_to(u, src.x, src.y)
        end
    elseif h.phase == "mining" then
        h.left = h.left - dt
        if h.left <= 0 then
            local m = h.mine
            local have = m.gold or economy.MINE_GOLD
            local take = math.min(trip, have)
            m.gold = have - take
            h.carry = take
            u.hidden_in_mine = nil
            m.miner = nil
            if m.gold <= 0 and g.kill then g.kill(m, nil) end
            h.phase = "to_drop"
            fresh = true
        end
    elseif h.phase == "chopping" then
        h.left = h.left - dt
        u.swing_chop = (u.swing_chop or 0) + dt
        if h.left <= 0 then
            h.left = economy.CHOP_EVERY
            local t = h.tree
            local take = math.min(economy.CHOP, t.lumber)
            t.lumber = t.lumber - take
            h.carry = h.carry + take
            if t.lumber <= 0 then
                t.fallen = true
                if t.doodad then t.doodad.fallen = true end
                if g.on_tree_fallen then g.on_tree_fallen(t) end
            end
            if h.carry >= trip then
                h.phase = "to_drop"
                fresh = true
            elseif t.lumber <= 0 then
                h.phase = "to_source"
                fresh = true
            end
        end
    end
    if h.phase == "to_drop" then
        local b = g.dropoff(u, h.kind)
        if not b then return end
        if require("demo.wc3map.footprint").gap(g, b, u.x, u.y) <= 60 then
            u.route = nil
            if h.carry > 0 then g.income(u.player, h.kind, h.carry) end
            h.carry = 0
            h.phase = "to_source"
            economy.step_worker(g, u, 0, true)
        elseif fresh or not u.route then
            g.walk_to(u, b.x, b.y)
        end
    end
end

function economy.update(g, dt)
    for _, u in ipairs(g.units) do
        if u.harvest then economy.step_worker(g, u, dt, false) end
    end
end
-- }}}

return economy
