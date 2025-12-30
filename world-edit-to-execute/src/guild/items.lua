#!/usr/bin/env luajit
--[[
Item & Equipment System

Defines items, equipment, and consumables for the guild system.
Modeled after WC3 item mechanics with abstracted data patterns.

Item types mirror WC3 categories:
- Equipment: Weapons, armor, accessories (grant stats)
- Consumables: Single-use items (grant effects)
- Materials: Crafting/quest components
- Tomes: Permanent stat boosts (consumed on use)
]]

local DIR = arg and arg[0] and arg[0]:match("(.*/)") or "./"

-- {{{ Constants
local ITEM_TYPE = {
    EQUIPMENT = "equipment",
    CONSUMABLE = "consumable",
    MATERIAL = "material",
    TOME = "tome",
}

local RARITY = {
    COMMON = { name = "Common", color = "white", multiplier = 1.0 },
    UNCOMMON = { name = "Uncommon", color = "green", multiplier = 1.25 },
    RARE = { name = "Rare", color = "blue", multiplier = 1.5 },
    EPIC = { name = "Epic", color = "purple", multiplier = 2.0 },
    LEGENDARY = { name = "Legendary", color = "orange", multiplier = 3.0 },
}

local EQUIPMENT_SLOT = {
    WEAPON = "weapon",
    ARMOR = "armor",
    ACCESSORY = "accessory",
}

-- Effect types for consumables
local EFFECT_TYPE = {
    HEAL_ENERGY = "heal_energy",
    GRANT_XP = "grant_xp",
    GRANT_GOLD = "grant_gold",
    BUFF_STAT = "buff_stat",
    UNLOCK_CAPABILITY = "unlock_capability",
    REVEAL_QUEST = "reveal_quest",
}
-- }}}

-- {{{ Item class
local Item = {}
Item.__index = Item

-- {{{ new
function Item.new(spec)
    local self = setmetatable({}, Item)

    -- Required fields
    self.id = spec.id or ("item_" .. tostring(os.time()))
    self.name = spec.name or "Unknown Item"
    self.type = spec.type or ITEM_TYPE.MATERIAL
    self.rarity = spec.rarity or "COMMON"

    -- Optional fields
    self.description = spec.description or ""
    self.icon = spec.icon or "?"
    self.stack_size = spec.stack_size or 1
    self.quantity = spec.quantity or 1

    -- Equipment fields
    self.slot = spec.slot  -- weapon, armor, accessory
    self.stats = spec.stats or {}  -- { strength = 5, agility = 3, ... }
    self.level_req = spec.level_req or 1
    self.capability_req = spec.capability_req  -- Required capability to equip

    -- Consumable fields
    self.effects = spec.effects or {}  -- { { type = "heal_energy", value = 50 }, ... }
    self.cooldown = spec.cooldown or 0  -- Seconds between uses

    -- Passive effects (apply while in inventory)
    self.passive_stats = spec.passive_stats or {}

    -- Economy
    self.buy_price = spec.buy_price or 0
    self.sell_price = spec.sell_price or math.floor((spec.buy_price or 0) * 0.5)

    -- Metadata
    self.soulbound = spec.soulbound or false  -- Cannot be traded/sold
    self.quest_item = spec.quest_item or false  -- Required for quest, cannot be discarded

    return self
end
-- }}}

-- {{{ get_rarity_info
function Item:get_rarity_info()
    return RARITY[self.rarity] or RARITY.COMMON
end
-- }}}

-- {{{ is_equipment
function Item:is_equipment()
    return self.type == ITEM_TYPE.EQUIPMENT and self.slot ~= nil
end
-- }}}

-- {{{ is_consumable
function Item:is_consumable()
    return self.type == ITEM_TYPE.CONSUMABLE
end
-- }}}

-- {{{ is_stackable
function Item:is_stackable()
    return self.stack_size > 1
end
-- }}}

-- {{{ can_equip
function Item:can_equip(hero)
    if not self:is_equipment() then
        return false, "Not equipment"
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

-- {{{ use
function Item:use(hero)
    if not self:is_consumable() then
        return false, "Cannot use non-consumable items"
    end

    local results = {}

    for _, effect in ipairs(self.effects) do
        local result = self:_apply_effect(effect, hero)
        table.insert(results, result)
    end

    -- Decrease quantity
    self.quantity = self.quantity - 1
    local consumed = self.quantity <= 0

    return true, results, consumed
end
-- }}}

-- {{{ _apply_effect
function Item:_apply_effect(effect, hero)
    local result = {
        type = effect.type,
        success = true,
        message = "",
    }

    if effect.type == EFFECT_TYPE.HEAL_ENERGY then
        -- Restore energy (endurance-based resource)
        local amount = effect.value or 0
        result.message = string.format("Restored %d energy", amount)

    elseif effect.type == EFFECT_TYPE.GRANT_XP then
        local xp = effect.value or 0
        local leveled, levels = hero:add_xp(xp)
        result.message = string.format("Gained %d XP", xp)
        if leveled then
            result.message = result.message .. string.format(" (Level up! +%d)", levels)
        end

    elseif effect.type == EFFECT_TYPE.GRANT_GOLD then
        local gold = effect.value or 0
        hero:add_gold(gold)
        result.message = string.format("Gained %d gold", gold)

    elseif effect.type == EFFECT_TYPE.UNLOCK_CAPABILITY then
        local cap = effect.capability
        if cap then
            hero.capabilities[cap] = true
            result.message = string.format("Unlocked capability: %s", cap)
        end

    elseif effect.type == EFFECT_TYPE.REVEAL_QUEST then
        result.message = string.format("Quest revealed: %s", effect.quest_id or "unknown")

    else
        result.success = false
        result.message = "Unknown effect type: " .. tostring(effect.type)
    end

    return result
end
-- }}}

-- {{{ clone
function Item:clone(quantity)
    local copy = Item.new({
        id = self.id,
        name = self.name,
        type = self.type,
        rarity = self.rarity,
        description = self.description,
        icon = self.icon,
        stack_size = self.stack_size,
        quantity = quantity or self.quantity,
        slot = self.slot,
        stats = self.stats,
        level_req = self.level_req,
        capability_req = self.capability_req,
        effects = self.effects,
        cooldown = self.cooldown,
        passive_stats = self.passive_stats,
        buy_price = self.buy_price,
        sell_price = self.sell_price,
        soulbound = self.soulbound,
        quest_item = self.quest_item,
    })
    return copy
end
-- }}}

-- {{{ format
function Item:format()
    local lines = {}
    local rarity = self:get_rarity_info()

    table.insert(lines, string.format("[%s] %s", rarity.name, self.name))

    if self.description ~= "" then
        table.insert(lines, self.description)
    end

    table.insert(lines, string.format("Type: %s", self.type))

    if self:is_equipment() then
        table.insert(lines, string.format("Slot: %s", self.slot))
        if self.level_req > 1 then
            table.insert(lines, string.format("Requires Level: %d", self.level_req))
        end
        if next(self.stats) then
            table.insert(lines, "Stats:")
            for stat, value in pairs(self.stats) do
                local sign = value >= 0 and "+" or ""
                table.insert(lines, string.format("  %s%d %s", sign, value, stat))
            end
        end
    end

    if self:is_consumable() and #self.effects > 0 then
        table.insert(lines, "Effects:")
        for _, effect in ipairs(self.effects) do
            table.insert(lines, string.format("  - %s: %s",
                effect.type, tostring(effect.value or effect.capability or "")))
        end
    end

    if self.buy_price > 0 then
        table.insert(lines, string.format("Price: %d gold", self.buy_price))
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ __tostring
function Item:__tostring()
    local rarity = self:get_rarity_info()
    if self:is_stackable() and self.quantity > 1 then
        return string.format("%s x%d", self.name, self.quantity)
    end
    return self.name
end
-- }}}
-- }}}

-- {{{ ItemRegistry
-- Central registry of all item definitions
local ItemRegistry = {
    items = {},
}

-- {{{ register
function ItemRegistry.register(spec)
    local item = Item.new(spec)
    ItemRegistry.items[item.id] = spec  -- Store spec, not instance
    return item.id
end
-- }}}

-- {{{ get
function ItemRegistry.get(item_id)
    local spec = ItemRegistry.items[item_id]
    if not spec then
        return nil, "Unknown item: " .. tostring(item_id)
    end
    return Item.new(spec)
end
-- }}}

-- {{{ list
function ItemRegistry.list(filter)
    local results = {}
    for id, spec in pairs(ItemRegistry.items) do
        local include = true

        if filter then
            if filter.type and spec.type ~= filter.type then
                include = false
            end
            if filter.rarity and spec.rarity ~= filter.rarity then
                include = false
            end
            if filter.slot and spec.slot ~= filter.slot then
                include = false
            end
            if filter.max_level and (spec.level_req or 1) > filter.max_level then
                include = false
            end
        end

        if include then
            table.insert(results, id)
        end
    end
    return results
end
-- }}}
-- }}}

-- {{{ Predefined Items (Guild-themed)
-- Weapons
ItemRegistry.register({
    id = "rusty_debugger",
    name = "Rusty Debugger",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.WEAPON,
    rarity = "COMMON",
    description = "A well-worn debugging tool. Better than nothing.",
    stats = { intelligence = 2 },
    buy_price = 50,
})

ItemRegistry.register({
    id = "syntax_sword",
    name = "Sword of Syntax",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.WEAPON,
    rarity = "UNCOMMON",
    description = "Cuts through parsing errors with ease.",
    stats = { intelligence = 5, agility = 2 },
    level_req = 5,
    buy_price = 200,
})

ItemRegistry.register({
    id = "refactoring_blade",
    name = "Blade of Refactoring",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.WEAPON,
    rarity = "RARE",
    description = "The wielder sees code structure with perfect clarity.",
    stats = { intelligence = 10, strength = 5 },
    level_req = 10,
    buy_price = 500,
})

ItemRegistry.register({
    id = "epsilon_edge",
    name = "Epsilon's Edge",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.WEAPON,
    rarity = "EPIC",
    description = "So precise it can split floating point errors.",
    stats = { intelligence = 15, agility = 8 },
    level_req = 15,
    capability_req = "Floating Point Wisdom",
    buy_price = 1500,
})

-- Armor
ItemRegistry.register({
    id = "basic_tests",
    name = "Basic Test Suite",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.ARMOR,
    rarity = "COMMON",
    description = "A few assertions are better than none.",
    stats = { endurance = 15 },
    buy_price = 50,
})

ItemRegistry.register({
    id = "coverage_cloak",
    name = "Cloak of Coverage",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.ARMOR,
    rarity = "UNCOMMON",
    description = "Protects against regressions. 80% coverage.",
    stats = { endurance = 30, strength = 3 },
    level_req = 5,
    buy_price = 200,
})

ItemRegistry.register({
    id = "ci_platemail",
    name = "CI Pipeline Platemail",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.ARMOR,
    rarity = "RARE",
    description = "Automated protection against all known bugs.",
    stats = { endurance = 50, strength = 5, agility = 3 },
    level_req = 10,
    buy_price = 500,
})

-- Accessories
ItemRegistry.register({
    id = "debug_ring",
    name = "Ring of Debug Logging",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.ACCESSORY,
    rarity = "COMMON",
    description = "print() statements everywhere.",
    stats = { intelligence = 1 },
    buy_price = 25,
})

ItemRegistry.register({
    id = "profiler_amulet",
    name = "Profiler's Amulet",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.ACCESSORY,
    rarity = "UNCOMMON",
    description = "See where the cycles go.",
    stats = { agility = 5, intelligence = 3 },
    level_req = 7,
    buy_price = 150,
})

ItemRegistry.register({
    id = "git_bisect_charm",
    name = "Charm of Git Bisect",
    type = ITEM_TYPE.EQUIPMENT,
    slot = EQUIPMENT_SLOT.ACCESSORY,
    rarity = "RARE",
    description = "Binary search through history to find the culprit.",
    stats = { intelligence = 8, agility = 5 },
    level_req = 10,
    buy_price = 400,
})

-- Consumables
ItemRegistry.register({
    id = "coffee_potion",
    name = "Potion of Coffee",
    type = ITEM_TYPE.CONSUMABLE,
    rarity = "COMMON",
    description = "Restores energy for more coding.",
    stack_size = 10,
    effects = {{ type = EFFECT_TYPE.HEAL_ENERGY, value = 25 }},
    buy_price = 10,
})

ItemRegistry.register({
    id = "energy_drink",
    name = "Energy Drink of Focus",
    type = ITEM_TYPE.CONSUMABLE,
    rarity = "UNCOMMON",
    description = "Maximum caffeine. Handle with care.",
    stack_size = 5,
    effects = {{ type = EFFECT_TYPE.HEAL_ENERGY, value = 75 }},
    buy_price = 30,
})

ItemRegistry.register({
    id = "xp_scroll",
    name = "Scroll of Experience",
    type = ITEM_TYPE.CONSUMABLE,
    rarity = "RARE",
    description = "Contains the wisdom of a completed code review.",
    stack_size = 1,
    effects = {{ type = EFFECT_TYPE.GRANT_XP, value = 100 }},
    buy_price = 200,
})

-- Tomes (permanent stat boosts)
ItemRegistry.register({
    id = "tome_of_patterns",
    name = "Tome of Design Patterns",
    type = ITEM_TYPE.TOME,
    rarity = "EPIC",
    description = "Reading this permanently increases intelligence.",
    effects = {{ type = EFFECT_TYPE.BUFF_STAT, stat = "intelligence", value = 5 }},
    buy_price = 1000,
})

-- Quest items
ItemRegistry.register({
    id = "epsilon_constant",
    name = "The Epsilon Constant",
    type = ITEM_TYPE.MATERIAL,
    rarity = "UNCOMMON",
    description = "A magical number: 1e-9. Obtained from Quest A1.",
    quest_item = true,
    soulbound = true,
})

ItemRegistry.register({
    id = "deep_copy_scroll",
    name = "Scroll of Deep Copy",
    type = ITEM_TYPE.MATERIAL,
    rarity = "RARE",
    description = "Contains the deep_copy() function. From Bounty B03.",
    quest_item = true,
    soulbound = true,
})
-- }}}

-- {{{ Module exports
return {
    Item = Item,
    ItemRegistry = ItemRegistry,

    -- Constants
    ITEM_TYPE = ITEM_TYPE,
    RARITY = RARITY,
    EQUIPMENT_SLOT = EQUIPMENT_SLOT,
    EFFECT_TYPE = EFFECT_TYPE,
}
-- }}}
