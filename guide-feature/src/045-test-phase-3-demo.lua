#!/usr/bin/env luajit
-- 045-test-phase-3-demo.lua
--
-- Runs the phase 3 demo as the owner would, but short and fast: against a
-- copy of the project whose input/ has the rehearsal's timers at one second
-- give or take half and a turn of a second and a half (longer than the timers, so canvases wait
-- and are replaced). Once kept, to check what it
-- showed against the rehearsal's own timings and receipt (read here, not
-- taken from the demo's word): every version drawn, with phase 2's marks
-- as letters under the rows; each version's maker, turn and round trip; the
-- round trips and their histogram; each voice's timeline and counts; the
-- canvases that waited and those replaced. Then through run-phase-demo,
-- which must leave nothing behind, and once in a pseudo-terminal, where
-- the marks are colours.
--
-- For a general: the demo is what the owner watches to see phase 3 work:
-- canvases going round three voices through mail, and how long each round
-- takes. This proves the demo shows what the programs really did.
--
-- usage:
--   luajit 045-test-phase-3-demo.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local rehearsal = dofile(DIR .. "/src/043-rehearsal.lua")

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
local function count(text, pattern)
    local n = 0
    for _ in string.gmatch(text or "", pattern) do n = n + 1 end
    return n
end
-- }}}

-- {{{ a copy of the project with fast settings, a git checkout of its own
local BASE = shell("mktemp -d")
local PROJECT = BASE .. "/guide-feature"
local TMP = BASE .. "/tmp"       -- where the demo makes its throwaway copy
shell("mkdir -p " .. q(PROJECT .. "/input") .. " " .. q(TMP))
for _, link in ipairs({ "src", "libs", "scripts", "issues", "run-phase-demo" }) do
    shell("ln -s " .. q(DIR .. "/" .. link) .. " " .. q(PROJECT .. "/" .. link))
end
write(PROJECT .. "/input/blitter", series.SETTINGS)
write(PROJECT .. "/input/turn-runner", slurp(DIR .. "/input/turn-runner"))
-- a turn longer than the carrier's timers, so canvases wait and are replaced
write(PROJECT .. "/input/stand-in-turn", 'words = "lantern harbor kitten orchard"\nseconds = 1.5\n')
write(PROJECT .. "/input/to-voices", slurp(DIR .. "/input/to-voices"))
write(PROJECT .. "/endpoints", slurp(DIR .. "/endpoints"))
local function rehearsal_settings(minutes)
    write(PROJECT .. "/input/rehearsal", "minutes = " .. minutes .. '\ncarrier = "stand-in"\n'
        .. 'first-port = 41223\npace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n')
end
rehearsal_settings("0.33")
shell("git -C " .. q(PROJECT) .. " init -q && git -C " .. q(PROJECT) .. " -c user.name=test "
    .. "-c user.email=test@localhost commit -q --allow-empty -m one")
local ENV = "TMPDIR=" .. q(TMP) .. " "
local DEMO = PROJECT .. "/issues/completed/demos/phase-3-demo"
-- }}}

io.write("\n=== the demo, kept ===\n")
-- {{{
local out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --keep")
check("it runs and ends cleanly", status == 0, string.sub(out or "", -2000))
local ROOT = string.match(out, "kept the throwaway project at (%S+)")
check("it names the copy it kept", ROOT ~= nil and slurp(ROOT .. "/input/rehearsal") ~= nil)
ROOT = ROOT or "/nowhere"
local SHM = ROOT .. "/tmp/shared-memory"
local receipt = goodbye.read(ROOT .. "/output/goodbye-rehearsal")
local c = receipt and receipt.counters or {}

-- the rehearsal's timings, read here
local rows = {}
for line in string.gmatch(slurp(SHM .. "/rehearsal-timings") or "", "[^\n]+") do
    if string.sub(line, 1, 1) ~= "#" then
        local f = {}
        for field in string.gmatch(line, "%S+") do f[#f + 1] = field end
        rows[#rows + 1] = { voice = f[1], turn = tonumber(f[2]), base = tonumber(f[3]),
            version = tonumber(f[4]), outcome = f[5], published = tonumber(f[6]),
            blitted = tonumber(f[12]) }
    end
end
local by_version = {}
for _, r in ipairs(rows) do if r.version then by_version[r.version] = r end end

local drawn = {}
for version in string.gmatch(out, "\n  version (%d+): ") do drawn[#drawn + 1] = tonumber(version) end
check("every version the rehearsal made is drawn, in order", #drawn == c.versions and #drawn >= 7
    and drawn[1] == 1 and drawn[#drawn] == #drawn, #drawn .. " drawn, " .. tostring(c.versions))
local matched, problem = 0, nil
for version, voice, turn, trip, base in string.gmatch(out,
    "\n  version (%d+): (%S+)'s turn (%d+), ([%d%.]+) s after version (%d+) was published") do
    local r = by_version[tonumber(version)]
    if r and r.voice == voice and r.turn == tonumber(turn) and r.base == tonumber(base)
        and math.abs((r.blitted - r.published) - tonumber(trip)) < 0.06 then
        matched = matched + 1
    else
        problem = problem or (version .. " " .. voice .. " " .. turn)
    end
end
check("each version names its voice, turn, base and round trip, as the timings have them",
    matched == #drawn - 1 and problem == nil, problem or matched)
check("phase 2's marks: plain, the voice's number under the cells it wrote",
    has(out, "|\n   ") and string.match(out, "\n   +[123]+") ~= nil)

local trips = 0
for _, r in ipairs(rows) do if r.version and r.published and r.blitted then trips = trips + 1 end end
check("the round trips listed are the blitted turns", count(out, "\n  version +%d+ from ") == trips,
    trips)
local in_all = string.match(out, "Round trip, version published[^\n]*\n.-\n  (%d+) in all")
check("the histogram counts them all", tonumber(in_all) == trips, in_all)
local bars = string.match(out, "Round trip, version published[^\n]*\n(.-)\n  %d+ in all")
local summed = 0
for line in string.gmatch((bars or "") .. "\n", "([^\n]*)\n") do
    summed = summed + (tonumber(string.match(line, "| .* (%d+)$")) or 0)
end
check("its buckets add up", summed == trips, summed)
check("and the leg that waits for rmail's timer beside it",
    has(out, "Of which waiting for rmail's timer"))

local timelines = true
for _, voice in ipairs(rehearsal.VOICES) do
    local line = string.match(out, "\n  " .. voice:gsub("%-", "%%-") .. " +([%.r=Sux]+)\n")
    local received, turns, sent = string.match(out, "\n  " .. voice:gsub("%-", "%%-")
        .. " +[%.r=Sux]+\n +(%d+) canvas[es]* received, (%d+) turns? run, (%d+) canvas[es]* sent")
    if not (line and #line == 60 and has(line, "S")
        and tonumber(received) == c[voice .. ".canvases-received"]
        and tonumber(turns) == c[voice .. ".turns-run"]
        and tonumber(sent) == c[voice .. ".canvases-sent"]) then
        timelines = false
    end
end
check("a timeline for each voice, with the receipt's counts", timelines)

local waited, replaced = 0, 0
for _, voice in ipairs(rehearsal.VOICES) do
    waited = waited + (c[voice .. ".canvases-waited"] or 0)
    replaced = replaced + (c[voice .. ".canvases-replaced"] or 0)
end
check("the canvases that waited are the receipt's, and some did", waited > 0
    and count(out, "waited for the turn on version") == waited, waited)
check("the canvases replaced are the receipt's, and some were", replaced > 0
    and count(out, "replaced before use, by a newer one") == replaced, replaced)
local superseded = 0
for _, r in ipairs(rows) do if r.outcome == "superseded" then superseded = superseded + 1 end end
check("the voices' canvases superseded in their outbox are the timings'",
    has(out, "and " .. superseded .. " of the voices' own canvases were superseded"))
check("the receipt is shown", has(out, "versions                     " .. tostring(c.versions)))
shell("rm -rf " .. q(string.match(ROOT, "^(.*)/guide%-feature$") or ROOT))
-- }}}

io.write("\n=== through run-phase-demo, and in a terminal ===\n")
-- {{{
-- one word only: once a voice's rows all hold it, its turns change nothing
rehearsal_settings("0.25")
write(PROJECT .. "/input/stand-in-turn", 'words = "lantern"\nseconds = 0.2\n')
out, status = shell(ENV .. q(PROJECT .. "/run-phase-demo") .. " " .. q(PROJECT) .. " 9")
check("run-phase-demo offers phase 3", string.match(out, "1 2 3") ~= nil, out)
out, status = shell(ENV .. q(PROJECT .. "/run-phase-demo") .. " " .. q(PROJECT) .. " 3")
check("and runs it", status == 0 and has(out, "Phase 3: the round trip through rmail"), out)
local shown = {}
for name, value in string.gmatch(out, "\n  (fg%-sora%-%d%.[%w%-]+) +(%d+)") do shown[name] = tonumber(value) end
local unchanged, agree = false, true
for _, voice in ipairs(rehearsal.VOICES) do
    local esc = voice:gsub("%-", "%%-")
    local line = string.match(out, "\n  " .. esc .. " +([%.r=Sux]+)\n") or ""
    if has(line, "u") then unchanged = true end
    local received, turns, sent = string.match(out, "\n  " .. esc
        .. " +[%.r=Sux]+\n +(%d+) canvas[es]* received, (%d+) turns? run, (%d+) canvas[es]* sent")
    if not (tonumber(received) == shown[voice .. ".canvases-received"]
        and tonumber(turns) == shown[voice .. ".turns-run"]
        and tonumber(sent) == shown[voice .. ".canvases-sent"]) then agree = false end
end
check("with turns that changed nothing, shown as u, the counts are still the receipt's",
    unchanged and agree, out)
check("leaving nothing behind", shell("ls -A " .. q(TMP)) == "", (shell("ls -A " .. q(TMP))))
rehearsal_settings("0.1")
local _, have_script = shell("command -v script")
if have_script == 0 then
    local coloured = shell(ENV .. "script -qc " .. q(q(DEMO) .. " " .. q(PROJECT)) .. " /dev/null")
    check("in a terminal the marks are colours", has(coloured, "\27[48;5;"))
    check("and it still leaves nothing behind", shell("ls -A " .. q(TMP)) == "")
end
-- }}}

shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
