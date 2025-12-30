#!/usr/bin/env luajit
--[[
Hero Unit System

Stores adventurer progress, inventory, and capabilities.
Modeled after WC3 hero mechanics with abstracted game systems.

Hero structure mirrors WC3 data patterns:
- Level progression with XP thresholds
- 6-slot inventory (like WC3 hero inventory)
- Equipment slots (weapon, armor, accessory)
- Stat attributes that can be modified
- Capabilities unlocked from quest completion
]]

local DIR = arg and arg[0] and arg[0]:match("(.*/)") or "./"

-- {{{ Constants
local INVENTORY_SIZE = 6
local EQUIPMENT_SLOTS = { "weapon", "armor", "accessory" }
local MAX_LEVEL = 25

-- XP thresholds per level (WC3-inspired curve)
local XP_THRESHOLDS = {
    [1] = 0,
    [2] = 200,
    [3] = 500,
    [4] = 900,
    [5] = 1400,
    [6] = 2000,
    [7] = 2700,
    [8] = 3500,
    [9] = 4400,
    [10] = 5400,
    [11] = 6500,
    [12] = 7700,
    [13] = 9000,
    [14] = 10400,
    [15] = 11900,
    [16] = 13500,
    [17] = 15200,
    [18] = 17000,
    [19] = 18900,
    [20] = 20900,
    [21] = 23000,
    [22] = 25200,
    [23] = 27500,
    [24] = 29900,
    [25] = 32400,
}

-- Base stats (WC3-inspired)
local BASE_STATS = {
    strength = 10,      -- Affects max quests in progress
    agility = 10,       -- Affects quest completion speed bonus
    intelligence = 10,  -- Affects capability unlock rate
    endurance = 100,    -- Max "energy" for daily quests
}

-- FIXME: Add WoW-style primary attributes
-- local WOW_PRIMARY_STATS = {
--     strength = 10,      -- Physical damage, block value
--     agility = 10,       -- Crit chance, dodge, attack power (rogues/hunters)
--     stamina = 10,       -- Health points (10 stamina = 100 HP)
--     intellect = 10,     -- Mana pool, spell crit
--     spirit = 10,        -- Mana/health regen out of combat
-- }

-- FIXME: Add WoW-style secondary stats
-- local WOW_SECONDARY_STATS = {
--     attack_power = 0,       -- Melee/ranged damage modifier
--     spell_power = 0,        -- Spell damage/healing modifier
--     armor = 0,              -- Physical damage reduction
--     crit_rating = 0,        -- Critical strike chance
--     haste_rating = 0,       -- Attack/cast speed increase
--     hit_rating = 0,         -- Reduces miss chance
--     dodge_rating = 0,       -- Chance to avoid attacks
--     parry_rating = 0,       -- Chance to parry (warriors/paladins)
--     block_rating = 0,       -- Chance to block with shield
--     resilience = 0,         -- PvP damage reduction
--     mastery = 0,            -- Spec-specific bonus
-- }

-- FIXME: Add WoW-style derived combat stats
-- local WOW_COMBAT_STATS = {
--     health = 100,           -- Current HP
--     max_health = 100,       -- Base + stamina * 10
--     mana = 100,             -- Current mana (if applicable)
--     max_mana = 100,         -- Base + intellect * 15
--     rage = 0,               -- Warrior resource (0-100)
--     energy = 100,           -- Rogue/cat resource (regenerates)
--     combo_points = 0,       -- Rogue/cat finisher resource
--     runic_power = 0,        -- Death knight resource
--     focus = 100,            -- Hunter resource
-- }

-- FIXME: Add WoW-style armor calculation
-- function calculate_armor_reduction(armor, attacker_level)
--     -- WoW armor formula (vanilla approximation)
--     -- Reduction = armor / (armor + 400 + 85 * attacker_level)
--     return armor / (armor + 400 + 85 * attacker_level)
-- end

-- FIXME: Add WoW-style damage calculation
-- function calculate_physical_damage(base_damage, attack_power, armor_reduction)
--     -- Base damage + (attack_power / 14) per second of weapon speed
--     local modified = base_damage + (attack_power / 14)
--     return modified * (1 - armor_reduction)
-- end

-- FIXME: Add WoW-style spell damage calculation
-- function calculate_spell_damage(base_damage, spell_power, coefficient)
--     -- Spell damage + (spell_power * coefficient)
--     -- Coefficient based on cast time: cast_time / 3.5 for damage spells
--     return base_damage + (spell_power * coefficient)
-- end

-- Stat growth per level
local STAT_GROWTH = {
    strength = 2,
    agility = 2,
    intelligence = 3,
    endurance = 10,
}

-- Titles based on level ranges
local TITLES = {
    { min = 1, max = 3, title = "Initiate" },
    { min = 4, max = 6, title = "Apprentice" },
    { min = 7, max = 10, title = "Journeyman" },
    { min = 11, max = 15, title = "Veteran" },
    { min = 16, max = 20, title = "Master" },
    { min = 21, max = 24, title = "Grand Master" },
    { min = 25, max = 25, title = "Legend" },
}
-- }}}

-- {{{ Hero class
local Hero = {}
Hero.__index = Hero

-- {{{ new
function Hero.new(name)
    local self = setmetatable({}, Hero)

    self.name = name or "Unknown Adventurer"
    self.level = 1
    self.xp = 0
    self.gold = 0

    -- Stats (base + level bonuses + equipment bonuses)
    self.base_stats = {}
    for stat, value in pairs(BASE_STATS) do
        self.base_stats[stat] = value
    end

    -- Inventory: 6 slots like WC3 hero
    self.inventory = {}
    for i = 1, INVENTORY_SIZE do
        self.inventory[i] = nil
    end

    -- Equipment: separate from inventory
    self.equipment = {}
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        self.equipment[slot] = nil
    end

    -- Quest tracking
    self.completed_quests = {}  -- quest_id -> completion_data
    self.active_quests = {}     -- quest_id -> start_time
    self.completed_bounties = {} -- bounty_id -> completion_data

    -- Capabilities unlocked from quests
    self.capabilities = {}  -- capability_name -> true

    -- Achievements/titles earned
    self.titles = { "Initiate" }
    self.active_title = "Initiate"

    -- Timestamps
    self.created_at = os.time()
    self.last_active = os.time()

    return self
end
-- }}}

-- {{{ get_level_for_xp
function Hero.get_level_for_xp(xp)
    local level = 1
    for lvl = 1, MAX_LEVEL do
        if xp >= (XP_THRESHOLDS[lvl] or math.huge) then
            level = lvl
        else
            break
        end
    end
    return level
end
-- }}}

-- {{{ get_xp_for_next_level
function Hero:get_xp_for_next_level()
    if self.level >= MAX_LEVEL then
        return nil  -- Max level
    end
    return XP_THRESHOLDS[self.level + 1]
end
-- }}}

-- {{{ get_xp_progress
function Hero:get_xp_progress()
    local current_threshold = XP_THRESHOLDS[self.level] or 0
    local next_threshold = XP_THRESHOLDS[self.level + 1]

    if not next_threshold then
        return 1.0, 0, 0  -- Max level
    end

    local level_xp = self.xp - current_threshold
    local level_range = next_threshold - current_threshold

    return level_xp / level_range, level_xp, level_range
end
-- }}}

-- {{{ add_xp
function Hero:add_xp(amount)
    local old_level = self.level
    self.xp = self.xp + amount
    self.level = Hero.get_level_for_xp(self.xp)

    -- Check for level up
    local leveled_up = self.level > old_level
    if leveled_up then
        self:_on_level_up(old_level, self.level)
    end

    return leveled_up, self.level - old_level
end
-- }}}

-- {{{ _on_level_up
function Hero:_on_level_up(old_level, new_level)
    -- Update title if threshold crossed
    for _, tier in ipairs(TITLES) do
        if new_level >= tier.min and new_level <= tier.max then
            if not self:has_title(tier.title) then
                table.insert(self.titles, tier.title)
                self.active_title = tier.title
            end
            break
        end
    end
end
-- }}}

-- {{{ get_stat
function Hero:get_stat(stat_name)
    local base = self.base_stats[stat_name] or 0

    -- Level bonus
    local level_bonus = (self.level - 1) * (STAT_GROWTH[stat_name] or 0)

    -- Equipment bonus
    local equip_bonus = 0
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local item = self.equipment[slot]
        if item and item.stats and item.stats[stat_name] then
            equip_bonus = equip_bonus + item.stats[stat_name]
        end
    end

    -- Item bonus (from inventory items with passive effects)
    local item_bonus = 0
    for i = 1, INVENTORY_SIZE do
        local item = self.inventory[i]
        if item and item.passive_stats and item.passive_stats[stat_name] then
            item_bonus = item_bonus + item.passive_stats[stat_name]
        end
    end

    return base + level_bonus + equip_bonus + item_bonus
end
-- }}}

-- {{{ get_all_stats
function Hero:get_all_stats()
    local stats = {}
    for stat_name, _ in pairs(BASE_STATS) do
        stats[stat_name] = self:get_stat(stat_name)
    end
    return stats
end
-- }}}

-- {{{ add_gold
function Hero:add_gold(amount)
    self.gold = self.gold + amount
    return self.gold
end
-- }}}

-- {{{ spend_gold
function Hero:spend_gold(amount)
    if self.gold < amount then
        return false, "Insufficient gold"
    end
    self.gold = self.gold - amount
    return true
end
-- }}}

-- {{{ add_to_inventory
function Hero:add_to_inventory(item)
    -- Find first empty slot
    for i = 1, INVENTORY_SIZE do
        if not self.inventory[i] then
            self.inventory[i] = item
            return true, i
        end
    end
    return false, "Inventory full"
end
-- }}}

-- {{{ remove_from_inventory
function Hero:remove_from_inventory(slot)
    if slot < 1 or slot > INVENTORY_SIZE then
        return nil, "Invalid slot"
    end
    local item = self.inventory[slot]
    self.inventory[slot] = nil
    return item
end
-- }}}

-- {{{ get_inventory_count
function Hero:get_inventory_count()
    local count = 0
    for i = 1, INVENTORY_SIZE do
        if self.inventory[i] then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ equip
function Hero:equip(item)
    local slot = item.slot
    if not slot then
        return false, "Item has no equipment slot"
    end

    -- Check if slot is valid
    local valid_slot = false
    for _, s in ipairs(EQUIPMENT_SLOTS) do
        if s == slot then
            valid_slot = true
            break
        end
    end
    if not valid_slot then
        return false, "Invalid equipment slot: " .. tostring(slot)
    end

    -- Check level requirement
    if item.level_req and self.level < item.level_req then
        return false, "Requires level " .. item.level_req
    end

    -- Unequip current item if any
    local old_item = self.equipment[slot]
    if old_item then
        local ok, err = self:add_to_inventory(old_item)
        if not ok then
            return false, "Cannot unequip: " .. err
        end
    end

    -- Equip new item
    self.equipment[slot] = item

    -- Remove from inventory if it was there
    for i = 1, INVENTORY_SIZE do
        if self.inventory[i] == item then
            self.inventory[i] = nil
            break
        end
    end

    return true
end
-- }}}

-- {{{ unequip
function Hero:unequip(slot)
    local item = self.equipment[slot]
    if not item then
        return nil, "Nothing equipped in slot"
    end

    local ok, result = self:add_to_inventory(item)
    if not ok then
        return nil, "Cannot unequip: " .. result
    end

    self.equipment[slot] = nil
    return item
end
-- }}}

-- {{{ complete_quest
function Hero:complete_quest(quest_id, quest_data)
    if self.completed_quests[quest_id] then
        return false, "Quest already completed"
    end

    -- Record completion
    self.completed_quests[quest_id] = {
        completed_at = os.time(),
        xp_earned = quest_data.xp or 0,
        gold_earned = quest_data.gold or 0,
        capability = quest_data.capability,
    }

    -- Remove from active if present
    self.active_quests[quest_id] = nil

    -- Award XP
    if quest_data.xp then
        self:add_xp(quest_data.xp)
    end

    -- Award gold
    if quest_data.gold then
        self:add_gold(quest_data.gold)
    end

    -- Unlock capability
    if quest_data.capability then
        self.capabilities[quest_data.capability] = true
    end

    return true
end
-- }}}

-- {{{ complete_bounty
function Hero:complete_bounty(bounty_id, bounty_data)
    if self.completed_bounties[bounty_id] then
        return false, "Bounty already completed"
    end

    -- Record completion
    self.completed_bounties[bounty_id] = {
        completed_at = os.time(),
        xp_earned = bounty_data.xp or 0,
        gold_earned = bounty_data.gold or 0,
        capability = bounty_data.capability,
    }

    -- Award XP (bounties give more)
    if bounty_data.xp then
        self:add_xp(bounty_data.xp)
    end

    -- Award gold
    if bounty_data.gold then
        self:add_gold(bounty_data.gold)
    end

    -- Unlock capability
    if bounty_data.capability then
        self.capabilities[bounty_data.capability] = true
    end

    -- Special title for first bounty
    if self:get_bounty_count() == 1 then
        if not self:has_title("Dragon Slayer") then
            table.insert(self.titles, "Dragon Slayer")
        end
    end

    return true
end
-- }}}

-- {{{ has_capability
function Hero:has_capability(capability_name)
    return self.capabilities[capability_name] == true
end
-- }}}

-- {{{ get_quest_count
function Hero:get_quest_count()
    local count = 0
    for _ in pairs(self.completed_quests) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ get_bounty_count
function Hero:get_bounty_count()
    local count = 0
    for _ in pairs(self.completed_bounties) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ has_title
function Hero:has_title(title)
    for _, t in ipairs(self.titles) do
        if t == title then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ set_active_title
function Hero:set_active_title(title)
    if self:has_title(title) then
        self.active_title = title
        return true
    end
    return false, "Title not earned"
end
-- }}}

-- {{{ serialize
function Hero:serialize()
    return {
        name = self.name,
        level = self.level,
        xp = self.xp,
        gold = self.gold,
        base_stats = self.base_stats,
        inventory = self.inventory,
        equipment = self.equipment,
        completed_quests = self.completed_quests,
        active_quests = self.active_quests,
        completed_bounties = self.completed_bounties,
        capabilities = self.capabilities,
        titles = self.titles,
        active_title = self.active_title,
        created_at = self.created_at,
        last_active = self.last_active,
    }
end
-- }}}

-- {{{ deserialize
function Hero.deserialize(data, ItemClass)
    local hero = setmetatable({}, Hero)

    hero.name = data.name or "Unknown Adventurer"
    hero.level = data.level or 1
    hero.xp = data.xp or 0
    hero.gold = data.gold or 0
    hero.base_stats = data.base_stats or {}
    hero.completed_quests = data.completed_quests or {}
    hero.active_quests = data.active_quests or {}
    hero.completed_bounties = data.completed_bounties or {}
    hero.capabilities = data.capabilities or {}
    hero.titles = data.titles or { "Initiate" }
    hero.active_title = data.active_title or "Initiate"
    hero.created_at = data.created_at or os.time()
    hero.last_active = data.last_active or os.time()

    -- Reconstruct inventory items with proper metatable
    hero.inventory = {}
    for i = 1, INVENTORY_SIZE do
        local item_data = data.inventory and data.inventory[i]
        if item_data and ItemClass then
            hero.inventory[i] = ItemClass.new(item_data)
        elseif item_data then
            hero.inventory[i] = item_data  -- Keep raw if no ItemClass
        else
            hero.inventory[i] = nil
        end
    end

    -- Reconstruct equipment with proper metatable
    hero.equipment = {}
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local item_data = data.equipment and data.equipment[slot]
        if item_data and ItemClass then
            hero.equipment[slot] = ItemClass.new(item_data)
        elseif item_data then
            hero.equipment[slot] = item_data
        else
            hero.equipment[slot] = nil
        end
    end

    return hero
end
-- }}}

-- {{{ format
function Hero:format()
    local lines = {}

    table.insert(lines, string.format("=== %s ===", self.name))
    table.insert(lines, string.format("Title: %s", self.active_title))
    table.insert(lines, string.format("Level: %d", self.level))

    local progress, current, needed = self:get_xp_progress()
    if needed > 0 then
        table.insert(lines, string.format("XP: %d / %d (%.0f%%)",
            self.xp, self:get_xp_for_next_level() or self.xp, progress * 100))
    else
        table.insert(lines, string.format("XP: %d (MAX LEVEL)", self.xp))
    end

    table.insert(lines, string.format("Gold: %d", self.gold))
    table.insert(lines, "")

    -- Stats
    table.insert(lines, "Stats:")
    local stats = self:get_all_stats()
    for stat, value in pairs(stats) do
        table.insert(lines, string.format("  %s: %d", stat, value))
    end
    table.insert(lines, "")

    -- Equipment
    table.insert(lines, "Equipment:")
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local item = self.equipment[slot]
        local item_name = item and item.name or "(empty)"
        table.insert(lines, string.format("  [%s] %s", slot, item_name))
    end
    table.insert(lines, "")

    -- Inventory
    table.insert(lines, "Inventory:")
    local has_items = false
    for i = 1, INVENTORY_SIZE do
        local item = self.inventory[i]
        if item then
            has_items = true
            table.insert(lines, string.format("  [%d] %s", i, item.name))
        end
    end
    if not has_items then
        table.insert(lines, "  (empty)")
    end
    table.insert(lines, "")

    -- Progress
    table.insert(lines, string.format("Quests Completed: %d", self:get_quest_count()))
    table.insert(lines, string.format("Bounties Claimed: %d", self:get_bounty_count()))

    -- Capabilities
    local cap_count = 0
    for _ in pairs(self.capabilities) do cap_count = cap_count + 1 end
    table.insert(lines, string.format("Capabilities Unlocked: %d", cap_count))

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ __tostring
function Hero:__tostring()
    return string.format("Hero<%s, Lv.%d %s>", self.name, self.level, self.active_title)
end
-- }}}
-- }}}

-- {{{ Module exports
return {
    Hero = Hero,

    -- Constants
    INVENTORY_SIZE = INVENTORY_SIZE,
    EQUIPMENT_SLOTS = EQUIPMENT_SLOTS,
    MAX_LEVEL = MAX_LEVEL,
    XP_THRESHOLDS = XP_THRESHOLDS,
    BASE_STATS = BASE_STATS,
    STAT_GROWTH = STAT_GROWTH,
    TITLES = TITLES,
}
-- }}}
