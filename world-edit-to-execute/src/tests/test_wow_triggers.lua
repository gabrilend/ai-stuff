--[[
Tests for W02e (triggers on the server), step 1: the shim
(server-side/ale/wc3shim/) on a fake ALE, checked against the project's
own runtime (src/jass/vm.lua) on the same scripts, and the converter's
coverage report (src/wowbuild/triggers.lua) for the maps in assets/.

    luajit src/tests/test_wow_triggers.lua [project folder]

The maps need StormLib (STORMLIB_PATH, or the project's deps/); without it
their part is skipped.
]]

-- {{{ Setup paths
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
package.path = DIR .. "src/?.lua;" .. DIR .. "src/?/init.lua;" ..
               DIR .. "server-side/ale/?.lua;" .. DIR .. "server-side/ale/?/init.lua;" .. package.path

local vm = require("jass.vm")
local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")
local shim = require("wc3shim")
local fake = require("wc3shim.fake_ale")
local triggers = require("wowbuild.triggers")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count, skip_count = 0, 0, 0
local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end
local function skip(name, why)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. ": " .. why)
end
local function section(name) print("\n=== " .. name .. " ===") end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local SCRATCH = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ Running one script both ways
-- The script transpiled as the VM loads it (env scope, the VM's types)
local REF = triggers.reference()
local function transpile(source)
    local ast, errs = parser.parse(lexer.tokenize(source))
    assert(not errs or #errs == 0, errs and errs[1] and tostring(errs[1].message))
    local lua, terrs = transpiler.transpile(ast, { scope = "env", native_types = REF.types, global_types = REF.global_types })
    assert(not terrs or #terrs == 0, terrs and terrs[1] and tostring(terrs[1].message))
    local globals = {}
    for _, d in ipairs(ast.declarations or {}) do
        if d.type == "GLOBAL_BLOCK" then for _, g in ipairs(d.declarations or {}) do globals[#globals + 1] = g.name end end
    end
    return lua, globals
end

-- map data as the converter writes it: slot 0, a made transform
local TRANSFORM = { scale = 1 / 30.72, x0 = 17000, y0 = 17066.67 }
local function made_data(extra)
    local d = {
        format = 1, map = { id = 900, instance = 0, directory = "WC3_test" },
        wc3_to_wow = TRANSFORM,
        templates = { { id = "hfoo", faction = 3000, entry = 9000000 }, { id = "hpea", faction = 3001, entry = 9000001 } },
        factions = { { template = 3000, players = { 0 } }, { template = 3001, players = { 1 } } },
        spawns = {},
    }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- VM on a bare world: run for `seconds` in ticks of dt, calling at(t) each tick
local function run_vm(lua, globals, seconds, at)
    local V = vm.new(nil, { player = 0 })
    local log = {}
    rawset(V.env, "Log", function(s) log[#log + 1] = { t = V.time, text = s } end)
    for _, g in ipairs(globals) do V.declared[g] = true end
    local chunk = assert(loadstring(lua, "=test"))
    setfenv(chunk, V.env)
    chunk()
    V:run_main()
    local dt = 0.02
    for _ = 1, math.floor(seconds / dt + 0.5) do
        V:tick(dt)
        if at then at(V, V.time) end
    end
    return V, log
end

-- the shim on a fake ALE stepped as often
local function run_shim(lua, globals, seconds, at, data, fake_opts)
    local A = fake.new(fake_opts or { map_id = 900, update_ms = 20, ground = function() return 12.5 end })
    local S = shim.new(A, data or made_data())
    local log = {}
    rawset(S.env, "Log", function(s) log[#log + 1] = { t = S:now(), text = s } end)
    local ok, err = S:load(lua, globals)
    assert(ok, err)
    S:run_main()
    for _ = 1, math.floor(seconds / 0.02 + 0.5) do
        A:advance(20)
        if at then at(S, A, S:now()) end
    end
    return S, A, log
end

-- Two lines say the same: their words equal, their whole numbers equal,
-- their reals (R2S's, with a point) within one 20 ms tick. The VM counts a
-- timer down tick by tick, timer after timer, so a timer read inside
-- another's callback can still show the last tick's time left (1.720 where
-- the shim, reading the clock, says 1.700).
local function same_text(x, y)
    if x == y then return true end
    local tx, ty = {}, {}
    for w in x:gmatch("%S+") do tx[#tx + 1] = w end
    for w in y:gmatch("%S+") do ty[#ty + 1] = w end
    if #tx ~= #ty then return false end
    for i = 1, #tx do
        if tx[i] ~= ty[i] then
            local a, b = tonumber(tx[i]), tonumber(ty[i])
            if not (a and b and tx[i]:find(".", 1, true) and math.abs(a - b) <= 0.0201) then return false end
        end
    end
    return true
end
local function same_log(a, b, slack)
    if #a ~= #b then return false, string.format("%d lines against %d", #a, #b) end
    for i = 1, #a do
        if not same_text(a[i].text, b[i].text) then return false, string.format("line %d: %q against %q", i, a[i].text, b[i].text) end
        if math.abs(a[i].t - b[i].t) > slack then
            return false, string.format("line %d (%s): at %.3f s against %.3f s", i, a[i].text, a[i].t, b[i].t)
        end
    end
    return true
end
local function show(log)
    local o = {}
    for _, l in ipairs(log) do o[#o + 1] = string.format("%.2f %s", l.t, l.text) end
    return table.concat(o, " | ")
end
-- }}}

-- {{{ The folder's boundary
section("The shim's folder: its own licence, nothing required from outside")

local function shim_files()
    local list = {}
    local p = io.popen("ls " .. quote(DIR .. "server-side/ale/wc3shim") .. " 2>/dev/null")
    for name in p:lines() do if name:match("%.lua$") then list[#list + 1] = name end end
    p:close()
    return list
end
local files = shim_files()
test("the shim's files are there", #files >= 5, #files)
local outside = {}
for _, name in ipairs(files) do
    local text = read(DIR .. "server-side/ale/wc3shim/" .. name) or ""
    for req in text:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do
        if not req:match("^wc3shim") then outside[#outside + 1] = name .. " -> " .. req end
    end
    test(name .. " says its licence", text:find("AGPL v3", 1, true) ~= nil)
end
test("the shim requires nothing outside its folder", #outside == 0, table.concat(outside, ", "))
local lic, repo_lic = read(DIR .. "server-side/LICENSE"), read(DIR .. "../LICENSE")
test("server-side/LICENSE is the GNU AGPL v3", lic and lic:find("GNU AFFERO GENERAL PUBLIC LICENSE", 1, true)
    and lic:find("Version 3, 19 November 2007", 1, true))
if repo_lic then test("... the repository's own text", lic == repo_lic) end

-- covered.lua lists exactly what the shim installs
local covered = triggers.covered(DIR)
local S0 = shim.new(fake.new(), made_data())
local extra, absent = {}, {}
for name in pairs(S0.natives) do if not covered.by_name[name] then extra[#extra + 1] = name end end
for name in pairs(covered.by_name) do if not S0.natives[name] then absent[#absent + 1] = name end end
table.sort(extra) table.sort(absent)
test("covered.lua names every native the shim installs", #extra == 0, table.concat(extra, " "))
test("covered.lua names nothing the shim lacks", #absent == 0, table.concat(absent, " "))
local not_in_ref = {}
for name in pairs(covered.by_name) do if not REF.natives[name] then not_in_ref[#not_in_ref + 1] = name end end
table.sort(not_in_ref)
test("every native the shim has, the reference runtime has too (so it can be checked)", #not_in_ref == 0,
    table.concat(not_in_ref, " "))
local n_covered = 0
for _ in pairs(covered.by_name) do n_covered = n_covered + 1 end
print(string.format("  (the shim implements %d natives in %d groups)", n_covered, #covered.groups))
-- }}}

-- {{{ Timers, waits and timer events against the VM
section("Timers, waits and timer events: the shim against the VM")

local SCRIPT = [[
globals
    timer t1 = null
    timer t2 = null
    integer n = 0
    trigger tt = null
    trigger tw = null
    integer every = 0
endglobals
function OnT1 takes nothing returns nothing
    set n = n + 1
    call Log("t1 " + I2S(n) + " t2 left " + R2S(TimerGetRemaining(t2)))
    if n == 3 then
        call PauseTimer(t2)
        call Log("paused, left " + R2S(TimerGetRemaining(t2)))
    endif
    if n == 5 then
        call ResumeTimer(t2)
    endif
    if n == 7 then
        call PauseTimer(t1)
    endif
endfunction
function OnT2 takes nothing returns nothing
    call Log("t2 expired, mine " + I2S(GetHandleId(GetExpiredTimer()) - GetHandleId(t2)) + ", elapsed " + R2S(TimerGetElapsed(t2)))
endfunction
function Every takes nothing returns boolean
    set every = every + 1
    call Log("periodic trigger " + I2S(every))
    if every == 4 then
        call DisableTrigger(tt)
    endif
    return true
endfunction
function Waits takes nothing returns nothing
    call Log("wait start")
    call TriggerSleepAction(1.3)
    call Log("wait end " + I2S(7 / 2))
    call PolledWait(0.5)
    call Log("polled end")
endfunction
function main takes nothing returns nothing
    set t1 = CreateTimer()
    set t2 = CreateTimer()
    call TimerStart(t1, 0.5, true, function OnT1)
    call TimerStart(t2, 2.2, false, function OnT2)
    set tt = CreateTrigger()
    call TriggerRegisterTimerEventPeriodic(tt, 0.45)
    call TriggerAddAction(tt, function Every)
    set tw = CreateTrigger()
    call TriggerRegisterTimerEventSingle(tw, 0.1)
    call TriggerAddAction(tw, function Waits)
    call Log("main done")
endfunction
]]
local lua, globals = transpile(SCRIPT)
local V, vlog = run_vm(lua, globals, 5)
local S, A, slog = run_shim(lua, globals, 5)
local ok, why = same_log(vlog, slog, 0.021)
test("the same lines at the same times (within a 20 ms update)", ok, (why or "") .. "\n    vm:   " .. show(vlog) .. "\n    shim: " .. show(slog))
test("the script's run is long enough to mean something", #slog >= 15, #slog)
test("no errors either way", #S.errors == 0 and #V.errors == 0, S.errors[1] and S.errors[1].message)
test("nothing missing in the shim", next(S.missing) == nil)
-- the paused periodic timer stays put
local left = S.natives.TimerGetRemaining(S.env.t1)
test("a paused timer keeps its time left", left > 0 and left <= 0.5, left)
-- every ALE call the shim made is in shim.ALE_USED
local listed = {}
for _, row in ipairs(shim.ALE_USED) do
    for part in row.name:gmatch("[^/]+") do
        local obj = row.name:match("^(%w+):")
        listed[(part:find(":") or not obj) and part or (obj .. ":" .. part)] = true
    end
end
local unlisted = {}
for name in pairs(A.used) do if not listed[name] then unlisted[#unlisted + 1] = name end end
test("every ALE call is listed in shim.ALE_USED", #unlisted == 0, table.concat(unlisted, " "))
test("every ALE row is marked unchecked until it's checked on the owner's machine", (function()
    for _, row in ipairs(shim.ALE_USED) do if row.checked ~= false then return false end end
    return true
end)())
-- a periodic timer of 0 doesn't hang an update
do
    local lua0, g0 = transpile([[
globals
    integer n = 0
endglobals
function F takes nothing returns nothing
    set n = n + 1
endfunction
function main takes nothing returns nothing
    call TimerStart(CreateTimer(), 0.0, true, function F)
endfunction
]])
    local S2 = run_shim(lua0, g0, 1)
    test("a periodic timer of timeout 0 runs every " .. shim.ZERO_PERIOD_MS .. " ms", S2.env.n >= 45 and S2.env.n <= 51, S2.env.n)
end
-- }}}

-- {{{ Gold and lumber
section("Players' gold and lumber: the shim against the VM")

local GOLD = [[
globals
    trigger tr = null
endglobals
function Rich takes nothing returns nothing
    call Log("rich " + I2S(GetPlayerId(GetTriggerPlayer())) + " at " + I2S(GetPlayerState(GetTriggerPlayer(), PLAYER_STATE_RESOURCE_GOLD)))
endfunction
function Show takes nothing returns nothing
    call Log("gold " + I2S(GetPlayerState(Player(0), PLAYER_STATE_RESOURCE_GOLD)) + " lumber " + I2S(GetPlayerState(Player(1), PLAYER_STATE_RESOURCE_LUMBER)) + " gathered " + I2S(GetPlayerState(Player(0), PLAYER_STATE_GOLD_GATHERED)) + "/" + I2S(GetPlayerState(Player(1), PLAYER_STATE_LUMBER_GATHERED)))
endfunction
function Earn takes nothing returns nothing
    call AdjustPlayerStateBJ(100, Player(0), PLAYER_STATE_RESOURCE_GOLD)
    call Show()
endfunction
function main takes nothing returns nothing
    set tr = CreateTrigger()
    call TriggerRegisterPlayerStateEvent(tr, Player(0), PLAYER_STATE_RESOURCE_GOLD, LIMIT_OP_GREATER_THAN_OR_EQUAL, 900)
    call TriggerAddAction(tr, function Rich)
    call SetPlayerState(Player(0), PLAYER_STATE_RESOURCE_GOLD, 500)
    call AdjustPlayerStateBJ(250, Player(0), PLAYER_STATE_RESOURCE_GOLD)
    call SetPlayerStateBJ(Player(1), PLAYER_STATE_RESOURCE_LUMBER, 120)
    call AdjustPlayerStateBJ(-30, Player(1), PLAYER_STATE_RESOURCE_LUMBER)
    call AdjustPlayerStateSimpleBJ(ConvertedPlayer(2), PLAYER_STATE_RESOURCE_LUMBER, 5)
    call Show()
    call TimerStart(CreateTimer(), 1.0, true, function Earn)
endfunction
]]
lua, globals = transpile(GOLD)
local heard = {}
V, vlog = run_vm(lua, globals, 3.5)
local A2 = fake.new({ map_id = 900, update_ms = 20 })
S = shim.new(A2, made_data(), { on_player_state = function(p, k, v) heard[#heard + 1] = p.id .. " " .. k .. " " .. v end })
slog = {}
rawset(S.env, "Log", function(s) slog[#slog + 1] = { t = S:now(), text = s } end)
assert(S:load(lua, globals))
S:run_main()
A2:advance(3500)
ok, why = same_log(vlog, slog, 0.021)
test("the same states, the same state event", ok, (why or "") .. "\n    vm:   " .. show(vlog) .. "\n    shim: " .. show(slog))
test("gold 750, lumber 95 (ConvertedPlayer(2) is Player(1)), 250 and 120 gathered after main", slog[1] and slog[1].text == "gold 750 lumber 95 gathered 250/120",
    slog[1] and slog[1].text)
test("the state event fires once, when gold reaches 900", (function()
    local n = 0
    for _, l in ipairs(slog) do if l.text:match("^rich") then n = n + 1 end end
    return n == 1
end)())
test("each change is told to the resource bar's hook", #heard >= 6 and heard[1] == "0 gold 500", heard[1])
-- }}}

-- {{{ Units made at a point, and regions entered
section("Units made at a point, and regions entered: the shim against the VM")

local UNITS = [[
globals
    unit u = null
    unit g = null
    rect r = null
    region rg = null
    trigger te = null
    trigger tl = null
endglobals
function Entered takes nothing returns nothing
    call Log("entered by " + I2S(GetUnitTypeId(GetEnteringUnit())) + " of " + I2S(GetPlayerId(GetOwningPlayer(GetTriggerUnit()))) + " at " + I2S(R2I(GetUnitX(GetTriggerUnit()) + 0.5)))
endfunction
function Left takes nothing returns nothing
    call Log("left by " + I2S(GetUnitTypeId(GetLeavingUnit())))
endfunction
function main takes nothing returns nothing
    set u = CreateUnit(Player(0), 'hfoo', -256.0, 128.0, 90.0)
    call CreateUnitAtLocSaveLast(Player(1), 'hfoo', Location(640.0, 0.0), 0.0)
    set g = CreateUnit(Player(0), 'nogh', 0.0, 0.0, 0.0)
    set r = Rect(512.0, -128.0, 768.0, 128.0)
    set te = CreateTrigger()
    call TriggerRegisterEnterRectSimple(te, r)
    call TriggerAddAction(te, function Entered)
    set rg = CreateRegion()
    call RegionAddRect(rg, r)
    set tl = CreateTrigger()
    call TriggerRegisterLeaveRegion(tl, rg, null)
    call TriggerAddAction(tl, function Left)
    call Log("made " + I2S(R2I(GetUnitX(u))) + "," + I2S(R2I(GetUnitY(u))) + " facing " + I2S(R2I(GetUnitFacing(u) + 0.5)) + " last " + I2S(R2I(GetUnitX(GetLastCreatedUnit()))))
endfunction
]]
lua, globals = transpile(UNITS)
-- the harness walks the first footman into the rect at 1 s and out at 2 s
local function walk_vm(V2, t)
    local u = V2.env.u
    if t >= 1.0 and t < 1.01 then u.x, u.y = 600, 0 end
    if t >= 2.0 and t < 2.01 then u.x, u.y = 900, 0 end
end
local spawned_at
local function walk_shim(S2, A3, t)
    local c = S2.env.u.creature
    if t < 0.03 then spawned_at = { c.x, c.y, c.z, c.o } end
    if t >= 1.0 and t < 1.01 then A3:move(c, S2.to_wow(600, 0)) end
    if t >= 2.0 and t < 2.01 then A3:move(c, S2.to_wow(900, 0)) end
end
V, vlog = run_vm(lua, globals, 3, walk_vm)
local A3
S, A3, slog = run_shim(lua, globals, 3, walk_shim)
test("no errors in the shim", #S.errors == 0, S.errors[1] and S.errors[1].message)
ok, why = same_log(vlog, slog, 0.12)
test("the same events (within the 100 ms region check)", ok, (why or "") .. "\n    vm:   " .. show(vlog) .. "\n    shim: " .. show(slog))
test("the walking footman enters, then leaves", slog[2] and slog[2].text:match("^entered by %d+ of 0 at 600$") ~= nil
    and slog[3] and slog[3].text:match("^left by") ~= nil, show(slog))
test("a unit standing in the rect when it is registered doesn't enter it", not show(slog):find("of 1", 1, true))
local c = S.env.u.creature
test("the footman is a creature of its template's entry", c and c.entry == 9000000, c and c.entry)
local X, Y = S.to_wow(-256, 128)
test("... at map.lua's transform of its WC3 point", spawned_at and math.abs(spawned_at[1] - X) < 1e-6 and math.abs(spawned_at[2] - Y) < 1e-6)
test("... on the server's ground", spawned_at and spawned_at[3] == 12.5)
test("... facing WC3's 90 degrees (north) as WoW's orientation 0", spawned_at and math.abs(spawned_at[4]) < 1e-9, spawned_at and spawned_at[4])
test("... not saved to the database", c and c.save == false)
local blue = S.env.bj_lastCreatedUnit.creature
test("blue's footman: the footman template, blue's faction set on the creature", blue and blue.entry == 9000000 and blue.faction == 3001,
    blue and (blue.entry .. "/" .. tostring(blue.faction)))
test("a type with no template is a ghost, counted", S.env.g and S.env.g.creature == nil and S.unspawnable.nogh == 1)
test("GetUnitX/Y read the creature back in WC3 units", math.abs(S.natives.GetUnitX(S.env.u) - 900) < 0.01
    and math.abs(S.natives.GetUnitY(S.env.u) - 0) < 0.01)
-- RemoveUnit
S.natives.RemoveUnit(S.env.u)
test("RemoveUnit despawns the creature", c.despawned == true)
-- no ground on the server yet (before W02d)
do
    local A4 = fake.new({ map_id = 900 })
    local S4 = shim.new(A4, made_data())
    local u4 = S4.natives.CreateUnit(S4.natives.Player(0), shim.s2id("hfoo"), 0, 0, 0)
    test("where the server has no ground, z = 0 and it is counted", u4.creature.z == 0 and S4.counts.no_ground == 1)
end
-- }}}

-- {{{ Adopting W02b's spawns
section("main() makes the placed units: the shim adopts W02b's spawns")

do
    local data = made_data({ spawns = {
        { guid = 1000000, entry = 9000000, id = "hfoo", player = 0, x = -1000.04, y = 512.03 },
        { guid = 1000001, entry = 9000000, id = "hfoo", player = 0, x = 300, y = 300 },
    } })
    local A5 = fake.new({ map_id = 900, ground = function() return 0 end })
    local placed = {}
    for _, s in ipairs(data.spawns) do
        local X5, Y5 = TRANSFORM.x0 + TRANSFORM.scale * s.y, TRANSFORM.y0 - TRANSFORM.scale * s.x
        placed[#placed + 1] = A5:place(s.guid, s.entry, X5, Y5, 0, 0, 3000)
    end
    local S5 = shim.new(A5, data)
    local l5, g5 = transpile([[
globals
    unit a = null
    unit b = null
    unit later = null
endglobals
function Later takes nothing returns nothing
    set later = CreateUnit(Player(0), 'hfoo', 300.0, 300.0, 0.0)
endfunction
function main takes nothing returns nothing
    set a = CreateUnit(Player(0), 'hfoo', -1000.0, 512.0, 270.0)
    set b = CreateUnit(Player(0), 'hfoo', 0.0, 0.0, 270.0)
    call TimerStart(CreateTimer(), 0.5, false, function Later)
endfunction
]])
    assert(S5:load(l5, g5))
    S5:run_main()
    A5:advance(1000)
    test("a CreateUnit in main() where a spawn stands takes that creature", S5.env.a.creature == placed[1] and S5.counts.adopted == 1)
    test("... a CreateUnit elsewhere spawns a new one", S5.env.b.creature ~= nil and S5.env.b.creature ~= placed[2])
    test("... after main(), CreateUnit always spawns", S5.env.later.creature ~= placed[2] and S5.counts.spawned == 2)
end
-- }}}

-- {{{ The coverage report: a made script
section("The coverage report: a made script")

do
    local scan = triggers.scan([[
native UnitAlive takes unit id returns boolean
function Helper takes nothing returns nothing
    call KillUnit(CreateUnit(Player(0), 'h000', 0, 0, 0))
endfunction
function main takes nothing returns nothing
    call Helper()
    call Helper()
    call CreateUnit(Player(1), 'hfoo', 1.0, 2.0, 3.0)
    call UnitAlive(null)
    call NoSuchNative()
endfunction
]])
    local rep = triggers.coverage(scan, covered, REF, { { id = "hfoo" } })
    local by = {}
    for _, e in ipairs(rep.natives) do by[e.name] = e end
    test("the script's own functions aren't natives", by.Helper == nil and by.main == nil)
    test("each native counted by call sites", by.CreateUnit and by.CreateUnit.calls == 2 and by.Player.calls == 2)
    test("covered and not", by.CreateUnit.shim and by.CreateUnit.group == "units" and not by.KillUnit.shim)
    test("the reference's answer is given", by.KillUnit.reference == "does" and by.NoSuchNative.reference == "missing")
    test("a native the map declares is marked", by.UnitAlive and by.UnitAlive.declared_in_map == true)
    test("the uncovered list", table.concat(rep.uncovered, " ") == "KillUnit NoSuchNative UnitAlive", table.concat(rep.uncovered, " "))
    test("unit types made with no template", table.concat(rep.unit_types_without_template, " ") == "h000")
    test("counts", rep.counts.names == 5 and rep.counts.covered_names == 2 and rep.counts.calls == 7 and rep.counts.covered_calls == 4,
        string.format("%d %d %d %d", rep.counts.names, rep.counts.covered_names, rep.counts.calls, rep.counts.covered_calls))
end
-- }}}

-- {{{ The maps in assets/
section("The maps in assets/: the report in the build folder, the script on the shim")

local mpq_ok, mpq = pcall(require, "mpq")
local function storm_ok()
    if not mpq_ok then return false end
    local a = mpq.open(DIR .. "assets/DAoW-2.1.w3x")
    if a then a:close() return true end
    return false
end
if not storm_ok() then
    skip("assets/ maps", "no StormLib (STORMLIB_PATH)")
else
    local wowbuild = require("wowbuild")
    local ls = io.popen("ls " .. quote(DIR .. "assets") .. " 2>/dev/null")
    local maps = {}
    for name in ls:lines() do if name:match("%.w3[xm]$") then maps[#maps + 1] = name end end
    ls:close()
    table.sort(maps)
    -- every map: the scan, against the reference and the shim
    local totals = { maps = 0, names = 0 }
    local all_names, all_covered = {}, {}
    print("  map                                      natives  calls  shim has  of calls  lacks  ref lacks")
    for _, name in ipairs(maps) do
        local a = mpq.open(DIR .. "assets/" .. name)
        local source = a and triggers.read_script(a)
        if a then a:close() end
        if source then
            local scan = triggers.scan(source)
            local rep = triggers.coverage(scan, covered, REF, {})
            local n = rep.counts
            totals.maps = totals.maps + 1
            for _, e in ipairs(rep.natives) do
                all_names[e.name] = true
                if e.shim then all_covered[e.name] = true end
            end
            print(string.format("  %-40s %7d %6d %9d %8.1f%% %6d %10d", name:sub(1, 40), n.names, n.calls, n.covered_names,
                n.covered_percent_calls, n.uncovered_names, n.reference_missing))
            test(name .. ": parsed", #scan.errors == 0, scan.errors[1])
        end
    end
    local u, cv = 0, 0
    for _ in pairs(all_names) do u = u + 1 end
    for _ in pairs(all_covered) do cv = cv + 1 end
    print(string.format("  (%d maps; %d distinct natives called, the shim has %d of them)", totals.maps, u, cv))
    test("every map in assets/ has a script", totals.maps == #maps, totals.maps .. " of " .. #maps)

    -- two maps converted: the files in the build folder, the script on the shim
    for _, name in ipairs({ "Master-Crafters-Final-Conquest.w3x", "DAoW-2.1.w3x" }) do
        local out = SCRATCH .. "/wete-w02e-test-" .. name:gsub("%W", "_")
        os.execute("rm -rf " .. quote(out))
        local okc, report = pcall(wowbuild.convert, DIR .. "assets/" .. name, out, { stock_dbc = false, patch = false })
        test(name .. ": converts", okc, not okc and report)
        if okc then
            local tr = report.triggers
            local P = triggers.paths(report.map_directory)
            test(name .. ": the conversion report counts the natives", tr and tr.script and tr.names > 100 and tr.covered_names > 30, tr and tr.names)
            test(name .. ": the script is transpiled", tr and tr.transpiled, tr and tr.transpile_error)
            local rtext = read(out .. "/" .. P.report)
            local rep = rtext and setfenv(assert(loadstring(rtext)), {})()
            test(name .. ": natives-report.lua is data", rep and rep.counts and #rep.natives == rep.counts.names)
            local dtext = read(out .. "/" .. P.data)
            local data = dtext and setfenv(assert(loadstring(dtext)), {})()
            local mtext = read(out .. "/map.lua")
            local mapfile = mtext and setfenv(assert(loadstring(mtext)), {})()
            test(name .. ": map-data.lua uses map.lua's id and transform", data and mapfile and data.map.id == mapfile.map.id
                and data.wc3_to_wow.x0 == mapfile.wc3_to_wow.x0 and data.wc3_to_wow.scale == mapfile.wc3_to_wow.scale)
            local placed = read(out .. "/placements.lua")
            local pl = placed and setfenv(assert(loadstring(placed)), {})()
            test(name .. ": ... and W02b's templates and spawns", data and pl and #data.templates == #pl.templates and #data.spawns == #pl.units
                and (#pl.units == 0 or data.spawns[1].guid == pl.units[1].guid))
            print(string.format("  (%s: %d natives, the shim has %d (%.1f%% of %d calls); %d unit types made without a template)",
                name, tr.names, tr.covered_names, tr.covered_percent_calls, tr.calls, tr.unit_types_without_template))

            -- the transpiled script on the shim (fake ALE, W02b's spawns placed) and on the VM
            local A6 = fake.new({ map_id = data.map.id, ground = function() return 0 end })
            for _, s in ipairs(data.spawns) do
                local X6 = data.wc3_to_wow.x0 + data.wc3_to_wow.scale * s.y
                local Y6 = data.wc3_to_wow.y0 - data.wc3_to_wow.scale * s.x
                A6:place(s.guid, s.entry, X6, Y6, 0, 0)
            end
            local S6 = shim.new(A6, data)
            local okl, err = S6:load(read(out .. "/" .. P.script))
            test(name .. ": the transpiled script loads on the shim", okl, err)
            S6:run_main()
            local made = S6.counts.adopted + S6.counts.spawned + S6.counts.ghosts
            A6:advance(10000)
            local unexpected = {}
            local lacks = {}
            for _, n2 in ipairs(rep.uncovered) do lacks[n2] = true end
            for n2 in pairs(S6.missing) do if not lacks[n2] then unexpected[#unexpected + 1] = n2 end end
            table.sort(unexpected)
            test(name .. ": every native missing at run time is in the report's list", #unexpected == 0, table.concat(unexpected, " "))
            local nmiss = 0
            for _ in pairs(S6.missing) do nmiss = nmiss + 1 end
            for k = 1, math.min(3, #S6.errors) do print("    shim error: " .. S6.errors[k].message:sub(1, 300)) end
            print(string.format("  (%s on the shim: %d errors, %d natives stubbed at run time, units %d adopted, %d spawned, %d ghosts)",
                name, S6.error_count, nmiss, S6.counts.adopted, S6.counts.spawned, S6.counts.ghosts))
            test(name .. ": main() and ten seconds of its timers run on the shim with no error", S6.error_count == 0,
                S6.errors[1] and S6.errors[1].message)
            test(name .. ": main() adopts every spawn W02b placed", S6.counts.adopted == #data.spawns, S6.counts.adopted .. " of " .. #data.spawns)
            local Vr = vm.new(nil, { player = 0 })
            for _, g in ipairs(data.globals) do Vr.declared[g] = true end
            -- the units the script makes through the natives the shim has
            -- (others, CreateNUnitsAtLoc and the rest, are stubs there yet)
            local vm_made = 0
            for _, n2 in ipairs({ "CreateUnit", "CreateUnitAtLoc", "CreateUnitAtLocSaveLast" }) do
                local f = Vr.env[n2]
                rawset(Vr.env, n2, function(...) vm_made = vm_made + 1 return f(...) end)
            end
            local chunk = assert(loadstring(read(out .. "/" .. P.script)))
            setfenv(chunk, Vr.env)
            chunk()
            Vr:run_main()
            test(name .. ": main() makes as many units on the shim as on the VM, through the natives the shim has", made == vm_made,
                made .. " against " .. vm_made .. " (" .. #Vr.world.units .. " in all on the VM)")
            local same_gold = true
            for p = 0, 11 do
                local a1 = Vr.natives.GetPlayerState(Vr:player(p), "PLAYER_STATE_RESOURCE_GOLD")
                local b1 = S6.natives.GetPlayerState(S6:player(p), "PLAYER_STATE_RESOURCE_GOLD")
                if a1 ~= b1 then same_gold = false end
            end
            test(name .. ": every player's gold after main() is the VM's", same_gold)
        end
        os.execute("rm -rf " .. quote(out))
    end
end
-- }}}

print(string.format("\nTests: %d passed, %d failed, %d skipped", pass_count, test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)
