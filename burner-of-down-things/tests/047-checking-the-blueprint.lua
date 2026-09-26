-- 047-checking-the-blueprint.lua
--
-- Checks phase 4 (issues 401–404): the outline's checks one finding at a
-- time, the graph's levels and reach, reading and checking issue files, and
-- the outline and describe steps driven by the stand-in on the tiny-notes
-- fixture — including bad first attempts that must be caught and retried.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local case = require("018-the-case")
local ledger = require("016-ledger")
local survey = require("029-the-survey")
local summary = require("030-the-survey-summary")
local outline = require("042-the-outline")
local graph = require("043-the-graph")
local issue_files = require("044-issue-files")
local describing = require("045-describing")

-- {{{ local function row
local function row(id, name, blocked_by, covers)
    return { id = id, name = name, blocked_by = blocked_by or "-", covers = covers or "-" }
end
-- }}}

-- {{{ local function findings_of
-- The findings of one named check.
local function findings_of(rows, survey_rows, name)
    local results = outline.check(rows, survey_rows or {})
    for _, r in ipairs(results) do
        if r.name == name then
            return r.findings
        end
    end
end
-- }}}

-- The outline's checks, one finding each.
kit.equal(#findings_of({ row("1011", "a") }, nil, "ids"), 1, "a four-digit id is refused")
kit.equal(#findings_of({ row("101", "a"), row("101", "b") }, nil, "ids"), 1, "a repeated id is refused")
kit.equal(#findings_of({}, nil, "ids"), 1, "an empty outline is refused")
kit.equal(#findings_of({ row("101", "Bad Name") }, nil, "names"), 1, "a bad name is refused")
kit.equal(#findings_of({ row("101", "a", "999") }, nil, "blockers"), 1, "a missing blocker is refused")
local cycle = findings_of({ row("101", "a", "103"), row("102", "b", "101"), row("103", "c", "102") }, nil, "cycles")
kit.equal(#cycle, 1, "a cycle is found")
kit.check(cycle[1] and cycle[1]:find("101 -> 103 -> 102 -> 101", 1, true) ~= nil, "and named in order: " .. tostring(cycle[1]))
local survey_rows = { { path = "a.lua", role = "code" }, { path = "README.md", role = "doc" }, { path = "Makefile", role = "build" } }
local coverage = findings_of({ row("101", "a", "-", "a.lua ghost.lua") }, survey_rows, "coverage")
kit.equal(#coverage, 2, "an uncovered build file and a covered ghost file")
local _, all_ok = outline.check({ row("101", "a", "-", "a.lua Makefile") }, survey_rows)
kit.check(all_ok, "a good outline passes every check")

-- The graph: a diamond, then the fixture's six issues.
local diamond = graph.build({ row("101", "a"), row("201", "b", "101"), row("202", "c", "101"), row("301", "d", "201 202") })
local levels = graph.levels(diamond)
kit.equal(#levels, 3, "three levels")
kit.equal(table.concat(levels[2], " "), "201 202", "level 1 holds the middle pair")
kit.equal(table.concat(graph.reach(diamond, { "101" }), " "), "101 201 202 301", "the foundation reaches everything")
kit.equal(table.concat(graph.reach(diamond, { "201" }), " "), "201 301", "a middle issue reaches what is built on it")
kit.equal(table.concat(graph.reach(diamond, { "301" }), " "), "301", "a leaf reaches itself")
kit.equal(table.concat(diamond.nodes["101"].blocks, " "), "201 202", "reverse edges")

local fixtures = kit.project.fixtures
local fixture_rows = require("014-text-tables").read(fixtures .. "/tiny-notes-blueprint/outline.tsv")
local notes_graph = graph.build(fixture_rows)
kit.equal(#graph.levels(notes_graph), 3, "tiny-notes has three levels")
kit.equal(#graph.reach(notes_graph, { "201" }), 2, "showing-notes reaches 2 of 6")

-- Issue files: reading and checking.
local issue = issue_files.read(fixtures .. "/tiny-notes-blueprint/issues/301-the-notes-command.md")
kit.equal(issue.id, "301", "id from the file name")
kit.equal(table.concat(issue.blocked_by, " "), "101 102 103 201 202", "blockers read")
kit.equal(issue.acceptance[1], "luajit tests/301-the-notes-command.lua", "acceptance command read")
kit.equal(#issue_files.check(issue, row("301", "the-notes-command", "101 102 103 201 202")), 0, "a good issue passes")
local wrong = issue_files.check(issue, row("301", "the-notes-command", "101"))
kit.equal(#wrong, 1, "different blockers from the outline are a finding")
local scratch = kit.scratch("issues")
kit.write_file(scratch .. "/issues/101-bare.md", "# 101\n\n## Current Behavior\n\nx\n\n## Blocked by\n\nNone\n")
local bare = issue_files.check(issue_files.read(scratch .. "/issues/101-bare.md"), row("101", "bare"))
kit.check(#bare >= 4, "missing sections and acceptance are findings (" .. #bare .. ")")
kit.equal(#issue_files.validate(kit.project.validate_issues, fixtures .. "/tiny-notes-blueprint",
    fixtures .. "/tiny-notes-blueprint/issues/201-showing-notes.md"), 0, "the house validator passes a fixture issue")
kit.check(#issue_files.validate(kit.project.validate_issues, scratch, scratch .. "/issues/101-bare.md") > 0,
    "the house validator's findings come through")
kit.raises(function() issue_files.validate("/no/such/validator", scratch, scratch .. "/issues/101-bare.md") end,
    "validator is missing", "a missing validator refuses")

-- The steps, driven by the stand-in on a copy of the fixture source.
-- {{{ local function fixture_case
local function fixture_case(label, options_text)
    local project, folder = kit.project_copy(label)
    local src = folder .. "/tiny-notes"
    fs.run("cp -r " .. fs.quote(fixtures .. "/tiny-notes") .. " " .. fs.quote(src))
    local record = case.open(project, label, src, "stand-in")
    kit.write_file(record.folder .. "/stand-in.lua", "return dofile(" .. string.format("%q", fixtures .. "/tiny-notes.stand-in.lua")
        .. ")({ root = " .. string.format("%q", fixtures) .. ", " .. (options_text or "") .. " })\n")
    survey.run(project, record, 2)
    summary.write(record.survey)
    return project, record
end
-- }}}

-- {{{ local function turns_of
local function turns_of(record, kind)
    local n = 0
    for _, name in ipairs(fs.list(record.turns)) do
        if name:match("^%d+%-" .. kind .. "%-") then n = n + 1 end
    end
    return n
end
-- }}}

local project, record = fixture_case("outline-retry", "bad_outline = 1")
local rows = outline.step(project, record, {})
kit.equal(#rows, 6, "the outline has six issues")
kit.equal(turns_of(record, "outline"), 2, "a bad first outline gets a second turn")
local index = ledger.index(ledger.read(record.ledger))
kit.check(ledger.has(index, "outline-failed", "attempt 1"), "the failed attempt is in the ledger")
kit.check(index["outline-failed"]["attempt 1"].text:find("notes.lua", 1, true) ~= nil, "naming the uncovered file")
kit.check(ledger.has(index, "outlined", "-"), "and the passing one")

local p2, r2 = fixture_case("outline-never", "bad_outline = 9")
kit.raises(function() outline.step(p2, r2, {}) end, "outline turns failed", "three bad outlines stop the step")

local p3, r3 = fixture_case("describe", "bad_describe = { [\"202\"] = 2 }")
local rows3 = outline.step(p3, r3, {})
local report = describing.step(p3, r3, rows3, {})
kit.equal(#report.described, 6, "all six issues described")
kit.equal(#report.failed, 0, "none failed")
kit.equal(turns_of(r3, "describe"), 8, "six first turns, and two more for 202")
local again = describing.step(p3, r3, rows3, {})
kit.equal(again.turns, 0, "describing again runs no turns")
kit.check(ledger.verify(r3.ledger).ok, "the ledger verifies")

local p4, r4 = fixture_case("describe-fails", "bad_describe = { [\"103\"] = 9 }")
local report4 = describing.step(p4, r4, outline.step(p4, r4, {}), {})
kit.equal(table.concat(report4.failed, " "), "103", "an issue that never passes is describe-failed")
kit.check(ledger.has(ledger.index(ledger.read(r4.ledger)), "describe-failed", "103"), "and so recorded")

kit.finish()
