--[[
route_b.lua - compare Liquipedia's published numbers with Route A's tables

Route B of issue 112 (sub-issue 112e). Reads the infoboxes of the pages
src/cli/route-b-fetch.lua cached, and compares every mapped field
(gamedata/route_b_fields.lua) with the same column in Route A's 1.29.2 melee
tables, read through the chain. A page's cached revision is the one as it
stood under 1.29.2 when that was fetched (old/), else today's (current/).

Verdicts per field:
  match       equal within the page's own rounding (a wiki value written with
              k decimals matches when within half of 10^-k; whole numbers
              exactly)
  mismatch    both present and different
  blank_is_zero  Route A's cell is blank where the page writes 0 (unused
              fields: a second weapon, food not produced); agreement
  only_b      the page gives a number for an object Route A doesn't have
  unreadable  the page's value isn't a number (text, blank, "-")
  upgrade_step, later_page, explained
              a mismatch (or a number only the wiki gives) with a reason,
              see explain() below; each row carries the reason in "why"

Usage:
  local route_b = require("gamedata.route_b")
  local a = route_b.load_route_a(install, layers)            -- 1.29.2 melee tables
  local pages = route_b.cached_pages(cache)                  -- title -> {text, source ("old"/"current"), meta}
  local report = route_b.compare_all(a, pages)
  report.rows, report.counts, report.pages_differing

Issue: issues/112e-route-b-published-values-cross-check.md
]]

local chain = require("gamedata.chain")
local slk = require("parsers.slk")
local FIELDS = require("gamedata.route_b_fields")
local FINDINGS = require("gamedata.route_b_findings")

local M = {}

-- {{{ function M.parse_infobox
-- The first infobox on a page: its template name and its fields (name ->
-- raw text, trimmed). As MediaWiki does, a field ends at the next "|" that
-- isn't inside a nested {{template}} or [[link]], so values may span lines
-- (lists) and a line may hold several fields ("|gold=800 |lumber=0", as
-- some item pages write them). Parts with no "name=" (positional) are
-- skipped: the infoboxes name every number.
function M.parse_infobox(text)
    -- Older revisions write "Infobox_building": MediaWiki reads an
    -- underscore in a title as a space, so both spellings are one template.
    local start = text:find("{{%s*[Ii]nfobox[ _]")
    if not start then return nil end
    local template = text:match("{{%s*([Ii]nfobox[ _][%w _]-)%s*\n", start) or text:match("{{%s*([Ii]nfobox[ _][%w _]-)%s*|", start)
    if not template then return nil end
    template = template:gsub("^i", "I"):gsub("_", " ")
    -- Walk from just inside the opening braces to the matching close,
    -- cutting at the top-level pipes. depth counts {{ }} and [[ ]] alike.
    local parts, from = {}, nil
    local depth, i = 0, start + 2
    while i <= #text do
        local two = text:sub(i, i + 1)
        if two == "{{" or two == "[[" then depth = depth + 1; i = i + 2
        elseif two == "}}" and depth == 0 then
            if from then parts[#parts + 1] = text:sub(from, i - 1) end
            break
        elseif two == "}}" or two == "]]" then depth = depth - 1; i = i + 2
        elseif depth == 0 and text:sub(i, i) == "|" then
            if from then parts[#parts + 1] = text:sub(from, i - 1) end
            from = i + 1; i = i + 1
        else i = i + 1 end
    end
    local fields = {}
    for _, part in ipairs(parts) do
        local name, value = part:match("^%s*([%w_]+)%s*=(.*)$")
        -- a part without "name=": a positional value, not one of ours
        if name then fields[name] = value:gsub("^%s+", ""):gsub("%s+$", "") end
    end
    return template, fields
end
-- }}}

-- {{{ function M.number
-- A wiki value as a number and its decimal places, or nil.
function M.number(raw)
    if not raw then return nil end
    local s = raw:gsub("<!%-%-.-%-%->", ""):gsub("&nbsp;", ""):gsub(",", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local n = s:match("^%-?%d+%.?%d*$") or s:match("^%-?%.%d+$")
    if not n then return nil end
    local decimals = n:match("%.(%d+)$")
    return tonumber(n), decimals and #decimals or 0
end
-- }}}

-- {{{ function M.load_route_a
-- Route A's 1.29.2 melee tables for the tables the field map names.
function M.load_route_a(install, layers, version)
    local c = chain.open({ install = install, layers = layers, layer = version or "1.29.2",
        w3i = { version = 25, editor_version = 0, game_data_set = 2, flags = { melee_map = true } } })
    local tables = {}
    for _, map in pairs(FIELDS) do
        for _, target in pairs(map) do
            local t = target:match("^([^.]+)%.")
            if not tables[t] then tables[t] = slk.parse((c:read("Units\\" .. t .. ".slk"))) end
        end
    end
    -- Item pages carry no id, and neither do building pages as they stood in
    -- 2018: they're paired by name, from the game's name files (Blizzard's
    -- names, used only on this machine to pair pages with rows). A name two
    -- objects share is marked false rather than guessed, and the page is
    -- reported unpaired.
    local profile = require("parsers.profile_txt")
    -- {{{ local function names_for
    local function names_for(files, rows)
        local strings = {}
        for _, file in ipairs(files) do
            profile.parse(assert(c:read("Units\\" .. file .. ".txt"), "no Units\\" .. file .. ".txt in the chain"), strings)
        end
        local by_name = {}
        for id, entry in pairs(strings) do
            local name = type(entry.Name) == "string" and entry.Name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or nil
            if name and rows[id] then
                -- a second object with this name: the name no longer pairs
                if by_name[name] ~= nil then by_name[name] = false else by_name[name] = id end
            end
        end
        return by_name
    end
    -- }}}
    local item_by_name = names_for({ "ItemStrings" }, tables.ItemData.rows)
    local unit_by_name = names_for({ "HumanUnitStrings", "OrcUnitStrings", "UndeadUnitStrings", "NightElfUnitStrings",
        "NeutralUnitStrings", "CampaignUnitStrings" }, tables.UnitBalance.rows)
    -- Which building upgrades into which (Town Hall -> Keep -> Castle), from
    -- the race function files' Upgrade lists: the game stores an upgraded
    -- building's cost as the total of the chain, the wiki the step.
    local func = {}
    for _, file in ipairs({ "HumanUnitFunc", "OrcUnitFunc", "UndeadUnitFunc", "NightElfUnitFunc", "NeutralUnitFunc", "CampaignUnitFunc" }) do
        profile.parse(assert(c:read("Units\\" .. file .. ".txt"), "no Units\\" .. file .. ".txt in the chain"), func)
    end
    local upgraded_from = {}
    for id, entry in pairs(func) do
        -- one id, or several joined by commas (Scout Tower: "hgtw,hctw,hatw"),
        -- or already a list; a missing field names no upgrades
        local list = entry.Upgrade
        if type(list) == "table" then list = table.concat(list, ",") end
        if type(list) == "string" then
            for to in list:gmatch("[^,]+") do upgraded_from[to] = id end
        end
    end
    c:close()
    return { version = version or "1.29.2", tables = tables, item_by_name = item_by_name, unit_by_name = unit_by_name,
        upgraded_from = upgraded_from }
end
-- }}}

-- {{{ function M.cached_pages
-- Every cached page: title -> {text, source, meta, no_old}; the old
-- revision (as it stood under 1.29.2) wins over today's where both exist and
-- the old one has text. no_old (boolean) is true when the page was asked for
-- as it stood under 1.29.2 and had no revision then (the page was written
-- later): today's text is read, and the report says so.
function M.cached_pages(cache)
    local pages = {}
    for _, source in ipairs({ "current", "old" }) do
        local listing = io.popen("ls '" .. cache .. "/" .. source .. "' 2>/dev/null")
        for name in listing:lines() do
            local base = name:match("^(.*)%.meta$")
            if base then
                local mf = io.open(cache .. "/" .. source .. "/" .. name, "r")
                local meta = mf:read("*l"); mf:close()
                local title = meta:match("^([^\t]*)")
                local tf = io.open(cache .. "/" .. source .. "/" .. base .. ".wikitext", "r")
                local text = tf and tf:read("*a") or ""
                if tf then tf:close() end
                if text ~= "" then
                    pages[title] = { text = text, source = source, meta = meta, no_old = false }
                elseif source == "old" and pages[title] then
                    -- asked for, and none existed then: today's text stays
                    pages[title].no_old = true
                end
            end
        end
        listing:close()
    end
    return pages
end
-- }}}

-- {{{ local function verdict
local function verdict(a, b, decimals, present)
    -- The game leaves unused fields blank (a unit's second weapon, food it
    -- doesn't produce) where the wiki writes 0: the same fact, reported as
    -- its own verdict so it's visible, and counted as agreement.
    if a == nil and present and b == 0 then return "blank_is_zero" end
    if a == nil then return "only_b" end
    if decimals == 0 then return (a == b) and "match" or "mismatch" end
    return (math.abs(a - b) <= 0.5 * 10 ^ -decimals + 1e-9) and "match" or "mismatch"
end
-- }}}

-- {{{ function M.compare_page
-- One page against Route A: list of {field, column, a, b, verdict}, the id
-- and the template. Returns nil and a reason when the page can't be
-- compared: no infobox we map, or no id (none written, and the title names
-- no object or more than one).
function M.compare_page(route_a, text, title)
    local template, fields = M.parse_infobox(text)
    if not template then return nil, "no infobox" end
    if not FIELDS[template] then return nil, "not a mapped infobox (" .. template .. ")" end
    local id = fields.id and fields.id:match("^%s*(%w%w%w%w)%s*$")
    if not id then
        -- items never carry an id; units and buildings sometimes don't
        local by_name = template == "Infobox item" and route_a.item_by_name or route_a.unit_by_name
        local found = title and by_name and by_name[title]
        if found == false then return nil, "no id, and the name is shared by several objects" end
        if not found then
            return nil, fields.id and ("id written as " .. fields.id .. ", and no object has this name") or "no id, and no object has this name"
        end
        id = found
    end
    local rows = {}
    for field, target in pairs(FIELDS[template]) do
        local raw = fields[field]
        if raw and raw:match("%S") then
            local t, col = target:match("^([^.]+)%.(.+)$")
            local row = route_a.tables[t] and route_a.tables[t].rows[id]
            local a = row and row[col]
            if type(a) ~= "number" then a = nil end
            local b, decimals = M.number(raw)
            local form = "plain"
            if b == nil then
                -- The 2018 building pages write "base / fully upgraded"
                -- (Castle: hp=2500 / 4000, armor=5 / 8, after three levels of
                -- Masonry); the base is the table's number. Any other text
                -- stays unreadable.
                local base = raw:match("^%s*([%d%.]+)%s*/%s*[%d%.]+%s*$")
                if base then b, decimals = M.number(base); form = "base / upgraded" end
            end
            local v
            if b == nil then v = "unreadable" else v = verdict(a, b, decimals, row ~= nil) end
            rows[#rows + 1] = { field = field, column = target, a = a, b = b, raw = raw, form = form, verdict = v }
        end
    end
    table.sort(rows, function(x, y) return x.field < y.field end)
    return rows, id, template
end
-- }}}

-- {{{ local function explain
-- A mismatch or a number only the wiki gives, when it has an explanation,
-- gets its own verdict, so what the report lists as unexplained is only what
-- is left to investigate:
--   upgrade_step  a cost of a building upgraded from another: the game's
--                 number is the earlier building's cost plus the wiki's step
--                 (proven by the sum, not assumed)
--   later_page    the page had no revision while 1.29.2 was current, so its
--                 numbers are a later patch's: nothing from 1.29.2 to check
--   explained     investigated by hand; the finding is in route_b_findings.lua
-- Anything else keeps its verdict (mismatch or only_b).
local function explain(route_a, r, page)
    local from = route_a.upgraded_from[r.id]
    local t, col = r.column:match("^([^.]+)%.(.+)$")
    if r.verdict == "mismatch" and from and (col == "goldcost" or col == "lumbercost") then
        local before = route_a.tables[t].rows[from]
        local prior = before and tonumber(before[col])
        if prior and prior + r.b == r.a then
            r.why = string.format("the game counts the whole chain: %s's %s plus this step (%s + %s)", from, col, prior, r.b)
            return "upgrade_step"
        end
    end
    local finding = FINDINGS[r.id .. "." .. r.column]
    if finding then r.why = finding.kind .. ": " .. finding.why; return "explained" end
    if page.no_old then r.why = "the page was first written after 1.30"; return "later_page" end
    return r.verdict
end
-- }}}

-- {{{ function M.compare_all
-- Every cached page. Returns { rows = list of {title, id, template, source,
-- field, column, a, b, verdict, why (for an explained mismatch)}, counts = verdict -> n, objects = n,
-- unpaired = list of {title, source, reason}, pages_differing = titles read
-- from today's revision that have a mismatch, a number only the wiki gives,
-- or no pairing (each fetched again as it stood under 1.29.2: an object
-- added later has no revision from then, which confirms it) }.
function M.compare_all(route_a, pages)
    local report = { rows = {}, counts = {}, pages_differing = {}, objects = 0, unpaired = {} }
    local titles = {}
    for t in pairs(pages) do titles[#titles + 1] = t end
    table.sort(titles)
    for _, title in ipairs(titles) do
        local page = pages[title]
        local rows, id, template = M.compare_page(route_a, page.text, title)
        -- a page that can't be compared is listed with its reason, never dropped silently
        if not rows then
            report.unpaired[#report.unpaired + 1] = { title = title, source = page.source, no_old = page.no_old, reason = id }
            if page.source == "current" and not page.no_old then report.pages_differing[#report.pages_differing + 1] = title end
        else
            report.objects = report.objects + 1
            local differs = false
            for _, r in ipairs(rows) do
                r.title, r.id, r.template, r.source, r.no_old = title, id, template, page.source, page.no_old
                if r.verdict == "mismatch" or r.verdict == "only_b" then r.verdict = explain(route_a, r, page) end
                report.rows[#report.rows + 1] = r
                report.counts[r.verdict] = (report.counts[r.verdict] or 0) + 1
                if r.verdict == "mismatch" or r.verdict == "only_b" then differs = true end
            end
            if differs and page.source == "current" and not page.no_old then
                report.pages_differing[#report.pages_differing + 1] = title
            end
        end
    end
    return report
end
-- }}}

return M
