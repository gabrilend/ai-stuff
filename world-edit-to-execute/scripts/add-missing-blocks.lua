#!/usr/bin/env luajit
-- add-missing-blocks.lua - writes the "Blocks" entries that issue files are missing
--
-- In plain terms: when one issue says it depends on another, the other should
-- say it blocks the first. The issue validator finds every place where only
-- one side says so. This tool reads the validator's report and adds the
-- missing names to the "Blocks" line of the issue that forgot them, creating
-- the line under the issue's dependency line when it has none. It only ever
-- adds; it never removes or rewrites a link.
--
-- Usage:
--   report=$(validate-issues <project>)
--   add-missing-blocks.lua [DIR] [--dry-run] <<< "$report"
--
-- DIR is the project folder (default below). Files in issues/archive/ and
-- issues/superseded/ are left alone and listed: a link from a live issue to
-- a retired one is fixed on the live side, by hand, not by giving the
-- retired issue a new "Blocks" line.

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local dry_run = false
for i = 1, #arg do
    if arg[i] == "--dry-run" then dry_run = true else DIR = arg[i] end
end
local ISSUES = DIR .. "/issues/"

-- {{{ local function read_file
local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function write_file
local function write_file(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end
-- }}}

-- {{{ local function collect_missing
-- Reads validator lines of the shape
--   "<file>: does not list <id> under Blocks, but <id> names it as a blocker"
-- and returns { [file] = { id, id, ... } } in first-seen order, no repeats.
local function collect_missing(report)
    local missing, order = {}, {}
    for line in report:gmatch("[^\n]+") do
        local file, id = line:match("^([^:]+%.md): does not list (%S+) under Blocks, but")
        if file then
            if not missing[file] then
                missing[file] = { seen = {} }
                order[#order + 1] = file
            end
            local entry = missing[file]
            if not entry.seen[id] then
                entry.seen[id] = true
                entry[#entry + 1] = id
            end
        end
    end
    return missing, order
end
-- }}}

-- {{{ local function add_blocks
-- Returns the file's new text with the ids added, or nil and a reason.
-- Two shapes are handled, the two the project's headers use:
--   an existing "**Blocks:** ..." line: the ids are appended to it;
--   no Blocks line, but a "**Dependencies:**" (or "Depends on", "Blocked by")
--   line: a new "**Blocks:** ..." line is added right under it.
local function add_blocks(text, ids)
    local list = table.concat(ids, ", ")
    local s, e = text:find("\n%*%*Blocks:%*%*[^\n]*")
    if s then
        local line = text:sub(s + 1, e)
        return text:sub(1, s) .. line .. ", " .. list .. text:sub(e + 1)
    end
    for _, label in ipairs({ "Dependencies", "Depends on", "Blocked by" }) do
        local ds, de = text:find("\n%*%*" .. label .. ":%*%*[^\n]*")
        if ds then
            return text:sub(1, de) .. "\n**Blocks:** " .. list .. text:sub(de + 1)
        end
    end
    return nil, "no Blocks or dependency line in its header"
end
-- }}}

-- {{{ main
local report = io.read("*a")
local missing, order = collect_missing(report)
local changed, skipped = 0, {}
for _, file in ipairs(order) do
    local ids = missing[file]
    -- Retired folders: the link is fixed on the live side instead.
    if file:match("^archive/") or file:match("^superseded/") then
        skipped[#skipped + 1] = file .. " (retired; fix the live issue that names it)"
    else
        local text = read_file(ISSUES .. file)
        local new_text, reason = add_blocks(text, ids)
        if new_text then
            if not dry_run then write_file(ISSUES .. file, new_text) end
            changed = changed + 1
            print((dry_run and "would add to " or "added to ") .. file .. ": " .. table.concat(ids, ", "))
        else
            skipped[#skipped + 1] = file .. " (" .. reason .. ")"
        end
    end
end
print(string.format("%d files %s; %d left for a person:", changed,
    dry_run and "would change" or "changed", #skipped))
for _, s in ipairs(skipped) do print("  " .. s) end
-- A skipped file is not an error, but it is not fixed either: exit 1 so a
-- caller can't mistake a partial repair for a full one.
os.exit(#skipped == 0 and 0 or 1)
-- }}}
