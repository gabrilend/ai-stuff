--[[
Reputation System - Per-Faction Standing Tracker

Manages faction reputations from Hated (-42000) to Exalted (+42999).
Each character can have standing with multiple factions.

Standing Levels (Vanilla WoW):
  Hated      -42000 to -6001   (hostile, will attack)
  Hostile    -6000  to -3001   (hostile, will attack)
  Unfriendly -3000  to -1      (will not interact)
  Neutral    0      to 2999    (basic interaction)
  Friendly   3000   to 8999    (discounts available)
  Honored    9000   to 20999   (more discounts)
  Revered    21000  to 41999   (rare items available)
  Exalted    42000  to 42999   (best rewards)

Usage:
  local reputation = require("runtime.currency.reputation")
  reputation.set(entity, "thrallmar", 9000)  -- Set to Honored
  print(reputation.get_standing_name(entity, "thrallmar"))  -- "Honored"
]]

local registry = require("runtime.currency.registry")

local reputation = {}

-- {{{ Constants
-- Use registry's standing thresholds
reputation.STANDING_THRESHOLDS = registry.STANDING_THRESHOLDS

-- Minimum and maximum reputation values
reputation.MIN_REPUTATION = -42000
reputation.MAX_REPUTATION = 42999

-- Default starting reputation for new factions
reputation.DEFAULT_STANDING = 0  -- Neutral
-- }}}

-- {{{ Faction definitions
-- Classic/Vanilla factions with their default starting standings
-- Note: This is extensible - maps can add custom factions
reputation.FACTIONS = {
    -- Alliance
    stormwind = { name = "Stormwind", default = 0, side = "alliance" },
    ironforge = { name = "Ironforge", default = 0, side = "alliance" },
    darnassus = { name = "Darnassus", default = 0, side = "alliance" },
    gnomeregan = { name = "Gnomeregan Exiles", default = 0, side = "alliance" },

    -- Horde
    orgrimmar = { name = "Orgrimmar", default = 0, side = "horde" },
    thunder_bluff = { name = "Thunder Bluff", default = 0, side = "horde" },
    undercity = { name = "Undercity", default = 0, side = "horde" },
    darkspear = { name = "Darkspear Trolls", default = 0, side = "horde" },

    -- TBC Horde
    thrallmar = { name = "Thrallmar", default = 0, side = "horde", expansion = "tbc" },
    mok_nathal = { name = "Mok'Nathal", default = 0, side = "horde", expansion = "tbc" },

    -- TBC Alliance
    honor_hold = { name = "Honor Hold", default = 0, side = "alliance", expansion = "tbc" },

    -- Neutral
    argent_dawn = { name = "Argent Dawn", default = 0, side = "neutral" },
    cenarion_circle = { name = "Cenarion Circle", default = 0, side = "neutral" },
    thorium_brotherhood = { name = "Thorium Brotherhood", default = 0, side = "neutral" },
    timbermaw_hold = { name = "Timbermaw Hold", default = -6000, side = "neutral" },  -- Starts hostile
    bloodsail_buccaneers = { name = "Bloodsail Buccaneers", default = -42000, side = "neutral" },  -- Hated

    -- Steamwheedle Cartel
    booty_bay = { name = "Booty Bay", default = 0, side = "neutral" },
    everlook = { name = "Everlook", default = 0, side = "neutral" },
    gadgetzan = { name = "Gadgetzan", default = 0, side = "neutral" },
    ratchet = { name = "Ratchet", default = 0, side = "neutral" },
}
-- }}}

-- {{{ Component defaults
-- ECS component structure for reputation storage
reputation.COMPONENT_DEFAULTS = {
    -- Faction ID -> standing value
    standings = {},

    -- Watched faction (shown on XP bar)
    watched_faction = nil,

    -- Modifiers (from items, buffs, etc.)
    modifiers = {},
}
-- }}}

-- {{{ reputation.register_component
-- Register the reputation ECS component.
function reputation.register_component()
    local ecs = require("runtime.ecs")
    local component = ecs.component or require("runtime.ecs.component")

    if component.get_defaults and component.get_defaults("reputation") then
        return
    end

    component.register("reputation", reputation.COMPONENT_DEFAULTS)
end
-- }}}

-- {{{ reputation.create
-- Create a fresh reputation data structure.
-- @param side Optional "alliance" or "horde" to initialize faction standings
-- @return New reputation table
function reputation.create(side)
    local rep = {
        standings = {},
        watched_faction = nil,
        modifiers = {},
    }

    -- Initialize faction standings based on side
    for faction_id, faction in pairs(reputation.FACTIONS) do
        if faction.side == side then
            -- Friendly with own faction
            rep.standings[faction_id] = 3000  -- Friendly
        elseif faction.side ~= "neutral" and faction.side ~= side and side then
            -- Hostile with opposing faction
            rep.standings[faction_id] = -6000  -- Hostile
        else
            -- Use default for neutral or unaffiliated
            rep.standings[faction_id] = faction.default
        end
    end

    return rep
end
-- }}}

-- {{{ reputation.get
-- Get standing value with a faction.
-- @param rep Reputation table (from component or create())
-- @param faction_id Faction identifier
-- @return Standing value, or nil if faction unknown
function reputation.get(rep, faction_id)
    if not rep or not rep.standings then
        return reputation.DEFAULT_STANDING
    end
    return rep.standings[faction_id] or reputation.DEFAULT_STANDING
end
-- }}}

-- {{{ reputation.set
-- Set standing with a faction.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @param value New standing value (clamped to valid range)
-- @return New standing value
function reputation.set(rep, faction_id, value)
    if not rep then return nil end
    rep.standings = rep.standings or {}

    -- Clamp to valid range
    value = math.max(reputation.MIN_REPUTATION, math.min(value, reputation.MAX_REPUTATION))
    rep.standings[faction_id] = value

    return value
end
-- }}}

-- {{{ reputation.add
-- Add to standing with a faction.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @param amount Amount to add (can be negative)
-- @return New standing value
function reputation.add(rep, faction_id, amount)
    local current = reputation.get(rep, faction_id)
    return reputation.set(rep, faction_id, current + amount)
end
-- }}}

-- {{{ reputation.get_standing_name
-- Get the standing level name for a faction.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return Standing name string (e.g., "Honored")
function reputation.get_standing_name(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    return registry.get_standing_name(value)
end
-- }}}

-- {{{ reputation.get_standing_index
-- Get the standing level index for a faction.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return Standing index (1-8, where 4 is Neutral)
function reputation.get_standing_index(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    return registry.get_standing_index(value)
end
-- }}}

-- {{{ reputation.get_progress
-- Get progress within current standing level.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return current, max, percent (within current tier)
function reputation.get_progress(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    local index = reputation.get_standing_index(rep, faction_id)
    local threshold = reputation.STANDING_THRESHOLDS[index]

    if not threshold then
        return 0, 1, 0
    end

    local range = threshold.max - threshold.min + 1
    local progress = value - threshold.min
    local percent = (progress / range) * 100

    return progress, range, percent
end
-- }}}

-- {{{ reputation.is_friendly
-- Check if standing is Friendly or higher.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return true if Friendly+
function reputation.is_friendly(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    return value >= 3000
end
-- }}}

-- {{{ reputation.is_hostile
-- Check if standing is Hostile or lower.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return true if Hostile or Hated
function reputation.is_hostile(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    return value < -3000
end
-- }}}

-- {{{ reputation.is_exalted
-- Check if standing is Exalted.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return true if Exalted
function reputation.is_exalted(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    return value >= 42000
end
-- }}}

-- {{{ reputation.can_interact
-- Check if character can interact with faction vendors/NPCs.
-- Unfriendly or worse blocks most interactions.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return true if can interact
function reputation.can_interact(rep, faction_id)
    local value = reputation.get(rep, faction_id)
    return value >= 0  -- Neutral or better
end
-- }}}

-- {{{ reputation.get_discount
-- Get vendor discount percentage based on standing.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return Discount multiplier (1.0 = no discount, 0.9 = 10% off)
function reputation.get_discount(rep, faction_id)
    local value = reputation.get(rep, faction_id)

    if value >= 42000 then  -- Exalted
        return 0.80  -- 20% discount
    elseif value >= 21000 then  -- Revered
        return 0.85  -- 15% discount
    elseif value >= 9000 then  -- Honored
        return 0.90  -- 10% discount
    elseif value >= 3000 then  -- Friendly
        return 0.95  -- 5% discount
    else
        return 1.0   -- No discount
    end
end
-- }}}

-- {{{ reputation.set_watched
-- Set the watched faction (shown on XP bar).
-- @param rep Reputation table
-- @param faction_id Faction identifier (or nil to clear)
function reputation.set_watched(rep, faction_id)
    if not rep then return end
    rep.watched_faction = faction_id
end
-- }}}

-- {{{ reputation.get_watched
-- Get the currently watched faction.
-- @param rep Reputation table
-- @return Faction ID or nil
function reputation.get_watched(rep)
    if not rep then return nil end
    return rep.watched_faction
end
-- }}}

-- {{{ reputation.get_faction_info
-- Get faction metadata.
-- @param faction_id Faction identifier
-- @return Faction info table or nil
function reputation.get_faction_info(faction_id)
    return reputation.FACTIONS[faction_id]
end
-- }}}

-- {{{ reputation.get_all_factions
-- Get list of all faction IDs.
-- @return Array of faction ID strings
function reputation.get_all_factions()
    local result = {}
    for id in pairs(reputation.FACTIONS) do
        result[#result + 1] = id
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ reputation.get_factions_by_side
-- Get factions filtered by side.
-- @param side "alliance", "horde", or "neutral"
-- @return Array of faction ID strings
function reputation.get_factions_by_side(side)
    local result = {}
    for id, faction in pairs(reputation.FACTIONS) do
        if faction.side == side then
            result[#result + 1] = id
        end
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ reputation.register_faction
-- Register a custom faction.
-- @param faction_id Unique identifier
-- @param info Table with name, default, side fields
function reputation.register_faction(faction_id, info)
    info.default = info.default or 0
    info.side = info.side or "neutral"
    reputation.FACTIONS[faction_id] = info
end
-- }}}

-- {{{ reputation.format
-- Format reputation for display.
-- @param rep Reputation table
-- @param faction_id Faction identifier
-- @return Formatted string like "Honored (15000/21000)"
function reputation.format(rep, faction_id)
    local standing = reputation.get_standing_name(rep, faction_id)
    local current, max, percent = reputation.get_progress(rep, faction_id)

    return string.format("%s (%d/%d - %.0f%%)", standing, current, max, percent)
end
-- }}}

-- {{{ reputation.reset
-- Reset all reputations to defaults.
-- @param rep Reputation table
function reputation.reset(rep)
    if not rep then return end
    rep.standings = {}
    rep.watched_faction = nil
    rep.modifiers = {}
end
-- }}}

return reputation
