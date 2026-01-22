-- {{{ exclusion-filter.lua
-- Issue 6-031: Configurable poem exclusion filter
-- Loads excluded poem IDs from excluded-poems.txt (project root) and provides
-- a check function to filter poems during extraction.
--
-- Excluded poems leave gaps in the ID sequence (tombstoning) -
-- IDs are assigned first, then exclusions are applied, preserving
-- stable anchor links and external references.
--
-- Usage:
--   local exclusion = require("exclusion-filter")
--   local filter = exclusion.load("excluded-poems.txt")
--   if filter:is_excluded("fediverse", "113847291038475") then
--       -- skip this poem
--   end
-- }}}

local M = {}

-- {{{ local function parse_exclusion_file
-- Parses the exclusion config file into a table of category -> set of IDs.
-- Returns a table like: { fediverse = { ["123"] = true }, notes = { ["foo"] = true } }
local function parse_exclusion_file(file_path)
    local exclusions = {
        fediverse = {},
        notes = {},
        messages = {},
        bluesky = {}
    }

    local file = io.open(file_path, "r")
    if not file then
        -- File doesn't exist - return empty exclusions (not an error)
        return exclusions, 0
    end

    local current_category = nil
    local total_count = 0

    for line in file:lines() do
        -- Trim whitespace
        line = line:match("^%s*(.-)%s*$")

        -- Skip empty lines and comments
        if line == "" or line:match("^#") then
            goto continue
        end

        -- Check for category header (e.g., "fediverse:")
        local category = line:match("^(%w+):$")
        if category then
            if exclusions[category] then
                current_category = category
            else
                -- Unknown category - warn but continue
                io.stderr:write(string.format(
                    "[exclusion-filter] Warning: Unknown category '%s' ignored\n",
                    category
                ))
            end
            goto continue
        end

        -- Add ID to current category
        if current_category then
            exclusions[current_category][line] = true
            total_count = total_count + 1
        end

        ::continue::
    end

    file:close()
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

-- {{{ function M.load
-- Load exclusions from a config file.
-- file_path: path to excluded-poems.txt (absolute or relative to cwd)
-- Returns: ExclusionFilter object
function M.load(file_path)
    local exclusions, total_count = parse_exclusion_file(file_path)

    local filter = setmetatable({
        exclusions = exclusions,
        total_count = total_count,
        file_path = file_path
    }, ExclusionFilter)

    return filter
end
-- }}}

-- {{{ function M.load_default
-- Load exclusions from the default config location.
-- dir: project directory (optional, defaults to cwd)
-- Returns: ExclusionFilter object
function M.load_default(dir)
    dir = dir or "."
    local file_path = dir .. "/excluded-poems.txt"
    return M.load(file_path)
end
-- }}}

return M
