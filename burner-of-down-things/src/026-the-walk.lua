-- 026-the-walk.lua
--
-- Listing every file under a folder. One `find` process does the walking
-- (LuaJIT has no directory reader of its own), printing each entry's type and
-- path separated by NUL bytes so no file name — spaces, newlines, anything —
-- can be misread. Folders named in the skip table are pruned inside `find`,
-- so their contents are never even listed.
--
-- Symbolic links are listed as their own entries and never followed: a link
-- can lead out of the source, or around in a circle.

local fs = require("017-the-filesystem")

local walk = {}

-- Folder names skipped by the survey, each with why. A snapshot (phase 3)
-- walks with no skip table at all, because there every file counts.
walk.SURVEY_SKIPS = {
    { name = ".git", why = "version control's own store, not the software" },
    { name = "node_modules", why = "installed packages, not the software's own source" },
    { name = "tmp", why = "scratch space" },
    { name = "build", why = "build output" },
    { name = "target", why = "build output (Rust, Maven)" },
    { name = "dist", why = "build output (JavaScript)" },
    { name = "__pycache__", why = "compiled Python" },
    { name = "llm-transcripts", why = "conversation records, not the software" },
    { name = "cases", why = "this machine's own case folders, if the source holds any" },
}

-- The largest source the survey will read unless told otherwise.
walk.DEFAULT_FILE_LIMIT = 20000

-- {{{ local function prune_expression
-- The part of the find command that skips folders by name.
local function prune_expression(skips)
    if not skips or #skips == 0 then
        return ""
    end
    local names = {}
    for i, skip in ipairs(skips) do
        names[i] = "-name " .. fs.quote(skip.name)
    end
    return "\\( -type d \\( " .. table.concat(names, " -o ") .. " \\) \\) -prune -o "
end
-- }}}

-- {{{ function walk.list
-- Returns an array of entries { path = relative path, kind = "file"|"link" },
-- sorted by path. `skips` is a skip table (or nil for none); `limit` is the
-- most entries allowed (nil for no limit).
function walk.list(root, skips, limit)
    if not fs.is_folder(root) then
        error("walk: not a folder: " .. tostring(root))
    end
    local command = "find -P " .. fs.quote(root) .. " -mindepth 1 " .. prune_expression(skips)
        .. "\\( -type f -o -type l \\) -printf '%y %P\\0'"
    local out, ok = fs.capture(command .. " 2>&1")
    -- find reports unreadable folders on stderr and exits non-zero; a walk
    -- that silently left folders out would let the blueprint miss them.
    if not ok then
        error("walk: find could not read everything under " .. root .. ":\n" .. out:gsub("%z", "\n"))
    end
    local entries = {}
    for kind_letter, path in out:gmatch("(%a) ([^%z]+)%z") do
        entries[#entries + 1] = { path = path, kind = kind_letter == "l" and "link" or "file" }
    end
    if limit and #entries > limit then
        error(string.format("walk: %s holds %d files, more than the limit of %d; raise the limit to survey it",
            root, #entries, limit))
    end
    table.sort(entries, function(a, b) return a.path < b.path end)
    return entries
end
-- }}}

return walk
