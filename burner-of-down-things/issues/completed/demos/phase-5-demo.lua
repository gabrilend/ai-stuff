-- phase-5-demo.lua
--
-- The phase 5 demonstration, run by phase-5-demo. Every earlier phase in
-- one line: a case (1) on the notes fixture, surveyed (2), described by
-- turns through the pool (3, 4), then built (5).

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

-- {{{ local function wall
local function wall()
    return tonumber((fs.capture("date +%s.%N")))
end
-- }}}

local scratch = project.scratch .. "/demo-phase-5"
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

-- {{{ local function described_case
local function described_case(name, options_text)
    local record = case.open(demo_project, name, scratch .. "/tiny-notes", "stand-in")
    fs.write(record.folder .. "/stand-in.lua", "return dofile(" .. string.format("%q", project.fixtures .. "/tiny-notes.stand-in.lua")
        .. ")({ root = " .. string.format("%q", project.fixtures) .. ", " .. options_text .. " })\n")
    survey.run(demo_project, record, nil)
    summary.write(record.survey)
    describing.step(demo_project, record, outline.step(demo_project, record, {}), {})
    return record
end
-- }}}

-- {{{ local function turn_timeline
-- The build and repair turns in the order they ran, from the ledger.
local function turn_timeline(record)
    local out = {}
    for _, line in ipairs(ledger.read(record.ledger)) do
        if line.kind == "turn-ended" and (line.about:find("-build-", 1, true) or line.about:find("-repair-", 1, true)) then
            out[#out + 1] = line
        elseif line.kind == "built" or line.kind == "build-failed" or line.kind == "delivered" then
            out[#out + 1] = line
        end
    end
    return out
end
-- }}}

print("PHASE 5 — THE DESIGN")
print("")
print("CASE ONE — issue 202 is built broken the first time")
local record = described_case("notes", 'broken_build = { ["202"] = 1 }')
local t0 = wall()
local report = building.step(demo_project, record, {})
local seconds = wall() - t0
for _, line in ipairs(turn_timeline(record)) do
    local mark = (line.kind == "built" or line.kind == "delivered") and "✓"
        or (line.kind == "build-failed" and "✗") or "·"
    local what = line.kind == "turn-ended" and (line.about:gsub("^%d+%-", "")) or line.kind
    print(string.format("  %s %-22s %-5s %s", mark, what, line.kind == "turn-ended" and "" or line.about,
        (line.text:gsub("; %d+ file%(s%) changed", "")):sub(1, 60)))
end
print("")
print(string.format("  %d waves, %d turns (%d repair), %.2f s — delivered: %s",
    report.waves, report.turns, report.repairs, seconds, report.delivered and "yes" or "no"))
local verified = ledger.verify(record.ledger)
local delivered_text = fs.read(record.output .. "/delivered")
print("  fingerprint in output/delivered matches the ledger line it names: "
    .. ((delivered_text:find(report.head, 1, true) and ledger.index(ledger.read(record.ledger))["delivered"]["-"].hash == report.head) and "yes" or "NO"))
print("  ledger chain: " .. (verified.ok and ("intact, " .. verified.count .. " lines") or "BROKEN"))
print("")

print("THE DESIGN RUNS — built from the blueprint, never from the source")
local notes_file = scratch .. "/notes.txt"
for _, args in ipairs({ "add buy oat milk '#home' '#errands'", "add oil the '#bike' chain", "add call the dentist", "list", "list '#bike'", "find MILK" }) do
    local out = fs.capture("cd " .. fs.quote(record.design) .. " && NOTES_FILE=" .. fs.quote(notes_file) .. " luajit notes.lua " .. args)
    print("  $ notes " .. args)
    for line in out:gmatch("[^\n]+") do
        print("    " .. line)
    end
end
local design_files, design_lines = 0, 0
for _, sub in ipairs({ "src", "tests" }) do
    for _, name in ipairs(fs.list(record.design .. "/" .. sub)) do
        -- Only the design's own code and tests; the skeleton's README notes
        -- are not part of what was built.
        if name:match("%.lua$") then
            design_files = design_files + 1
            local _, n = fs.read(record.design .. "/" .. sub .. "/" .. name):gsub("\n", "")
            design_lines = design_lines + n
        end
    end
end
print(string.format("  design: %d source and test files, %d lines, in %s", design_files + 1, design_lines,
    "…/cases/notes/design (a house project: " .. #fs.list(record.design) .. " entries at its top)"))
print("")

print("CASE TWO — issue 202 can never be built")
local broken = described_case("notes-broken", 'broken_build = { ["202"] = 9 }')
local report2 = building.step(demo_project, broken, {})
local marks = {}
for _, id in ipairs(report2.built) do marks[id] = "built" end
for _, id in ipairs(report2.failed) do marks[id] = "FAILED" end
for _, id in ipairs(report2.held) do marks[id] = "held: " .. report2.held_why[id] end
local rows = text_tables.read(broken.blueprint .. "/outline.tsv")
for line in graph.text(graph.build(rows), marks):gmatch("[^\n]+") do
    print("  " .. line)
end
print(string.format("  built %d, failed %d, held %d, %d repairs — delivered: %s",
    #report2.built, #report2.failed, #report2.held, report2.repairs, report2.delivered and "yes" or "no"))

print("")
print("CASE THREE — a builder grades itself: 201 is built with the tags quietly dropped,")
print("and its own test weakened to match. Only the referee's workflows, written from")
print("the blueprint by a turn that never saw the design, can catch it.")
-- {{{ local function show_search
-- The path each search took: narrow audits, wider looks, the fix.
local function show_search(report)
    for _, search in ipairs(report.searches or {}) do
        print("  workflow " .. search.workflow .. " failed; the search went:")
        for i, step in ipairs(search.path) do
            print(string.format("    %d. %s", i, step))
        end
        print("    → " .. (search.fixed and "fixed" or "not found"))
    end
end
-- }}}

local quiet = described_case("notes-quiet", 'quiet_bug = { ["201"] = 1 }')
local report3 = building.step(demo_project, quiet, {})
print("  201's own acceptance: " .. ledger.index(ledger.read(quiet.ledger)).built["201"].text)
show_search(report3)
print(string.format("  delivered: %s — the search stopped as soon as the workflow passed",
    report3.delivered and "yes" or "no"))

print("")
print("CASE FOUR — the same bug, but no part looked at alone shows it: the view widens")
print("to pairs chosen at random (the odd one out skipped), then to everything, until")
print("a look names the part; then it narrows back to that one part to fix it.")
local hidden = described_case("notes-hidden", 'quiet_bug = { ["201"] = 1 }, hidden_bug = true')
local report4 = building.step(demo_project, hidden, {})
show_search(report4)
for _, line in ipairs(ledger.read(hidden.ledger)) do
    if line.kind == "inspected" then
        print(string.format("  inspected %-12s named %s", line.about, line.text))
    end
end
print("  delivered: " .. (report4.delivered and "yes" or "no") .. " — dynamic re-abstraction")

-- The designs' own scratch space lives outside the demo folder.
for _, r in ipairs({ record, broken, quiet, hidden }) do
    local key = design_folder.scratch_key(r)
    fs.remove_tree("/tmp/burner-of-down-things/cases/" .. key)
    fs.remove_tree("/dev/shm/burner-of-down-things/cases/" .. key)
end
fs.remove_tree(scratch)
