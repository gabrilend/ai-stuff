-- 02-exclusion.lua — "is this path unimportant?", answered from the shared list.
--
-- General description: build a fast yes/no test for whether a file lives in a
-- junk directory (a cache, a build output, a .git tree). We do not invent that
-- list — we read it from the one unified .gitignore that the delta-version
-- project already maintains for every project on these drives. One source of
-- truth. If that file is missing we warn loudly and exclude nothing, because
-- silently excluding everything (or nothing, pretending it was intentional)
-- would be a lie about what the catalog contains.
--
-- IMPORTANT design note: excluded does NOT mean discarded. This module only
-- LABELS. The scanner still records excluded files (with excluded=true) so they
-- stay in the chronological timeline; only the browse walk skips them.

local DIR = DIR or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/libs/?.lua;" .. package.path
local utils = require("01-utils")

local M = {}

-- {{{ glob_to_pattern
-- Translate a gitignore glob into a Lua pattern body (no anchors). `**` spans
-- path segments (matches slashes), a single `*` stays inside one segment, `?`
-- is one non-slash character, and every Lua-magic character is escaped so a `.`
-- in the glob means a literal dot.
local function glob_to_pattern(glob)
    local out, i = {}, 1
    while i <= #glob do
        local c = glob:sub(i, i)
        if c == "*" then
            if glob:sub(i + 1, i + 1) == "*" then
                out[#out + 1] = ".*"      -- ** : across segments
                i = i + 2
            else
                out[#out + 1] = "[^/]*"   -- *  : within one segment
                i = i + 1
            end
        elseif c == "?" then
            out[#out + 1] = "[^/]"
            i = i + 1
        elseif c:match("[%^%$%(%)%%%.%[%]%+%-]") then
            out[#out + 1] = "%" .. c      -- escape a Lua-magic char
            i = i + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ compile_rule
-- Turn one gitignore line into a compiled rule, or nil for comments/blanks.
-- Fields: negate (leading !), has_slash (a path pattern vs a bare-name pattern),
-- and either seg_pat (match against any single path segment) or path_pat (match
-- against the whole path as a run of complete segments).
local function compile_rule(line)
    -- Trim surrounding whitespace; drop comments and blanks.
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line == "" or line:sub(1, 1) == "#" then return nil end

    local negate = false
    if line:sub(1, 1) == "!" then negate = true; line = line:sub(2) end

    -- CRUCIAL design decision. A pure type filter like *.mkv / *.o / *.log
    -- excludes a whole FILE TYPE, not a directory. The shared gitignore lists
    -- these so binaries never land in git — but OUR job is to keep the browse
    -- walk out of unimportant *directories*, and the very media types git
    -- rejects (*.mkv, *.mp4, *.flac, ...) are exactly what the user most wants
    -- to walk. So we deliberately DROP type-glob patterns. This single line is
    -- why a .mkv inside my-recorded-videos stays browsable even though the
    -- shared .gitignore names *.mkv. Directory and specific-file patterns
    -- (node_modules/, build, Thumbs.db, __pycache__) are kept.
    if line:match("^%*%.[^/]*$") then return nil end

    -- A trailing slash marks a directory pattern; we drop the slash and, since
    -- excluded files are still catalogued, treat it like any segment match.
    line = line:gsub("/+$", "")
    -- A leading slash anchors to a repo root in git, but across five separate
    -- drives there is no single root, so we strip it and match by segments.
    line = line:gsub("^/+", "")
    if line == "" then return nil end

    local has_slash = line:find("/") ~= nil
    local body = glob_to_pattern(line)

    if has_slash then
        -- Match when the path contains this run of complete segments, bounded by
        -- slashes or the ends of the path. WHY the /-padding: it prevents
        -- "build" from matching inside "rebuilt".
        return { negate = negate, has_slash = true,
                 path_pat = "/" .. body .. "/" }
    else
        -- Match against any single segment of the path, whole.
        return { negate = negate, has_slash = false,
                 seg_pat = "^" .. body .. "$" }
    end
end
-- }}}

-- {{{ split_segments
local function split_segments(path)
    local segs = {}
    for seg in path:gmatch("[^/]+") do segs[#segs + 1] = seg end
    return segs
end
-- }}}

-- {{{ Matcher:is_excluded
local Matcher = {}
Matcher.__index = Matcher

function Matcher:is_excluded(path)
    -- gitignore semantics: rules apply in order; a later match wins, and a
    -- negation (!) re-includes. So we carry a state and let each hit flip it.
    local excluded = false
    local padded = "/" .. path .. "/"
    local segs = split_segments(path)
    for _, rule in ipairs(self.rules) do
        local hit = false
        if rule.has_slash then
            hit = padded:find(rule.path_pat) ~= nil
        else
            for _, seg in ipairs(segs) do
                if seg:match(rule.seg_pat) then hit = true; break end
            end
        end
        if hit then excluded = not rule.negate end
    end
    return excluded
end
-- }}}

-- {{{ M.build
-- Read the shared .gitignore at source_path and compile it into a Matcher. A
-- missing source is a flagged fallback: we return a matcher that excludes
-- nothing and we say so, rather than pretending the drive has no junk.
--
-- extra_patterns is an optional list of raw pattern strings appended after the
-- shared list. It exists for names git omits from .gitignore by convention --
-- above all ".git" itself, which git self-ignores and so never writes into a
-- gitignore, yet which we must still skip in the browse walk.
function M.build(source_path, extra_patterns)
    local rules = {}
    local usable = false
    local f = io.open(source_path, "r")
    if not f then
        utils.log_warn("exclusion source not readable (" .. tostring(source_path)
            .. ") -- FALLBACK: excluding nothing from the shared list")
    else
        for line in f:lines() do
            local rule = compile_rule(line)
            if rule then rules[#rules + 1] = rule end
        end
        f:close()
        usable = true
    end
    local from_file = #rules
    for _, raw in ipairs(extra_patterns or {}) do
        local rule = compile_rule(raw)
        if rule then rules[#rules + 1] = rule end
    end
    utils.log_info(string.format(
        "exclusion list: %d dir/name rules from %s + %d always-exclude",
        from_file, source_path, #rules - from_file))
    return setmetatable({ rules = rules, source = source_path, usable = usable },
                        Matcher)
end
-- }}}

return M
