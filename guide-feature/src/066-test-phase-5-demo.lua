#!/usr/bin/env luajit
-- 066-test-phase-5-demo.lua
--
-- Runs the phase 5 demo as the owner would, but short: forty seconds of
-- rehearsal, against a copy of the project whose rehearsal timers are one
-- second give or take half. Once kept, to check what it showed against the
-- programs' own record (read here, not taken from the demo's word):
--   - kuvalu's checkout and its index, built at its commit;
--   - the demo voice's clone, with the index copied in, and where it went;
--   - the question at five focuses: the pieces of each are the ones the
--     look tool gives here for the same index, focus 1's four in a row and
--     focus 0's twelve reaching the last rank, fewer to more between;
--   - every look in the rehearsal's table, as the turns' logs have it, and
--     looks focused and broad from every voice;
--   - where each voice's clone went, as its log says, and the RAM tier;
--   - the receipts' look and index counts.
-- Then through run-phase-demo, which must offer phase 5 and leave nothing
-- behind, not even a stand-in model running or its RAM tier.
--
-- For a general: the demo is what the owner watches to see phase 5 work:
-- one question answered narrowly and then ever more widely, and three
-- voices looking into the project before they write. This proves the demo
-- shows what the programs did.
--
-- usage:
--   luajit 066-test-phase-5-demo.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local rehearsal = dofile(DIR .. "/src/043-rehearsal.lua")
local index = dofile(DIR .. "/src/060-embedding-index.lua")
local look = dofile(DIR .. "/src/064-look.lua")
local stand_in = dofile(DIR .. "/src/047-stand-in-llama.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function escape(text) return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
-- the stand-in models still running from this test's copies, after giving
-- them the second they take to notice the demo is gone (--parent)
local function models_running(where)
    local n = 0
    for _ = 1, 30 do
        n = 0
        for pid in string.gmatch(select(1, shell("ls /proc")) or "", "%d+") do
            local line = slurp("/proc/" .. pid .. "/cmdline") or ""
            if has(line, "047-stand-in-llama.lua") and has(line, where) then n = n + 1 end
        end
        if n == 0 then return 0 end
        shell("sleep 0.1")
    end
    return n
end
-- }}}

-- {{{ a copy of the project with fast timers, a git checkout of its own
local BASE = shell("mktemp -d")
local PROJECT = BASE .. "/guide-feature"
local TMP = BASE .. "/tmp"       -- where the demo makes its throwaway copy
shell("mkdir -p " .. q(PROJECT .. "/input") .. " " .. q(TMP))
for _, link in ipairs({ "src", "libs", "scripts", "issues", "run-phase-demo" }) do
    shell("ln -s " .. q(DIR .. "/" .. link) .. " " .. q(PROJECT .. "/" .. link))
end
write(PROJECT .. "/input/blitter", series.SETTINGS)
for _, name in ipairs({ "turn-runner", "turn", "turn-instructions", "stand-in-turn", "to-voices",
                        "look", "project-clone", "embedding-index" }) do
    write(PROJECT .. "/input/" .. name, slurp(DIR .. "/input/" .. name))
end
local REHEARSAL = 'minutes = 5\ncarrier = "stand-in"\n'
    .. 'first-port = 41523\npace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n'
write(PROJECT .. "/input/rehearsal", REHEARSAL)
shell("git -C " .. q(PROJECT) .. " init -q && git -C " .. q(PROJECT) .. " -c user.name=test "
    .. "-c user.email=test@localhost commit -q --allow-empty -m one")
local ENV = "TMPDIR=" .. q(TMP) .. " "
local DEMO = PROJECT .. "/issues/completed/demos/phase-5-demo"
-- }}}

io.write("\n=== the demo, kept ===\n")
-- {{{
local out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --minutes 0.67 --keep")
check("it runs and ends cleanly", status == 0, string.sub(out or "", -2500))
local ROOT, SHM = string.match(out or "", "kept the throwaway project at (%S+) %(its RAM tier at (%S+)%)")
check("it names the copy it kept, and its RAM tier", ROOT ~= nil and slurp(ROOT .. "/endpoints") ~= nil,
    string.sub(out or "", -300))
ROOT, SHM = ROOT or "/nowhere", SHM or "/nowhere"
local KUVALU = string.match(ROOT, "^(.*)/guide%-feature$") .. "/kuvalu/ai-stuff"
local COMMIT = shell("git -C " .. q(KUVALU) .. " rev-parse HEAD") or ""

-- kuvalu's side
local source = index.read(KUVALU .. "/guide-feature/.embedding-index")
check("kuvalu's checkout: guide-feature's code in a monorepo folder, one commit, its index at it",
    source and source.meta.commit == COMMIT and source.count > 500
    and has(out, "in its guide-feature folder, at commit " .. string.sub(COMMIT, 1, 7) .. ".")
    and has(out, source.count .. " pieces"), source and source.count)
local DEMO_CLONE = ROOT .. "/tmp/shared-memory/clones/demo/guide-feature"
local disk_clone = ROOT .. "/clones/demo/guide-feature"
local clone_dir = slurp(DEMO_CLONE .. "/guide-feature/.embedding-index/meta") and DEMO_CLONE or disk_clone
local copied = index.read(clone_dir .. "/guide-feature/.embedding-index")
check("the demo voice's clone has the index, copied whole, and the demo says where it went",
    copied and copied.count == source.count and copied.meta.commit == COMMIT
    and has(out, "the embedding index was copied from the source, " .. source.count .. " pieces")
    and (has(out, "cloned in RAM at " .. DEMO_CLONE) or has(out, "cloned on disk (the slower path) at "
        .. disk_clone)), clone_dir)

-- the question at five focuses: the same pieces the look tool gives here
local values = look.read_settings(PROJECT)
local same, sizes, problem = 0, {}, nil
for _, focus in ipairs({ 1, 0.75, 0.5, 0.25, 0 }) do
    local found = look.find({ project = clone_dir .. "/guide-feature", commit = COMMIT, words = "canvas width",
        focus = focus, values = values, model_name = function() return copied.meta.model end,
        embedder = { name = "embed", url = "http://127.0.0.1:9", kind = "embedding", timeout = 1 },
        -- the stand-in model's own vector for the names, made here
        embed = function(texts) return { stand_in.embedding(texts[1], copied.dimensions) } end })
    local heading = out:match("\nfocus " .. escape(string.format("%.2f", focus)) .. "[^\n]*\n[^\n]*\n(.-)\n  ranks 1 to")
    local rows = {}
    for rank, file, first, last in string.gmatch(heading or "", "\n?  +(%d+) +%-?[%d.]+ [^\n]-  (%S+) (%d+)%-(%d+) %(") do
        rows[#rows + 1] = rank .. " " .. file .. " " .. first .. "-" .. last
    end
    local expect = {}
    for _, piece in ipairs(found.chosen or {}) do
        expect[#expect + 1] = piece.rank .. " " .. piece.file .. " " .. piece.first .. "-" .. piece.last
    end
    sizes[#sizes + 1] = #rows
    if found.chosen and table.concat(rows, "; ") == table.concat(expect, "; ") then
        same = same + 1
    else
        problem = problem or (focus .. ":\n" .. table.concat(rows, "\n") .. "\n vs \n" .. table.concat(expect, "\n")
            .. "\n" .. tostring(found.why))
    end
end
check("each focus shows the pieces the look tool gives for that focus, in rank order", same == 5, problem)
check("4, 6, 8, 10 and 12 pieces from focus 1 to focus 0", table.concat(sizes, " ") == "4 6 8 10 12",
    table.concat(sizes, " "))
check("each with a similarity chart and where it sits among all the pieces",
    select(2, string.gsub(out, "\n  ranks 1 to " .. source.count .. ":  |", "")) == 5
    and has(out, "  |#")) -- plain: the output is not a terminal
check("and the focused answer as the model reads it",
    has(out, "\n  | look focused (canvas width): 4 of the project's " .. source.count .. " pieces"))
-- }}}

-- {{{ the rehearsal's looks, against the turns' own logs
local WS = ROOT .. "/tmp/shared-memory/rehearsal"
local WS_ROOT = WS .. "/project/guide-feature"
local WS_SHM = WS .. "/shm/guide-feature"
local looks, focuses, voices_looked = {}, {}, {}
for _, voice in ipairs(rehearsal.VOICES) do
    for line in string.gmatch(slurp(WS_SHM .. "/turn-" .. voice .. ".log") or "", "[^\n]+") do
        local turn, version, focus, about, rest =
            line:match("^%S+ turn (%d+) on version (%d+), look (%S+) %((.-)%): (.*)$")
        if turn then
            looks[#looks + 1] = { voice = voice, turn = turn, version = version, focus = focus,
                about = about, rest = (rest:gsub(", [%d.]+ seconds$", "")) }
            focuses[focus] = (focuses[focus] or 0) + 1
            voices_looked[voice] = true
        end
    end
end
check("the voices looked, focused and broad, all three of them",
    #looks >= 6 and (focuses.focused or 0) >= 3 and (focuses.broad or 0) >= 1
    and voices_looked["fg-sora-1"] and voices_looked["fg-sora-2"] and voices_looked["fg-sora-3"], #looks)
local rows = 0
for _, l in ipairs(looks) do
    if out:match("\n  " .. escape(l.voice) .. " +" .. l.turn .. " +" .. l.version .. "  " .. escape(l.focus)
        .. " +" .. escape(l.about) .. " +" .. escape(l.rest) .. "\n") then rows = rows + 1 end
end
check("the table holds every look, as the logs have it", rows == #looks, rows .. " of " .. #looks)
check("every look was answered with pieces, none refused",
    #looks > 0 and not has(out, "refused"), out:match("refused[^\n]*"))
check("and one look is shown as its model read it",
    has(out, "fg-sora-1's broad look, as its model read it") and has(out, "\n  | --- "))
local placed = 0
for _, voice in ipairs(rehearsal.VOICES) do
    local log = slurp(WS_SHM .. "/turn-" .. voice .. ".log") or ""
    local where = log:match(": cloned (in RAM) at ") or log:match(": cloned (on disk) %(the slower path%) at ")
    local shown = out:match("\n  " .. escape(voice) .. ": (in RAM)") or out:match("\n  " .. escape(voice) .. ": (on disk)")
    if where and where == shown then placed = placed + 1 end
end
check("each voice's clone: RAM or disk, as its log says", placed == 3, placed)
local tier = shell("stat -f -c %T " .. q(SHM))
check("the RAM tier: a tmpfs in /dev/shm when one can be written, and the demo says which",
    (tier == "tmpfs") == has(out, "a tmpfs: in memory)") and (tier ~= "tmpfs" or SHM:match("^/dev/shm/")), tier)
local counts_right, counts_seen = 0, {}
for _, voice in ipairs(rehearsal.VOICES) do
    local path = WS_ROOT .. "/output/goodbye-turn-" .. voice
    -- a turn still running has moved the last receipt to .previous
    local r = goodbye.read(path) or goodbye.read(path .. ".previous")
    local names = {}
    for name, value in pairs(r and r.counters or {}) do
        if name:match("^look") or name:match("^index") or name:match("^clone") then
            names[#names + 1] = name .. " " .. value
        end
    end
    table.sort(names)
    counts_seen[#counts_seen + 1] = voice .. ": " .. table.concat(names, ", ")
    if r and has(out, "\n  " .. voice .. ": " .. table.concat(names, ", ")) then
        counts_right = counts_right + 1
    end
end
check("each voice's last receipt's look, index and clone counts are shown as they are", counts_right == 3,
    table.concat(counts_seen, "\n        ") .. "\n" .. tostring(out:match("\nThe last turn's receipt.-\n\n")))
check("no stand-in model is left running", models_running(ROOT) == 0)
shell("rm -rf " .. q(string.match(ROOT, "^(.*)/guide%-feature$") or ROOT))
if SHM:match("^/dev/shm/tmp%.") then shell("rm -rf " .. q(SHM)) end
-- }}}

io.write("\n=== through run-phase-demo ===\n")
-- {{{
out, status = shell(ENV .. q(PROJECT .. "/run-phase-demo") .. " " .. q(PROJECT) .. " 9")
check("run-phase-demo offers phase 5", string.match(out, "1 2 3 4 5") ~= nil, out)
-- this time no clone fits its share of RAM, so every clone goes on disk
write(PROJECT .. "/input/project-clone", (slurp(DIR .. "/input/project-clone")
    :gsub("\nram%-share%s*=[^\n]*", "\nram-share = 0.00001")))
out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --minutes 0.2")
check("and it runs short, ending cleanly", status == 0 and has(out, "Phase 5: looking into the project")
    and has(out, "Every look the models made"), string.sub(out or "", -1500))
local on_disk = 0
for _, voice in ipairs(rehearsal.VOICES) do
    if has(out, "\n  " .. voice .. ": on disk, ") then on_disk = on_disk + 1 end
end
check("a clone that does not fit its share of RAM is shown on disk, and why",
    on_disk == 3 and has(out, "cloned on disk (the slower path) at ")
    and has(out, "of working room are more than 0% of the"), out:match("Each voice's clone.-\n\n"))
local TIER = out:match("The RAM tier for this run: (%S+),") or "/nowhere"
check("leaving nothing behind, in the temporary folder or the RAM tier",
    shell("ls -A " .. q(TMP)) == "" and TIER ~= "/nowhere" and not io.open(TIER),
    (shell("ls -A " .. q(TMP))) .. " " .. TIER)
check("not even a stand-in model", models_running(TMP) == 0)
-- }}}

shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
