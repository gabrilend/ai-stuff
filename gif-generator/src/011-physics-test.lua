-- 011-physics-test.lua — proof for the integrator.
--
-- What this is, generally: hand-built particles pushed through known
-- ticks, checked against arithmetic — exponential slowing, exactly
-- linear drift, same-day deaths for a same-lifetime cohort, and the
-- two-runs-one-seed determinism the whole project stands on.
-- Run directly: luajit src/011-physics-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local pool = require("006-pool")
local emit = require("008-emit")
local physics = require("010-physics")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

local DT = 0.04

-- {{{ local function lone_particle()
-- One hand-made particle with everything chosen, nothing rolled.
local function lone_particle(vx, drag, jitter, life)
    local p = pool.new(4)
    local i = pool.spawn(p, "t")
    p.x[i], p.y[i] = 0, 0
    p.vx[i], p.vy[i] = vx, 0
    p.age[i] = 0
    p.life[i] = life
    p.drag[i] = drag
    p.jitter[i] = jitter
    p.seed[i] = 1
    p.hue[i] = 0
    return p
end
-- }}}

-- drag-only: speed decays exactly as (1 - drag*dt)^ticks
local p = lone_particle(100, 2.0, 0, 999)
local rng = emit.rng(3)
for _ = 1, 25 do physics.tick(p, rng, DT) end
local expected = 100 * (1 - 2.0 * DT) ^ 25
check("drag alone slows exponentially, to the digit",
      math.abs(p.vx[0] - expected) < 0.01)
check("drag alone never bends the path sideways", p.vy[0] == 0)

-- nothing at all: motion is exactly linear
local p2 = lone_particle(50, 0, 0, 999)
for _ = 1, 50 do physics.tick(p2, emit.rng(1), DT) end
check("no drag, no jitter: exactly linear drift",
      math.abs(p2.x[0] - 50 * DT * 50) < 1e-3)

-- overdrag clamps to rest instead of vibrating backward
local p3 = lone_particle(100, 100, 0, 999)
physics.tick(p3, emit.rng(1), DT)
check("absurd drag reads as rest, not as vibration", p3.vx[0] >= 0)

-- a cohort with one lifetime dies on the same tick, together
local cohort = pool.new(64)
for n = 1, 32 do
    local i = pool.spawn(cohort, "t")
    cohort.x[i], cohort.y[i], cohort.vx[i], cohort.vy[i] = n, n, 0, 0
    cohort.age[i], cohort.life[i] = 0, 0.2
    cohort.drag[i], cohort.jitter[i] = 0, 0
    cohort.seed[i], cohort.hue[i] = 1, 0
end
local rngc = emit.rng(2)
for _ = 1, 4 do physics.tick(cohort, rngc, DT) end
check("the cohort lives while its time remains", cohort.live == 32)
physics.tick(cohort, rngc, DT)
check("the cohort dies together, on time", cohort.live == 0)

-- fade: newborn blazes near one, the dying ember near zero, and the
-- curve only ever descends
local pf = lone_particle(0, 0, 0, 1.0)
local newborn = physics.fade_of(pf, 0)
local mono = true
local last = newborn
local rf = emit.rng(4)
for _ = 1, 24 do
    physics.tick(pf, rf, DT)
    local f = physics.fade_of(pf, 0)
    if f > last then mono = false end
    last = f
end
check("a newborn blazes", newborn > 0.9)
check("an elder embers", last < 0.15)
check("the fade only ever descends", mono)

-- determinism: jittered swarms replay exactly under one seed
-- {{{ local function swarm_run()
local function swarm_run(seed)
    -- 500/s for 0.8s is 400 births and the default life outlives the
    -- run — the overflow wall caught this pool at 256 on first try,
    -- doing for this test exactly what it exists to do
    local sp = pool.new(512)
    local sr = emit.rng(seed)
    local rec = emit.recipe({ rate = 500, jitter = 80 }, 0)
    local carry = 0
    for _ = 1, 20 do
        carry = emit.step(sp, sr, rec, "t", 128, 128, 0, -1, 1, DT, carry)
        physics.tick(sp, sr, DT)
    end
    return sp
end
-- }}}
local sa = swarm_run(11)
local sb = swarm_run(11)
local same = sa.live == sb.live
for i = 0, sa.live - 1 do
    if sa.x[i] ~= sb.x[i] or sa.y[i] ~= sb.y[i] then same = false end
end
check("a jittered swarm replays exactly under one seed", same)

print(string.format("physics: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
