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

Footprints are STAND-INS by building size (the pathing textures, upat,
aren't read yet).

    construction.init(game)           -- after production and heroes
    game.can_build(worker, id, x, y) -> true, or false and why
    game.build(worker, id, x, y)      -- the order
    game.cancel_build(building)
    construction.update(game, dt)
]]

local construction = {}

construction.GRID = 64
construction.START_HP = 0.1
construction.REFUND = 0.75
construction.REACH = 60
-- footprint radius by building size (stand-ins)
construction.FOOTPRINT = { small = 96, medium = 128, hall = 192, tower = 64, altar = 128, special = 128 }

-- {{{ helpers
local function footprint(spec)
    return construction.FOOTPRINT[spec and spec.size or "medium"] or 128
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

local function race_of(g, u)
    local r = g.data and g.data.units:value(u.id, "urac")
    if type(r) == "string" then return r:lower() end
    return "human"
end
-- }}}

-- {{{ construction.init
function construction.init(g)
    local C = g.constants

    function g.snap(x, y)
        local s = construction.GRID
        return math.floor(x / s + 0.5) * s, math.floor(y / s + 0.5) * s
    end

    -- {{{ placement
    -- does a building of type id fit at (x, y)
    function g.placeable(id, x, y, builder)
        local spec = g.unit_spec(id)
        local r = footprint(spec)
        local b = g.bounds
        if x - r < b.x0 or y - r < b.y0 or x + r > b.x1 or y + r > b.y1 then return false, "off the map" end
        -- the ground: walkable, dry, one cliff level, not too steep
        local t = g.scene.terrain
        local lo, hi, level
        local step = 64
        for dy = -r, r, step do
            for dx = -r, r, step do
                local px, py = x + dx, y + dy
                if g.pathing then
                    local i, j = g.pathing:cell(px, py)
                    if not g.pathing:walkable(i, j) then return false, "can't build there" end
                end
                local z = g.scene.sample.ground_at(px, py)
                if g.scene.sample.water_at(px, py) > z + 1 then return false, "can't build on water" end
                lo, hi = math.min(lo or z, z), math.max(hi or z, z)
                local ti = math.floor((px - t.offset_x) / 128 + 0.5)
                local tj = math.floor((py - t.offset_y) / 128 + 0.5)
                local tp = t:get_tile(ti, tj)
                if tp then
                    if level and tp.layer_height ~= level then return false, "not level ground" end
                    level = tp.layer_height
                end
            end
        end
        if hi - lo > 96 then return false, "not level ground" end
        -- clear of other buildings (units step aside)
        for _, u in ipairs(g.units) do
            if u.spec.design == "building" and u.alive ~= false and not u.removed then
                local rr = footprint(u.spec) + r
                if (u.x - x) ^ 2 + (u.y - y) ^ 2 < (rr * 0.9) ^ 2 then return false, "something's in the way" end
            end
        end
        return true
    end
    -- }}}

    -- {{{ g.can_build
    function g.can_build(w, id, x, y)
        if not w or w.alive == false or w.spec.design ~= "unit" then return false, "can't build" end
        local listed = false
        for _, b in ipairs(g.db.unit_list(w.id, "ubui")) do if b == id then listed = true end end
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
        x, y = g.snap(x, y)
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

    -- any other order ends a worker's part (a human's building waits)
    local order = g.order
    function g.order(list, kind, ...)
        if kind ~= "build" then
            for _, u in ipairs(list) do
                if u.construct and u.construct.phase ~= "inside" then
                    if u.construct.building then u.construct.building.builder = nil end
                    u.construct = nil
                end
            end
        end
        return order(list, kind, ...)
    end

    -- a building going up can't train
    local can_train = g.can_train
    function g.can_train(b, id)
        if b and b.building_up then return false, "under construction" end
        return can_train(b, id)
    end

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
        w.x, w.y = b.x, b.y - footprint(b.spec) - 30
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
        local spec = g.unit_spec(c.id)
        local reach = footprint(spec) + construction.REACH
        if (w.x - c.x) ^ 2 + (w.y - c.y) ^ 2 <= reach * reach then
            construction.start(g, w, c)
        elseif fresh or not w.route then
            g.walk_to(w, c.x, c.y)
        end
    end
end

function construction.update(g, dt)
    for _, u in ipairs(g.units) do
        if u.construct then construction.step_worker(g, u, dt, false) end
        if u.building_up and u.alive ~= false and not u.removed then
            -- a human building rises only while its worker is at it
            local working = u.build_style ~= "human" or (u.builder and u.builder.alive ~= false
                and u.builder.construct and u.builder.construct.building == u)
            if u.build_style == nil then working = true end
            if working then
                local share = dt / u.build_time
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
