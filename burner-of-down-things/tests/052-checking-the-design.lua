-- 052-checking-the-design.lua
--
-- Checks phase 5 (issues 501–504): the design folder's layout and its own
-- scratch space, running acceptance (pass, failure with its output, a
-- timeout), building in waves with the stand-in on the tiny-notes fixture —
-- a clean build, a build repaired once, a build that never passes and holds
-- its reach, a later build that breaks an earlier issue — and delivery.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local ledger = require("016-ledger")
local outline = require("042-the-outline")
local describing = require("045-describing")
local issue_files = require("044-issue-files")
local design_folder = require("048-the-design-folder")
local acceptance = require("049-acceptance")
local building = require("050-building")

-- {{{ local function described_case
-- A fixture case already outlined and described, ready to build.
local function described_case(label, options_text)
    local project, record = kit.fixture_case(label, options_text)
    describing.step(project, record, outline.step(project, record, {}), {})
    return project, record
end
-- }}}

-- The design folder.
local project, record = described_case("layout", "")
kit.check(design_folder.lay_out(project, record), "the first layout lays the folder out")
for _, sub in ipairs({ "src", "docs", "issues", "input", "output", "notes" }) do
    kit.check(fs.is_folder(record.design .. "/" .. sub), "design has " .. sub .. "/")
end
local door = fs.capture("readlink " .. fs.quote(record.design .. "/tmp")):gsub("\n$", "")
kit.equal(door, "/tmp/burner-of-down-things/cases/" .. design_folder.scratch_key(record),
    "the design's scratch door is its own, keyed by case")
kit.check(fs.read(record.design .. "/README"):find(record.name, 1, true) ~= nil, "the README names the case")
kit.check(fs.exists(record.output .. "/first-build"), "the person is told acceptance commands will run")
kit.check(not design_folder.lay_out(project, record), "a second layout does nothing")

-- Acceptance.
kit.write_file(record.design .. "/ok.sh", "echo fine\n")
kit.write_file(record.issues .. "/901-probe.md", "# 901\n\n## Acceptance\n\n```sh\nbash ok.sh\necho second; exit 3\nbash ok.sh\n```\n")
local probe = issue_files.read(record.issues .. "/901-probe.md")
local failed = acceptance.run(record, probe, nil)
kit.check(not failed.ok, "a failing command fails the issue")
kit.equal(failed.command, "echo second; exit 3", "the failing command is named")
kit.check(failed.output:find("second", 1, true) ~= nil, "and its output carried")
kit.write_file(record.issues .. "/902-slow.md", "# 902\n\n## Acceptance\n\n```sh\nsleep 5\n```\n")
local slow = acceptance.run(record, issue_files.read(record.issues .. "/902-slow.md"), nil, 1)
kit.check(not slow.ok and slow.timed_out, "a command past its limit is stopped and said to be")
os.remove(record.issues .. "/901-probe.md")
os.remove(record.issues .. "/902-slow.md")

-- A clean build: three waves, everything built, delivered.
local report = building.step(project, record, {})
kit.equal(#report.built, 6, "six issues built")
kit.equal(report.waves, 3, "in three waves")
kit.equal(report.turns, 6, "one turn each")
kit.check(report.delivered, "delivered")
kit.check(fs.read(record.output .. "/delivered"):find(report.head, 1, true) ~= nil, "delivery names the ledger head")
local index = ledger.index(ledger.read(record.ledger))
kit.check(ledger.has(index, "delivered", "-"), "a delivered line in the ledger")
local out = fs.capture("cd " .. fs.quote(record.design) .. " && NOTES_FILE=n.txt luajit notes.lua add hello '#x' && NOTES_FILE=n.txt luajit notes.lua list")
kit.check(out:find("hello", 1, true) ~= nil, "the delivered design runs")
local again = building.step(project, record, {})
kit.equal(again.turns, 0, "building again runs no turns")
local deliveries = 0
for _, line in ipairs(ledger.read(record.ledger)) do
    if line.kind == "delivered" then deliveries = deliveries + 1 end
end
kit.equal(deliveries, 1, "and appends no second delivery")

-- A build repaired once.
local p2, r2 = described_case("repair-once", 'broken_build = { ["202"] = 1 }')
local report2 = building.step(p2, r2, {})
kit.equal(report2.repairs, 1, "one repair")
kit.check(report2.delivered, "then delivered")
kit.check(fs.read(r2.turns .. "/" .. fs.list(r2.turns)[#fs.list(r2.turns) - 1] .. "/prompt.md"):len() > 0, "turn folders written")

-- A build that never passes: its reach is held, the rest is built.
local p3, r3 = described_case("never", 'broken_build = { ["202"] = 9 }')
local report3 = building.step(p3, r3, {})
kit.equal(table.concat(report3.failed, " "), "202", "202 fails")
kit.equal(table.concat(report3.held, " "), "301", "and 301, built on it, is held")
kit.equal(kit.turns_of(r3, "build") , 5, "301 never gets a build turn")
kit.equal(kit.turns_of(r3, "repair"), 2, "202 gets two repairs")
kit.check(not report3.delivered, "nothing is delivered")
kit.check(ledger.has(ledger.index(ledger.read(r3.ledger)), "build-failed", "202"), "build-failed recorded")

-- A later build breaks an earlier issue: caught after the wave, repaired.
local p4, r4 = described_case("regression", 'also_writes = { ["201"] = { ["src/store.lua"] = "error(\'store broken by 201\')\\n" } }')
local report4 = building.step(p4, r4, {})
kit.check(report4.delivered, "delivered despite the breakage")
kit.equal(kit.turns_of(r4, "repair"), 1, "one repair: 101, broken by 201's build")
local repaired_101 = false
for _, name in ipairs(fs.list(r4.turns)) do
    if name:match("%-repair%-101$") then repaired_101 = true end
end
kit.check(repaired_101, "the repair was of 101")

-- An issue that could not be described holds its reach from the start.
local p5, r5 = kit.fixture_case("undescribed", 'bad_describe = { ["103"] = 9 }')
describing.step(p5, r5, outline.step(p5, r5, {}), {})
local report5 = building.step(p5, r5, {})
kit.equal(table.concat(report5.held, " "), "301", "301 is held behind undescribed 103")
kit.equal(kit.turns_of(r5, "build"), 4, "101 102 201 202 are built; 103 and 301 are not")

kit.check(ledger.verify(r4.ledger).ok, "the ledger verifies")
kit.finish()
