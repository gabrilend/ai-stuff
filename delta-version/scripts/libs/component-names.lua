-- component-names.lua - when two component names mean the same thing.
--
-- Shared by todone.lua (issue 053b) and todone-roadmap.lua (053c), so a
-- name in config/shared-components.conf matches the names todone reports.
--
--   M.key_of(name)            tier 1: the name with case, spaces, "-" and
--                             "_" ignored (ThreadPool = thread-pool)
--   M.load_synonyms(path)     tier 2: a map from each name's key to the
--                             name to report, read from lines
--                             "name = alias, alias" (missing file: empty)
--   M.canonical(name, synonyms)   the name to report for a name

local M = {}

-- {{{ function M.key_of()
function M.key_of(name)
    return (name:lower():gsub("[%s%-_]+", ""))
end
-- }}}

-- {{{ function M.load_synonyms()
function M.load_synonyms(path)
    local map = {}
    local file = io.open(path, "r")
    if not file then return map end
    for line in file:lines() do
        line = line:gsub("#.*$", "")
        local name, aliases = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
        if name and name ~= "" then
            map[M.key_of(name)] = name
            for alias in aliases:gmatch("[^,]+") do
                alias = alias:gsub("^%s+", ""):gsub("%s+$", "")
                if alias ~= "" then map[M.key_of(alias)] = name end
            end
        end
    end
    file:close()
    return map
end
-- }}}

-- {{{ function M.canonical()
function M.canonical(name, synonyms)
    return synonyms[M.key_of(name)] or name
end
-- }}}

return M
