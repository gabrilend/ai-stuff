#!/usr/bin/env luajit
-- 057-test-phase-4-demo.lua
--
-- Runs the phase 4 demo as the owner would, but short: forty seconds,
-- against a copy of the project whose rehearsal timers are one second give
-- or take half. Once kept, to check what it showed against the turns' own
-- logs and receipts (read here, not taken from the demo's word): every
-- version drawn with its marks; under each version the turn that made it,
-- with its endpoint, tries and words; every turn in the table; per voice and
-- endpoint the turns, seconds, tries and tokens, with fg-sora-2 on both
-- endpoints after use-endpoint switched it, and the switch done in the
-- workspace's endpoints file. Then through run-phase-demo, which must leave
-- nothing behind, not even a stand-in model running.
--
-- For a general: the demo is what the owner watches to see phase 4 work:
-- three voices really asking a model for every edit, the edits that did not
-- fit sent back, and one voice moved to another model halfway, with the
-- numbers to show it. This proves the demo shows what the programs did.
--
-- usage:
--   luajit 057-test-phase-4-demo.lua [--dir ROOT]

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
for _, name in ipairs({ "turn-runner", "turn", "turn-instructions", "stand-in-turn", "to-voices" }) do
    write(PROJECT .. "/input/" .. name, slurp(DIR .. "/input/" .. name))
end
write(PROJECT .. "/input/rehearsal", 'minutes = 5\ncarrier = "stand-in"\n'
    .. 'first-port = 41423\npace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n')
shell("git -C " .. q(PROJECT) .. " init -q && git -C " .. q(PROJECT) .. " -c user.name=test "
    .. "-c user.email=test@localhost commit -q --allow-empty -m one")
local ENV = "TMPDIR=" .. q(TMP) .. " "
local DEMO = PROJECT .. "/issues/completed/demos/phase-4-demo"
-- }}}

io.write("\n=== the demo, kept ===\n")
-- {{{
local out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --minutes 0.67 --keep")
check("it runs and ends cleanly", status == 0, string.sub(out or "", -2000))
local ROOT = string.match(out or "", "kept the throwaway project at (%S+)")
check("it names the copy it kept", ROOT ~= nil and slurp(ROOT .. "/endpoints") ~= nil)
ROOT = ROOT or "/nowhere"
local WS = ROOT .. "/tmp/shared-memory/rehearsal"
local WS_ROOT = WS .. "/project/guide-feature"
local WS_SHM = WS .. "/shm/guide-feature"
local receipt = goodbye.read(ROOT .. "/output/goodbye-rehearsal")
local c = receipt and receipt.counters or {}

-- the turns, from their own logs, read here
local TURN_LINE = "turn (%d+) on version (%d+) fits: endpoint (%S+) %(%S+%), asks %d+, "
    .. "tries (%d+), problems: (.-), look calls %d+[^,]*, tokens (%d+) %+ (%d+), ([%d%.]+) "
    .. "seconds, (%d+) words"
local turns, by_key = {}, {}
for _, voice in ipairs(rehearsal.VOICES) do
    for line in string.gmatch(slurp(WS_SHM .. "/turn-" .. voice .. ".log") or "", "[^\n]+") do
        local turn, version, endpoint, tries, problems, prompt, completion, seconds, words =
            line:match(TURN_LINE)
        if turn then
            local t = { voice = voice, turn = tonumber(turn), version = tonumber(version),
                endpoint = endpoint, tries = tonumber(tries), problems = problems,
                prompt = tonumber(prompt), completion = tonumber(completion),
                seconds = tonumber(seconds), words = tonumber(words) }
            turns[#turns + 1] = t
            by_key[voice .. "/" .. turn] = t
        end
    end
end
check("the voices ran real turns: some fitted at once, some were sent back",
    #turns >= 9 and count(table.concat((function()
        local l = {}
        for _, t in ipairs(turns) do l[#l + 1] = t.problems end
        return l
    end)(), "\n"), "too%-wide") >= 1, #turns)

local drawn = {}
for version in string.gmatch(out, "\n  version (%d+): ") do drawn[#drawn + 1] = tonumber(version) end
check("every version the rehearsal made is drawn, in order", #drawn == c.versions and #drawn >= 7
    and drawn[1] == 1 and drawn[#drawn] == #drawn, #drawn .. " drawn, " .. tostring(c.versions))
check("with phase 2's marks, as numbers under the rows (plain)",
    string.match(out, "|\n   +[123][123 ]*\n") ~= nil)
local under, agree, problem = 0, 0, nil
for voice, turn, line in string.gmatch(out, "\n  version %d+: (%S+)'s turn (%d+)[^\n]*\n    ([^\n]+)") do
    under = under + 1
    local t = by_key[voice .. "/" .. turn]
    local expect = t and (t.endpoint .. ", " .. (t.tries == 1 and "fit at the first try"
        or ("fit at try " .. t.tries .. " (sent back: " .. t.problems .. ")")) .. "; "
        .. t.words .. " word")
    if t and has(line, expect) then agree = agree + 1 else problem = problem or line end
end
check("under each version, its turn as the turn's log has it: endpoint, tries and why, words",
    under >= 6 and agree == under, problem or under)

local rows = 0
for voice, turn, version, endpoint, tries in string.gmatch(out,
    "\n  (fg%-sora%-%d) +(%d+) +(%d+)  (%S+) +(%d+)  ") do
    local t = by_key[voice .. "/" .. turn]
    if t and t.version == tonumber(version) and t.endpoint == endpoint
        and t.tries == tonumber(tries) then rows = rows + 1 end
end
check("the table holds every turn, as the logs have them", rows == #turns, rows .. " of " .. #turns)

-- per voice and endpoint
local totals = {}
for _, t in ipairs(turns) do
    local key = t.voice .. " " .. t.endpoint
    totals[key] = totals[key] or { n = 0, seconds = 0, tries = 0 }
    totals[key].n = totals[key].n + 1
    totals[key].seconds = totals[key].seconds + t.seconds
    totals[key].tries = totals[key].tries + t.tries
end
local shown, right = 0, 0
for voice, endpoint, n, seconds, tries in string.gmatch(out,
    "\n  (fg%-sora%-%d) +(stand%-in%-%a) +(%d+) +([%d%.]+) +([%d%.]+) ") do
    shown = shown + 1
    local tot = totals[voice .. " " .. endpoint]
    if tot and tot.n == tonumber(n) and math.abs(tot.seconds / tot.n - tonumber(seconds)) < 0.006
        and math.abs(tot.tries / tot.n - tonumber(tries)) < 0.006 then right = right + 1 end
end
local keys = 0
for _ in pairs(totals) do keys = keys + 1 end
check("per voice and endpoint: turns, seconds and tries per turn, as the logs add up",
    shown == keys and right == shown, right .. " of " .. shown .. " (" .. keys .. ")")
check("the switch: use-endpoint ran on the workspace's file, and said so",
    has(out, ">>> use.fg-sora-2: stand-in-a -> stand-in-b")
    and has(slurp(WS_ROOT .. "/endpoints"), 'use.fg-sora-2 = "stand-in-b"'), out)
check("and shows in the numbers: fg-sora-2 on both endpoints, the others on the first only",
    totals["fg-sora-2 stand-in-a"] and totals["fg-sora-2 stand-in-b"]
    and not totals["fg-sora-1 stand-in-b"] and not totals["fg-sora-3 stand-in-b"])
local slower = totals["fg-sora-2 stand-in-b"] and totals["fg-sora-2 stand-in-a"]
    and totals["fg-sora-2 stand-in-b"].seconds / totals["fg-sora-2 stand-in-b"].n
        > totals["fg-sora-2 stand-in-a"].seconds / totals["fg-sora-2 stand-in-a"].n
check("the second model is slower, and it shows", slower)
-- A turn still running when the rehearsal ended may since have moved its
-- receipt to .previous and written a new one: the one shown is either.
local function shown_as(r)
    local names = {}
    for name, value in pairs(r and r.counters or {}) do names[#names + 1] = name .. " " .. value end
    table.sort(names)
    return table.concat(names, ", ")
end
local receipts = 0
for _, voice in ipairs(rehearsal.VOICES) do
    local path = WS_ROOT .. "/output/goodbye-turn-" .. voice
    local now, before = goodbye.read(path), goodbye.read(path .. ".previous")
    if (now and has(out, "  " .. voice .. ": " .. shown_as(now) .. "\n"))
        or (before and has(out, "  " .. voice .. ": " .. shown_as(before) .. "\n"))
        or has(out, "  " .. voice .. ": none\n") then
        receipts = receipts + 1
    end
end
check("each voice's last turn receipt is shown as it is", receipts == 3, receipts)
check("and each runner's counts are the rehearsal's receipt's", (function()
    for _, voice in ipairs(rehearsal.VOICES) do
        local esc = voice:gsub("%-", "%%-")
        local received, run, sent = out:match("\n  " .. esc
            .. " +(%d+) canvas[es]* received, (%d+) turns? run, (%d+) canvas[es]* sent")
        if not (tonumber(received) == c[voice .. ".canvases-received"]
            and tonumber(run) == c[voice .. ".turns-run"]
            and tonumber(sent) == c[voice .. ".canvases-sent"]) then return false end
    end
    return true
end)())
check("no stand-in model is left running", models_running(ROOT) == 0)
shell("rm -rf " .. q(string.match(ROOT, "^(.*)/guide%-feature$") or ROOT))
-- }}}

io.write("\n=== through run-phase-demo ===\n")
-- {{{
out, status = shell(ENV .. q(PROJECT .. "/run-phase-demo") .. " " .. q(PROJECT) .. " 9")
check("run-phase-demo offers phase 4", string.match(out, "1 2 3 4") ~= nil, out)
write(PROJECT .. "/input/rehearsal", 'minutes = 5\ncarrier = "stand-in"\n'
    .. 'first-port = 41423\npace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n')
out, status = shell(ENV .. q(DEMO) .. " " .. q(PROJECT) .. " --minutes 0.2")
check("and it runs short, ending cleanly", status == 0 and has(out, "Phase 4: the turn")
    and has(out, "Every turn, from the turns' own logs"), string.sub(out or "", -1500))
check("leaving nothing behind", shell("ls -A " .. q(TMP)) == "", (shell("ls -A " .. q(TMP))))
check("not even a stand-in model", models_running(TMP) == 0)
-- }}}

shell("rm -rf " .. q(BASE))
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
