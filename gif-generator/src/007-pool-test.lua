-- 007-pool-test.lua — proof for the particle pool.
--
-- What this is, generally: churns the pool through births and deaths
-- and asserts the prefix stays solid, the count stays honest, the
-- overflow wall names its asker, and the sizing arithmetic covers a
-- known steady state. Run directly: luajit src/007-pool-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local pool = require("006-pool")

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

-- birth fills the prefix in order
local p = pool.new(8)
local a = pool.spawn(p, "test")
local b = pool.spawn(p, "test")
local c = pool.spawn(p, "test")
check("births hand out the prefix in order",
      a == 0 and b == 1 and c == 2 and p.live == 3)

-- death is swap-with-last: the last particle moves into the hole
-- (test values are float32-exact on purpose: 0.3 stored in a float
-- comes back as a different double, and equality would lie)
p.x[0], p.x[1], p.x[2] = 10, 20, 30
p.seed[0], p.seed[1], p.seed[2] = 0.25, 0.5, 0.75
pool.kill(p, 0)
check("the last particle moves into the emptied slot",
      p.live == 2 and p.x[0] == 30 and p.seed[0] == 0.75)
check("the middle particle never moved",
      p.x[1] == 20 and p.seed[1] == 0.5)

-- killing the last live slot is just the count dropping
pool.kill(p, 1)
check("killing the tail only drops the count",
      p.live == 1 and p.x[0] == 30)

-- the overflow wall names its asker
local tiny = pool.new(2)
pool.spawn(tiny, "left-hand")
pool.spawn(tiny, "left-hand")
local ok, err = pcall(pool.spawn, tiny, "left-hand")
check("overflow is refused", not ok)
-- plain-text find: a dash in a Lua pattern is a quantifier, and
-- "left-hand" as a pattern never matches the literal "left-hand"
check("the overflow error names the asking stroke",
      err ~= nil and err:find("left-hand", 1, true) ~= nil)

-- killing beyond the prefix is a caller bug, said aloud
check("killing a dead index is refused",
      not pcall(pool.kill, tiny, 5))

-- fuzz: deterministic churn never leaks a slot or bends the count
local state = 88172645463325252
local function xorshift()
    state = state % 4294967296
    state = bit.bxor(state, bit.lshift(state, 13)) % 4294967296
    state = bit.bxor(state, bit.rshift(state, 17)) % 4294967296
    state = bit.bxor(state, bit.lshift(state, 5)) % 4294967296
    return state
end
local fz = pool.new(128)
local model = 0
local honest = true
for step = 1, 20000 do
    if xorshift() % 3 > 0 and model < 128 then
        pool.spawn(fz, "fuzz")
        model = model + 1
    elseif model > 0 then
        pool.kill(fz, xorshift() % model)
        model = model - 1
    end
    if fz.live ~= model then honest = false end
end
check("twenty thousand churns never bend the count", honest)

-- sizing: one emitter at steady state holds rate x life particles;
-- the estimate must cover it (headroom above, never below)
local size = pool.size_for({ { rate = 400, life = 0.6,
                               from = 0.0, upto = 2.0 } })
check("sizing covers the steady state of rate times life",
      size >= 400 * 0.6)
check("sizing does not balloon absurdly (stays under 3x steady)",
      size < 400 * 0.6 * 3)

-- two overlapping windows stack; disjoint windows do not
local stacked = pool.size_for({
    { rate = 100, life = 0.5, from = 0.0, upto = 2.0 },
    { rate = 100, life = 0.5, from = 0.0, upto = 2.0 },
})
local disjoint = pool.size_for({
    { rate = 100, life = 0.5, from = 0.0, upto = 1.0 },
    { rate = 100, life = 0.5, from = 3.0, upto = 4.0 },
})
check("overlapping demands stack in the estimate",
      stacked > disjoint)

print(string.format("pool: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
