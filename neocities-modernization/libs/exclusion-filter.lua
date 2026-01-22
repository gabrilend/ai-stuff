-- {{{ exclusion-filter.lua
-- Issue 6-031: Configurable poem exclusion filter
-- Issue 10-003: Now loads from config.lua excluded_poems section
--
-- Excluded poems leave gaps in the ID sequence (tombstoning) -
-- IDs are assigned first, then exclusions are applied, preserving
-- stable anchor links and external references.
--
-- Usage:
--   local exclusion = require("exclusion-filter")
--   local filter = exclusion.load_default(DIR)
--   if filter:is_excluded("fediverse", "113847291038475") then
--       -- skip this poem
--   end
-- }}}

local M = {}

-- {{{ local function load_exclusions_from_config
-- Loads exclusions from unified config, converting arrays to sets
-- Returns a table like: { fediverse = { ["123"] = true }, notes = { ["foo"] = true } }
local function load_exclusions_from_config(project_dir)
    local exclusions = {
        fediverse = {},
        notes = {},
        messages = {},
        bluesky = {}
    }
    local total_count = 0

    -- Load config-loader
    local ok, config_loader = pcall(require, "config-loader")
    if not ok then
        return exclusions, total_count
    end

    if project_dir then
        config_loader.set_project_root(project_dir)
    end

    local config = config_loader.load()
    if not config or not config.excluded_poems then
        return exclusions, total_count
    end

    -- Convert arrays to sets
    for category, ids in pairs(config.excluded_poems) do
        if exclusions[category] and type(ids) == "table" then
            for _, id in ipairs(ids) do
                exclusions[category][tostring(id)] = true
                total_count = total_count + 1
            end
        end
    end

    return exclusions, total_count
end
-- }}}

-- {{{ ExclusionFilter class
-- Object that holds loaded exclusions and provides query methods
local ExclusionFilter = {}
ExclusionFilter.__index = ExclusionFilter

-- {{{ function ExclusionFilter:is_excluded
-- Check if a poem should be excluded.
-- category: string like "fediverse", "notes", "messages", "bluesky"
-- id: the category-specific identifier (will be converted to string)
-- Returns: true if excluded, false otherwise
function ExclusionFilter:is_excluded(category, id)
    if not self.exclusions[category] then
        return false
    end
    return self.exclusions[category][tostring(id)] == true
end
-- }}}

-- {{{ function ExclusionFilter:count
-- Returns the count of exclusions for a category, or total if no category specified
function ExclusionFilter:count(category)
    if category then
        local count = 0
        for _ in pairs(self.exclusions[category] or {}) do
            count = count + 1
        end
        return count
    end
    return self.total_count
end
-- }}}

-- {{{ function ExclusionFilter:get_excluded_ids
-- Returns a list of excluded IDs for a category (for logging/debugging)
function ExclusionFilter:get_excluded_ids(category)
    local ids = {}
    for id, _ in pairs(self.exclusions[category] or {}) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end
-- }}}

-- {{{ function ExclusionFilter:summary
-- Returns a summary string for logging
function ExclusionFilter:summary()
    local parts = {}
    for _, cat in ipairs({"fediverse", "notes", "messages", "bluesky"}) do
        local count = self:count(cat)
        if count > 0 then
            table.insert(parts, string.format("%s: %d", cat, count))
        end
    end
    if #parts == 0 then
        return "no exclusions configured"
    end
    return table.concat(parts, ", ")
end
-- }}}
-- }}}

-- {{{ function M.load_default
-- Load exclusions from unified config (config.lua excluded_poems section)
-- dir: project directory (optional, for config-loader)
-- Returns: ExclusionFilter object
function M.load_default(dir)
    local exclusions, total_count = load_exclusions_from_config(dir)

    local filter = setmetatable({
        exclusions = exclusions,
        total_count = total_count,
        source = "config.lua"
    }, ExclusionFilter)

    return filter
end
-- }}}

-- {{{ function M.load
-- Backward compatibility wrapper - now just calls load_default
-- file_path parameter is ignored (kept for API compatibility)
function M.load(file_path, dir)
    return M.load_default(dir)
end
-- }}}

return M
