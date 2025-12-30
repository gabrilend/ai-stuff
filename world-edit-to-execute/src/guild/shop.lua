#!/usr/bin/env luajit
--[[
Shop & Marketplace System

Handles buying, selling, and trading items.
Modeled after WC3 shop mechanics with abstracted data patterns.

Shop types mirror WC3 categories:
- Merchant: General goods, consumables
- Armory: Weapons and armor
- Arcane: Magical items, tomes
- Guild: Quest-related items, capability unlocks
]]

local DIR = arg and arg[0] and arg[0]:match("(.*/)") or "./"

-- Load dependencies
local items_module = require("src.guild.items")
local Item = items_module.Item
local ItemRegistry = items_module.ItemRegistry
local ITEM_TYPE = items_module.ITEM_TYPE
local RARITY = items_module.RARITY

-- {{{ Constants
local SHOP_TYPE = {
    MERCHANT = "merchant",
    ARMORY = "armory",
    ARCANE = "arcane",
    GUILD = "guild",
}

-- Sell price modifier (percentage of buy price)
local SELL_MODIFIER = 0.5

-- Discount types
local DISCOUNT_TYPE = {
    FLAT = "flat",        -- Fixed gold reduction
    PERCENT = "percent",  -- Percentage reduction
    LEVEL = "level",      -- Discount based on hero level
}
-- }}}

-- {{{ Shop class
local Shop = {}
Shop.__index = Shop

-- {{{ new
function Shop.new(spec)
    local self = setmetatable({}, Shop)

    self.id = spec.id or ("shop_" .. tostring(os.time()))
    self.name = spec.name or "General Store"
    self.type = spec.type or SHOP_TYPE.MERCHANT
    self.description = spec.description or ""

    -- Stock: item_id -> { quantity, restock_time, max_stock }
    self.stock = {}

    -- Pricing overrides: item_id -> custom_price
    self.price_overrides = spec.price_overrides or {}

    -- Active discounts
    self.discounts = spec.discounts or {}

    -- Requirements to access shop
    self.level_req = spec.level_req or 1
    self.capability_req = spec.capability_req

    -- Shop state
    self.open = true
    self.last_restock = os.time()
    self.restock_interval = spec.restock_interval or 3600  -- 1 hour default

    return self
end
-- }}}

-- {{{ add_stock
function Shop:add_stock(item_id, quantity, max_stock)
    if not ItemRegistry.items[item_id] then
        return false, "Unknown item: " .. item_id
    end

    self.stock[item_id] = {
        quantity = quantity or -1,  -- -1 = unlimited
        max_stock = max_stock or quantity,
        restock_time = nil,
    }

    return true
end
-- }}}

-- {{{ remove_stock
function Shop:remove_stock(item_id)
    self.stock[item_id] = nil
end
-- }}}

-- {{{ get_stock
function Shop:get_stock(item_id)
    local stock = self.stock[item_id]
    if not stock then
        return nil
    end
    return stock.quantity
end
-- }}}

-- {{{ is_in_stock
function Shop:is_in_stock(item_id)
    local stock = self.stock[item_id]
    if not stock then
        return false
    end
    return stock.quantity == -1 or stock.quantity > 0
end
-- }}}

-- {{{ get_buy_price
function Shop:get_buy_price(item_id, hero)
    local item = ItemRegistry.get(item_id)
    if not item then
        return nil, "Unknown item"
    end

    local base_price = self.price_overrides[item_id] or item.buy_price

    -- Apply discounts
    local discount = 0
    for _, d in ipairs(self.discounts) do
        if not d.item_id or d.item_id == item_id then
            if d.type == DISCOUNT_TYPE.FLAT then
                discount = discount + d.value
            elseif d.type == DISCOUNT_TYPE.PERCENT then
                discount = discount + (base_price * d.value / 100)
            elseif d.type == DISCOUNT_TYPE.LEVEL and hero then
                discount = discount + (hero.level * d.value)
            end
        end
    end

    local final_price = math.max(1, math.floor(base_price - discount))
    return final_price
end
-- }}}

-- {{{ get_sell_price
function Shop:get_sell_price(item)
    if item.soulbound or item.quest_item then
        return 0  -- Cannot sell
    end

    local base = item.sell_price or math.floor(item.buy_price * SELL_MODIFIER)
    return base
end
-- }}}

-- {{{ can_access
function Shop:can_access(hero)
    if not self.open then
        return false, "Shop is closed"
    end

    if hero.level < self.level_req then
        return false, "Requires level " .. self.level_req
    end

    if self.capability_req and not hero:has_capability(self.capability_req) then
        return false, "Requires capability: " .. self.capability_req
    end

    return true
end
-- }}}

-- {{{ buy
function Shop:buy(hero, item_id, quantity)
    quantity = quantity or 1

    -- Check access
    local can, err = self:can_access(hero)
    if not can then
        return false, err
    end

    -- Check stock
    if not self:is_in_stock(item_id) then
        return false, "Out of stock"
    end

    local stock = self.stock[item_id]
    if stock.quantity ~= -1 and stock.quantity < quantity then
        return false, "Insufficient stock (have " .. stock.quantity .. ")"
    end

    -- Get item template
    local item = ItemRegistry.get(item_id)
    if not item then
        return false, "Unknown item"
    end

    -- Check inventory space
    local inv_count = hero:get_inventory_count()
    local slots_needed = item:is_stackable() and 1 or quantity
    if inv_count + slots_needed > 6 then
        return false, "Inventory full"
    end

    -- Calculate price
    local unit_price = self:get_buy_price(item_id, hero)
    local total_price = unit_price * quantity

    -- Check gold
    if hero.gold < total_price then
        return false, "Insufficient gold (need " .. total_price .. ", have " .. hero.gold .. ")"
    end

    -- Execute transaction
    hero:spend_gold(total_price)

    -- Reduce stock
    if stock.quantity ~= -1 then
        stock.quantity = stock.quantity - quantity
    end

    -- Add items to inventory
    if item:is_stackable() then
        item.quantity = quantity
        hero:add_to_inventory(item)
    else
        for i = 1, quantity do
            local copy = item:clone(1)
            hero:add_to_inventory(copy)
        end
    end

    return true, {
        item_id = item_id,
        quantity = quantity,
        total_cost = total_price,
    }
end
-- }}}

-- {{{ sell
function Shop:sell(hero, slot)
    -- Check access
    local can, err = self:can_access(hero)
    if not can then
        return false, err
    end

    -- Get item from inventory
    local item = hero.inventory[slot]
    if not item then
        return false, "No item in slot " .. slot
    end

    -- Check if sellable
    if item.soulbound then
        return false, "Cannot sell soulbound items"
    end
    if item.quest_item then
        return false, "Cannot sell quest items"
    end

    -- Calculate sell price
    local unit_price = self:get_sell_price(item)
    local total_price = unit_price * (item.quantity or 1)

    -- Execute transaction
    hero:remove_from_inventory(slot)
    hero:add_gold(total_price)

    return true, {
        item_name = item.name,
        quantity = item.quantity or 1,
        gold_earned = total_price,
    }
end
-- }}}

-- {{{ add_discount
function Shop:add_discount(spec)
    table.insert(self.discounts, {
        type = spec.type or DISCOUNT_TYPE.PERCENT,
        value = spec.value or 0,
        item_id = spec.item_id,  -- nil = applies to all
        expires = spec.expires,  -- nil = permanent
        name = spec.name or "Discount",
    })
end
-- }}}

-- {{{ clear_expired_discounts
function Shop:clear_expired_discounts()
    local now = os.time()
    local active = {}
    for _, d in ipairs(self.discounts) do
        if not d.expires or d.expires > now then
            table.insert(active, d)
        end
    end
    self.discounts = active
end
-- }}}

-- {{{ restock
function Shop:restock()
    for item_id, stock in pairs(self.stock) do
        if stock.max_stock and stock.quantity ~= -1 then
            stock.quantity = stock.max_stock
        end
    end
    self.last_restock = os.time()
end
-- }}}

-- {{{ list_items
function Shop:list_items(hero)
    local items = {}

    for item_id, stock in pairs(self.stock) do
        local item = ItemRegistry.get(item_id)
        if item then
            local in_stock = stock.quantity == -1 or stock.quantity > 0
            local can_afford = hero and hero.gold >= self:get_buy_price(item_id, hero)
            local can_equip = true
            local equip_err = nil

            if item:is_equipment() then
                can_equip, equip_err = item:can_equip(hero)
            end

            table.insert(items, {
                id = item_id,
                item = item,
                price = self:get_buy_price(item_id, hero),
                stock = stock.quantity,
                in_stock = in_stock,
                can_afford = can_afford,
                can_equip = can_equip,
                equip_error = equip_err,
            })
        end
    end

    -- Sort by type, then by price
    table.sort(items, function(a, b)
        if a.item.type ~= b.item.type then
            return a.item.type < b.item.type
        end
        return a.price < b.price
    end)

    return items
end
-- }}}

-- {{{ format
function Shop:format(hero)
    local lines = {}

    table.insert(lines, string.format("=== %s ===", self.name))
    table.insert(lines, string.format("Type: %s", self.type))
    if self.description ~= "" then
        table.insert(lines, self.description)
    end
    table.insert(lines, "")

    if hero then
        table.insert(lines, string.format("Your Gold: %d", hero.gold))
        table.insert(lines, "")
    end

    -- Active discounts
    if #self.discounts > 0 then
        table.insert(lines, "Active Discounts:")
        for _, d in ipairs(self.discounts) do
            local desc = d.name
            if d.type == DISCOUNT_TYPE.PERCENT then
                desc = desc .. string.format(" (%d%% off)", d.value)
            elseif d.type == DISCOUNT_TYPE.FLAT then
                desc = desc .. string.format(" (-%d gold)", d.value)
            end
            table.insert(lines, "  * " .. desc)
        end
        table.insert(lines, "")
    end

    -- Items for sale
    table.insert(lines, "Items for Sale:")
    local items = self:list_items(hero)

    if #items == 0 then
        table.insert(lines, "  (No items available)")
    else
        for _, entry in ipairs(items) do
            local status = ""
            if not entry.in_stock then
                status = " [OUT OF STOCK]"
            elseif hero and not entry.can_afford then
                status = " [CANNOT AFFORD]"
            elseif hero and not entry.can_equip and entry.item:is_equipment() then
                status = " [" .. (entry.equip_error or "LOCKED") .. "]"
            end

            local stock_str = ""
            if entry.stock ~= -1 then
                stock_str = string.format(" (x%d)", entry.stock)
            end

            local rarity = entry.item:get_rarity_info()
            table.insert(lines, string.format("  [%d gold] %s%s%s",
                entry.price, entry.item.name, stock_str, status))
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ __tostring
function Shop:__tostring()
    local stock_count = 0
    for _ in pairs(self.stock) do stock_count = stock_count + 1 end
    return string.format("Shop<%s, %d items>", self.name, stock_count)
end
-- }}}
-- }}}

-- {{{ ShopRegistry
-- Central registry of all shops
local ShopRegistry = {
    shops = {},
}

-- {{{ register
function ShopRegistry.register(shop)
    ShopRegistry.shops[shop.id] = shop
    return shop.id
end
-- }}}

-- {{{ get
function ShopRegistry.get(shop_id)
    return ShopRegistry.shops[shop_id]
end
-- }}}

-- {{{ list
function ShopRegistry.list(filter)
    local results = {}
    for id, shop in pairs(ShopRegistry.shops) do
        local include = true

        if filter then
            if filter.type and shop.type ~= filter.type then
                include = false
            end
            if filter.open ~= nil and shop.open ~= filter.open then
                include = false
            end
        end

        if include then
            table.insert(results, shop)
        end
    end
    return results
end
-- }}}
-- }}}

-- {{{ Predefined Shops
local function create_default_shops()
    -- General Merchant
    local merchant = Shop.new({
        id = "guild_merchant",
        name = "Guild Merchant",
        type = SHOP_TYPE.MERCHANT,
        description = "Basic supplies for aspiring adventurers.",
    })
    merchant:add_stock("coffee_potion", -1)
    merchant:add_stock("energy_drink", -1)
    merchant:add_stock("debug_ring", 5)
    merchant:add_stock("basic_tests", 3)
    ShopRegistry.register(merchant)

    -- Armory
    local armory = Shop.new({
        id = "guild_armory",
        name = "Guild Armory",
        type = SHOP_TYPE.ARMORY,
        description = "Equipment for serious bug hunters.",
        level_req = 3,
    })
    armory:add_stock("rusty_debugger", 5)
    armory:add_stock("syntax_sword", 2)
    armory:add_stock("refactoring_blade", 1)
    armory:add_stock("coverage_cloak", 3)
    armory:add_stock("ci_platemail", 1)
    armory:add_stock("profiler_amulet", 2)
    armory:add_stock("git_bisect_charm", 1)
    ShopRegistry.register(armory)

    -- Arcane Shop
    local arcane = Shop.new({
        id = "arcane_library",
        name = "Arcane Library",
        type = SHOP_TYPE.ARCANE,
        description = "Rare tomes and magical items.",
        level_req = 10,
    })
    arcane:add_stock("xp_scroll", 5)
    arcane:add_stock("tome_of_patterns", 1)
    arcane:add_stock("epsilon_edge", 1)
    ShopRegistry.register(arcane)

    -- Guild Shop (unlocked by capabilities)
    local guild_shop = Shop.new({
        id = "guild_hall",
        name = "Guild Hall Shop",
        type = SHOP_TYPE.GUILD,
        description = "Exclusive items for proven adventurers.",
        capability_req = "Parser Edge Case Handling",
    })
    -- Guild shop sells quest-reward items for those who missed them
    -- Or specialty items
    ShopRegistry.register(guild_shop)
end

-- Initialize default shops
create_default_shops()
-- }}}

-- {{{ Module exports
return {
    Shop = Shop,
    ShopRegistry = ShopRegistry,

    -- Constants
    SHOP_TYPE = SHOP_TYPE,
    SELL_MODIFIER = SELL_MODIFIER,
    DISCOUNT_TYPE = DISCOUNT_TYPE,
}
-- }}}
