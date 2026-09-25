#!/usr/bin/env luajit
-- route-b-report.lua - Route B's report: Liquipedia's published numbers against Route A's tables
--
-- In plain terms: compares every number Liquipedia's pages give for a unit,
-- building or item (as the pages stood when 1.29.2 was current, where they
-- have changed since) with the same number in the game's own 1.29.2 tables,
-- read from the player's install, and writes a readable report: how much
-- agrees, and every disagreement with both values, for investigation. It
-- fetches nothing (src/cli/route-b-fetch.lua does that, once).
--
-- Usage:
--   luajit src/cli/route-b-report.lua [--dir DIR] [output folder]
--     default output: tmp/shared-memory/route-b/ (report.md, and refetch.txt:
--     the pages still read from today's revision that differ, for
--     route-b-fetch.lua old)
--
-- Issue: issues/112e-route-b-published-values-cross-check.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local route_b = require("gamedata.route_b")

local out_folder = arg[1] or (DIR .. "/tmp/shared-memory/route-b")
local a = route_b.load_route_a(DIR .. "/wc3-installs/frozen-throne", DIR .. "/wc3-installs/patch-layers")
local pages = route_b.cached_pages(DIR .. "/wc3-installs/external-values")
local r = route_b.compare_all(a, pages)

-- {{{ local function revision
-- Which text a row was read from: as it stood under 1.29.2, or today's (and
-- whether that's because the page had no revision from then).
local function revision(p)
    if p.source == "old" then return "under 1.29.2" end
    if p.no_old then return "today's (none before 1.30)" end
    return "today's"
end
-- }}}

-- {{{ local function fmt
local function fmt(v)
    if v == nil then return "—" end
    if type(v) == "number" then return (string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")) end
    return tostring(v)
end
-- }}}

local n_pages = 0
for _ in pairs(pages) do n_pages = n_pages + 1 end
local c = r.counts
local agree = (c.match or 0) + (c.blank_is_zero or 0)
local explained = (c.upgrade_step or 0) + (c.explained or 0) + (c.later_page or 0)
local compared = agree + explained + (c.mismatch or 0)
local sources = { old = 0, current = 0, no_old = 0 }
for _, p in pairs(pages) do
    sources[p.source] = sources[p.source] + 1
    if p.no_old then sources.no_old = sources.no_old + 1 end
end

local lines = {}
local function w(s) lines[#lines + 1] = s or "" end
w("# Route B report: published values against Route A (" .. a.version .. ")")
w("")
w(string.format("Generated %s. Route A: the game's own %s melee tables, read from this install.", os.date("!%Y-%m-%d %H:%M UTC"), a.version))
w("Route B: Liquipedia's Warcraft III wiki (https://liquipedia.net/warcraft/, CC BY-SA 3.0), each page as it")
w("stood under 1.29.2 where it has changed since (the last revision before 2018-08-08), else today's.")
w("")
w("## Summary")
w("")
w(string.format("- Pages read: %d (%d as they stood under 1.29.2, %d today's, of which %d had no revision before 1.30); objects compared: %d",
    n_pages, sources.old, sources.current, sources.no_old, r.objects))
w(string.format("- Numbers both routes give: %d; agree: %d (%.1f%%), of which %d are a blank cell the wiki writes as 0", compared, agree, compared > 0 and 100 * agree / compared or 0, c.blank_is_zero or 0))
-- A later page isn't an explanation, only a reason nothing can be checked:
-- its line is kept apart from the reasons found.
w(string.format("- Disagree, with the reason found: %d (an upgrade's cost counted over the chain: %d; investigated by hand: %d)",
    (c.upgrade_step or 0) + (c.explained or 0), c.upgrade_step or 0, c.explained or 0))
w(string.format("- Disagree, have not been checked: %d (the page was first written after 1.30, so it shows a later patch's numbers; its 1.29.2 value is still unconfirmed)", c.later_page or 0))
w(string.format("- Disagree, unexplained: %d (listed below, to investigate)", c.mismatch or 0))
w(string.format("- Only on the wiki (no such object or cell in Route A): %d; unreadable on the wiki: %d", c.only_b or 0, c.unreadable or 0))
w(string.format("- Pages not compared (no infobox, or no id and no single object by that name): %d", #r.unpaired))
w("")

local function section(title, verdict)
    local rows = {}
    for _, row in ipairs(r.rows) do if row.verdict == verdict then rows[#rows + 1] = row end end
    w("## " .. title .. " (" .. #rows .. ")")
    w("")
    if #rows == 0 then w("None."); w(""); return end
    w("| Page | Id | Field | Column | Route A | Route B | Revision |")
    w("|------|----|-------|--------|---------|---------|----------|")
    for _, row in ipairs(rows) do
        w(string.format("| %s | %s | %s | %s | %s | %s | %s |", row.title, row.id, row.field, row.column, fmt(row.a),
            verdict == "unreadable" and row.raw:gsub("\n", " "):gsub("|", "/") or fmt(row.b), revision(row)))
    end
    w("")
end
section("Disagreements, unexplained", "mismatch")
section("Only on the wiki, unexplained", "only_b")

-- {{{ explained rows, each with its reason
local function reasons(title, verdict)
    local rows = {}
    for _, row in ipairs(r.rows) do if row.verdict == verdict then rows[#rows + 1] = row end end
    w("## " .. title .. " (" .. #rows .. ")")
    w("")
    if #rows == 0 then w("None."); w(""); return end
    w("| Page | Id | Column | Route A | Route B | Revision | Why |")
    w("|------|----|--------|---------|---------|----------|-----|")
    for _, row in ipairs(rows) do
        w(string.format("| %s | %s | %s | %s | %s | %s | %s |", row.title, row.id, row.column, fmt(row.a), fmt(row.b), revision(row), row.why))
    end
    w("")
end
-- }}}
reasons("Explained by hand", "explained")
reasons("An upgrade's cost counted over the chain", "upgrade_step")
reasons("Pages first written after 1.30", "later_page")
section("Unreadable on the wiki", "unreadable")

-- Pages read but not compared, each with why: nothing is dropped silently.
w("## Pages not compared (" .. #r.unpaired .. ")")
w("")
if #r.unpaired == 0 then w("None.") end
for _, p in ipairs(r.unpaired) do
    w(string.format("- %s (%s): %s", p.title, revision(p), p.reason))
end
w("")

os.execute("mkdir -p '" .. out_folder .. "'")
local f = assert(io.open(out_folder .. "/report.md", "w"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
-- The pages still read from today's revision that differ: the list the
-- fetcher's "old" phase takes, so the next step needs no hand-made list.
local rf = assert(io.open(out_folder .. "/refetch.txt", "w"))
for _, title in ipairs(r.pages_differing) do rf:write(title, "\n") end
rf:close()
print(string.format("%d objects; %d numbers compared, %d agree, %d differ with a reason, %d have not been checked, %d unexplained (+%d only on the wiki); report: %s/report.md",
    r.objects, compared, agree, (c.upgrade_step or 0) + (c.explained or 0), c.later_page or 0, c.mismatch or 0, c.only_b or 0, out_folder))
