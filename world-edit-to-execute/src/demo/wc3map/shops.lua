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

Which unit buys (issue 539), as the shop's Select Hero / Select Unit:
each player may have a chosen buyer at a shop (its patron): the unit the
player picked there (the shop's buyer button cycles through its units in
range; a unit selected just before the shop is picked; a unit sent to
the shop with a right click is picked when it arrives). The patron buys
while it's alive, in range and able (an inventory for items); otherwise
the player's nearest unit in range does.

    game.shop_candidates(shop, player, needs_inventory)   -- nearest first
    game.set_patron(shop, unit), game.patron(shop, player), game.next_patron(shop, player)
    game.visit_shop(unit, shop)     -- walk there; the patron on arrival
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

    -- the player's units in range of the shop, nearest first (with an
    -- inventory when buying items)
    local function able(shop, u, player, needs_inventory)
        return u and u.player == player and u.alive and not u.removed and u ~= shop and u.spec.design == "unit"
            and not u.hidden and (not needs_inventory or (g.inventory_size and g.inventory_size(u) > 0))
            and (u.x - shop.x) ^ 2 + (u.y - shop.y) ^ 2 <= shops.RANGE ^ 2
    end
    function g.shop_candidates(shop, player, needs_inventory)
        local list = {}
        for _, u in ipairs(g.units) do
            if able(shop, u, player, needs_inventory) then list[#list + 1] = u end
        end
        table.sort(list, function(a, b)
            return (a.x - shop.x) ^ 2 + (a.y - shop.y) ^ 2 < (b.x - shop.x) ^ 2 + (b.y - shop.y) ^ 2
        end)
        return list
    end

    -- the chosen buyer (issue 539)
    function g.set_patron(shop, u)
        if not u or not able(shop, u, u.player, false) then return false, "not in range of the shop" end
        shop.patrons = shop.patrons or {}
        shop.patrons[u.player] = u
        return true
    end
    function g.patron(shop, player, needs_inventory)
        local p = shop.patrons and shop.patrons[player]
        if able(shop, p, player, needs_inventory) then return p end
        return nil
    end
    -- the next of the player's units in range (heroes and carriers first
    -- when the shop sells items)
    function g.next_patron(shop, player)
        local items = false
        for _, e in ipairs(g.stock(shop)) do if e.kind == "item" then items = true end end
        local list = g.shop_candidates(shop, player, items)
        if #list == 0 then return nil end
        local cur = g.buyer_for(shop, player, items)
        local at = 0
        for i, u in ipairs(list) do if u == cur then at = i end end
        local nxt = list[at % #list + 1]
        g.set_patron(shop, nxt)
        return nxt
    end
    -- walk to the shop; the patron when it arrives
    function g.visit_shop(u, shop)
        if not u or u.spec.design ~= "unit" or not g.is_shop(shop) or not g.sells_to(shop, u.player) then
            return false
        end
        g.order({ u }, "move", shop.x, shop.y)
        u.visiting = shop
        return true
    end

    -- who buys: the patron, else the nearest able unit in range
    function g.buyer_for(shop, player, needs_inventory)
        return g.patron(shop, player, needs_inventory) or g.shop_candidates(shop, player, needs_inventory)[1]
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
    -- the local player's buyer at a shop, for the card (issue 539)
    g.db.shop_buyer = function(shop)
        local items = false
        for _, e in ipairs(g.stock(shop)) do if e.kind == "item" then items = true end end
        return g.buyer_for(shop, g.player, items), items
    end

    -- a unit sent to a shop stops being on its way when told otherwise
    local order = g.order
    function g.order(list, kind, ...)
        for _, u in ipairs(list) do u.visiting = nil end
        return order(list, kind, ...)
    end
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
    -- units sent to a shop: its patron when in range (issue 539)
    for _, u in ipairs(g.units) do
        local shop = u.visiting
        if shop then
            if u.alive == false or shop.alive == false or shop.removed then
                u.visiting = nil
            elseif (u.x - shop.x) ^ 2 + (u.y - shop.y) ^ 2 <= (shops.RANGE * 0.8) ^ 2 then
                u.visiting = nil
                g.set_patron(shop, u)
                g.order({ u }, "stop")
            end
        end
    end
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
