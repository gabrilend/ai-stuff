--[[
Items and Inventories (Issue 532)

Items as WC3 keeps them:

  types      from the item tables (the map's changes over ItemData.slk and
             the item profiles, g.data.items): name, class, level,
             charges (iuse), usable (iusa), perishable (iper), powerup
             (ipow: used at once when picked up: tomes, runes), droppable
             (idro), pawnable (ipaw), cost (igol, ilum), model (ifil),
             stock (isto, istr, isst: shops, issue 533), and abilities
             (iabi)
  on the map items lie on the ground (g.items), or are carried
  carried    in a unit's inventory: heroes carry six (the inventory
             ability, AInv); other units none unless they have it.
             What an item's abilities give applies while it's carried:
             attributes, damage, armour, hit points, mana, regeneration,
             move and attack speed (their data fields: Istr, Iagi, Iint,
             Iatt, Idef, Ilif, Iman, Ihpr, Imrp, Imvb, Isx1)
  powerups   used when picked up; their attribute data (Istr, Iagi, Iint)
             is a hero's for good, Ixpg experience (tomes)
  orders     pick up (walk to it), drop, give, use. Using an item fires
             USE_ITEM and casts its first ability through the ability
             system (issue 529) if that's a spell the game knows, else
             applies an instant restore when its data has one (Ihpg hit
             points, Impg mana); a charge is spent, and a perishable item
             with none left is gone
  events     PICKUP_ITEM, DROP_ITEM, USE_ITEM for the script
             (GetManipulatingUnit, GetManipulatedItem)

The item ability field codes are FROM MEMORY; an item whose data gives
none of them gives nothing (the rest of the item still works).

    items.init(game)
    local it = game.create_item("ratf", x, y)
    game.give_item(hero, it), game.drop_item(hero, it, x, y), game.use_item(hero, it, target, x, y)
    game.pick_up(hero, it)      -- walks there first
    items.update(game, dt)
]]

local buffs = require("demo.wc3map.buffs")

local items = {}

items.REACH = 150
items.DEFAULT_MODEL = "Objects\\InventoryItems\\TreasureChest\\treasurechest.mdl"
-- what item abilities' data fields give (code -> stat)
items.BONUS = { Istr = "str", Iagi = "agi", Iint = "int", Iatt = "damage", Idef = "armor", Ilif = "hp",
                Iman = "mana", Ihpr = "hp_regen", Imrp = "mana_regen", Imvb = "move", Isx1 = "attack" }

-- {{{ items.init
function items.init(g)
    g.items = {}
    local types = {}

    local function num(v, def) return tonumber(v) or def end
    local function flag(v, def)
        if v == nil then return def end
        return v == 1 or v == true or v == "1"
    end

    -- {{{ item types
    function g.item_type(id)
        local t = types[id]
        if t then return t end
        local D = g.data.items
        local function v(code) return (D:value(id, code)) end
        t = {
            id = id, name = v("unam") or (D.profile_field and D:profile_field(id, "Name")) or id,
            class = v("icla") or "Permanent", level = num(v("ilev"), 1),
            charges = num(v("iuse"), 0), usable = flag(v("iusa"), false), perishable = flag(v("iper"), false),
            powerup = flag(v("ipow"), false), droppable = flag(v("idro"), true), pawnable = flag(v("ipaw"), true),
            gold = num(v("igol"), 0), lumber = num(v("ilum"), 0),
            model = v("ifil") or (D.profile_field and D:profile_field(id, "file")) or items.DEFAULT_MODEL,
            stock_max = num(v("isto"), 1), stock_replenish = num(v("istr"), 30), stock_start = num(v("isst"), 0),
            abilities = D.list and D:list(id, "iabi") or {},
        }
        types[id] = t
        return t
    end
    -- }}}

    -- {{{ making and unmaking
    function g.create_item(id, x, y)
        local t = g.item_type(id)
        local it = { id = id, x = x or 0, y = y or 0, charges = t.charges, type = t,
                     droppable = t.droppable, pawnable = t.pawnable }
        it.z = g.ground_at and g.ground_at(it.x, it.y) or 0
        g.items[#g.items + 1] = it
        return it
    end

    function g.remove_item(it)
        if not it or it.removed then return end
        if it.owner then g.take_item(it.owner, it, true) end
        it.removed = true
    end

    function g.inventory_size(u)
        if not u or u.spec.design ~= "unit" then return 0 end
        local lvl = u.abilities and u.abilities.AInv
        if lvl and lvl > 0 then
            local n = tonumber((g.data.abilities:value("AInv", "inv1", lvl)))
            return n and math.max(0, math.min(6, n)) or 6
        end
        return u.spec.hero and 6 or 0
    end

    function g.item_at(x, y, r)
        local best, bd = nil, (r or items.REACH) ^ 2
        for _, it in ipairs(g.items) do
            if not it.owner and not it.removed and not it.hidden then
                local d = (it.x - x) ^ 2 + (it.y - y) ^ 2
                if d < bd then best, bd = it, d end
            end
        end
        return best
    end
    -- }}}

    local function event(what, u, it)
        if g.script then g.script:unit_event(what, u, { item = it }) end
    end

    -- {{{ carried items' bonuses
    function g.refresh_items(u)
        local st = { str = 0, agi = 0, int = 0, damage = 0, armor = 0, hp = 0, mana = 0, hp_regen = 0,
                     mana_regen = 0, move = 0, attack = 0 }
        local abilities = {}
        for k = 0, 5 do
            local it = u.inventory and u.inventory[k]
            if it then
                for _, a in ipairs(it.type.abilities) do
                    abilities[a] = 1
                    for code, stat in pairs(items.BONUS) do
                        local v = tonumber((g.data.abilities:value(a, code, 1)))
                        if v then st[stat] = st[stat] + v end
                    end
                end
            end
        end
        -- hit points and mana given or taken back as items come and go
        local was = u.item_stats or { hp = 0, mana = 0 }
        u.item_stats = st
        u.item_abilities = abilities
        if u.hero and g.refresh_hero then
            g.refresh_hero(u)
        else
            if u.hp_max then
                u.hp_max = u.hp_max + st.hp - was.hp
                u.hp = math.min(u.hp_max, (u.hp or 0) + math.max(0, st.hp - was.hp))
            end
            if u.mana_max then u.mana_max = u.mana_max + st.mana - was.mana end
        end
        buffs.sum(u)
    end
    -- }}}

    -- {{{ giving and taking
    function g.give_item(u, it, slot, quiet)
        if not u or not it or it.removed or u.alive == false then return false, "can't" end
        if it.owner == u then return true end
        local size = g.inventory_size(u)
        if size == 0 then return false, "no inventory" end
        -- powerups are used at once (tomes, runes)
        if it.type.powerup then
            if it.owner then g.take_item(it.owner, it, true) end
            it.owner = u
            if not quiet then event("PICKUP_ITEM", u, it) end
            g.use_item(u, it)
            it.owner = nil
            it.removed = true
            return true
        end
        u.inventory = u.inventory or {}
        if slot == nil then
            for k = 0, size - 1 do
                if not u.inventory[k] then slot = k break end
            end
        end
        if slot == nil or slot >= size or u.inventory[slot] then return false, "inventory is full" end
        if it.owner then g.take_item(it.owner, it, true) end
        u.inventory[slot] = it
        it.owner, it.slot = u, slot
        g.refresh_items(u)
        if not quiet then event("PICKUP_ITEM", u, it) end
        return true
    end

    -- off a unit (to nowhere: the caller places it)
    function g.take_item(u, it, quiet)
        if not u or not u.inventory or not it or it.owner ~= u then return false end
        u.inventory[it.slot] = nil
        it.owner, it.slot = nil, nil
        g.refresh_items(u)
        if not quiet then event("DROP_ITEM", u, it) end
        return true
    end

    function g.drop_item(u, it, x, y)
        if not it or it.owner ~= u then return false, "not carried" end
        if it.droppable == false then return false, "can't drop that" end
        g.take_item(u, it)
        it.x, it.y = x or u.x, y or u.y
        it.z = g.ground_at and g.ground_at(it.x, it.y) or 0
        return true
    end

    function g.pick_up(u, it)
        if not it or it.owner or it.removed then return false, "nothing to pick up" end
        if g.inventory_size(u) == 0 then return false, "no inventory" end
        g.order({ u }, "stop")
        u.fetch = it
        u.order = { kind = "pickup" }
        g.walk_to(u, it.x, it.y)
        return true
    end
    -- }}}

    -- {{{ using
    function g.use_item(u, it, target, x, y)
        if not it or it.owner ~= u then return false, "not carried" end
        local t = it.type
        if not t.usable and not t.powerup then return false, "not usable" end
        if it.charges <= 0 and t.charges > 0 then return false, "no charges left" end
        local abil = t.abilities[1]
        -- a spell the game knows: cast through the ability system
        if abil and g.ability_spec then
            local b, kind = g.ability_spec(abil, 1)
            if b and (b.effect or b.tick) then
                u.item_abilities = u.item_abilities or {}
                u.item_abilities[abil] = 1
                local ok, why = g.cast(u, abil, target, x, y)
                if not ok then return false, why end
            elseif abil then
                -- else an instant restore from its data
                local A = g.data.abilities
                local ready_at = u.cooldowns and u.cooldowns[abil]
                if ready_at and ready_at > g.time then return false, "not ready yet" end
                local hp = tonumber((A:value(abil, "Ihpg", 1)))
                local mana = tonumber((A:value(abil, "Impg", 1)))
                -- a powerup's attributes are for good (tomes)
                if t.powerup and u.hero then
                    for code, k in pairs({ Istr = "str", Iagi = "agi", Iint = "int" }) do
                        local v = tonumber((A:value(abil, code, 1)))
                        if v then u.hero[k .. "_bonus"] = u.hero[k .. "_bonus"] + v end
                    end
                    local xp = tonumber((A:value(abil, "Ixpg", 1)))
                    if xp and g.add_xp then g.add_xp(u, xp) end
                    if g.refresh_hero then g.refresh_hero(u) end
                end
                if hp and u.hp then u.hp = math.min(u.hp_max or u.hp, u.hp + hp) end
                if mana and u.mana_max then u.mana = math.min(u.mana_max, (u.mana or 0) + mana) end
                local cd = tonumber((A:value(abil, "acdn", 1))) or 0
                u.cooldowns = u.cooldowns or {}
                u.cooldowns[abil] = g.time + cd
            end
        end
        event("USE_ITEM", u, it)
        if t.charges > 0 then
            it.charges = it.charges - 1
            if it.charges <= 0 and t.perishable then g.remove_item(it) end
        end
        return true
    end
    -- }}}

    -- a unit fetching an item stops when told otherwise
    local order = g.order
    function g.order(list, kind, ...)
        if kind ~= "pickup" then
            for _, u in ipairs(list) do u.fetch = nil end
        end
        return order(list, kind, ...)
    end
end
-- }}}

-- {{{ items.update
function items.update(g, dt)
    for _, u in ipairs(g.units) do
        local it = u.fetch
        if it then
            if it.owner or it.removed or u.alive == false then
                u.fetch = nil
                if u.order and u.order.kind == "pickup" then u.order = nil end
            elseif (u.x - it.x) ^ 2 + (u.y - it.y) ^ 2 <= items.REACH ^ 2 then
                u.fetch, u.route = nil, nil
                if u.order and u.order.kind == "pickup" then u.order = nil end
                g.give_item(u, it)
            elseif not u.route then
                g.walk_to(u, it.x, it.y)
            end
        end
    end
    -- the removed go
    local keep = {}
    for _, it in ipairs(g.items) do if not it.removed then keep[#keep + 1] = it end end
    g.items = keep
end
-- }}}

return items
