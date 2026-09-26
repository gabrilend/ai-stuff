-- phase-3-demo.lua
--
-- The phase 3 demonstration, run by phase-3-demo. A case on a small source
-- (phase 1), surveyed (phase 2), then sets of stand-in turns through the
-- pool: a throughput run, a set with every kind of misbehaviour, the Claude
-- Code command lines, and snapshot costs on the largest source at hand.

local DIR = arg[1]
local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
local project = paths_module.for_project(DIR)

local fs = require("017-the-filesystem")
local case = require("018-the-case")
local ledger = require("016-ledger")
local survey = require("029-the-survey")
local kinds = require("034-turn-kinds")
local snapshots = require("036-snapshots")
local harnesses = require("037-the-harness-table")
local pool = require("039-the-turn-pool")

-- {{{ local function wall
local function wall()
    return tonumber((fs.capture("date +%s.%N")))
end
-- }}}

-- {{{ local function bar
local function bar(value, max, width)
    local filled = math.floor(value / max * width + 0.5)
    return string.rep("█", filled) .. string.rep("·", width - filled)
end
-- }}}

local scratch = project.scratch .. "/demo-phase-3"
if fs.is_folder(scratch) then
    fs.remove_tree(scratch)
end
fs.make_folder(scratch .. "/source/lib")
fs.write(scratch .. "/source/main.lua", 'local u = require("lib.util")\nprint(u.greet("world"))\n')
fs.write(scratch .. "/source/lib/util.lua", 'return { greet = function(n) return "hello " .. n end }\n')
-- {{{ local function shorten
-- Replaces the scratch folder (under either spelling: through the tmp link,
-- or its real place in /dev/shm) with "…", as plain text — the folder name
-- holds dashes, which a Lua pattern would read as instructions.
local real_scratch = fs.real_path(scratch)
local function shorten(text)
    for _, long in ipairs({ scratch, real_scratch }) do
        local out, from = {}, 1
        while true do
            local i, j = text:find(long, from, true)
            if not i then
                break
            end
            out[#out + 1] = text:sub(from, i - 1) .. "…"
            from = j + 1
        end
        out[#out + 1] = text:sub(from)
        text = table.concat(out)
    end
    return text
end
-- }}}

local demo_project = {}
for k, v in pairs(project) do
    demo_project[k] = v
end
demo_project.cases = scratch .. "/cases"

local record = case.open(demo_project, "hands", scratch .. "/source", "stand-in")
survey.run(demo_project, record, nil)

-- The stand-in's script: what each turn does.
fs.write(record.folder .. "/stand-in.lua", [[
local script = {
    ["describe 301"] = { misbehave = "write-outside", say = "wrote outside" },
    ["describe 401"] = { misbehave = "write-source", say = "wrote into the source" },
    ["describe 501"] = { misbehave = "fail" },
    ["describe 502"] = { misbehave = "hang" },
}
setmetatable(script, { __index = function(_, key)
    local id = key:match("^describe (%d+)$")
    if id then
        return { writes = { ["blueprint/issues/" .. id .. "-piece.md"] = "# " .. id .. "\n" } }
    end
end })
return script
]])

-- {{{ local function describe_turn
local function describe_turn(id)
    return kinds.make_turn(record, "describe", {
        about = id, name = "piece-" .. id, blocked_by = "-", covered_files = "main.lua",
        issue_path = record.issues .. "/" .. id .. "-piece.md", outline_text = "(demo)", findings = "none",
    })
end
-- }}}

print("PHASE 3 — THE HANDS")
print("")

-- Throughput: 48 well-behaved turns through pools of 1, 4 and 8.
print("THROUGHPUT — 48 stand-in describe turns per run, each a separate process")
local rates = {}
local next_id = 100
for _, size in ipairs({ 1, 4, 8 }) do
    local set = {}
    for i = 1, 48 do
        next_id = next_id + 1
        set[i] = describe_turn(tostring(next_id))
    end
    local t0 = wall()
    local results = pool.run_set(demo_project, record, set, { size = size })
    local seconds = wall() - t0
    local kept = 0
    for _, r in ipairs(results) do
        if r.verdict == "kept" then kept = kept + 1 end
    end
    rates[#rates + 1] = { size = size, rate = 48 / seconds, seconds = seconds, kept = kept }
end
local top = 0
for _, r in ipairs(rates) do top = math.max(top, r.rate) end
for _, r in ipairs(rates) do
    print(string.format("  pool of %d  %6.1f turns/s  %5.2f s  kept %2d/48  %s", r.size, r.rate, r.seconds, r.kept, bar(r.rate, top, 26)))
end
print("  (each turn: prepare folder, write instructions, start a process, then snapshot the")
print("   whole case and source before and after the set and charge every change)")
print("")

-- Misbehaviour: one set holding each way a turn can go wrong.
print("MISBEHAVIOUR — each run as its own set, so each verdict is its own")
local cases_to_show = {
    { "301", "writes a file outside its folders" },
    { "401", "writes into the source" },
    { "501", "exits with an error" },
    { "502", "hangs (limit 2 s)" },
    { "601", "behaves" },
}
for _, c in ipairs(cases_to_show) do
    local results, summary = pool.run_set(demo_project, record, { describe_turn(c[1]) }, { limit = 2 })
    local r = results[1]
    local mark = r.verdict == "kept" and "✓" or "✗"
    print(string.format("  %s describe %s  %-34s → %-7s %s", mark, c[1], c[2], r.verdict, r.why))
    for _, b in ipairs(summary.breaches) do
        print("        " .. b.how .. " " .. shorten(b.path))
    end
    if summary.source_touched then
        print("        the source was touched — a run would stop here")
    end
end
print("")

-- Command lines: what Claude Code would be started with.
print("CLAUDE CODE — the command line each kind of turn gets (paths shortened)")
local samples = {
    outline = { about = "-", survey_summary = "", file_table = "", outline_path = record.blueprint .. "/outline.tsv", findings = "none" },
    build = { about = "101", target = "", issue_text = "", blocker_texts = "" },
}
for _, name in ipairs({ "outline", "build" }) do
    local turn = kinds.make_turn(record, name, samples[name])
    local full = harnesses.TABLE["claude-code"].command(demo_project, turn)
    local sees_source = full:find(record.source, 1, true) ~= nil
    local line = shorten(full)
    print(string.format("  %s (%s the source):", name, sees_source and "can read" or "cannot see"))
    print("    " .. line:gsub(" %-%-", "\n      --"))
end
print("")

-- Snapshot cost on the largest source at hand.
local big = "/home/ritz/games/azeroth-core/wow-chat-2026/source-alpha"
if fs.is_folder(big) then
    print("SNAPSHOTS — " .. big)
    local t0 = wall()
    local first, hashed_first = snapshots.take(demo_project, { big }, {}, nil)
    local first_seconds = wall() - t0
    t0 = wall()
    local _, hashed_second = snapshots.take(demo_project, { big }, {}, first)
    local second_seconds = wall() - t0
    local count = 0
    for _ in pairs(first) do count = count + 1 end
    print("  (the first reads every byte from disk and hashes it; later ones reuse checksums")
    print("   for every file whose size and time have not moved)")
    print(string.format("  first snapshot   %6d files, %6d hashed, %5.2f s  (%.3f s per 1000 files)",
        count, hashed_first, first_seconds, first_seconds / count * 1000))
    print(string.format("  second snapshot  %6d files, %6d hashed, %5.2f s  (%.3f s per 1000 files)",
        count, hashed_second, second_seconds, second_seconds / count * 1000))
    print("")
end

local verified = ledger.verify(record.ledger)
print(string.format("LEDGER — %d lines, chain %s, head %s…", verified.count or 0,
    verified.ok and "intact" or "BROKEN", (verified.head or ""):sub(1, 16)))

fs.remove_tree(scratch)
