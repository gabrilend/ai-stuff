--[[
Currency Conversion - WC3 ↔ WoW Cross-Play Bridge

Enables conversion between WC3 player resources and WoW character currencies.
This is the key feature for cross-play between the two game modes.

Conversion Rates:
  1 WC3 Gold = 100 WoW Copper (= 1 WoW Silver)
  1 WC3 Lumber = No direct WoW equivalent (remains as lumber)

Usage:
  local conversion = require("runtime.currency.conversion")

  -- Convert WC3 gold to WoW copper
  conversion.wc3_to_wow(player_id, entity, 100)  -- 100 WC3 gold → 10000 copper

  -- Convert WoW copper to WC3 gold
  conversion.wow_to_wc3(entity, player_id, 15000)  -- 15000 copper → 150 WC3 gold
]]

local conversion = {}

-- {{{ Constants
-- Conversion rate: how many WoW copper per WC3 gold
conversion.WC3_GOLD_TO_COPPER = 100

-- Minimum amounts for conversion
conversion.MIN_WC3_GOLD = 1
conversion.MIN_COPPER = 100  -- At least 1 silver worth
-- }}}

-- {{{ local function get_resources
local function get_resources()
    return require("runtime.resources")
end
-- }}}

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

-- {{{ conversion.wc3_to_wow
-- Convert WC3 gold (player resource) to WoW copper (character inventory).
--
-- @param player_id WC3 player slot ID
-- @param entity Character entity with money_bag component
-- @param amount Amount of WC3 gold to convert
-- @return true and copper amount on success, false and error on failure
function conversion.wc3_to_wow(player_id, entity, amount)
    if not amount or amount < conversion.MIN_WC3_GOLD then
        return false, "Amount must be at least " .. conversion.MIN_WC3_GOLD
    end

    local resources = get_resources()
    local money_bag_mod = get_money_bag()
    local ecs = get_ecs()

    -- Check WC3 gold available
    local current_gold = resources.get(player_id, "gold")
    if current_gold < amount then
        return false, "Insufficient WC3 gold"
    end

    -- Get character's money bag
    local bag = ecs.get_component(entity, "money_bag")
    if not bag then
        return false, "Entity has no money_bag component"
    end

    -- Calculate copper equivalent
    local copper_amount = amount * conversion.WC3_GOLD_TO_COPPER

    -- Perform the conversion (atomic)
    resources.subtract(player_id, "gold", amount)
    money_bag_mod.add_copper(bag, copper_amount)

    return true, copper_amount
end
-- }}}

-- {{{ conversion.wow_to_wc3
-- Convert WoW copper (character inventory) to WC3 gold (player resource).
--
-- Note: Fractional copper that doesn't convert to a full WC3 gold is returned
-- to the character's money bag.
--
-- @param entity Character entity with money_bag component
-- @param player_id WC3 player slot ID
-- @param copper_amount Amount of copper to convert
-- @return true and WC3 gold amount on success, false and error on failure
function conversion.wow_to_wc3(entity, player_id, copper_amount)
    if not copper_amount or copper_amount < conversion.MIN_COPPER then
        return false, "Amount must be at least " .. conversion.MIN_COPPER .. " copper"
    end

    local resources = get_resources()
    local money_bag_mod = get_money_bag()
    local ecs = get_ecs()

    -- Get character's money bag
    local bag = ecs.get_component(entity, "money_bag")
    if not bag then
        return false, "Entity has no money_bag component"
    end

    -- Check copper available
    if not money_bag_mod.can_afford(bag, copper_amount) then
        return false, "Insufficient copper"
    end

    -- Calculate WC3 gold equivalent (integer division)
    local wc3_gold = math.floor(copper_amount / conversion.WC3_GOLD_TO_COPPER)
    local remainder = copper_amount % conversion.WC3_GOLD_TO_COPPER

    if wc3_gold < 1 then
        return false, "Amount too small to convert (need at least 100 copper)"
    end

    -- Perform the conversion
    -- Only deduct the copper that actually converts (leave remainder)
    local copper_to_deduct = wc3_gold * conversion.WC3_GOLD_TO_COPPER
    money_bag_mod.remove_copper(bag, copper_to_deduct)
    resources.add(player_id, "gold", wc3_gold)

    return true, wc3_gold, remainder
end
-- }}}

-- {{{ conversion.get_exchange_rate
-- Get the current exchange rate.
-- @param from_currency "wc3_gold" or "copper"
-- @param to_currency "copper" or "wc3_gold"
-- @return Rate (how many 'to' per 'from')
function conversion.get_exchange_rate(from_currency, to_currency)
    if from_currency == "wc3_gold" and to_currency == "copper" then
        return conversion.WC3_GOLD_TO_COPPER
    elseif from_currency == "copper" and to_currency == "wc3_gold" then
        return 1 / conversion.WC3_GOLD_TO_COPPER
    elseif from_currency == "wc3_gold" and to_currency == "silver" then
        return 1  -- 1 WC3 gold = 1 WoW silver
    elseif from_currency == "wc3_gold" and to_currency == "gold" then
        return 0.01  -- 1 WC3 gold = 0.01 WoW gold
    else
        return nil
    end
end
-- }}}

-- {{{ conversion.preview_wc3_to_wow
-- Preview what a WC3→WoW conversion would yield.
-- Does not actually perform the conversion.
-- @param amount WC3 gold amount
-- @return Table with copper, silver, gold breakdown
function conversion.preview_wc3_to_wow(amount)
    local copper = amount * conversion.WC3_GOLD_TO_COPPER

    return {
        total_copper = copper,
        gold = math.floor(copper / 10000),
        silver = math.floor((copper % 10000) / 100),
        copper = copper % 100,
        formatted = require("runtime.currency.money_bag").format_copper(copper),
    }
end
-- }}}

-- {{{ conversion.preview_wow_to_wc3
-- Preview what a WoW→WC3 conversion would yield.
-- Does not actually perform the conversion.
-- @param copper_amount Total copper amount
-- @return Table with wc3_gold and remainder
function conversion.preview_wow_to_wc3(copper_amount)
    local wc3_gold = math.floor(copper_amount / conversion.WC3_GOLD_TO_COPPER)
    local remainder = copper_amount % conversion.WC3_GOLD_TO_COPPER

    return {
        wc3_gold = wc3_gold,
        remainder_copper = remainder,
        lost_value = remainder,  -- Copper that won't convert
    }
end
-- }}}

-- {{{ conversion.can_convert_wc3_to_wow
-- Check if WC3→WoW conversion is possible.
-- @param player_id WC3 player slot ID
-- @param entity Character entity
-- @param amount WC3 gold amount
-- @return true if possible, false and reason otherwise
function conversion.can_convert_wc3_to_wow(player_id, entity, amount)
    if not amount or amount < conversion.MIN_WC3_GOLD then
        return false, "Amount too small"
    end

    local resources = get_resources()
    local current = resources.get(player_id, "gold")
    if current < amount then
        return false, "Insufficient WC3 gold"
    end

    local ecs = get_ecs()
    local bag = ecs.get_component(entity, "money_bag")
    if not bag then
        return false, "No money bag"
    end

    return true
end
-- }}}

-- {{{ conversion.can_convert_wow_to_wc3
-- Check if WoW→WC3 conversion is possible.
-- @param entity Character entity
-- @param player_id WC3 player slot ID
-- @param copper_amount Copper amount
-- @return true if possible, false and reason otherwise
function conversion.can_convert_wow_to_wc3(entity, player_id, copper_amount)
    if not copper_amount or copper_amount < conversion.MIN_COPPER then
        return false, "Amount too small"
    end

    local ecs = get_ecs()
    local bag = ecs.get_component(entity, "money_bag")
    if not bag then
        return false, "No money bag"
    end

    local money_bag_mod = get_money_bag()
    if not money_bag_mod.can_afford(bag, copper_amount) then
        return false, "Insufficient copper"
    end

    local wc3_gold = math.floor(copper_amount / conversion.WC3_GOLD_TO_COPPER)
    if wc3_gold < 1 then
        return false, "Not enough to convert (need 100+ copper)"
    end

    return true
end
-- }}}

return conversion
