--[[
Money Bag - Physical Coin Storage Component

Manages copper/silver/gold coins in dedicated inventory slots.
Coins are physical items that occupy special "money bag" slots,
separate from the main inventory.

Conversion rates (WoW standard):
  100 copper = 1 silver
  100 silver = 1 gold
  10000 copper = 1 gold

Usage:
  local money_bag = require("runtime.currency.money_bag")

  -- Register component
  money_bag.register_component()

  -- Add coins (auto-converts to higher denominations)
  money_bag.add_copper(bag, 15000)  -- Results in 1g 50s

  -- Check affordability
  if money_bag.can_afford(bag, 5000) then
      money_bag.remove_copper(bag, 5000)
  end

  -- Format for display
  print(money_bag.format(bag))  -- "1g 50s 0c"
]]

local money_bag = {}

-- {{{ Constants
-- Dispatch table for coin values (in copper)
local COIN_VALUES = {
    copper = 1,
    silver = 100,
    gold = 10000,
}

-- Order for display and auto-conversion (highest to lowest)
local COIN_ORDER = { "gold", "silver", "copper" }

-- Component defaults
local COMPONENT_DEFAULTS = {
    -- Dedicated slots for each coin type
    slots = {
        copper = { quantity = 0 },
        silver = { quantity = 0 },
        gold = { quantity = 0 },
    },
    -- Cached total in copper for quick checks
    total_copper = 0,
    -- Dirty flag for recalculation
    dirty = false,
}
-- }}}

-- {{{ money_bag.register_component
-- Register the money_bag ECS component.
-- Call this during game initialization.
function money_bag.register_component()
    local ecs = require("runtime.ecs")
    local component = ecs.component or require("runtime.ecs.component")

    -- Check if already registered
    if component.get_defaults and component.get_defaults("money_bag") then
        return
    end

    component.register("money_bag", {
        slots = {
            copper = { quantity = 0 },
            silver = { quantity = 0 },
            gold = { quantity = 0 },
        },
        total_copper = 0,
        dirty = false,
    })
end
-- }}}

-- {{{ money_bag.create
-- Create a fresh money_bag data structure.
-- Used when adding component to entity or for testing.
-- @return New money_bag table
function money_bag.create()
    return {
        slots = {
            copper = { quantity = 0 },
            silver = { quantity = 0 },
            gold = { quantity = 0 },
        },
        total_copper = 0,
        dirty = false,
    }
end
-- }}}

-- {{{ money_bag.recalculate_total
-- Recalculate total_copper from slot quantities.
-- @param bag Money bag table
function money_bag.recalculate_total(bag)
    local total = 0
    total = total + (bag.slots.copper.quantity * COIN_VALUES.copper)
    total = total + (bag.slots.silver.quantity * COIN_VALUES.silver)
    total = total + (bag.slots.gold.quantity * COIN_VALUES.gold)
    bag.total_copper = total
    bag.dirty = false
end
-- }}}

-- {{{ money_bag.normalize
-- Normalize coins to standard denominations (auto-convert up).
-- 150 copper becomes 1 silver + 50 copper.
-- @param bag Money bag table
function money_bag.normalize(bag)
    -- First, convert everything to copper
    local total = 0
    total = total + bag.slots.copper.quantity
    total = total + bag.slots.silver.quantity * 100
    total = total + bag.slots.gold.quantity * 10000

    -- Then distribute into denominations (greedy, highest first)
    bag.slots.gold.quantity = math.floor(total / 10000)
    total = total % 10000

    bag.slots.silver.quantity = math.floor(total / 100)
    total = total % 100

    bag.slots.copper.quantity = total

    -- Update cached total
    money_bag.recalculate_total(bag)
end
-- }}}

-- {{{ money_bag.set_total
-- Set total copper and distribute into denominations.
-- @param bag Money bag table
-- @param total_copper Total copper value to set
function money_bag.set_total(bag, total_copper)
    total_copper = math.max(0, math.floor(total_copper))

    -- Distribute into denominations
    bag.slots.gold.quantity = math.floor(total_copper / 10000)
    local remaining = total_copper % 10000

    bag.slots.silver.quantity = math.floor(remaining / 100)
    remaining = remaining % 100

    bag.slots.copper.quantity = remaining

    bag.total_copper = total_copper
    bag.dirty = false
end
-- }}}

-- {{{ money_bag.add_copper
-- Add copper value, auto-normalizing to higher denominations.
-- @param bag Money bag table
-- @param amount Copper value to add (can be negative)
-- @return New total copper
function money_bag.add_copper(bag, amount)
    local new_total = bag.total_copper + amount
    money_bag.set_total(bag, new_total)
    return bag.total_copper
end
-- }}}

-- {{{ money_bag.remove_copper
-- Remove copper value.
-- @param bag Money bag table
-- @param amount Copper value to remove
-- @return true on success, false if insufficient funds
function money_bag.remove_copper(bag, amount)
    if bag.total_copper < amount then
        return false, "Insufficient funds"
    end
    money_bag.set_total(bag, bag.total_copper - amount)
    return true
end
-- }}}

-- {{{ money_bag.can_afford
-- Check if bag has enough copper.
-- @param bag Money bag table
-- @param copper_amount Copper value to check
-- @return true if affordable
function money_bag.can_afford(bag, copper_amount)
    return bag.total_copper >= copper_amount
end
-- }}}

-- {{{ money_bag.get_total
-- Get total copper value.
-- @param bag Money bag table
-- @return Total copper
function money_bag.get_total(bag)
    if bag.dirty then
        money_bag.recalculate_total(bag)
    end
    return bag.total_copper
end
-- }}}

-- {{{ money_bag.get_coin
-- Get quantity of a specific coin type.
-- @param bag Money bag table
-- @param coin_type "copper", "silver", or "gold"
-- @return Quantity
function money_bag.get_coin(bag, coin_type)
    if bag.slots[coin_type] then
        return bag.slots[coin_type].quantity
    end
    return 0
end
-- }}}

-- {{{ money_bag.set_coin
-- Set quantity of a specific coin type.
-- Note: This does NOT auto-normalize. Use with caution.
-- @param bag Money bag table
-- @param coin_type "copper", "silver", or "gold"
-- @param quantity New quantity
function money_bag.set_coin(bag, coin_type, quantity)
    if bag.slots[coin_type] then
        bag.slots[coin_type].quantity = math.max(0, math.floor(quantity))
        bag.dirty = true
    end
end
-- }}}

-- {{{ money_bag.format
-- Format bag contents as "Xg Ys Zc" string.
-- @param bag Money bag table
-- @return Formatted string
function money_bag.format(bag)
    if bag.dirty then
        money_bag.recalculate_total(bag)
    end

    local gold = bag.slots.gold.quantity
    local silver = bag.slots.silver.quantity
    local copper = bag.slots.copper.quantity

    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. "c" end

    return table.concat(parts, " ")
end
-- }}}

-- {{{ money_bag.format_copper
-- Format a copper amount as "Xg Ys Zc" string.
-- @param copper_amount Total copper value
-- @return Formatted string
function money_bag.format_copper(copper_amount)
    if not copper_amount or copper_amount < 0 then
        return "0c"
    end

    local gold = math.floor(copper_amount / 10000)
    local silver = math.floor((copper_amount % 10000) / 100)
    local copper = copper_amount % 100

    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. "c" end

    return table.concat(parts, " ")
end
-- }}}

-- {{{ money_bag.parse
-- Parse "Xg Ys Zc" string to copper amount.
-- @param money_string String like "1g 50s" or "500c"
-- @return Total copper value
function money_bag.parse(money_string)
    if not money_string or money_string == "" then
        return 0
    end

    local total = 0

    -- Match gold
    local gold = money_string:match("(%d+)g")
    if gold then total = total + tonumber(gold) * 10000 end

    -- Match silver
    local silver = money_string:match("(%d+)s")
    if silver then total = total + tonumber(silver) * 100 end

    -- Match copper
    local copper = money_string:match("(%d+)c")
    if copper then total = total + tonumber(copper) end

    return total
end
-- }}}

-- {{{ money_bag.transfer
-- Transfer copper from one bag to another.
-- @param from_bag Source money bag
-- @param to_bag Destination money bag
-- @param amount Copper amount to transfer
-- @return true on success, false if insufficient funds
function money_bag.transfer(from_bag, to_bag, amount)
    if from_bag.total_copper < amount then
        return false, "Insufficient funds"
    end

    money_bag.remove_copper(from_bag, amount)
    money_bag.add_copper(to_bag, amount)
    return true
end
-- }}}

-- {{{ money_bag.split
-- Split coins for making change.
-- Converts 1 gold to 100 silver, or 1 silver to 100 copper.
-- @param bag Money bag table
-- @param coin_type "gold" or "silver"
-- @return true on success, false if no coins to split
function money_bag.split(bag, coin_type)
    if coin_type == "gold" and bag.slots.gold.quantity > 0 then
        bag.slots.gold.quantity = bag.slots.gold.quantity - 1
        bag.slots.silver.quantity = bag.slots.silver.quantity + 100
        return true
    elseif coin_type == "silver" and bag.slots.silver.quantity > 0 then
        bag.slots.silver.quantity = bag.slots.silver.quantity - 1
        bag.slots.copper.quantity = bag.slots.copper.quantity + 100
        return true
    end
    return false
end
-- }}}

-- {{{ money_bag.merge
-- Merge lower denominations into higher ones.
-- @param bag Money bag table
function money_bag.merge(bag)
    money_bag.normalize(bag)
end
-- }}}

-- {{{ money_bag.clone
-- Create a copy of a money bag.
-- @param bag Money bag table
-- @return New money bag with same values
function money_bag.clone(bag)
    local copy = money_bag.create()
    copy.slots.copper.quantity = bag.slots.copper.quantity
    copy.slots.silver.quantity = bag.slots.silver.quantity
    copy.slots.gold.quantity = bag.slots.gold.quantity
    copy.total_copper = bag.total_copper
    copy.dirty = bag.dirty
    return copy
end
-- }}}

-- {{{ money_bag.empty
-- Check if bag is empty.
-- @param bag Money bag table
-- @return true if total is 0
function money_bag.empty(bag)
    return bag.total_copper == 0
end
-- }}}

-- {{{ money_bag.reset
-- Reset bag to zero.
-- @param bag Money bag table
function money_bag.reset(bag)
    bag.slots.copper.quantity = 0
    bag.slots.silver.quantity = 0
    bag.slots.gold.quantity = 0
    bag.total_copper = 0
    bag.dirty = false
end
-- }}}

-- {{{ Exports
money_bag.COIN_VALUES = COIN_VALUES
money_bag.COIN_ORDER = COIN_ORDER
-- }}}

return money_bag
