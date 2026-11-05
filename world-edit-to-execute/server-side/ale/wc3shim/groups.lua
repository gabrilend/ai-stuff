--[[
wc3shim natives for unit groups (issue W02e, step 2)

Licence: GNU AGPL v3 (server-side/LICENSE).

Groups, ForGroup and GetEnumUnit, the enumerations (units in a rect, in
range, of a player, of a type) and Blizzard.j's group functions over
them, and group orders. Each does what the project's own runtime's native
of the same name does (src/jass/natives/world.lua, bj.lua).

Where the server forces a difference: the enumerations walk the units the
script knows (S.units: the ones it made or adopted), not every creature
on the server's map. W02b's spawns that main() never names, and
creatures the server spawns itself, aren't in them (W02e's open item 2).
Positions are read from the creatures as the enumeration tests them.

Installed by init.lua: require("wc3shim.groups")(S, N, shim).
]]

return function(S, N, shim)
    local id2s, s2id = shim.id2s, shim.s2id
    local function set(name, value) rawset(S.env, name, value) return value end
    local function get(name) return rawget(S.env, name) end
    local sync = S.sync

    -- {{{ Groups
    local function new_group() return S:handle({ kind = "group", list = {}, set = {} }) end
    local function add(g, u)
        if g and u and not g.set[u] then g.set[u] = true; g.list[#g.list + 1] = u end
    end
    -- removed units leave groups (as WC3's do, lazily)
    local function clean(g)
        local l = {}
        for _, u in ipairs(g.list) do
            if u.removed then g.set[u] = nil else l[#l + 1] = u end
        end
        g.list = l
        return l
    end
    S.group_units = clean
    N.CreateGroup = new_group
    N.DestroyGroup = function(g) if g then g.destroyed = true; g.list, g.set = {}, {} end end
    N.GroupAddUnit = add
    N.GroupRemoveUnit = function(g, u)
        if not g or not u or not g.set[u] then return end
        g.set[u] = nil
        for k, v in ipairs(g.list) do if v == u then table.remove(g.list, k) break end end
    end
    N.GroupAddUnitSimple = function(u, g) N.GroupAddUnit(g, u) end
    N.GroupRemoveUnitSimple = function(u, g) N.GroupRemoveUnit(g, u) end
    N.GroupClear = function(g) if g then g.list, g.set = {}, {} end end
    N.IsUnitInGroup = function(u, g) return g ~= nil and u ~= nil and g.set[u] == true end
    N.FirstOfGroup = function(g) return g and clean(g)[1] end
    N.ForGroup = function(g, fn)
        if not g or not fn then return end
        local copy = {}
        for k, u in ipairs(clean(g)) do copy[k] = u end
        for _, u in ipairs(copy) do S:with({ enum_unit = u }, fn) end
    end
    -- ForGroupBJ destroys the group after if bj_wantDestroyGroup was set
    N.ForGroupBJ = function(g, fn)
        local destroy = get("bj_wantDestroyGroup")
        set("bj_wantDestroyGroup", false)
        N.ForGroup(g, fn)
        if destroy then N.DestroyGroup(g) end
    end
    N.GetEnumUnit = function() local c = S.ctx return c and c.enum_unit end
    N.CountUnitsInGroup = function(g) return g and #clean(g) or 0 end
    N.GroupAddGroup = function(src, dst) if src and dst then for _, u in ipairs(clean(src)) do add(dst, u) end end end
    N.GroupRemoveGroup = function(src, dst)
        if src and dst then for _, u in ipairs(clean(src)) do N.GroupRemoveUnit(dst, u) end end
    end
    N.GroupPickRandomUnit = function(g)
        local l = g and clean(g) or {}
        return #l > 0 and l[math.random(#l)] or nil
    end
    N.GetRandomSubGroup = function(count, src)
        local pool = {}
        for k, u in ipairs(clean(src)) do pool[k] = u end
        local g = new_group()
        for _ = 1, math.min(count, #pool) do add(g, table.remove(pool, math.random(#pool))) end
        return g
    end
    N.IsUnitGroupEmptyBJ = function(g) return g == nil or #clean(g) == 0 end
    N.IsUnitGroupDeadBJ = function(g)
        for _, u in ipairs(clean(g)) do if S.alive(u) then return false end end
        return true
    end
    N.IsUnitGroupInRectBJ = function(g, r)
        for _, u in ipairs(clean(g)) do if not N.RectContainsUnit(r, u) then return false end end
        return true
    end
    N.GetLastCreatedGroup = function() return get("bj_lastCreatedGroup") end
    -- }}}

    -- {{{ Enumerations: the units the script knows, living and dead (not
    -- removed), tested with the filter as GetFilterUnit
    local function enum_into(g, filter, test)
        if not g then return end
        g.list, g.set = {}, {}
        local list = {}
        for k, u in ipairs(S.units) do list[k] = u end
        for _, u in ipairs(list) do
            if not u.removed and test(sync(u)) and S:test(filter, { filter_unit = u }) then add(g, u) end
        end
    end
    local function group_from(filter, test)
        local g = new_group()
        enum_into(g, filter, test)
        return g
    end
    local function in_rect(r) return function(u) return N.RectContainsCoords(r, u.x, u.y) end end
    local function in_range(x, y, d) return function(u) return (u.x - x) ^ 2 + (u.y - y) ^ 2 <= d * d end end
    local function of(p) return function(u) return p ~= nil and u.player == p.id end end
    N.GroupEnumUnitsInRect = function(g, r, filter) enum_into(g, filter, in_rect(r)) end
    N.GroupEnumUnitsInRange = function(g, x, y, d, filter) enum_into(g, filter, in_range(x, y, d)) end
    N.GroupEnumUnitsInRangeOfLoc = function(g, l, d, filter) enum_into(g, filter, in_range(l.x, l.y, d)) end
    N.GroupEnumUnitsOfPlayer = function(g, p, filter) enum_into(g, filter, of(p)) end
    -- by type name: as the VM's, UnitId2String gives the id itself back,
    -- so GroupEnumUnitsOfType(g, UnitId2String(id), f) finds the type
    N.UnitId2String = function(id) return id2s(id) end
    N.UnitId2StringBJ = N.UnitId2String
    N.UnitId = function(name) return #(name or "") == 4 and s2id(name) or 0 end
    N.GroupEnumUnitsOfType = function(g, name, filter)
        enum_into(g, filter, function(u) return u.id == name or u.name == name end)
    end
    N.GetUnitsInRectAll = function(r) return group_from(nil, in_rect(r)) end
    N.GetUnitsInRectMatching = function(r, filter) return group_from(filter, in_rect(r)) end
    N.GetUnitsInRectOfPlayer = function(r, p)
        local inside = in_rect(r)
        return group_from(nil, function(u) return p ~= nil and u.player == p.id and inside(u) end)
    end
    N.GetUnitsInRectOfPlayerBJ = N.GetUnitsInRectOfPlayer
    N.GetUnitsInRangeOfLocAll = function(d, l) return group_from(nil, in_range(l.x, l.y, d)) end
    N.GetUnitsInRangeOfLocMatching = function(d, l, filter) return group_from(filter, in_range(l.x, l.y, d)) end
    N.GetUnitsOfPlayerAll = function(p) return group_from(nil, of(p)) end
    N.GetUnitsOfPlayerMatching = function(p, filter) return group_from(filter, of(p)) end
    N.GetUnitsOfPlayerAndTypeId = function(p, id)
        local s = id2s(id)
        return group_from(nil, function(u) return p ~= nil and u.player == p.id and u.id == s end)
    end
    N.GetUnitsOfTypeIdAll = function(id)
        local s = id2s(id)
        return group_from(nil, function(u) return u.id == s end)
    end
    N.CountLivingPlayerUnitsOfTypeId = function(id, p)
        local s, n = id2s(id), 0
        for _, u in ipairs(S.units) do
            if p and u.player == p.id and u.id == s and S.alive(u) then n = n + 1 end
        end
        return n
    end
    -- the filters Blizzard.j's enumerations use, reading its bj_groupEnum* variables
    N.GetUnitsOfPlayerAndTypeIdFilter = function()
        local u = S.ctx and S.ctx.filter_unit
        return u ~= nil and s2id(u.id) == get("bj_groupEnumTypeId")
    end
    N.GetUnitsOfTypeIdAllFilter = N.GetUnitsOfPlayerAndTypeIdFilter
    N.GetUnitsInRectOfPlayerFilter = function()
        local u, p = S.ctx and S.ctx.filter_unit, get("bj_groupEnumOwningPlayer")
        return u ~= nil and p ~= nil and u.player == p.id
    end
    -- }}}

    -- {{{ Units made in a group (Blizzard.j)
    N.CreateNUnitsAtLoc = function(n, id, p, l, facing)
        local g = new_group()
        set("bj_lastCreatedGroup", g)
        for _ = 1, n do
            local u = N.CreateUnitAtLocSaveLast(p, id, l, facing)
            add(g, u)
        end
        return g
    end
    N.CreateNUnitsAtLocFacingLocBJ = function(n, id, p, l, look)
        return N.CreateNUnitsAtLoc(n, id, p, l, N.AngleBetweenPoints(l, look))
    end
    -- }}}

    -- {{{ Group orders
    local function each_order(g, fn)
        if not g then return false end
        local any = false
        for _, u in ipairs(clean(g)) do any = fn(u) or any end
        return any
    end
    N.GroupPointOrder = function(g, name, x, y) return each_order(g, function(u) return S.point_order(u, name, x, y) end) end
    N.GroupPointOrderById = N.GroupPointOrder
    N.GroupPointOrderLoc = function(g, name, l) return N.GroupPointOrder(g, name, l.x, l.y) end
    N.GroupPointOrderByIdLoc = N.GroupPointOrderLoc
    N.GroupPointOrderLocBJ = N.GroupPointOrderLoc
    N.GroupTargetOrder = function(g, name, t) return each_order(g, function(u) return S.target_order(u, name, t) end) end
    N.GroupTargetOrderById = N.GroupTargetOrder
    N.GroupTargetOrderBJ = N.GroupTargetOrder
    N.GroupImmediateOrder = function(g, name) return each_order(g, function(u) return S.immediate_order(u, name) end) end
    N.GroupImmediateOrderById = N.GroupImmediateOrder
    N.GroupImmediateOrderBJ = N.GroupImmediateOrder
    -- }}}
end
