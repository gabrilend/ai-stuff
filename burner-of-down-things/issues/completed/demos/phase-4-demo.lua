-- phase-4-demo.lua
--
-- The phase 4 demonstration, run by phase-4-demo. The tiny-notes fixture
-- (copied to scratch space) is opened as a case (phase 1), surveyed (phase
-- 2), outlined and described by stand-in turns through the pool (phase 3),
-- then shown as a graph, a coverage map and the validator's verdict.

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

-- {{{ local function wall
local function wall()
    return tonumber((fs.capture("date +%s.%N")))
end
-- }}}

-- {{{ local function width
-- Characters on screen, not bytes (box-drawing characters are 3 bytes).
local function width(text)
    local _, continuation = text:gsub("[\128-\191]", "")
    return #text - continuation
end
-- }}}

-- {{{ local function pad
local function pad(text, n)
    return text .. string.rep(" ", math.max(0, n - width(text)))
end
-- }}}

local scratch = project.scratch .. "/demo-phase-4"
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

local record = case.open(demo_project, "tiny-notes", scratch .. "/tiny-notes", "stand-in")
fs.write(record.folder .. "/stand-in.lua", "return dofile(" .. string.format("%q", project.fixtures .. "/tiny-notes.stand-in.lua")
    .. ")({ root = " .. string.format("%q", project.fixtures) .. ", bad_outline = 1, bad_describe = { [\"202\"] = 2 } })\n")

print("PHASE 4 — THE BLUEPRINT")
print("")
print("source: a small notes program (add, list by tag, find), six files")
local t0 = wall()
local counts = survey.run(demo_project, record, nil)
summary.write(record.survey)
print(string.format("surveyed: %d files, %d links", counts.files, counts.links))
print("")

local rows = outline.step(demo_project, record, {})
local report = describing.step(demo_project, record, rows, {})
local seconds = wall() - t0

-- What the ledger saw, in order: the story of the description.
print("THE LEDGER'S ACCOUNT (outline and describe lines)")
for _, line in ipairs(ledger.read(record.ledger)) do
    if line.kind == "outlined" or line.kind == "outline-failed" or line.kind == "described" or line.kind == "describe-failed" then
        local mark = (line.kind:find("failed") and "✗" or "✓")
        print(string.format("  %s %-15s %-10s %s", mark, line.kind, line.about, line.text:sub(1, 70)))
    end
end
print("")

-- The graph as columns, one per level.
local g = graph.build(rows)
local levels = graph.levels(g)
print("THE GRAPH — build order runs left to right; ← names what an issue is built on")
local columns, tallest = {}, 0
for level, ids in ipairs(levels) do
    local lines = { "level " .. (level - 1) }
    for _, id in ipairs(ids) do
        local node = g.nodes[id]
        local label = id .. " " .. node.name
        local under = #node.blocked_by > 0 and ("← " .. table.concat(node.blocked_by, " ")) or "(foundation)"
        local w = math.max(width(label), width(under)) + 2
        lines[#lines + 1] = "┌" .. string.rep("─", w) .. "┐"
        lines[#lines + 1] = "│ " .. pad(label, w - 1) .. "│"
        lines[#lines + 1] = "│ " .. pad(under, w - 1) .. "│"
        lines[#lines + 1] = "└" .. string.rep("─", w) .. "┘"
    end
    columns[level] = lines
    tallest = math.max(tallest, #lines)
end
local column_width = {}
for level, lines in ipairs(columns) do
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, width(l)) end
    column_width[level] = w + 3
end
for i = 1, tallest do
    local cells = {}
    for level, lines in ipairs(columns) do
        cells[level] = pad(lines[i] or "", column_width[level])
    end
    print("  " .. table.concat(cells))
end
print("")

-- Coverage: every code file of the survey, and the issue that describes it.
print("COVERAGE — every code file of the source, and the issue that describes it")
local coverer = {}
for _, r in ipairs(rows) do
    for _, p in ipairs(outline.words(r.covers)) do
        coverer[p] = r.id .. " " .. r.name
    end
end
local covered, code_files = 0, 0
for _, f in ipairs((text_tables.read(record.survey .. "/files.tsv"))) do
    if f.role == "code" then
        code_files = code_files + 1
        if coverer[f.path] then covered = covered + 1 end
        print(string.format("  %-16s %5s lines  →  %s", f.path, f.lines, coverer[f.path] or "NOT COVERED"))
    end
end
print("")

-- The house validator over the whole blueprint.
local out, ok = fs.capture(fs.quote(project.validate_issues) .. " " .. fs.quote(record.blueprint) .. " 2>&1")
print("HOUSE VALIDATOR on the whole blueprint: " .. (ok and "clean" or "findings"))
for line in out:gmatch("[^\n]+") do
    print("  " .. line)
end
print("")

local turns = 0
for _, name in ipairs(fs.list(record.turns)) do
    if name:match("^%d%d%d%d%-") then turns = turns + 1 end
end
print(string.format("NUMBERS — %d issues, %d levels, %d of %d code files covered, %d turns (%d retries), %.2f s",
    #rows, #levels, covered, code_files, turns, turns - 1 - #rows, seconds))
print("the blueprint is at " .. record.blueprint .. " (removed when the demo ends)")

fs.remove_tree(scratch)
