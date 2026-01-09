--[[
Vendor Transaction Flow - Coin-Based Buy/Sell

Bridges the Shop system with the new money_bag currency system.
Handles coin-based transactions where selling items returns physical
copper/silver/gold to the player's money bag.

Supports:
- WoW mode: Entity-based transactions with money_bag component
- WC3 mode: Player-based transactions with resources.lua
- Reputation-based discounts

Usage:
  local vendor = require("runtime.currency.vendor")

  -- Sell an item (coins returned to money_bag)
  vendor.sell_item(player_entity, shop, item, slot)

  -- Buy an item (coins deducted from money_bag)
  vendor.buy_item(player_entity, shop, item_id, quantity)

  -- Get price with reputation discount
  local price = vendor.get_buy_price(player_entity, shop, item_id)
]]

local vendor = {}

-- {{{ Constants

-- Transaction modes
vendor.MODE = {
    WOW = "wow",        -- Use money_bag component
    WC3 = "wc3",        -- Use WC3 resources
    HYBRID = "hybrid",  -- Allow both
}

-- Default mode
vendor._mode = vendor.MODE.WOW

-- Sell price as percentage of buy price (can be overridden per shop)
vendor.DEFAULT_SELL_MODIFIER = 0.5

-- Minimum sell price in copper
vendor.MIN_SELL_PRICE = 1

-- }}}

-- {{{ Lazy-loaded dependencies

-- {{{ local function get_money_bag
local function get_money_bag()
    return require("runtime.currency.money_bag")
end
-- }}}

-- {{{ local function get_ecs
local function get_ecs()
    return require("runtime.ecs")
end
-- }}}

-- {{{ local function get_reputation
local function get_reputation()
    return require("runtime.currency.reputation")
end
-- }}}

-- {{{ local function get_resources
local function get_resources()
    return require("runtime.resources")
end
-- }}}

-- }}}

-- {{{ vendor.set_mode
-- Set the transaction mode.
-- @param mode "wow", "wc3", or "hybrid"
function vendor.set_mode(mode)
    if mode == vendor.MODE.WOW or mode == vendor.MODE.WC3 or mode == vendor.MODE.HYBRID then
        vendor._mode = mode
    end
end
-- }}}

-- {{{ vendor.get_mode
-- Get the current transaction mode.
-- @return Current mode string
function vendor.get_mode()
    return vendor._mode
end
-- }}}

-- {{{ vendor.get_entity_money_bag
-- Get the money_bag component from an entity.
-- @param entity Entity or entity ID
-- @return money_bag component or nil
function vendor.get_entity_money_bag(entity)
    local ecs = get_ecs()
    return ecs.get_component(entity, "money_bag")
end
-- }}}

-- {{{ vendor.get_entity_reputation
-- Get the reputation component from an entity.
-- @param entity Entity or entity ID
-- @return reputation component or nil
function vendor.get_entity_reputation(entity)
    local ecs = get_ecs()
    return ecs.get_component(entity, "reputation")
end
-- }}}

-- {{{ vendor.get_faction_discount
-- Get discount multiplier based on faction reputation.
-- @param entity Entity with reputation component
-- @param faction_id Faction identifier
-- @return Discount multiplier (1.0 = no discount, 0.8 = 20% off)
function vendor.get_faction_discount(entity, faction_id)
    if not faction_id then
        return 1.0
    end

    local rep_component = vendor.get_entity_reputation(entity)
    if not rep_component then
        return 1.0
    end

    local reputation = get_reputation()
    return reputation.get_discount(rep_component, faction_id)
end
-- }}}

-- {{{ vendor.get_buy_price
-- Get the buy price for an item, including reputation discounts.
-- @param entity Buying entity
-- @param shop Shop instance
-- @param item_id Item identifier
-- @return Price in copper, or nil if item not found
function vendor.get_buy_price(entity, shop, item_id)
    if not shop or not item_id then
        return nil
    end

    -- Get base price from shop (in gold units for legacy compatibility)
    local base_price = shop:get_buy_price(item_id, nil)
    if not base_price then
        return nil
    end

    -- Convert to copper (shop prices are in gold units)
    local copper_price = base_price * 10000

    -- Apply reputation discount if shop has a faction
    if shop.faction_id then
        local discount = vendor.get_faction_discount(entity, shop.faction_id)
        copper_price = math.floor(copper_price * discount)
    end

    return copper_price
end
-- }}}

-- {{{ vendor.get_sell_price
-- Get the sell price for an item.
-- @param item Item instance
-- @param shop Optional shop instance (for custom sell modifiers)
-- @return Price in copper, or 0 if unsellable
function vendor.get_sell_price(item, shop)
    if not item then
        return 0
    end

    -- Cannot sell soulbound or quest items
    if item.soulbound or item.quest_item then
        return 0
    end

    -- Get sell modifier
    local modifier = vendor.DEFAULT_SELL_MODIFIER
    if shop and shop.sell_modifier then
        modifier = shop.sell_modifier
    end

    -- Calculate sell price in copper
    local base = item.sell_price or (item.buy_price or 0)
    local copper_price = math.floor(base * 10000 * modifier)

    return math.max(vendor.MIN_SELL_PRICE, copper_price)
end
-- }}}

-- {{{ vendor.can_afford
-- Check if entity can afford a copper amount.
-- @param entity Entity with money_bag component
-- @param copper_amount Amount in copper
-- @return true if affordable, false otherwise
function vendor.can_afford(entity, copper_amount)
    if vendor._mode == vendor.MODE.WC3 then
        -- WC3 mode: check player resources
        -- Entity must have player_id or be a player_id directly
        local player_id = entity.player_id or entity
        local resources = get_resources()
        local gold = resources.get(player_id, "gold") or 0
        -- Convert copper to WC3 gold (100 copper = 1 WC3 gold)
        local wc3_gold_needed = math.ceil(copper_amount / 100)
        return gold >= wc3_gold_needed
    else
        -- WoW mode: check money_bag
        local bag = vendor.get_entity_money_bag(entity)
        if not bag then
            return false
        end
        local money_bag = get_money_bag()
        return money_bag.can_afford(bag, copper_amount)
    end
end
-- }}}

-- {{{ vendor.spend_copper
-- Spend copper from entity's money bag.
-- @param entity Entity with money_bag component
-- @param copper_amount Amount to spend
-- @return true on success, false on failure
function vendor.spend_copper(entity, copper_amount)
    if vendor._mode == vendor.MODE.WC3 then
        local player_id = entity.player_id or entity
        local resources = get_resources()
        local wc3_gold = math.ceil(copper_amount / 100)
        local current = resources.get(player_id, "gold") or 0
        if current < wc3_gold then
            return false, "Insufficient gold"
        end
        resources.subtract(player_id, "gold", wc3_gold)
        return true
    else
        local bag = vendor.get_entity_money_bag(entity)
        if not bag then
            return false, "No money bag"
        end
        local money_bag = get_money_bag()
        return money_bag.remove_copper(bag, copper_amount)
    end
end
-- }}}

-- {{{ vendor.add_copper
-- Add copper to entity's money bag.
-- @param entity Entity with money_bag component
-- @param copper_amount Amount to add
-- @return New total copper
function vendor.add_copper(entity, copper_amount)
    if vendor._mode == vendor.MODE.WC3 then
        local player_id = entity.player_id or entity
        local resources = get_resources()
        -- Convert copper to WC3 gold (100 copper = 1 WC3 gold)
        local wc3_gold = math.floor(copper_amount / 100)
        resources.add(player_id, "gold", wc3_gold)
        return wc3_gold * 100  -- Return equivalent copper
    else
        local bag = vendor.get_entity_money_bag(entity)
        if not bag then
            return 0
        end
        local money_bag = get_money_bag()
        return money_bag.add_copper(bag, copper_amount)
    end
end
-- }}}

-- {{{ vendor.buy_item
-- Buy an item from a shop using the money_bag system.
-- @param entity Entity buying the item
-- @param shop Shop instance
-- @param item_id Item identifier
-- @param quantity Number to buy (default 1)
-- @return true and receipt on success, false and error on failure
function vendor.buy_item(entity, shop, item_id, quantity)
    quantity = quantity or 1

    -- Validate shop
    if not shop then
        return false, "No shop specified"
    end

    -- Check stock
    if not shop:is_in_stock(item_id) then
        return false, "Out of stock"
    end

    local stock = shop.stock[item_id]
    if stock.quantity ~= -1 and stock.quantity < quantity then
        return false, "Insufficient stock"
    end

    -- Get price in copper
    local unit_price = vendor.get_buy_price(entity, shop, item_id)
    if not unit_price then
        return false, "Unknown item"
    end
    local total_price = unit_price * quantity

    -- Check if can afford
    if not vendor.can_afford(entity, total_price) then
        local money_bag = get_money_bag()
        return false, "Insufficient funds (need " .. money_bag.format_copper(total_price) .. ")"
    end

    -- Execute transaction: spend money
    local ok, err = vendor.spend_copper(entity, total_price)
    if not ok then
        return false, err
    end

    -- Reduce shop stock
    if stock.quantity ~= -1 then
        stock.quantity = stock.quantity - quantity
    end

    -- Return receipt (caller handles inventory)
    return true, {
        item_id = item_id,
        quantity = quantity,
        unit_price = unit_price,
        total_price = total_price,
        formatted_price = get_money_bag().format_copper(total_price),
    }
end
-- }}}

-- {{{ vendor.sell_item
-- Sell an item to a shop, receiving coins in money_bag.
-- @param entity Entity selling the item
-- @param shop Shop instance (or nil for default sell price)
-- @param item Item instance being sold
-- @return true and receipt on success, false and error on failure
function vendor.sell_item(entity, shop, item)
    -- Validate item
    if not item then
        return false, "No item specified"
    end

    -- Check if sellable
    if item.soulbound then
        return false, "Cannot sell soulbound items"
    end
    if item.quest_item then
        return false, "Cannot sell quest items"
    end

    -- Calculate sell price in copper
    local quantity = item.quantity or 1
    local unit_price = vendor.get_sell_price(item, shop)
    local total_price = unit_price * quantity

    if total_price <= 0 then
        return false, "Item has no value"
    end

    -- Add coins to money bag
    vendor.add_copper(entity, total_price)

    -- Return receipt (caller handles inventory removal)
    return true, {
        item_name = item.name or item.id,
        quantity = quantity,
        unit_price = unit_price,
        total_earned = total_price,
        formatted_earned = get_money_bag().format_copper(total_price),
    }
end
-- }}}

-- {{{ vendor.preview_buy
-- Preview a buy transaction without executing it.
-- @param entity Entity that would buy
-- @param shop Shop instance
-- @param item_id Item identifier
-- @param quantity Number to buy
-- @return Preview table
function vendor.preview_buy(entity, shop, item_id, quantity)
    quantity = quantity or 1

    local unit_price = vendor.get_buy_price(entity, shop, item_id)
    if not unit_price then
        return nil, "Unknown item"
    end

    local total_price = unit_price * quantity
    local can_afford_it = vendor.can_afford(entity, total_price)
    local money_bag = get_money_bag()

    return {
        item_id = item_id,
        quantity = quantity,
        unit_price = unit_price,
        total_price = total_price,
        formatted_price = money_bag.format_copper(total_price),
        can_afford = can_afford_it,
        in_stock = shop:is_in_stock(item_id),
    }
end
-- }}}

-- {{{ vendor.preview_sell
-- Preview a sell transaction without executing it.
-- @param entity Entity that would sell
-- @param shop Shop instance
-- @param item Item instance
-- @return Preview table
function vendor.preview_sell(entity, shop, item)
    if not item then
        return nil, "No item"
    end

    local quantity = item.quantity or 1
    local unit_price = vendor.get_sell_price(item, shop)
    local total_price = unit_price * quantity
    local money_bag = get_money_bag()

    return {
        item_name = item.name or item.id,
        quantity = quantity,
        unit_price = unit_price,
        total_earned = total_price,
        formatted_earned = money_bag.format_copper(total_price),
        sellable = unit_price > 0 and not item.soulbound and not item.quest_item,
    }
end
-- }}}

-- {{{ vendor.format_price
-- Format a copper amount for display.
-- @param copper_amount Amount in copper
-- @return Formatted string
function vendor.format_price(copper_amount)
    return get_money_bag().format_copper(copper_amount)
end
-- }}}

-- {{{ vendor.get_current_money
-- Get entity's current money as formatted string.
-- @param entity Entity with money_bag component
-- @return Formatted string like "1g 50s 30c"
function vendor.get_current_money(entity)
    if vendor._mode == vendor.MODE.WC3 then
        local player_id = entity.player_id or entity
        local resources = get_resources()
        local gold = resources.get(player_id, "gold") or 0
        return gold .. " WC3 gold"
    else
        local bag = vendor.get_entity_money_bag(entity)
        if not bag then
            return "0c"
        end
        local money_bag = get_money_bag()
        return money_bag.format(bag)
    end
end
-- }}}

-- {{{ vendor.get_current_copper
-- Get entity's current money in copper.
-- @param entity Entity with money_bag component
-- @return Total copper amount
function vendor.get_current_copper(entity)
    if vendor._mode == vendor.MODE.WC3 then
        local player_id = entity.player_id or entity
        local resources = get_resources()
        local gold = resources.get(player_id, "gold") or 0
        return gold * 100  -- Convert WC3 gold to copper
    else
        local bag = vendor.get_entity_money_bag(entity)
        if not bag then
            return 0
        end
        local money_bag = get_money_bag()
        return money_bag.get_total(bag)
    end
end
-- }}}

return vendor
