-- phase-6-demo.lua
--
-- The phase 6 demonstration, run by phase-6-demo. A delivered case (phases
-- 1–5) takes three requests; each is graded (6) and drawn on the graph
-- (4), held or rebuilt (5), and the design is run after each.

local DIR = arg[1]
local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
local project = paths_module.for_project(DIR)

local text_tables = require("014-text-tables")
local fs = require("017-the-filesystem")
local case = require("018-the-case")
local ledger = require("016-ledger")
local survey = require("029-the-survey")
local summary = require("030-the-survey-summary")
local outline = require("042-the-outline")
local graph = require("043-the-graph")
local describing = require("045-describing")
local design_folder = require("048-the-design-folder")
local building = require("050-building")
local updating = require("055-updating")

local scratch = project.scratch .. "/demo-phase-6"
if fs.is_folder(scratch) then
    fs.remove_tree(scratch)
end
fs.make_folder(scratch)
fs.run("cp -r " .. fs.quote(project.fixtures .. "/tiny-notes") .. " " .. fs.quote(scratch .. "/tiny-notes"))
local demo_project = {}
for k, v in pairs(project) do
    demo_project[k] = v
end
demo_project.cases = scratch .. "/cases"

local record = case.open(demo_project, "notes", scratch .. "/tiny-notes", "stand-in")
fs.write(record.folder .. "/stand-in.lua", "return dofile(" .. string.format("%q", project.fixtures .. "/tiny-notes.stand-in.lua")
    .. ")({ root = " .. string.format("%q", project.fixtures) .. ", with_requests = true })\n")
survey.run(demo_project, record, nil)
summary.write(record.survey)
describing.step(demo_project, record, outline.step(demo_project, record, {}), {})
building.step(demo_project, record, {})

local notes_file = scratch .. "/notes.txt"
-- {{{ local function run_notes
local function run_notes(args)
    local out = fs.capture("cd " .. fs.quote(record.design) .. " && NOTES_FILE=" .. fs.quote(notes_file) .. " luajit notes.lua " .. args)
    return out
end
-- }}}
run_notes("add buy oat milk '#home'")
run_notes("add oil the '#bike' chain")

-- {{{ local function draw_reach
-- The graph with the touched issue(s) marked ● and the rest of the reach ○.
local function draw_reach(touched, reach)
    local g = graph.build((text_tables.read(record.blueprint .. "/outline.tsv")))
    local is_touched, in_reach = {}, {}
    for _, id in ipairs(touched) do is_touched[id] = true end
    for _, id in ipairs(reach) do in_reach[id] = true end
    for level, ids in ipairs(graph.levels(g)) do
        local cells = {}
        for _, id in ipairs(ids) do
            local mark = is_touched[id] and "●" or (in_reach[id] and "○" or " ")
            cells[#cells + 1] = mark .. " " .. id .. " " .. g.nodes[id].name
        end
        print(string.format("    level %d  %s", level - 1, table.concat(cells, "   ")))
    end
end
-- }}}

-- {{{ local function builds_since
local function builds_since(seq)
    local n = 0
    for _, l in ipairs(ledger.read(record.ledger)) do
        if l.seq > seq and l.kind == "turn-started" and (l.about:find("-build-", 1, true) or l.about:find("-repair-", 1, true)) then
            n = n + 1
        end
    end
    return n
end
-- }}}

-- {{{ local function turns_since
local function turns_since(seq)
    local n = 0
    for _, l in ipairs(ledger.read(record.ledger)) do
        if l.seq > seq and l.kind == "turn-started" then n = n + 1 end
    end
    return n
end
-- }}}

print("PHASE 6 — THE UPDATE")
print("")
print("the notes program was described and rebuilt from its blueprint (phases 4, 5)")
print("before any request, `notes list` prints:")
for line in run_notes("list"):gmatch("[^\n]+") do print("    " .. line) end
print("")

local REQUESTS = { "count-in-list", "hash-marked-tags", "file-header" }
local tally = {}
for _, name in ipairs(REQUESTS) do
    fs.write(record.input .. "/" .. name, fs.read(project.fixtures .. "/tiny-notes-requests/" .. name .. "/request"))
    ledger.append(record.ledger, "request-received", name, "noticed in input/")
    local seq = #ledger.read(record.ledger)
    print("REQUEST " .. name .. ": \"" .. fs.read(record.input .. "/" .. name):gsub("\n$", "") .. "\"")
    local result = updating.step(demo_project, record, {})[1]
    -- What the locate turn named, as the ledger's graded line records it.
    local graded_text = ledger.index(ledger.read(record.ledger)).graded[name].text
    local touched = {}
    for id in (graded_text:match("touched ([^;]*)") or ""):gmatch("%d%d%d") do touched[#touched + 1] = id end
    print(string.format("  graded %s — touches %s, reaches %d of 6 (● touched, ○ rebuilt because built on it)",
        result.grade, table.concat(touched, " "), #result.reach))
    draw_reach(touched, result.reach)
    if result.outcome == "held" then
        print("  held: the grade is foundation, so the machine stops and shows the person first")
        print("  output/" .. name .. ".grade says:")
        for line in fs.read(record.output .. "/" .. name .. ".grade"):gmatch("[^\n]+") do print("      " .. line) end
        print("  the person runs `update --go`")
        result = updating.step(demo_project, record, { go = true })[1]
    end
    local rebuilt = builds_since(seq)
    local turns = turns_since(seq)
    tally[#tally + 1] = { name = name, grade = result.grade, rebuilt = rebuilt, turns = turns, reach = #result.reach }
    print(string.format("  %s — %d issues rebuilt, %d turns (locate, amend, builds)", result.outcome, rebuilt, turns))
    print("  `notes list` now prints:")
    for line in run_notes("list"):gmatch("[^\n]+") do print("    " .. line) end
    if name == "file-header" then
        print("  and the notes file's first line is: " .. (fs.read(notes_file):match("^[^\n]*")))
        print("  (it gains the header the next time the program saves; add one note:)")
        run_notes("add call the dentist")
        print("  first line now: " .. (fs.read(notes_file):match("^[^\n]*")))
    end
    print("")
end

print("NUMBERS — how much of the design each grade rebuilt")
for _, t in ipairs(tally) do
    print(string.format("  %-18s %-10s %d of 6 issues  %s  %d turns",
        t.name, t.grade, t.reach, string.rep("█", t.reach * 4) .. string.rep("·", (6 - t.reach) * 4), t.turns))
end
local verified = ledger.verify(record.ledger)
print(string.format("  ledger: %d lines, chain %s", verified.count, verified.ok and "intact" or "BROKEN"))

local key = design_folder.scratch_key(record)
fs.remove_tree("/tmp/burner-of-down-things/cases/" .. key)
fs.remove_tree("/dev/shm/burner-of-down-things/cases/" .. key)
fs.remove_tree(scratch)
