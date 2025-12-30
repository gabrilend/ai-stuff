#!/usr/bin/env luajit
--[[
Guild System

Main entry point for the guild/hero/shop system.
Provides unified API for hero management, item handling, and shop interactions.

This system gamifies the quest/bounty workflow by providing:
- Hero progression (XP, levels, stats)
- Inventory management (6 slots like WC3)
- Equipment system (weapon, armor, accessory)
- Shop/marketplace for items
- Persistence via JSON save files
]]

local DIR = arg and arg[0] and arg[0]:match("(.*/)") or "./"

-- Load submodules
local hero_module = require("src.guild.hero")
local items_module = require("src.guild.items")
local shop_module = require("src.guild.shop")

local Hero = hero_module.Hero
local Item = items_module.Item
local ItemRegistry = items_module.ItemRegistry
local Shop = shop_module.Shop
local ShopRegistry = shop_module.ShopRegistry

-- {{{ JSON utilities (simple serialization)
local function serialize_value(val, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    local t = type(val)

    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        -- Escape special characters
        local escaped = val:gsub('\\', '\\\\')
                          :gsub('"', '\\"')
                          :gsub('\n', '\\n')
                          :gsub('\r', '\\r')
                          :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif t == "table" then
        -- Check if array or object
        local is_array = true
        local max_index = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
                break
            end
            max_index = math.max(max_index, k)
        end
        -- Also check for sparse arrays
        if is_array and max_index > 0 then
            for i = 1, max_index do
                if val[i] == nil then
                    is_array = false
                    break
                end
            end
        end

        local parts = {}
        if is_array and max_index > 0 then
            for i = 1, max_index do
                table.insert(parts, serialize_value(val[i], indent + 1))
            end
            return "[\n" .. indent_str .. "  " ..
                   table.concat(parts, ",\n" .. indent_str .. "  ") ..
                   "\n" .. indent_str .. "]"
        else
            for k, v in pairs(val) do
                local key = type(k) == "string" and k or tostring(k)
                table.insert(parts, '"' .. key .. '": ' .. serialize_value(v, indent + 1))
            end
            if #parts == 0 then
                return "{}"
            end
            return "{\n" .. indent_str .. "  " ..
                   table.concat(parts, ",\n" .. indent_str .. "  ") ..
                   "\n" .. indent_str .. "}"
        end
    else
        return '"[' .. t .. ']"'
    end
end

local function to_json(data)
    return serialize_value(data, 0)
end

-- Simple JSON parser (converts JSON to Lua table)
local function from_json(str)
    -- Convert JSON syntax to Lua syntax
    -- Replace JSON arrays [] with Lua tables {}
    str = str:gsub("%[", "{")
    str = str:gsub("%]", "}")

    -- Replace null with nil
    str = str:gsub('"null"', "nil")
    str = str:gsub(':null', ":nil")
    str = str:gsub('%[null', "{nil")

    -- Handle true/false (already valid Lua)
    -- Handle string keys (JSON uses "key": but Lua needs ["key"] = )
    str = str:gsub('"([^"]+)"%s*:', '["%1"] = ')

    -- Try to load as Lua table
    local chunk, err = loadstring("return " .. str)
    if not chunk then
        return nil, "JSON parse error: " .. (err or "unknown")
    end

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "JSON eval error: " .. tostring(result)
    end

    return result
end
-- }}}

-- {{{ Persistence
local SAVE_DIR = ".guild"

-- {{{ ensure_save_dir
local function ensure_save_dir()
    os.execute("mkdir -p " .. SAVE_DIR)
end
-- }}}

-- {{{ save_hero
local function save_hero(hero)
    ensure_save_dir()
    local data = hero:serialize()
    local json = to_json(data)

    local filename = SAVE_DIR .. "/" .. hero.name:gsub("[^%w]", "_") .. ".json"
    local f = io.open(filename, "w")
    if not f then
        return false, "Cannot write to " .. filename
    end
    f:write(json)
    f:close()

    return true, filename
end
-- }}}

-- {{{ load_hero
local function load_hero(name)
    local filename = SAVE_DIR .. "/" .. name:gsub("[^%w]", "_") .. ".json"
    local f = io.open(filename, "r")
    if not f then
        return nil, "Save file not found: " .. filename
    end

    local content = f:read("*a")
    f:close()

    local data, err = from_json(content)
    if not data then
        return nil, err
    end

    -- Pass Item class for proper item reconstruction
    return Hero.deserialize(data, Item)
end
-- }}}

-- {{{ list_saved_heroes
local function list_saved_heroes()
    ensure_save_dir()
    local heroes = {}

    local handle = io.popen("ls -1 " .. SAVE_DIR .. "/*.json 2>/dev/null")
    if handle then
        for line in handle:lines() do
            local name = line:match("/([^/]+)%.json$")
            if name then
                table.insert(heroes, name:gsub("_", " "))
            end
        end
        handle:close()
    end

    return heroes
end
-- }}}
-- }}}

-- {{{ Quest/Bounty Integration
-- Quest data from the quest log
local QUEST_DATA = {
    S1 = { xp = 50, gold = 25, capability = "Parser Edge Case Handling" },
    S2 = { xp = 75, gold = 30, capability = "Silent Error Detection" },
    A1 = { xp = 100, gold = 50, capability = "Floating Point Wisdom" },
    A2 = { xp = 100, gold = 50, capability = "Defensive Logging" },
    J1 = { xp = 200, gold = 100, capability = "Binary Safety Patterns" },
    J2 = { xp = 200, gold = 100, capability = "Table Unpacking Mastery" },
    J3 = { xp = 250, gold = 125, capability = "Error Propagation Design" },
    V1 = { xp = 400, gold = 200, capability = "Count Caching" },
}

local BOUNTY_DATA = {
    B01 = { xp = 1000, gold = 500, capability = "Priority Queue Mastery" },
    B02 = { xp = 800, gold = 400, capability = "Resource Lifecycle Control" },
    B03 = { xp = 800, gold = 400, capability = "Deep Copy Techniques" },
}

-- {{{ get_quest_data
local function get_quest_data(quest_id)
    return QUEST_DATA[quest_id]
end
-- }}}

-- {{{ get_bounty_data
local function get_bounty_data(bounty_id)
    return BOUNTY_DATA[bounty_id]
end
-- }}}
-- }}}

-- {{{ Module exports
return {
    -- Hero system
    Hero = Hero,
    XP_THRESHOLDS = hero_module.XP_THRESHOLDS,
    MAX_LEVEL = hero_module.MAX_LEVEL,
    INVENTORY_SIZE = hero_module.INVENTORY_SIZE,
    EQUIPMENT_SLOTS = hero_module.EQUIPMENT_SLOTS,

    -- Item system
    Item = Item,
    ItemRegistry = ItemRegistry,
    ITEM_TYPE = items_module.ITEM_TYPE,
    RARITY = items_module.RARITY,
    EQUIPMENT_SLOT = items_module.EQUIPMENT_SLOT,

    -- Shop system
    Shop = Shop,
    ShopRegistry = ShopRegistry,
    SHOP_TYPE = shop_module.SHOP_TYPE,
    DISCOUNT_TYPE = shop_module.DISCOUNT_TYPE,

    -- Persistence
    save_hero = save_hero,
    load_hero = load_hero,
    list_saved_heroes = list_saved_heroes,

    -- Quest integration
    get_quest_data = get_quest_data,
    get_bounty_data = get_bounty_data,
    QUEST_DATA = QUEST_DATA,
    BOUNTY_DATA = BOUNTY_DATA,

    -- Utilities
    to_json = to_json,
    from_json = from_json,
}
-- }}}
