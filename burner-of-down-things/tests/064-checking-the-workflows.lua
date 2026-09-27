-- 064-checking-the-workflows.lua
--
-- Checks issue 506: workflows written from the blueprint alone. The referee
-- sees only the blueprint; no build or repair turn can write a workflow; a
-- workflow that passes with nothing built is sent back; a builder whose own
-- test passes but whose behaviour is wrong is caught by a workflow and
-- repaired; a referee that never writes a toothed workflow blocks delivery;
-- and an amend rewrites the workflows so the rebuilt design is checked
-- against the changed behaviour.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local ledger = require("016-ledger")
local kinds = require("034-turn-kinds")
local outline = require("042-the-outline")
local describing = require("045-describing")
local building = require("050-building")
local updating = require("055-updating")
local workflows = require("063-workflows")

-- The table: the referee reads the blueprint only; only it writes workflows.
local referee = kinds.TABLE.referee
kit.equal(table.concat(referee.reads, " "), "blueprint/", "the referee reads the blueprint and nothing else")
for name, row in pairs(kinds.TABLE) do
    for _, w in ipairs(row.writes) do
        if w:find("^workflows") then
            kit.equal(name, "referee", "only the referee may write workflows (found " .. name .. ")")
        end
    end
end

-- {{{ local function described_case
local function described_case(label, options_text)
    local project, record = kit.fixture_case(label, options_text)
    describing.step(project, record, outline.step(project, record, {}), {})
    return project, record
end
-- }}}

-- A clean build: workflows written first, all passing, delivered.
local project, record = described_case("workflows", "")
local report = building.step(project, record, {})
kit.check(report.delivered, "a clean build is delivered")
local list = workflows.list(record)
kit.equal(#list, 5, "five workflows written")
kit.equal(table.concat(list[1].covers, " "), "101 103 201 301", "each names what it covers")
kit.equal(#workflows.run_all(record), 0, "every workflow passes on the delivered design")
local referee_turn
for _, name in ipairs(fs.list(record.turns)) do
    if name:match("%-referee%-") then referee_turn = record.turns .. "/" .. name end
end
local prompt = fs.read(referee_turn .. "/prompt.md") .. fs.read(referee_turn .. "/instructions.md")
kit.check(not prompt:find(record.source, 1, true), "the referee's prompt and instructions never name the source")
kit.check(not prompt:find(record.design, 1, true), "nor the design")

-- A workflow with no teeth is sent back.
local p2, r2 = described_case("toothless", "toothless_referee = 1")
local report2 = building.step(p2, r2, {})
kit.equal(kit.turns_of(r2, "referee"), 2, "a toothless first set gets a second referee turn")
kit.check(report2.delivered, "then the design is delivered")
kit.check(not fs.exists(r2.workflows .. "/09-always.sh"), "the toothless workflow is gone")

-- A referee that never writes toothed workflows blocks delivery.
local p3, r3 = described_case("never-toothed", "toothless_referee = 9")
local report3 = building.step(p3, r3, {})
kit.check(not report3.delivered, "no referees, no delivery")
kit.check(ledger.has(ledger.index(ledger.read(r3.ledger)), "referee-failed", "-"), "referee-failed recorded")

-- The quiet bug: the builder's own test passes; the workflow does not.
local p4, r4 = described_case("quiet-bug", 'quiet_bug = { ["201"] = 1 }')
local report4 = building.step(p4, r4, {})
kit.check(report4.delivered, "the quiet bug is caught and repaired, then delivered")
local idx = ledger.index(ledger.read(r4.ledger))
kit.equal(idx.built["201"].text, "acceptance passed", "201's own acceptance passed on the buggy build")
local repair_prompt
for _, name in ipairs(fs.list(r4.turns)) do
    if name:match("%-audit%-201$") then repair_prompt = fs.read(r4.turns .. "/" .. name .. "/prompt.md") end
end
kit.check(repair_prompt and repair_prompt:find("The failing workflow: 02-tags.sh", 1, true) ~= nil,
    "201 was audited because of the tags workflow (issue 507)")
kit.check(repair_prompt and not repair_prompt:find("covers:", 1, true), "the audit saw the workflow's output, not its text")

-- A build turn that writes a workflow is a breach.
local p5, r5 = described_case("build-writes-referee", "")
kit.write_file(r5.folder .. "/stand-in.lua", "return { referee = function() return dofile(" .. string.format("%q", r5.folder .. "/fixture-referee.lua") .. ") end,"
    .. " build = { writes = { ['workflows/01-mine.sh'] = '#!/usr/bin/env bash\\n# covers: 101\\nexit 0\\n' } } }\n")
kit.write_file(r5.folder .. "/fixture-referee.lua", "local w = dofile(" .. string.format("%q", kit.project.fixtures .. "/tiny-notes-referee.lua") .. ")\n"
    .. "local b = {} for _, id in ipairs({'101','102','103','201','202','301'}) do b[id] = '' end\n"
    .. "local writes = {} for n, t in pairs(w(b)) do writes['workflows/' .. n] = t end\nreturn { writes = writes }\n")
kit.raises(function() building.step(p5, r5, {}) end, "wrote outside its folders", "a build turn writing a workflow is a breach")

-- An amend rewrites the workflows; the rebuilt design passes the new ones.
local p6, r6 = described_case("amended", "with_requests = true")
building.step(p6, r6, {})
kit.write_file(r6.input .. "/count-in-list", fs.read(kit.project.fixtures .. "/tiny-notes-requests/count-in-list/request"))
ledger.append(r6.ledger, "request-received", "count-in-list", "noticed")
local results = updating.step(p6, r6, {})
kit.equal(results[1].outcome, "done", "the request is done")
kit.check(fs.read(r6.workflows .. "/01-add-and-list.sh"):find("2 notes", 1, true) ~= nil, "the listing workflow now expects the count")
kit.equal(#workflows.run_all(r6), 0, "and the rebuilt design passes every workflow")

kit.check(ledger.verify(r4.ledger).ok, "the ledger verifies")
kit.finish()
