-- 057-checking-the-update.lua
--
-- Checks phase 6 (issues 601–603): the grade rule at each of its edges,
-- reading a locate turn's answer, the graded line read back, locating with
-- a bad first answer, amending (a good amend changes only what it names;
-- three bad amends leave the blueprint byte-identical), and the update step
-- over the fixture's three requests under each hold setting — with each
-- rebuild exactly its reach.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local ledger = require("016-ledger")
local text_tables = require("014-text-tables")
local case = require("018-the-case")
local outline = require("042-the-outline")
local graph = require("043-the-graph")
local describing = require("045-describing")
local building = require("050-building")
local grading = require("053-grading")
local amending = require("054-amending")
local updating = require("055-updating")

-- {{{ local function row
local function row(id, blocked_by)
    return { id = id, name = "n" .. id, blocked_by = blocked_by or "-", covers = "-" }
end
-- }}}

-- The grade rule on a six-issue graph:
--   101, 102 (level 0); 201 <- 101; 202 <- 102; 203 <- 102; 301 <- 202
local g = graph.build({ row("101"), row("102"), row("201", "101"), row("202", "102"), row("203", "102"), row("301", "202") })
kit.equal((grading.grade(g, { "301" }, {})), "surface", "a leaf is surface")
kit.equal((grading.grade(g, { "201" }, {})), "surface", "a level-1 leaf is surface")
local grade_202, reach_202 = grading.grade(g, { "202" }, {})
kit.equal(grade_202, "middle", "an issue with one issue built on it (reach 2 of 6) is middle")
kit.equal(table.concat(reach_202, " "), "202 301", "and its reach is itself and what is built on it")
local g7 = graph.build({ row("101"), row("201", "101"), row("301", "201"), row("302", "201"), row("102"), row("103") })
kit.equal((grading.grade(g7, { "201" }, {})), "foundation", "a reach of exactly half (3 of 6) is foundation — the line's edge")
kit.equal((grading.grade(g, { "101" }, {})), "foundation", "a level-0 issue is foundation")
kit.equal((grading.grade(g, {}, { "3" })), "surface", "a request needing only a new issue is surface")

-- Reading a locate turn's answer.
local touched, new_phases, findings = grading.parse_touched("301\n\nnew 4\n301\n", g)
kit.equal(table.concat(touched, " "), "301", "ids read once each")
kit.equal(table.concat(new_phases, " "), "4", "new lines read")
kit.equal(#findings, 0, "a good answer has no findings")
local _, _, bad = grading.parse_touched("999\n", g)
kit.check(#bad == 1 and bad[1]:find("999", 1, true) ~= nil, "an unknown id is a finding that names it")
local _, _, empty = grading.parse_touched("\n", g)
kit.equal(#empty, 1, "an empty answer is a finding")

-- The graded line read back.
local folder = kit.scratch("grade")
local fake = { ledger = folder .. "/ledger", output = folder }
ledger.create(fake.ledger, "x")
grading.record(fake, "req", "middle", { "202" }, {}, { "202", "301" }, 6)
local line = ledger.read(fake.ledger)[2]
local pg, pt, pn, pr = grading.parse_graded(line.text)
kit.check(pg == "middle" and pt[1] == "202" and #pn == 0 and table.concat(pr, " ") == "202 301", "a graded line reads back: " .. line.text)
kit.check(fs.read(folder .. "/req.grade"):find("rebuilds: 2 of 6", 1, true) ~= nil, "the person's grade file says how much is rebuilt")

-- {{{ local function delivered_case
-- The fixture described and built, with its three requests playable.
local function delivered_case(label, hold)
    local project, record = kit.fixture_case(label, "with_requests = true")
    describing.step(project, record, outline.step(project, record, {}), {})
    building.step(project, record, {})
    if hold then
        record.hold = hold
        case.save(record)
    end
    return project, record
end
-- }}}

-- {{{ local function drop_requests
local function drop_requests(record, names)
    for _, name in ipairs(names) do
        kit.write_file(record.input .. "/" .. name, fs.read(kit.project.fixtures .. "/tiny-notes-requests/" .. name .. "/request"))
        ledger.append(record.ledger, "request-received", name, "noticed")
    end
end
-- }}}

-- {{{ local function builds_since
-- Build turns run after ledger line `seq`, by issue id.
local function builds_since(record, seq)
    local ids = {}
    for _, l in ipairs(ledger.read(record.ledger)) do
        if l.seq > seq and l.kind == "turn-started" and l.about:find("%-build%-") then
            ids[#ids + 1] = l.about:match("%-build%-(%d+)$")
        end
    end
    table.sort(ids)
    return table.concat(ids, " ")
end
-- }}}

-- The update step under the default hold (foundation).
local project, record = delivered_case("update", nil)
drop_requests(record, { "count-in-list", "hash-marked-tags", "file-header" })
local seq0 = #ledger.read(record.ledger)
local results = updating.step(project, record, {})
local outcome = {}
for _, r in ipairs(results) do outcome[r.name] = r.outcome .. " " .. (r.grade or "") end
kit.equal(outcome["count-in-list"], "done surface", "the surface request is done")
kit.equal(outcome["hash-marked-tags"], "done middle", "the middle request is done")
kit.equal(outcome["file-header"], "held foundation", "the foundation request is held")
kit.equal(builds_since(record, seq0), "201 301 301", "rebuilt exactly the reaches: 301, then 201 and 301")
kit.check(fs.read(record.design .. "/src/show.lua"):find("#", 1, true) ~= nil, "the middle change reached the design")
local again = updating.step(project, record, {})
kit.equal(#again, 1, "only the held request still waits")
local held_lines = 0
for _, l in ipairs(ledger.read(record.ledger)) do
    if l.kind == "held" then held_lines = held_lines + 1 end
end
kit.equal(held_lines, 1, "a request held twice is recorded held once")
local seq1 = #ledger.read(record.ledger)
local go = updating.step(project, record, { go = true })
kit.equal(go[1].outcome, "done", "--go carries the foundation request through")
kit.equal(builds_since(record, seq1), "101 201 202 301", "rebuilding its whole reach")
local notes_out = fs.capture("cd " .. fs.quote(record.design) .. " && NOTES_FILE=n.txt luajit notes.lua add x '#y' && head -1 n.txt && NOTES_FILE=n.txt luajit notes.lua list")
kit.check(notes_out:find("# notes v1", 1, true) and notes_out:find("[#y]", 1, true) and notes_out:find("1 note", 1, true),
    "all three changes are in the running design")
kit.equal(#updating.waiting(ledger.read(record.ledger)), 0, "nothing waits")

-- Hold "none" holds nothing; hold "middle" holds the middle one too.
local p2, r2 = delivered_case("hold-none", "none")
drop_requests(r2, { "file-header" })
kit.equal(updating.step(p2, r2, {})[1].outcome, "done", "with no hold a foundation request goes straight through")
local p3, r3 = delivered_case("hold-middle", "middle")
drop_requests(r3, { "hash-marked-tags" })
kit.equal(updating.step(p3, r3, {})[1].outcome, "held", "with the hold at middle a middle request waits")

-- Locating: a bad first answer, then a good one.
local p4, r4 = delivered_case("locate", nil)
kit.write_file(r4.folder .. "/stand-in.lua", [[
return { locate = function(turn)
    return { writes = { ["turn/touched"] = turn.attempt == 1 and "999\n" or "301\n" } }
end }
]])
kit.write_file(r4.input .. "/wish", "a wish\n")
local t4 = grading.locate(p4, r4, graph.build((text_tables.read(r4.blueprint .. "/outline.tsv"))), "wish", {})
kit.equal(table.concat(t4, " "), "301", "the second locate answer is taken")
kit.equal(kit.turns_of(r4, "locate"), 2, "after one bad answer")

-- Amending: three bad amends put the blueprint back exactly.
local before = {}
for _, name in ipairs(fs.list(r4.issues)) do before[name] = fs.read(r4.issues .. "/" .. name) end
local outline_before = fs.read(r4.blueprint .. "/outline.tsv")
kit.write_file(r4.folder .. "/stand-in.lua", [[
return { amend = { writes = {
    ["blueprint/issues/301-the-notes-command.md"] = "# 301\n\nno sections at all\n",
    ["blueprint/issues/401-stray.md"] = "# 401\n",
} } }
]])
local amended = amending.amend(p4, r4, "wish", { "301" }, {})
kit.check(not amended.ok, "an amend that never passes fails")
kit.equal(kit.turns_of(r4, "amend"), 3, "after three turns")
local same = fs.read(r4.blueprint .. "/outline.tsv") == outline_before
for _, name in ipairs(fs.list(r4.issues)) do
    if before[name] ~= fs.read(r4.issues .. "/" .. name) then same = false end
end
for name in pairs(before) do
    if not fs.exists(r4.issues .. "/" .. name) then same = false end
end
kit.check(same and not fs.exists(r4.issues .. "/401-stray.md"), "the blueprint is byte-identical to before, the stray file gone")
local kept_way_back = 0
for _, name in ipairs(fs.list(r4.turns)) do
    if name:match("%-amend%-") and fs.exists(r4.turns .. "/" .. name .. "/before/outline.tsv")
        and fs.exists(r4.turns .. "/" .. name .. "/before/301-the-notes-command.md") then
        kept_way_back = kept_way_back + 1
    end
end
kit.equal(kept_way_back, 3, "each amend turn keeps its way back beside it")

kit.check(ledger.verify(record.ledger).ok, "the ledger verifies")
kit.finish()
