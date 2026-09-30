--[[
Taverns and Shops (Issue 533)

Buildings that sell, as in WC3:

  what      a building sells the units in its useu list (a tavern's
            heroes, mercenary camps' units) and the items in its usei
            list (shops), plus what the script adds (AddUnitToStock,
            AddItemToStock ...)
  stock     each type has a count, a maximum, and a replenish interval:
            one comes back each interval up to the maximum; a type first
            becomes available after its start delay. From the sold
            type's data: units usma / usrg / usst, items isto / istr /
            isst (stand-ins 1, 30 s, 0 s)
  buying    a player buys with a unit of its own near the shop (within
            SHOP_RANGE: the "select unit / hero" range): units appear
            beside the shop as the buyer's (food, hero limits and hero
            tokens counting as for training); items go into the buyer's
            inventory (to the ground beside it when full). Neutral shops
            sell to anyone; a player's own shops to it and its allies.
            EVENT_PLAYER_UNIT_SELL / SELL_ITEM fire for the shop's owner
            (GetSoldUnit, GetSoldItem, GetBuyingUnit)
  pawning   a unit near a shop that sells items can sell a pawnable item
            back for PawnItemRate (the gameplay constant, 0.5) of its
            cost (EVENT_PLAYER_UNIT_PAWN_ITEM)

    shops.init(game)            -- after items and heroes
    game.stock(shop)            -- { {id, kind = "unit"|"item", count, max, ...}, ... }
    game.buy(shop, player, id)  -- true, or false and why
    game.pawn(unit, item, shop)
    shops.update(game, dt)
]]

local shops = {}

shops.RANGE = 600
shops.STOCK_MAX, shops.REPLENISH, shops.START = 1, 30, 0

-- {{{ shops.init
function shops.init(g)
    local C = g.constants

    local function num(v, def) return tonumber(v) or def end

    -- {{{ stock
    local function entry(kind, id, count, max)
        local e = { id = id, kind = kind }
        if kind == "unit" then
            local D = g.data.units
            e.max = num((D:value(id, "usma")), shops.STOCK_MAX)
            e.replenish = num((D:value(id, "usrg")), shops.REPLENISH)
            e.start = num((D:value(id, "usst")), shops.START)
        else
            local t = g.item_type(id)
            e.max, e.replenish, e.start = t.stock_max or shops.STOCK_MAX, t.stock_replenish or shops.REPLENISH,
                t.stock_start or shops.START
        end
        if max then e.max = max end
        e.count = count or (e.start > 0 and 0 or e.max)
        e.next = g.time + (e.start > 0 and e.start or e.replenish)
        return e
    end

    function g.stock(shop)
        if shop.shop_stock then return shop.shop_stock end
        local list = {}
        if shop.spec.design == "building" or shop.player >= 12 then
            for _, id in ipairs(g.db.unit_list(shop.id, "useu")) do list[#list + 1] = entry("unit", id) end
            for _, id in ipairs(g.db.unit_list(shop.id, "usei")) do list[#list + 1] = entry("item", id) end
        end
        shop.shop_stock = list
        return list
    end

    function g.is_shop(u)
        return u and u.alive ~= false and #g.stock(u) > 0
    end

    -- the script's stock changes
    function g.add_stock(shop, kind, id, count, max)
        local list = g.stock(shop)
        for _, e in ipairs(list) do
            if e.id == id then
                e.count, e.max = count or e.count, max or e.max
                return e
            end
        end
        local e = entry(kind, id, count, max)
        list[#list + 1] = e
        return e
    end
    function g.remove_stock(shop, id)
        local list = g.stock(shop)
        for i, e in ipairs(list) do
            if e.id == id then table.remove(list, i) return true end
        end
        return false
    end
    -- }}}

    -- {{{ who may buy, and with which unit
    function g.sells_to(shop, player)
        if shop.player >= 12 then return true end
        return shop.player == player or (g.allied and g.allied(shop.player, player)) or false
    end

    -- the player's unit nearest the shop within range (with an inventory
    -- when buying items)
    function g.buyer_for(shop, player, needs_inventory)
        local best, bd = nil, shops.RANGE ^ 2
        for _, u in ipairs(g.units) do
            if u.player == player and u.alive and not u.removed and u ~= shop and u.spec.design == "unit"
                and (not needs_inventory or (g.inventory_size and g.inventory_size(u) > 0)) then
                local d = (u.x - shop.x) ^ 2 + (u.y - shop.y) ^ 2
                if d <= bd then best, bd = u, d end
            end
        end
        return best
    end
    -- }}}

    -- {{{ g.buy
    function g.buy(shop, player, id)
        if not g.is_shop(shop) then return false, "not a shop" end
        if not g.sells_to(shop, player) then return false, "won't sell to you" end
        local e
        for _, x in ipairs(g.stock(shop)) do if x.id == id then e = x end end
        if not e then return false, "not sold here" end
        if e.count <= 0 then return false, "out of stock" end
        local buyer = g.buyer_for(shop, player, e.kind == "item")
        if not buyer then
            return false, e.kind == "item" and "no hero near the shop" or "no unit of yours near the shop"
        end
        local s = g.state(player)
        local gold, lumber
        if e.kind == "unit" then
            local c = g.unit_cost(id)
            gold, lumber = c.gold, c.lumber
            local hero = id:sub(1, 1):match("%u") ~= nil
            if hero and g.tech_limit then
                local hmax = g.tech_limit(player, "HERO")
                if hmax and g.tech_count(player, "HERO") >= hmax then return false, "hero limit reached" end
                local tmax = g.tech_limit(player, id)
                if tmax and g.tech_count(player, id) >= tmax then return false, "limit reached" end
            end
            -- a hero token hires a hero for nothing
            if hero and (tonumber(s.hero_tokens) or 0) > 0 then gold, lumber = 0, 0 end
            local used, cap = g.food(player)
            if c.food > 0 and used + c.food > cap then return false, "not enough food" end
        else
            local t = g.item_type(id)
            gold, lumber = t.gold, t.lumber
        end
        if (s.gold or 0) < gold then return false, "not enough gold" end
        if (s.lumber or 0) < lumber then return false, "not enough lumber" end
        s.gold, s.lumber = s.gold - gold, s.lumber - lumber
        e.count = e.count - 1
        if e.count < e.max and e.next <= g.time then e.next = g.time + e.replenish end
        local s2id = require("jass.vm").s2id
        if e.kind == "unit" then
            if gold == 0 and id:sub(1, 1):match("%u") and (tonumber(s.hero_tokens) or 0) > 0 then
                s.hero_tokens = s.hero_tokens - 1
            end
            local a = math.atan2(buyer.y - shop.y, buyer.x - shop.x)
            local u = g.spawn(id, player, shop.x + math.cos(a) * 220, shop.y + math.sin(a) * 220, a)
            if g.made then g.made(u, "trained") end
            if g.script then g.script:unit_event("SELL", shop, { sold = u, buyer = buyer }) end
            return true, u
        end
        local it = g.create_item(id, buyer.x, buyer.y)
        if not g.give_item(buyer, it) then
            it.x, it.y = buyer.x + 60, buyer.y
        end
        if g.script then g.script:unit_event("SELL_ITEM", shop, { item = it, buyer = buyer }) end
        return true, it
    end
    -- }}}

    -- {{{ g.pawn
    function g.pawn(u, it, shop)
        if not it or it.owner ~= u then return false, "not carried" end
        if it.pawnable == false then return false, "can't be sold" end
        if not shop then
            -- the nearest item shop in range
            local bd = shops.RANGE ^ 2
            for _, b in ipairs(g.units) do
                if b.alive ~= false and b.shop_stock ~= false and g.sells_to(b, u.player) then
                    local d = (b.x - u.x) ^ 2 + (b.y - u.y) ^ 2
                    if d <= bd then
                        for _, e in ipairs(g.stock(b)) do if e.kind == "item" then shop, bd = b, d break end end
                    end
                end
            end
        end
        if not shop then return false, "no shop near" end
        local rate = C:get("PawnItemRate") or 0.5
        local t = it.type
        local charge_share = (t.charges > 0) and (it.charges / t.charges) or 1
        local gold = math.floor(t.gold * rate * charge_share)
        local lumber = math.floor(t.lumber * rate * charge_share)
        g.take_item(u, it, true)
        it.removed = true
        local s = g.state(u.player)
        s.gold, s.lumber = (s.gold or 0) + gold, (s.lumber or 0) + lumber
        if g.script then g.script:unit_event("PAWN_ITEM", u, { item = it, buyer = shop }) end
        return true, gold
    end
    -- }}}

    -- the command card asks
    g.db.shop_stock = function(u) return g.is_shop(u) and g.stock(u) or {} end
    g.db.item_button = function(id)
        local t = g.item_type(id)
        local D = g.data.items
        return { name = t.name, hotkey = (D:value(id, "uhot")), x = tonumber((D:value(id, "ubpx"))),
                 y = tonumber((D:value(id, "ubpy"))), tip = (D:value(id, "utub")) }
    end
end
-- }}}

-- {{{ shops.update
-- stock comes back, one per interval, up to its maximum
function shops.update(g, dt)
    g.shop_clock = (g.shop_clock or 0) + dt
    if g.shop_clock < 0.5 then return end
    g.shop_clock = 0
    for _, u in ipairs(g.units) do
        local list = u.shop_stock
        if list and u.alive ~= false then
            for _, e in ipairs(list) do
                if e.count < e.max and g.time >= e.next then
                    e.count = e.count + 1
                    e.next = g.time + e.replenish
                end
            end
        end
    end
end
-- }}}

return shops
