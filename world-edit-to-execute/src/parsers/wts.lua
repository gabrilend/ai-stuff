-- WTS (Trigger Strings) Parser
-- Parses war3map.wts string table files and resolves TRIGSTR_xxx references.
-- The wts file is a plain text file mapping numeric IDs to string content.

local wts = {}

-- {{{ parse
-- Parse wts file content into a string table.
-- Returns a table mapping numeric IDs to string content.
local function parse(content)
    local strings = {}

    -- Normalize line endings to \n
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Pattern: STRING <id> followed by { content }
    -- The content can span multiple lines and contain nested braces
    local pos = 1
    while pos <= #content do
        -- Find next STRING declaration
        local id_start, id_end, id = content:find("STRING%s+(%d+)", pos)
        if not id_start then
            break
        end

        -- Find opening brace
        local brace_start = content:find("{", id_end + 1)
        if not brace_start then
            break
        end

        -- Find matching closing brace (handle nested braces)
        local depth = 1
        local text_start = brace_start + 1
        local i = text_start
        while i <= #content and depth > 0 do
            local ch = content:sub(i, i)
            if ch == "{" then
                depth = depth + 1
            elseif ch == "}" then
                depth = depth - 1
            end
            i = i + 1
        end

        if depth == 0 then
            local text_end = i - 2  -- Before the closing brace
            local text = content:sub(text_start, text_end)

            -- Trim leading and trailing newlines (but preserve internal formatting)
            text = text:gsub("^\n", ""):gsub("\n$", "")

            local string_id = tonumber(id)
            if string_id and not strings[string_id] then
                strings[string_id] = text
            end
        end

        pos = i
    end

    return strings
end
-- }}}

-- {{{ StringTable class
local StringTable = {}
StringTable.__index = StringTable

-- {{{ new
-- Create a new StringTable from wts content.
function StringTable.new(wts_content)
    local self = setmetatable({}, StringTable)
    self.strings = {}
    if wts_content then
        self:load(wts_content)
    end
    return self
end
-- }}}

-- {{{ load
-- Load strings from wts content.
function StringTable:load(wts_content)
    self.strings = parse(wts_content)
end
-- }}}

-- {{{ get
-- Get a string by ID. Returns nil if not found.
function StringTable:get(id)
    return self.strings[id]
end
-- }}}

-- {{{ resolve
-- Resolve TRIGSTR_xxx references in text.
-- Replaces TRIGSTR_<id> with the corresponding string content.
-- Negative IDs resolve to empty strings.
-- Unresolved IDs remain as literal TRIGSTR_xxx.
function StringTable:resolve(text)
    if not text then
        return text
    end

    return text:gsub("TRIGSTR_(-?%d+)", function(id_str)
        local id = tonumber(id_str)
        if id and id >= 0 and self.strings[id] then
            return self.strings[id]
        elseif id and id < 0 then
            return ""  -- Negative IDs resolve to empty
        else
            return "TRIGSTR_" .. id_str  -- Keep unresolved
        end
    end)
end
-- }}}

-- {{{ count
-- Return the number of strings in the table.
function StringTable:count()
    local n = 0
    for _ in pairs(self.strings) do
        n = n + 1
    end
    return n
end
-- }}}

-- {{{ ids
-- Return a sorted list of all string IDs.
function StringTable:ids()
    local result = {}
    for id in pairs(self.strings) do
        result[#result + 1] = id
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ pairs
-- Iterate over all strings (id, content).
function StringTable:pairs()
    return pairs(self.strings)
end
-- }}}
-- }}}

-- {{{ Module interface
wts.parse = parse
wts.StringTable = StringTable

-- {{{ new
-- Convenience function to create a StringTable.
function wts.new(content)
    return StringTable.new(content)
end
-- }}}

-- {{{ format
-- Format a StringTable for display.
function wts.format(st)
    local lines = {}
    lines[#lines + 1] = string.format("StringTable: %d strings", st:count())
    lines[#lines + 1] = ""

    local ids = st:ids()
    for i, id in ipairs(ids) do
        if i > 20 then
            lines[#lines + 1] = string.format("  ... and %d more", #ids - 20)
            break
        end
        local content = st:get(id)
        -- Truncate long strings for display
        if #content > 60 then
            content = content:sub(1, 57) .. "..."
        end
        -- Show first line only for multi-line strings
        local first_line = content:match("^([^\n]*)")
        if first_line ~= content then
            first_line = first_line .. " [...]"
        end
        lines[#lines + 1] = string.format("  [%d] %s", id, first_line)
    end

    return table.concat(lines, "\n")
end
-- }}}
-- }}}

return wts
