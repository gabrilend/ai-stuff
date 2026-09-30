--[[
Construction (Issue 531)

Workers put up buildings, as in WC3:

  placing   a structure the worker can build (its ubui list) goes where
            it fits: its footprint on the map, on walkable, dry, level
            ground of one cliff level, clear of other buildings (the
            position snaps to the 64-unit grid). Requirements, limits and
            cost are checked as for training
  starting  the worker walks to the site; when it arrives the cost is
            paid and the structure appears at a tenth of its hit points
            (EVENT_PLAYER_UNIT_CONSTRUCT_START)
  building  it rises over its build time (ubld), hit points with it. How
            the worker takes part is its race's way:
              human      stays and works; the building waits while it's away
              orc        goes inside until it's done
              undead     starts it and is free (the building rises alone)
              night elf  a living building (an Ancient: classed "ancient",
                         or able to uproot) takes its wisp in for good; the
                         rest (moon wells, hunter's halls ...) the wisp only
                         starts, and grows alone
            (from the builder's race, urac; others build the human way)
  finished  CONSTRUCT_FINISH; its food made and training count from now
  cancel    the structure goes, the worker comes back, and 75% of the cost
            is refunded (CONSTRUCT_CANCEL)

Repair, helping and upgrades (issue 535):

  repair    a worker that repairs (the Ahrp / Arep / Aren abilities, else
            human and orc workers and wisps) mends its own or an ally's
            building or machine (classed "mechanical"): the whole of its
            hit points over RepairTimeRatio (1.5) times its build time, at
            RepairCostRatio (0.35) of its cost, paid as it goes; it stops
            when the purse is empty. Repairers stack
  helping   a human building going up takes more workers: its builder at
            the full rate, each helper at the repair rate, paid as repair
  upgrades  a building upgrades to a type in its uupt list (Town Hall to
            Keep to Castle, towers): the new type's cost and build time,
            its requirements; it can't train meanwhile; cancelling refunds
            everything. When done it becomes the new type (g.morph), its
            hit points in proportion (UPGRADE_START / _CANCEL / _FINISH)

Footprints are the buildings' pathing textures, cell by cell against the
map's pathing map (footprint.lua, issue 536).

    construction.init(game)           -- after production and heroes
    game.can_build(worker, id, x, y) -> true, or false and why
    game.build(worker, id, x, y)      -- the order
    game.cancel_build(building)
    game.can_repair(worker, target), game.repair(worker, target)
    game.upgrades(building), game.can_upgrade(b, id), game.upgrade(b, id), game.cancel_upgrade(b)
    construction.update(game, dt)
]]

local construction = {}

construction.GRID = 64
construction.START_HP = 0.1
construction.REFUND = 0.75
construction.REACH = 60
local fp = require("demo.wc3map.footprint")

-- {{{ helpers
-- half a building type's larger side (issue 536: from its footprint)
local function footprint(g, id)
    return fp.radius(g, id)
end
construction.footprint = footprint

-- a night elf Ancient: a living building, the wisp its spirit
-- (the stock Ancients by id, for when the tables don't say)
local UPROOT = { Aro1 = true, Aro2 = true }
local ANCIENTS = { etol = true, etoa = true, etoe = true, eaom = true, eaoe = true, eaow = true, etrp = true,
                   eden = true }
local function living(g, id)
    local D = g.data and g.data.units
    if D then
        local t = D:value(id, "utyp")
        if type(t) == "string" then return t:lower():find("ancient") ~= nil end
        for _, a in ipairs(D.list and D:list(id, "uabi") or {}) do if UPROOT[a] then return true end end
    end
    return ANCIENTS[id] == true
end
construction.living = living

-- a unit type's list: the map's (or the command card's stock lists), else
-- the stock tables
local function list(g, id, code)
    local l = g.db.unit_list(id, code)
    if #l > 0 then return l end
    local D = g.data and g.data.units
    return D and D.list and D:list(id, code) or {}
end

local REPAIRS = { Ahrp = true, Arep = true, Aren = true }

local function race_of(g, u)
    local r = g.data and g.data.units:value(u.id, "urac")
    if type(r) == "string" then return r:lower() end
    return "human"
end
-- }}}

-- {{{ construction.init
function construction.init(g)
    local C = g.constants

    -- a building type's centre lines its footprint up with the 32-unit
    -- cells (issue 536); without a type, the 64-unit grid
    function g.snap(x, y, id)
        if id then return fp.snap(fp.shape(g, id), x, y) end
        local s = construction.GRID
        return math.floor(x / s + 0.5) * s, math.floor(y / s + 0.5) * s
    end

    -- {{{ placement
    -- does a building of type id fit at (x, y): its footprint's cells on
    -- buildable ground of one level, clear of other buildings' (issue 536)
    function g.placeable(id, x, y, builder)
        local ok, why = fp.check(g, id, x, y)
        return ok, why
    end
    -- }}}

    -- {{{ g.can_build
    function g.can_build(w, id, x, y)
        if not w or w.alive == false or w.spec.design ~= "unit" then return false, "can't build" end
        local listed = false
        for _, b in ipairs(list(g, w.id, "ubui")) do if b == id then listed = true end end
        if not listed then return false, "can't build that" end
        local c = g.unit_cost(id)
        for _, r in ipairs(c.requires) do
            if not g.has_tech(w.player, r) then return false, "requires " .. r end
        end
        if g.tech_limit then
            local max = g.tech_limit(w.player, id)
            if max == 0 then return false, "not allowed" end
            if max and g.tech_count(w.player, id) >= max then return false, "limit reached" end
        end
        local s = g.state(w.player)
        if (s.gold or 0) < c.gold then return false, "not enough gold" end
        if (s.lumber or 0) < c.lumber then return false, "not enough lumber" end
        if x then
            local ok, why = g.placeable(id, x, y, w)
            if not ok then return false, why end
        end
        return true
    end
    -- }}}

    -- {{{ g.build
    function g.build(w, id, x, y)
        x, y = g.snap(x, y, id)
        local ok, why = g.can_build(w, id, x, y)
        if not ok then return false, why end
        g.order({ w }, "stop")
        w.construct = { id = id, x = x, y = y, phase = "to_site" }
        w.order = { kind = "build", x = x, y = y }
        construction.step_worker(g, w, 0, true)
        return true
    end

    function g.cancel_build(b)
        if not b or not b.building_up or b.alive == false then return false end
        local c = g.unit_cost(b.id)
        local s = g.state(b.player)
        s.gold = (s.gold or 0) + math.floor(c.gold * construction.REFUND)
        s.lumber = (s.lumber or 0) + math.floor(c.lumber * construction.REFUND)
        local w = b.builder
        if g.script then g.script:unit_event("CONSTRUCT_CANCEL", b) end
        g.remove(b)
        construction.release(g, b, w)
        g.buildings_changed = true
        return true
    end
    -- }}}

    -- {{{ repair, and helping a building up
    local function mechanical(u)
        local t = g.data and g.data.units:value(u.id, "utyp")
        return type(t) == "string" and t:lower():find("mechanical") ~= nil
    end

    function g.can_repair(w, t)
        if not w or w.alive == false or w.spec.design ~= "unit" then return false, "can't repair" end
        local able = false
        for id in pairs(REPAIRS) do
            if w.abilities and (w.abilities[id] or 0) > 0 then able = true end
        end
        if not able and w.spec.archetype == "worker" then
            local r = race_of(g, w)
            able = r == "human" or r == "orc" or r == "nightelf"
        end
        if not able then return false, "can't repair" end
        if not t or t.alive == false or t.removed then return false, "nothing to repair" end
        if t.player ~= w.player and not (g.allied and g.allied(t.player, w.player)) then
            return false, "not yours"
        end
        if t.building_up then
            if t.build_style ~= "human" or race_of(g, w) ~= "human" then return false, "can't help build that" end
            return true
        end
        if t.spec.design ~= "building" and not mechanical(t) then return false, "only buildings and machines" end
        if (t.hp or 0) >= (t.hp_max or 0) then return false, "not damaged" end
        return true
    end

    function g.repair(w, t)
        local ok, why = g.can_repair(w, t)
        if not ok then return false, why end
        g.order({ w }, "stop")
        w.repair = { target = t }
        w.order = { kind = "repair", target = t }
        g.walk_to(w, t.x, t.y)
        return true
    end
    -- }}}

    -- {{{ upgrades
    function g.upgrades(b) return list(g, b.id, "uupt") end

    function g.can_upgrade(b, id)
        if not b or b.alive == false or b.removed or b.spec.design ~= "building" then return false, "can't" end
        if b.building_up then return false, "under construction" end
        if b.upgrading then return false, "already upgrading" end
        local listed = false
        for _, u in ipairs(g.upgrades(b)) do if u == id then listed = true end end
        if not listed then return false, "doesn't upgrade to that" end
        if b.queue and #b.queue > 0 then return false, "busy training" end
        local c = g.unit_cost(id)
        for _, r in ipairs(c.requires) do
            if not g.has_tech(b.player, r) then return false, "requires " .. r end
        end
        if g.tech_limit then
            local max = g.tech_limit(b.player, id)
            if max == 0 then return false, "not allowed" end
            if max and g.tech_count(b.player, id) >= max then return false, "limit reached" end
        end
        local s = g.state(b.player)
        if (s.gold or 0) < c.gold then return false, "not enough gold" end
        if (s.lumber or 0) < c.lumber then return false, "not enough lumber" end
        return true
    end

    function g.upgrade(b, id)
        local ok, why = g.can_upgrade(b, id)
        if not ok then return false, why end
        local c = g.unit_cost(id)
        local s = g.state(b.player)
        s.gold, s.lumber = s.gold - c.gold, s.lumber - c.lumber
        local t = math.max(1, c.time or 60)
        b.upgrading = { to = id, left = t, time = t, gold = c.gold, lumber = c.lumber }
        if g.script then g.script:unit_event("UPGRADE_START", b) end
        return true
    end

    function g.cancel_upgrade(b)
        local up = b and b.upgrading
        if not up then return false end
        local s = g.state(b.player)
        s.gold, s.lumber = (s.gold or 0) + up.gold, (s.lumber or 0) + up.lumber
        b.upgrading = nil
        if g.script then g.script:unit_event("UPGRADE_CANCEL", b) end
        return true
    end
    -- }}}

    -- any other order ends a worker's part (a human's building waits)
    local order = g.order
    function g.order(units, kind, ...)
        if kind ~= "build" then
            for _, u in ipairs(units) do
                if u.construct and u.construct.phase ~= "inside" then
                    if u.construct.building then u.construct.building.builder = nil end
                    u.construct = nil
                end
            end
        end
        if kind ~= "repair" then
            for _, u in ipairs(units) do u.repair = nil end
        end
        return order(units, kind, ...)
    end

    -- a building going up, or upgrading, can't train
    local can_train = g.can_train
    function g.can_train(b, id)
        if b and b.building_up then return false, "under construction" end
        if b and b.upgrading then return false, "upgrading" end
        return can_train(b, id)
    end

    g.db.upgrades = function(b) return g.upgrades(b) end

    -- the natives ask what the structure being built is
    g.construction_events = true
end
-- }}}

-- {{{ Workers and structures, a step at a time
function construction.release(g, b, w)
    if not w then return end
    if w.construct and w.construct.phase == "inside" then
        w.hidden_in_building = nil
        w.hidden = w.hidden_before
        w.x, w.y = b.x, b.y - footprint(g, b.id) - 30
        if w.mover then w.mover.x, w.mover.y = w.x, w.y end
    end
    w.construct = nil
    if w.order and w.order.kind == "build" then w.order = nil end
end

function construction.start(g, w, c)
    local cost = g.unit_cost(c.id)
    local s = g.state(w.player)
    if (s.gold or 0) < cost.gold or (s.lumber or 0) < cost.lumber then
        w.construct, w.order = nil, nil
        return false
    end
    local ok = g.placeable(c.id, c.x, c.y, w)
    if not ok then w.construct, w.order = nil, nil return false end
    s.gold, s.lumber = s.gold - cost.gold, s.lumber - cost.lumber
    local b = g.spawn(c.id, w.player, c.x, c.y, math.rad(270))
    b.building_up = true
    b.progress = 0
    b.build_time = math.max(1, cost.time or 60)
    b.hp = (b.hp_max or 100) * construction.START_HP
    b.builder = w
    c.building = b
    local race = race_of(g, w)
    b.build_style = race
    g.buildings_changed = true
    if g.script then g.script:unit_event("CONSTRUCT_START", b) end
    if race == "orc" then
        c.phase = "inside"
        w.hidden_before, w.hidden = w.hidden, true
        w.hidden_in_building = b
        w.route = nil
    elseif race == "undead" or (race == "nightelf" and not living(g, c.id)) then
        b.builder = nil
        w.construct, w.order = nil, nil
    elseif race == "nightelf" then
        b.builder = nil
        g.remove(w)
    else
        c.phase = "working"
        w.route = nil
    end
    return true
end

function construction.step_worker(g, w, dt, fresh)
    local c = w.construct
    if not c then return end
    if w.alive == false then
        if c.building then c.building.builder = nil end
        w.construct = nil
        return
    end
    if c.phase == "to_site" then
        local reach = footprint(g, c.id) + construction.REACH
        if (w.x - c.x) ^ 2 + (w.y - c.y) ^ 2 <= reach * reach then
            construction.start(g, w, c)
        elseif fresh or not w.route then
            g.walk_to(w, c.x, c.y)
        end
    end
end

-- {{{ repairers, a step at a time
-- pay for a share of a unit's worth (fractions carried over); false when
-- the purse can't
local function charge(g, player, id, share)
    local c = g.unit_cost(id)
    local ratio = g.constants:get("RepairCostRatio") or 0.35
    local s = g.state(player)
    s.repair_owed = s.repair_owed or { gold = 0, lumber = 0 }
    local o = s.repair_owed
    local gold, lumber = o.gold + c.gold * ratio * share, o.lumber + c.lumber * ratio * share
    local pay_g, pay_l = math.floor(gold), math.floor(lumber)
    if (s.gold or 0) < pay_g or (s.lumber or 0) < pay_l then return false end
    s.gold, s.lumber = s.gold - pay_g, s.lumber - pay_l
    o.gold, o.lumber = gold - pay_g, lumber - pay_l
    return true
end

function construction.step_repair(g, w, dt)
    local r = w.repair
    local t = r.target
    local function done()
        w.repair = nil
        if w.order and w.order.kind == "repair" then w.order = nil end
    end
    if w.alive == false or not t or t.alive == false or t.removed then return done() end
    local reach = (t.spec.design == "building" and footprint(g, t.id) or 40) + construction.REACH
    if (w.x - t.x) ^ 2 + (w.y - t.y) ^ 2 > reach * reach then
        if not w.route then g.walk_to(w, t.x, t.y) end
        return
    end
    w.route = nil
    if w.mover then w.mover.dest = nil end
    local time_ratio = g.constants:get("RepairTimeRatio") or 1.5
    if t.building_up then
        -- helping it up: counted by the building's step
        t.helpers = (t.helpers or 0) + 1
        return
    end
    if (t.hp or 0) >= (t.hp_max or 0) then return done() end
    local c = g.unit_cost(t.id)
    local share = dt / (math.max(1, c.time or 60) * time_ratio)
    share = math.min(share, (t.hp_max - t.hp) / t.hp_max)
    if not charge(g, w.player, t.id, share) then return done() end
    t.hp = math.min(t.hp_max, t.hp + t.hp_max * share)
    r.working = true
end
-- }}}

function construction.update(g, dt)
    for _, u in ipairs(g.units) do
        if u.building_up then u.helpers = 0 end
    end
    for _, u in ipairs(g.units) do
        if u.repair then construction.step_repair(g, u, dt) end
    end
    local time_ratio = g.constants:get("RepairTimeRatio") or 1.5
    for _, u in ipairs(g.units) do
        -- an upgrade under way
        local up = u.upgrading
        if up and (u.alive == false or u.removed) then
            u.upgrading = nil
        elseif up then
            up.left = up.left - dt
            if up.left <= 0 then
                u.upgrading = nil
                g.morph(u, up.to)
                if g.made then g.made(u, "upgraded") end
                if g.script then g.script:unit_event("UPGRADE_FINISH", u) end
            end
        end
        if u.construct then construction.step_worker(g, u, dt, false) end
        if u.building_up and u.alive ~= false and not u.removed then
            -- a human building rises only while its worker (or a helper) is at it
            local builder = u.builder and u.builder.alive ~= false
                and u.builder.construct and u.builder.construct.building == u
            local working = u.build_style ~= "human" or builder or (u.helpers or 0) > 0
            if u.build_style == nil then working = true end
            if working then
                local share = (u.build_style ~= "human" or builder) and dt / u.build_time or 0
                -- helpers: each at the repair rate, paid as repair
                for _ = 1, u.helpers or 0 do
                    local extra = dt / (u.build_time * time_ratio)
                    if charge(g, u.player, u.id, extra) then share = share + extra end
                end
                u.progress = math.min(1, u.progress + share)
                u.hp = math.min(u.hp_max or u.hp, u.hp + (u.hp_max or 0) * (1 - construction.START_HP) * share)
                if u.progress >= 1 then
                    u.building_up = nil
                    u.progress = nil
                    g.buildings_changed = true
                    local w = u.builder
                    u.builder = nil
                    construction.release(g, u, w)
                    if g.made then g.made(u, "built") end
                    if g.script then g.script:unit_event("CONSTRUCT_FINISH", u, { constructed = u }) end
                end
            end
        end
    end
end
-- }}}

return construction
