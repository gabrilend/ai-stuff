-- 040-checking-the-hands.lua
--
-- Checks phase 3 (issues 301–306): turn folders and the clean-room rule,
-- instructions with crafts, snapshots and charging, the harness table and
-- the Claude Code command line, and the pool — parallel, with turns that
-- write outside their folders, write into the source, fail, and hang.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local case = require("018-the-case")
local ledger = require("016-ledger")
local kinds = require("034-turn-kinds")
local instructions = require("035-instructions")
local snapshots = require("036-snapshots")
local harnesses = require("037-the-harness-table")
local pool = require("039-the-turn-pool")

local project, folder = kit.project_copy("hands")
local src = folder .. "/source"
kit.write_file(src .. "/main.lua", "print('hello')\n")
kit.write_file(src .. "/lib/util.lua", "return {}\n")
local record = case.open(project, "hands", src, "stand-in")

-- {{{ local function describe_values
local function describe_values(id)
    return {
        about = id, name = "piece-" .. id, blocked_by = "-", covered_files = "main.lua",
        issue_path = record.issues .. "/" .. id .. "-piece.md", outline_text = "(outline)", findings = "none",
    }
end
-- }}}

-- {{{ local function build_values
local function build_values(id)
    return { about = id, target = "the same kind of software", issue_text = "(issue)", blocker_texts = "(none)" }
end
-- }}}

-- The kinds table and turn folders.
kit.raises(function() kinds.fill("a {{b}} c", {}) end, "slot 'b'", "a missing slot refuses")
kit.equal(kinds.fill("a {{b}} c", { b = 1 }), "a 1 c", "slots fill")
local t1 = kinds.make_turn(record, "describe", describe_values("101"))
local t2 = kinds.make_turn(record, "build", build_values("101"))
kit.equal(t1.id, "0001-describe-101", "first turn numbered 0001")
kit.equal(t2.id, "0002-build-101", "numbers count up across kinds")
kit.check(fs.exists(t1.folder .. "/prompt.md") and fs.exists(t1.folder .. "/confinement.lua"), "turn folder holds prompt and confinement")
kit.equal(t1.prompt:match("^[^\n]+"), "turn: describe 101", "prompt's first line names kind and about")
kit.equal(t1.writes[1], record.issues .. "/101-", "describe writes only its own issue prefix")
for _, p in ipairs(t1.reads) do
    kit.check(p:sub(1, 1) == "/", "read path absolute: " .. p)
end
local reads_source = {}
for name in pairs(kinds.TABLE) do
    if kinds.reads_source(name) then reads_source[#reads_source + 1] = name end
end
table.sort(reads_source)
kit.equal(table.concat(reads_source, ","), "describe,outline", "only outline and describe may read the source")
for _, p in ipairs(t2.reads) do
    kit.check(p:sub(1, #record.source) ~= record.source, "a build turn's reads exclude the source")
end

-- Instructions and crafts.
local text = instructions.write(t1, record, project.skills, "")
kit.check(text:find("# Craft: issue-lifecycle", 1, true) ~= nil, "describe gets the issue-lifecycle craft")
kit.check(text:find(record.issues .. "/101-", 1, true) ~= nil, "instructions name the write path")
local build_text = instructions.write(t2, record, project.skills, "")
kit.check(build_text:find(record.source, 1, true) == nil, "a build turn's instructions never name the source")
kit.check(build_text:find("does not exist for you", 1, true) ~= nil, "a build turn is told the source is absent")
kit.write_file(record.input .. "/crafts", "# the person's crafts\npolyglot-source\n")
local with_person = instructions.write(t2, record, project.skills, "the center says hello")
kit.check(with_person:find("# Craft: polyglot-source", 1, true) ~= nil, "build takes the person's crafts")
kit.check(with_person:find("the center says hello", 1, true) ~= nil, "the center paragraph is included")
kit.raises(function() instructions.write(t2, record, folder .. "/no-skills-here", "") end,
    "has no skill file", "a missing craft refuses")
os.remove(record.input .. "/crafts")

-- Snapshots: reuse, same-bytes rewrite, create/change/remove, links.
local snap_root = folder .. "/snap"
kit.write_file(snap_root .. "/a.txt", "a\n")
kit.write_file(snap_root .. "/b.txt", "b\n")
kit.write_file(snap_root .. "/c.txt", "c\n")
fs.run("ln -s /nowhere " .. fs.quote(snap_root .. "/dangling"))
local s1, hashed1 = snapshots.take(project, { snap_root }, {}, nil)
kit.equal(hashed1, 3, "first snapshot hashes every file (links are not hashed)")
kit.equal(s1[snap_root .. "/dangling"].hash, "link:/nowhere", "a link's checksum is its target")
local s2, hashed2 = snapshots.take(project, { snap_root }, {}, s1)
kit.equal(hashed2, 0, "an unchanged tree hashes nothing the second time")
fs.run("sleep 0.01; touch " .. fs.quote(snap_root .. "/a.txt"))
kit.write_file(snap_root .. "/b.txt", "B\n")
os.remove(snap_root .. "/c.txt")
kit.write_file(snap_root .. "/d.txt", "d\n")
local s3 = snapshots.take(project, { snap_root }, {}, s2)
local changes = snapshots.compare(s2, s3)
local how = {}
for _, c in ipairs(changes) do how[c.path:match("[^/]+$")] = c.how end
kit.equal(how["a.txt"], nil, "touched with the same bytes is not a change")
kit.equal(how["b.txt"], "changed", "changed bytes are a change")
kit.equal(how["c.txt"], "removed", "removal reported")
kit.equal(how["d.txt"], "created", "creation reported")
-- Files over the hash limit are known by size and time, never read.
local saved_limit = snapshots.HASH_LIMIT
snapshots.HASH_LIMIT = 1
local big_snap, big_hashed = snapshots.take(project, { snap_root }, {}, nil)
kit.equal(big_hashed, 0, "files over the limit are not hashed")
kit.check(big_snap[snap_root .. "/b.txt"].hash:find("^large:") ~= nil, "they are known by size and time")
snapshots.HASH_LIMIT = saved_limit
local excluded_snap = snapshots.take(project, { snap_root }, { snap_root .. "/d.txt" }, nil)
kit.equal(excluded_snap[snap_root .. "/d.txt"], nil, "excluded paths are left out")

-- Charging: most specific prefix wins; shared prefixes go to the set.
local fake_turns = {
    { id = "A", writes = { "/x/issues/101-" } },
    { id = "B", writes = { "/x/issues/102-" } },
    { id = "C", writes = { "/x/design/" } },
    { id = "D", writes = { "/x/design/" } },
}
local charged = snapshots.charge({
    { path = "/x/issues/101-a.md", how = "created" },
    { path = "/x/issues/102-b.md", how = "created" },
    { path = "/x/design/src/m.lua", how = "created" },
    { path = "/x/elsewhere", how = "created" },
}, fake_turns)
kit.equal(#charged.by_turn.A, 1, "101's file charged to A")
kit.equal(#charged.by_turn.B, 1, "102's file charged to B")
kit.equal(#charged.set, 1, "a shared design file charged to the set")
kit.equal(#charged.breaches, 1, "a file no turn may write is a breach")

-- The harness table.
harnesses.TABLE["needs-nothing-real"] = { name = "x", needs = { "no-such-program-xyz" }, pool = 1, limit = 1 }
kit.raises(function() harnesses.row("needs-nothing-real") end, "no-such-program-xyz", "missing programs refused by name")
harnesses.TABLE["needs-nothing-real"] = nil
kit.raises(function() harnesses.row("imaginary") end, "no harness named", "an unknown harness refused")
local claude = harnesses.TABLE["claude-code"]
local describe_line = claude.command(project, t1)
kit.check(describe_line:find("--restricted", 1, true) ~= nil, "Claude Code runs restricted")
kit.check(describe_line:find("--tools Read,Write,Edit,Glob,Grep", 1, true) ~= nil, "only file tools")
kit.check(describe_line:find("--add-dir " .. fs.quote(record.source), 1, true) ~= nil, "describe may reach the source")
kit.check(describe_line:find("Edit(/" .. record.source .. "/**)", 1, true) ~= nil, "describe is denied edits in the source")
local build_line = claude.command(project, t2)
kit.check(build_line:find(record.source, 1, true) == nil, "a build turn's command line never names the source")
kit.equal(harnesses.working_folder(t2), record.design, "a build turn runs in the design folder")
-- The folders Claude Code can reach: never the whole case (which holds every
-- earlier turn's record, and those can quote the source), never turns/.
local reach = harnesses.claude_directories(t2)
kit.equal(table.concat(reach, " "), record.blueprint, "a build turn reaches the blueprint besides its design folder, nothing else")
for _, dir in ipairs(harnesses.claude_directories(t1)) do
    kit.check(dir ~= record.folder and dir:sub(1, #record.turns) ~= record.turns,
        "a describe turn never reaches the whole case or turns/: " .. dir)
end
kit.equal(harnesses.working_folder(t1), record.issues, "a describe turn runs in the issues folder")

-- The pool: a script for the stand-in.
kit.write_file(record.folder .. "/stand-in.lua", [[
return {
    ["describe 201"] = { writes = { ["blueprint/issues/201-a.md"] = "# 201\n" }, sleep = 1 },
    ["describe 202"] = { writes = { ["blueprint/issues/202-b.md"] = "# 202\n" }, sleep = 1 },
    ["describe 203"] = { writes = { ["blueprint/issues/203-c.md"] = "# 203\n" }, sleep = 1 },
    ["describe 204"] = { writes = { ["blueprint/issues/204-d.md"] = "# 204\n" }, sleep = 1 },
    ["describe 205"] = { writes = { ["blueprint/issues/205-e.md"] = "# 205\n" }, sleep = 1 },
    ["describe 206"] = { writes = { ["blueprint/issues/206-f.md"] = "# 206\n" }, sleep = 1 },
    ["describe 207"] = { writes = { ["blueprint/issues/207-g.md"] = "# 207\n" }, sleep = 1 },
    ["describe 208"] = { writes = { ["blueprint/issues/208-h.md"] = "# 208\n" }, sleep = 1 },
    ["describe 301"] = { misbehave = "write-outside" },
    ["describe 302"] = { writes = { ["blueprint/issues/302-z.md"] = "# 302\n" } },
    ["describe 401"] = { misbehave = "write-source" },
    ["describe 501"] = { misbehave = "fail" },
    ["describe 502"] = { misbehave = "hang" },
    ["describe 503"] = function(turn) return { writes = { ["blueprint/issues/503-x.md"] = "attempt " .. turn.attempt .. "\n" } } end,
}
]])

-- {{{ local function now
local function now()
    return tonumber((fs.capture("date +%s.%N")))
end
-- }}}

local set = {}
for i = 1, 8 do
    set[i] = kinds.make_turn(record, "describe", describe_values(tostring(200 + i)))
end
local t0 = now()
local results = pool.run_set(project, record, set, { size = 4 })
local seconds = now() - t0
kit.check(seconds < 3.5, string.format("eight one-second turns in a pool of four take about two seconds (%.2fs)", seconds))
local all_kept = true
for _, r in ipairs(results) do
    if r.verdict ~= "kept" or #r.changes ~= 1 then all_kept = false end
end
kit.check(all_kept, "every well-behaved turn is kept with its one file charged to it")

local bad = { kinds.make_turn(record, "describe", describe_values("301")), kinds.make_turn(record, "describe", describe_values("302")) }
local bad_results, summary = pool.run_set(project, record, bad, {})
kit.equal(bad_results[1].verdict, "breach", "the turn that wrote outside is a breach")
kit.equal(bad_results[2].verdict, "breach", "and so is its neighbour: a set cannot be told apart")
kit.equal(#summary.breaches, 1, "one breaching path")
local lines = ledger.read(record.ledger)
local saw_breach = false
for _, l in ipairs(lines) do
    if l.kind == "breach" and l.text:find("outside-", 1, true) then saw_breach = true end
end
kit.check(saw_breach, "the ledger names the breaching path")

local src_results, src_summary = pool.run_set(project, record, { kinds.make_turn(record, "describe", describe_values("401")) }, {})
kit.equal(src_results[1].verdict, "breach", "writing into the source is a breach")
kit.check(src_summary.source_touched, "and is reported as touching the source")

local fail_results = pool.run_set(project, record, {
    kinds.make_turn(record, "describe", describe_values("501")),
    kinds.make_turn(record, "describe", describe_values("502")),
}, { limit = 2 })
kit.equal(fail_results[1].verdict, "failed", "a non-zero exit is failed")
kit.check(fail_results[1].why:find("told to fail", 1, true) ~= nil, "the failure carries the harness's own words")
kit.equal(fail_results[2].verdict, "failed", "a hanging turn is failed")
kit.check(fail_results[2].why:find("limit", 1, true) ~= nil, "and said to have run past its limit")

local a1 = pool.run_set(project, record, { kinds.make_turn(record, "describe", describe_values("503")) }, {})
local a2 = pool.run_set(project, record, { kinds.make_turn(record, "describe", describe_values("503")) }, {})
kit.equal(fs.read(record.issues .. "/503-x.md"), "attempt 2\n", "the stand-in counts attempts per kind and about")
kit.check(a1[1].verdict == "kept" and a2[1].verdict == "kept", "both attempts kept")
kit.check(ledger.verify(record.ledger).ok, "the ledger still verifies after every set")

kit.finish()
