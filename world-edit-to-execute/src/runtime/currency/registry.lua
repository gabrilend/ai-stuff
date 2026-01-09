--[[
Currency Registry - Schema Definitions and Category Constants

Defines all currency types with their properties, caps, and behaviors.
Uses dispatch table pattern from Issue 016 for O(1) lookup.

Currency Categories:
- PHYSICAL: Coins in dedicated bag slots (copper, silver, gold)
- ABSTRACT: Pure counters with caps (honor, arena, justice, valor)
- TOKEN: Physical items that stack in bags (marks, badges)
- REPUTATION: Per-faction standings (-42000 to +42999)
- SKILL: Profession/weapon skills (1-300+)
- WC3_RESOURCE: Player-level resources (gold, lumber, food)
]]

local registry = {}

-- {{{ CURRENCY_CATEGORY
-- Enum for currency storage and behavior types
registry.CURRENCY_CATEGORY = {
    PHYSICAL = 1,      -- Coins in dedicated bag slots
    ABSTRACT = 2,      -- Pure counters (honor, arena points)
    TOKEN = 3,         -- Physical tokens in inventory
    REPUTATION = 4,    -- Per-faction standings
    SKILL = 5,         -- Profession/weapon skills
    WC3_RESOURCE = 6,  -- Classic WC3 per-player resources
}
-- }}}

-- {{{ STANDING_THRESHOLDS
-- Reputation standing levels (Vanilla WoW)
registry.STANDING_THRESHOLDS = {
    { name = "Hated",      min = -42000, max = -6001, index = 1 },
    { name = "Hostile",    min = -6000,  max = -3001, index = 2 },
    { name = "Unfriendly", min = -3000,  max = -1,    index = 3 },
    { name = "Neutral",    min = 0,      max = 2999,  index = 4 },
    { name = "Friendly",   min = 3000,   max = 8999,  index = 5 },
    { name = "Honored",    min = 9000,   max = 20999, index = 6 },
    { name = "Revered",    min = 21000,  max = 41999, index = 7 },
    { name = "Exalted",    min = 42000,  max = 42999, index = 8 },
}
-- }}}

-- {{{ HONOR_RANKS
-- Vanilla PvP honor ranks (Alliance titles shown, Horde equivalent exists)
registry.HONOR_RANKS = {
    [0]  = { alliance = "None",           horde = "None",           min_honor = 0 },
    [1]  = { alliance = "Private",        horde = "Scout",          min_honor = 15 },
    [2]  = { alliance = "Corporal",       horde = "Grunt",          min_honor = 2000 },
    [3]  = { alliance = "Sergeant",       horde = "Sergeant",       min_honor = 5000 },
    [4]  = { alliance = "Master Sergeant",horde = "Senior Sergeant",min_honor = 10000 },
    [5]  = { alliance = "Sergeant Major", horde = "First Sergeant", min_honor = 15000 },
    [6]  = { alliance = "Knight",         horde = "Stone Guard",    min_honor = 20000 },
    [7]  = { alliance = "Knight-Lieutenant", horde = "Blood Guard", min_honor = 25000 },
    [8]  = { alliance = "Knight-Captain", horde = "Legionnaire",    min_honor = 30000 },
    [9]  = { alliance = "Knight-Champion",horde = "Centurion",      min_honor = 35000 },
    [10] = { alliance = "Lieutenant Commander", horde = "Champion", min_honor = 40000 },
    [11] = { alliance = "Commander",      horde = "Lieutenant General", min_honor = 45000 },
    [12] = { alliance = "Marshal",        horde = "General",        min_honor = 50000 },
    [13] = { alliance = "Field Marshal",  horde = "Warlord",        min_honor = 55000 },
    [14] = { alliance = "Grand Marshal",  horde = "High Warlord",   min_honor = 60000 },
}
-- }}}

-- {{{ CURRENCY_SCHEMA
-- Master registry of all currency types
-- Each currency has:
--   index: Numeric ID for dispatch table
--   category: CURRENCY_CATEGORY value
--   cap: Maximum value (nil = unlimited)
--   default: Starting value
--   display_name: Human-readable name
--   icon: Asset reference (optional)
--   conversion: For physical money, rate to lower denomination
--   weekly_cap: Weekly earning limit (optional)
--   decay_rate: Weekly decay percentage (optional)
--   scope: "character", "account", or "player" (WC3)

registry.CURRENCY_SCHEMA = {
    -- =========================================================================
    -- Physical Money (WoW coins in dedicated bag slots)
    -- =========================================================================
    copper = {
        index = 1,
        category = registry.CURRENCY_CATEGORY.PHYSICAL,
        cap = nil,  -- Unlimited (display handles overflow)
        default = 0,
        display_name = "Copper",
        icon = "inv_misc_coin_01",
        item_id = "currency_copper",
        stack_max = 9999,
        conversion = nil,  -- Base unit
    },
    silver = {
        index = 2,
        category = registry.CURRENCY_CATEGORY.PHYSICAL,
        cap = nil,
        default = 0,
        display_name = "Silver",
        icon = "inv_misc_coin_03",
        item_id = "currency_silver",
        stack_max = 9999,
        conversion = { to = "copper", rate = 100 },
    },
    gold = {
        index = 3,
        category = registry.CURRENCY_CATEGORY.PHYSICAL,
        cap = nil,
        default = 0,
        display_name = "Gold",
        icon = "inv_misc_coin_07",
        item_id = "currency_gold",
        stack_max = 9999,
        conversion = { to = "silver", rate = 100 },
    },

    -- =========================================================================
    -- Abstract Currencies (PvP/PvE point systems)
    -- =========================================================================
    honor = {
        index = 10,
        category = registry.CURRENCY_CATEGORY.ABSTRACT,
        cap = 75000,
        weekly_cap = nil,  -- Vanilla had weekly contribution, not cap
        decay_rate = 0.25,  -- 25% weekly decay in Vanilla
        default = 0,
        display_name = "Honor",
        icon = "inv_misc_token_pvp",
        scope = "character",
    },
    arena_points = {
        index = 11,
        category = registry.CURRENCY_CATEGORY.ABSTRACT,
        cap = 10000,
        weekly_cap = 5000,
        decay_rate = 0,
        default = 0,
        display_name = "Arena Points",
        icon = "inv_misc_token_arena",
        scope = "character",
    },
    justice_points = {
        index = 12,
        category = registry.CURRENCY_CATEGORY.ABSTRACT,
        cap = 4000,
        weekly_cap = nil,
        decay_rate = 0,
        default = 0,
        display_name = "Justice Points",
        icon = "pvecurrency-justice",
        scope = "account",
    },
    valor_points = {
        index = 13,
        category = registry.CURRENCY_CATEGORY.ABSTRACT,
        cap = 4000,
        weekly_cap = 1000,
        decay_rate = 0,
        default = 0,
        display_name = "Valor Points",
        icon = "pvecurrency-valor",
        scope = "account",
    },
    conquest_points = {
        index = 14,
        category = registry.CURRENCY_CATEGORY.ABSTRACT,
        cap = 4000,
        weekly_cap = 1800,
        decay_rate = 0,
        default = 0,
        display_name = "Conquest Points",
        icon = "pvecurrency-conquest",
        scope = "character",
    },

    -- =========================================================================
    -- Token Currencies (Physical items in inventory)
    -- =========================================================================
    mark_warsong = {
        index = 20,
        category = registry.CURRENCY_CATEGORY.TOKEN,
        cap = nil,
        default = 0,
        display_name = "Warsong Gulch Mark of Honor",
        icon = "inv_misc_token_battleground",
        item_id = "mark_warsong_gulch",
        stack_max = 20,
    },
    mark_arathi = {
        index = 21,
        category = registry.CURRENCY_CATEGORY.TOKEN,
        cap = nil,
        default = 0,
        display_name = "Arathi Basin Mark of Honor",
        icon = "inv_jewelry_amulet_07",
        item_id = "mark_arathi_basin",
        stack_max = 20,
    },
    mark_alterac = {
        index = 22,
        category = registry.CURRENCY_CATEGORY.TOKEN,
        cap = nil,
        default = 0,
        display_name = "Alterac Valley Mark of Honor",
        icon = "inv_jewelry_necklace_21",
        item_id = "mark_alterac_valley",
        stack_max = 20,
    },
    badge_justice = {
        index = 23,
        category = registry.CURRENCY_CATEGORY.TOKEN,
        cap = nil,
        default = 0,
        display_name = "Badge of Justice",
        icon = "spell_holy_championsbond",
        item_id = "badge_of_justice",
        stack_max = 200,
    },

    -- =========================================================================
    -- WC3 Resources (Player-level, not character-level)
    -- =========================================================================
    wc3_gold = {
        index = 100,
        category = registry.CURRENCY_CATEGORY.WC3_RESOURCE,
        cap = 999999,
        default = 0,
        display_name = "Gold",
        icon = "goldcoin",
        scope = "player",
        -- Conversion to WoW copper: 1 WC3 gold = 100 copper
        wow_conversion = { to = "copper", rate = 100 },
    },
    wc3_lumber = {
        index = 101,
        category = registry.CURRENCY_CATEGORY.WC3_RESOURCE,
        cap = 999999,
        default = 0,
        display_name = "Lumber",
        icon = "lumber",
        scope = "player",
    },
    wc3_food_used = {
        index = 102,
        category = registry.CURRENCY_CATEGORY.WC3_RESOURCE,
        cap = 300,
        default = 0,
        display_name = "Food Used",
        scope = "player",
    },
    wc3_food_cap = {
        index = 103,
        category = registry.CURRENCY_CATEGORY.WC3_RESOURCE,
        cap = 300,
        default = 0,
        display_name = "Food Cap",
        scope = "player",
    },
}
-- }}}

-- {{{ Index lookup tables
-- Built on module load for O(1) access
registry._by_index = {}
registry._by_name = {}

for name, schema in pairs(registry.CURRENCY_SCHEMA) do
    registry._by_index[schema.index] = schema
    registry._by_index[schema.index].name = name
    registry._by_name[name] = schema
end
-- }}}

-- {{{ registry.get_schema
-- Get currency schema by name or index.
-- @param id Currency name (string) or index (number)
-- @return Schema table or nil
function registry.get_schema(id)
    if type(id) == "number" then
        return registry._by_index[id]
    else
        return registry._by_name[id]
    end
end
-- }}}

-- {{{ registry.get_category
-- Get category for a currency.
-- @param id Currency name or index
-- @return Category constant or nil
function registry.get_category(id)
    local schema = registry.get_schema(id)
    return schema and schema.category
end
-- }}}

-- {{{ registry.is_physical
-- Check if currency is a physical coin type.
function registry.is_physical(id)
    return registry.get_category(id) == registry.CURRENCY_CATEGORY.PHYSICAL
end
-- }}}

-- {{{ registry.is_abstract
-- Check if currency is an abstract counter.
function registry.is_abstract(id)
    return registry.get_category(id) == registry.CURRENCY_CATEGORY.ABSTRACT
end
-- }}}

-- {{{ registry.is_wc3
-- Check if currency is a WC3 resource.
function registry.is_wc3(id)
    return registry.get_category(id) == registry.CURRENCY_CATEGORY.WC3_RESOURCE
end
-- }}}

-- {{{ registry.get_standing_name
-- Get reputation standing name for a value.
-- @param value Reputation value (-42000 to +42999)
-- @return Standing name string
function registry.get_standing_name(value)
    for _, threshold in ipairs(registry.STANDING_THRESHOLDS) do
        if value >= threshold.min and value <= threshold.max then
            return threshold.name
        end
    end
    return "Unknown"
end
-- }}}

-- {{{ registry.get_standing_index
-- Get reputation standing index for a value.
-- @param value Reputation value
-- @return Standing index (1-8)
function registry.get_standing_index(value)
    for _, threshold in ipairs(registry.STANDING_THRESHOLDS) do
        if value >= threshold.min and value <= threshold.max then
            return threshold.index
        end
    end
    return 4  -- Default to Neutral
end
-- }}}

-- {{{ registry.get_honor_rank
-- Get honor rank data for an honor value.
-- @param honor_value Current honor
-- @return Rank number, rank data table
function registry.get_honor_rank(honor_value)
    local rank = 0
    for r = 14, 0, -1 do
        if honor_value >= registry.HONOR_RANKS[r].min_honor then
            rank = r
            break
        end
    end
    return rank, registry.HONOR_RANKS[rank]
end
-- }}}

-- {{{ registry.get_all_currencies
-- Get list of all currency names.
-- @return Array of currency name strings
function registry.get_all_currencies()
    local result = {}
    for name in pairs(registry.CURRENCY_SCHEMA) do
        result[#result + 1] = name
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ registry.get_currencies_by_category
-- Get currencies filtered by category.
-- @param category CURRENCY_CATEGORY value
-- @return Array of currency name strings
function registry.get_currencies_by_category(category)
    local result = {}
    for name, schema in pairs(registry.CURRENCY_SCHEMA) do
        if schema.category == category then
            result[#result + 1] = name
        end
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ registry.register_custom
-- Register a custom currency (for map-specific currencies).
-- @param name Currency name
-- @param schema Schema table with required fields
-- @return true on success, false if name already exists
function registry.register_custom(name, schema)
    if registry.CURRENCY_SCHEMA[name] then
        return false, "Currency already exists: " .. name
    end

    -- Assign next available index
    local max_index = 0
    for _, s in pairs(registry.CURRENCY_SCHEMA) do
        if s.index > max_index then
            max_index = s.index
        end
    end
    schema.index = max_index + 1

    -- Set defaults
    schema.category = schema.category or registry.CURRENCY_CATEGORY.ABSTRACT
    schema.default = schema.default or 0
    schema.display_name = schema.display_name or name

    -- Register
    registry.CURRENCY_SCHEMA[name] = schema
    registry._by_index[schema.index] = schema
    registry._by_index[schema.index].name = name
    registry._by_name[name] = schema

    return true
end
-- }}}

return registry
