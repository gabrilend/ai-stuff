-- phase-2-demo.lua
--
-- The phase 2 demonstration, run by phase-2-demo. Surveys each example
-- project into a scratch case (phase 1's cases and ledger), prints them side
-- by side, then times the largest source on one thread and on all.

local DIR = arg[1]
local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
local project = paths_module.for_project(DIR)

local fs = require("017-the-filesystem")
local case = require("018-the-case")
local ledger = require("016-ledger")
local survey = require("029-the-survey")
local summary = require("030-the-survey-summary")

-- {{{ local function wall
-- Wall-clock seconds with fractions; os.clock counts CPU time of every
-- thread together, which would hide what parallel reading buys.
local function wall()
    local out = fs.capture("date +%s.%N")
    return tonumber(out)
end
-- }}}

-- {{{ local function bar
local function bar(value, max, width)
    local filled = math.floor(value / max * width + 0.5)
    return string.rep("█", filled) .. string.rep("·", width - filled)
end
-- }}}

local scratch = project.scratch .. "/demo-phase-2"
if fs.is_folder(scratch) then
    fs.remove_tree(scratch)
end
fs.make_folder(scratch)
local demo_project = {}
for k, v in pairs(project) do
    demo_project[k] = v
end
demo_project.cases = scratch .. "/cases"

-- This machine cannot survey itself in place (a case refuses a source inside
-- the project), so a copy of its own source, checks and documents is made.
local self_copy = scratch .. "/this-machine"
fs.make_folder(self_copy)
fs.run("cp -r " .. fs.quote(DIR .. "/src") .. " " .. fs.quote(DIR .. "/tests") .. " " .. fs.quote(DIR .. "/docs")
    .. " " .. fs.quote(DIR .. "/machine") .. " " .. fs.quote(self_copy))

local SOURCES = {
    { name = "kiln", path = "/home/ritz/programming/ai-playground/kiln" },
    { name = "rao-chat", path = "/home/ritz/programs/rao-chat" },
    { name = "wow-chat-src", path = "/home/ritz/games/azeroth-core/wow-chat-2026/src" },
    { name = "this-machine", path = self_copy },
}
local BIG = { name = "azerothcore", path = "/home/ritz/games/azeroth-core/wow-chat-2026/source-alpha" }

print("PHASE 2 — THE SURVEY")
print("")

local results = {}
local missing = {}
for _, s in ipairs(SOURCES) do
    if fs.is_folder(s.path) then
        local record = case.open(demo_project, s.name, s.path, "stand-in")
        local t0 = wall()
        local counts = survey.run(demo_project, record, nil)
        local seconds = wall() - t0
        summary.write(record.survey)
        ledger.append(record.ledger, "surveyed", "-", counts.files .. " files")
        results[#results + 1] = {
            name = s.name, s = summary.compute(record.survey), seconds = seconds,
            head = ledger.head(record.ledger),
        }
    else
        missing[#missing + 1] = s.name .. " (" .. s.path .. ")"
    end
end

-- {{{ local function pad
-- Pads to a width in characters, not bytes: "…" is three bytes of UTF-8 but
-- one character on screen, and string.format counts bytes.
local function pad(text, width)
    text = tostring(text)
    local _, continuation_bytes = text:gsub("[\128-\191]", "")
    local shown = #text - continuation_bytes
    return text .. string.rep(" ", math.max(1, width - shown))
end
-- }}}

-- {{{ local function row
local function row(label, fn)
    local cells = { pad(label, 26) }
    for _, r in ipairs(results) do
        cells[#cells + 1] = pad(fn(r), 24)
    end
    print(table.concat(cells))
end
-- }}}

-- {{{ local function short
local function short(text, n)
    text = tostring(text or "-")
    if #text > n then
        return "…" .. text:sub(-(n - 1))
    end
    return text
end
-- }}}

row("", function(r) return r.name end)
row("files", function(r) return r.s.totals.files end)
row("lines", function(r) return r.s.totals.lines end)
row("main language", function(r)
    local l = r.s.by_language[1]
    return l and (l.name .. " " .. math.floor(l.lines / math.max(1, r.s.totals.lines) * 100) .. "%") or "-"
end)
row("second language", function(r)
    local l = r.s.by_language[2]
    return l and (l.name .. " " .. math.floor(l.lines / math.max(1, r.s.totals.lines) * 100) .. "%") or "-"
end)
row("links inside / outside", function(r) return r.s.totals.links_inside .. " / " .. r.s.totals.links_outside end)
row("most leaned-on file", function(r) return short(r.s.foundations[1] and r.s.foundations[1].path, 22) end)
row("  …included by", function(r) return r.s.foundations[1] and r.s.foundations[1].included_by or 0 end)
row("entry points", function(r) return #r.s.entry_points end)
row("C compile units", function(r) return r.s.compile_units end)
row("outside dependencies", function(r) return #r.s.outside end)
row("largest code file", function(r) return short(r.s.largest[1] and r.s.largest[1].path, 22) end)
row("survey time (all cores)", function(r) return string.format("%.3f s", r.seconds) end)
row("ledger head", function(r) return r.head:sub(1, 16) .. "…" end)
print("")
if #missing > 0 then
    print("not found, skipped: " .. table.concat(missing, ", "))
    print("")
end

-- Speed: the biggest source on one thread and on all of them.
if fs.is_folder(BIG.path) then
    local effil = require("effil")
    local cores = effil.hardware_threads()
    print(string.format("SPEED — %s (%s)", BIG.name, BIG.path))
    local timings = {}
    local file_count
    for _, threads in ipairs({ 1, 2, 4, cores }) do
        local t0 = wall()
        local _, _, _, count = survey.read_source(demo_project, BIG.path, threads, 50000)
        local seconds = wall() - t0
        file_count = count
        timings[#timings + 1] = { threads = threads, rate = count / seconds, seconds = seconds }
    end
    local top_rate = 0
    for _, t in ipairs(timings) do
        top_rate = math.max(top_rate, t.rate)
    end
    for _, t in ipairs(timings) do
        print(string.format("  %2d thread%s %8.0f files/s  %5.2f s  %s", t.threads, t.threads == 1 and " " or "s",
            t.rate, t.seconds, bar(t.rate, top_rate, 30)))
    end
    print(string.format("  %d files; %.1fx faster on %d threads than on one",
        file_count, timings[#timings].rate / timings[1].rate, cores))
else
    print("the large source for the speed test was not found at " .. BIG.path)
end

fs.remove_tree(scratch)
