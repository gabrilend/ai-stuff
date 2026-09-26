-- 028-include-lines.lua
--
-- Which file includes which. One scanner per include style reads a file's
-- text line by line and returns the names it includes; the resolver turns a
-- name as written into a path inside the source, trying candidates in a fixed
-- order (docs/004, "resolving a link"). A name that resolves nowhere is a
-- dependency outside the source: a system library, an installed package.
--
-- A link (docs/002):  from (path), to (path, or the name as written),
--                     kind (require | include | import | source),
--                     inside ("yes" | "no")

local includes = {}

-- Each scanner: the line-comment prefix (lines starting with it are skipped),
-- the link kind, and patterns. A pattern's first capture is the name; a
-- pattern marked outside=true records the name as outside without resolving
-- (C's angle-bracket includes name system headers).
includes.SCANNERS = {
    lua = {
        comment = "%-%-", kind = "require",
        patterns = {
            { "require%s*%(?%s*[\"']([^\"']+)[\"']" },
            { "dofile%s*%(?%s*[\"']([^\"']+)[\"']" },
        },
    },
    c = {
        comment = "//", kind = "include",
        patterns = {
            { "^%s*#%s*include%s*\"([^\"]+)\"" },
            { "^%s*#%s*include%s*<([^>]+)>", outside = true },
        },
    },
    shell = {
        comment = "#", kind = "source",
        patterns = {
            { "^%s*source%s+[\"']?([^\"'%s;]+)" },
            { "^%s*%.%s+[\"']?([^\"'%s;]+)" },
        },
    },
    python = {
        comment = "#", kind = "import",
        patterns = {
            { "^%s*from%s+([%w_%.]+)%s+import" },
            { "^%s*import%s+([%w_%.]+)" },
        },
    },
    javascript = {
        comment = "//", kind = "import",
        patterns = {
            { "import%s.-from%s*[\"']([^\"']+)[\"']" },
            { "^%s*import%s*[\"']([^\"']+)[\"']" },
            { "require%s*%(%s*[\"']([^\"']+)[\"']%s*%)" },
        },
    },
}

-- Extra candidate spellings per scanner: how a name as written becomes a
-- file name. Each function returns an array of candidate relative names.
local SPELLINGS = {
    lua = function(name)
        local out = { name }
        if not name:match("%.lua$") then
            local slashed = name:gsub("%.", "/")
            out[#out + 1] = slashed .. ".lua"
            out[#out + 1] = slashed .. "/init.lua"
            out[#out + 1] = name .. ".lua"
        end
        return out
    end,
    python = function(name)
        local slashed = name:gsub("%.", "/")
        return { slashed .. ".py", slashed .. "/__init__.py" }
    end,
    javascript = function(name)
        return { name, name .. ".js", name .. ".ts", name .. ".mjs", name .. "/index.js" }
    end,
    c = function(name) return { name } end,
    shell = function(name) return { name } end,
}

-- {{{ function includes.normalise
-- Removes "." and resolves ".." in a relative path; returns nil when ".."
-- would climb out of the source.
function includes.normalise(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            if #parts == 0 then
                return nil
            end
            parts[#parts] = nil
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return table.concat(parts, "/")
end
-- }}}

-- Plain words, one of which must appear on any line a scanner's patterns can
-- match. Only lines holding one are pattern-matched: in a large C++ tree that
-- is a few thousand lines out of millions, and pattern matching every line
-- was nearly all of the survey's time.
local KEYWORDS = {
    lua = { "require", "dofile" },
    c = { "include" },
    shell = { "source", "." },
    python = { "import" },
    javascript = { "import", "require" },
}

-- {{{ local function candidate_lines
-- The lines of `text` holding any of `words`, in order, each once.
local function candidate_lines(text, words)
    local starts = {}
    for _, word in ipairs(words) do
        local from = 1
        while true do
            local at = text:find(word, from, true)
            if not at then
                break
            end
            -- The start of the line holding this occurrence.
            local line_start = at
            while line_start > 1 and text:byte(line_start - 1) ~= 10 do
                line_start = line_start - 1
            end
            starts[line_start] = true
            -- Continue after this line, since the line is already taken.
            local line_end = text:find("\n", at, true)
            if not line_end then
                break
            end
            from = line_end + 1
        end
    end
    local ordered = {}
    for start in pairs(starts) do
        ordered[#ordered + 1] = start
    end
    table.sort(ordered)
    local lines = {}
    for i, start in ipairs(ordered) do
        local line_end = text:find("\n", start, true)
        lines[i] = text:sub(start, (line_end or #text + 1) - 1)
    end
    return lines
end
-- }}}

-- {{{ function includes.scan
-- Returns an array of { name, kind, outside } found in `text` by the named
-- scanner. Commented-out lines are skipped.
function includes.scan(scanner_name, text)
    local scanner = includes.SCANNERS[scanner_name]
    if not scanner then
        return {}
    end
    local found = {}
    local comment_start = "^%s*" .. scanner.comment
    for _, line in ipairs(candidate_lines(text, KEYWORDS[scanner_name])) do
        if not line:find(comment_start) then
            for _, p in ipairs(scanner.patterns) do
                -- In LuaJIT (Lua 5.1), gmatch reads a leading '^' as a literal
                -- caret, so an anchored pattern would silently never match.
                -- Anchored patterns match once per line; others repeat.
                if p[1]:sub(1, 1) == "^" then
                    local name = line:match(p[1])
                    if name then
                        found[#found + 1] = { name = name, kind = scanner.kind, outside = p.outside or false }
                    end
                else
                    for name in line:gmatch(p[1]) do
                        found[#found + 1] = { name = name, kind = scanner.kind, outside = p.outside or false }
                    end
                end
            end
        end
    end
    return found
end
-- }}}

-- {{{ function includes.resolve
-- `from` is the including file's path; `name` as written; `scanner_name` its
-- scanner; `all_paths` a set of every surveyed path. Returns the resolved
-- path and "yes", or the name as written and "no".
function includes.resolve(from, name, scanner_name, all_paths)
    local spell = SPELLINGS[scanner_name]
    if not spell then
        return name, "no"
    end
    local folder = from:match("^(.*)/[^/]*$")
    -- An absolute name points outside the source by definition.
    if name:sub(1, 1) == "/" then
        return name, "no"
    end
    -- Relative to the including file first, then to the source root.
    local bases = {}
    if folder then
        bases[#bases + 1] = folder .. "/"
    end
    bases[#bases + 1] = ""
    for _, base in ipairs(bases) do
        for _, candidate in ipairs(spell(name)) do
            local path = includes.normalise(base .. candidate)
            if path and all_paths[path] then
                return path, "yes"
            end
        end
    end
    return name, "no"
end
-- }}}

return includes
