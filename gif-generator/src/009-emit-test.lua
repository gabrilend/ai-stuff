-- 009-emit-test.lua — proof for emitters, the generator, and the
-- fractional carry.
--
-- What this is, generally: counts births against arithmetic, runs
-- the same seed twice and different seeds twice, and pushes an
-- awkward spawn rate through a long run to show the carry never
-- drifts. Run directly: luajit src/009-emit-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local pool = require("006-pool")
local emit = require("008-emit")

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

local DT = 0.04   -- one 25fps tick

-- divisible rates birth exact counts every tick
local p = pool.new(4096)
local rng = emit.rng(7)
local recipe = emit.recipe({ rate = 400 }, 0)
local carry = 0
carry = emit.step(p, rng, recipe, "t", 100, 100, 1, 0, 1.0, DT, carry)
check("400 per second at 25 fps is exactly 16 this tick", p.live == 16)
for _ = 1, 99 do
    carry = emit.step(p, rng, recipe, "t", 100, 100, 1, 0, 1.0, DT, carry)
end
check("one hundred ticks of 16 is exactly 1600", p.live == 1600)

-- awkward rates never drift: 7.3 per second over 40 seconds is 292,
-- and the carry keeps us within one birth of it at any cut
local p2 = pool.new(4096)
local rng2 = emit.rng(7)
local awkward = emit.recipe({ rate = 7.3 }, 0)
local c2 = 0
for _ = 1, 1000 do
    c2 = emit.step(p2, rng2, awkward, "t", 0, 0, 1, 0, 1.0, DT, c2)
end
-- "within one birth" means AT MOST one: the floor-and-carry can
-- honestly sit one below the real-number total when the fractions
-- sum to a hair under a whole (7.3 x 0.04 is not exact in floats)
check("an awkward rate lands within one birth of the arithmetic",
      math.abs(p2.live - 7.3 * 40) <= 1)

-- determinism: one seed, two runs, identical particles
-- {{{ local function birth_run()
local function birth_run(seed)
    local pp = pool.new(512)
    local rr = emit.rng(seed)
    local rec = emit.recipe({ rate = 250, spread = 3 }, 0)
    local cc = 0
    for _ = 1, 10 do
        cc = emit.step(pp, rr, rec, "t", 50, 60, 0, 1, 1.0, DT, cc)
    end
    return pp
end
-- }}}
local run_a = birth_run(42)
local run_b = birth_run(42)
local identical = run_a.live == run_b.live
for i = 0, run_a.live - 1 do
    if run_a.x[i] ~= run_b.x[i] or run_a.y[i] ~= run_b.y[i]
       or run_a.vx[i] ~= run_b.vx[i] or run_a.life[i] ~= run_b.life[i] then
        identical = false
    end
end
check("one seed tells one story, twice", identical)

local run_c = birth_run(43)
local diverged = false
for i = 0, math.min(run_a.live, run_c.live) - 1 do
    if run_a.x[i] ~= run_c.x[i] then diverged = true end
end
check("different seeds tell different stories", diverged)

-- envelope strength scales emission: half strength, half births
local p3 = pool.new(4096)
local rng3 = emit.rng(9)
local c3 = 0
for _ = 1, 100 do
    c3 = emit.step(p3, rng3, recipe, "t", 0, 0, 1, 0, 0.5, DT, c3)
end
check("half envelope strength births half the particles",
      p3.live == 800)

-- zero strength births nothing at all
local p4 = pool.new(64)
local c4 = emit.step(p4, emit.rng(1), recipe, "t", 0, 0, 1, 0, 0.0, DT, 0)
check("a silent envelope births nothing", p4.live == 0 and c4 == 0)

-- full aim rides the heading: every velocity points the heading's way
local p5 = pool.new(512)
local aimed = emit.recipe({ rate = 250, aim = 1.0 }, 0)
emit.step(p5, emit.rng(5), aimed, "t", 0, 0, 0, -1, 1.0, DT, 0)
local all_upward = p5.live > 0
for i = 0, p5.live - 1 do
    if p5.vy[i] >= 0 or math.abs(p5.vx[i]) > 1e-6 then all_upward = false end
end
check("full aim sends every birth along the heading", all_upward)

-- the recipe wall: misspelled fields are refused with the legal list
local ok, err = pcall(emit.recipe, { rte = 100 }, 0)
check("a misspelled recipe field is refused", not ok)
check("the refusal lists the legal fields",
      err ~= nil and err:find("spread", 1, true) ~= nil)

-- seed zero is legal and does not silence the generator
local rz = emit.rng(0)
local a = emit.uniform(rz)
local b = emit.uniform(rz)
check("seed zero still rolls", a ~= b or a ~= 0)

print(string.format("emit: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
