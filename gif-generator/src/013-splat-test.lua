-- 013-splat-test.lua — proof for the snapshot and the splatter.
--
-- What this is, generally: stamps known particles onto small
-- canvases and checks symmetry, additivity, edge clipping, sub-pixel
-- honesty, and — the border's whole point — that rendering a
-- snapshot equals rendering the pool it froze, to the last float.
-- Run directly: luajit src/013-splat-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local pool = require("006-pool")
local emit = require("008-emit")
local physics = require("010-physics")
local splat = require("012-splat")
local canvas = require("000-canvas")

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

local colors = splat.colors_for({ "ember" })

-- {{{ local function plant()
-- One particle, placed by hand, mid-life so fade is unremarkable.
local function plant(p, x, y)
    local i = pool.spawn(p, "t")
    p.x[i], p.y[i] = x, y
    p.vx[i], p.vy[i] = 0, 0
    p.age[i], p.life[i] = 0.1, 1.0
    p.drag[i], p.jitter[i] = 0, 0
    p.seed[i], p.hue[i] = 1, 0
    return i
end
-- }}}

-- a stamp at an exact pixel center is fourfold symmetric
local p = pool.new(8)
plant(p, 8, 8)
local cv = canvas.new(17, 17)
canvas.clear(cv)
splat.render_pool(cv, p, colors)
local symmetric = true
for d = 1, 2 do
    local east  = cv.energy[(8 * 17 + (8 + d)) * 3]
    local west  = cv.energy[(8 * 17 + (8 - d)) * 3]
    local south = cv.energy[((8 + d) * 17 + 8) * 3]
    local north = cv.energy[((8 - d) * 17 + 8) * 3]
    if east ~= west or south ~= north or east ~= south then
        symmetric = false
    end
end
check("a centered stamp is fourfold symmetric", symmetric)
check("the stamp's heart is its brightest point",
      cv.energy[(8 * 17 + 8) * 3] > cv.energy[(8 * 17 + 9) * 3])

-- two coincident particles deposit exactly the sum
local p2 = pool.new(8)
plant(p2, 8, 8)
plant(p2, 8, 8)
local cv2 = canvas.new(17, 17)
canvas.clear(cv2)
splat.render_pool(cv2, p2, colors)
local doubled = true
for i = 0, 17 * 17 * 3 - 1 do
    if math.abs(cv2.energy[i] - 2 * cv.energy[i]) > 1e-6 then
        doubled = false
    end
end
check("two coincident particles are exactly the sum", doubled)

-- a particle at the very edge clips by bounds, never by error
local p3 = pool.new(8)
plant(p3, 0.3, 0.2)
local cv3 = canvas.new(17, 17)
canvas.clear(cv3)
local clipped_ok = pcall(splat.render_pool, cv3, p3, colors)
check("an edge particle clips without complaint", clipped_ok)
check("the clipped stamp still lands what fits",
      cv3.energy[0] > 0)

-- sub-pixel positions matter: a half-pixel shift changes the light
local p4 = pool.new(8)
plant(p4, 8.5, 8)
local cv4 = canvas.new(17, 17)
canvas.clear(cv4)
splat.render_pool(cv4, p4, colors)
check("a half-pixel shift is not the same picture",
      cv4.energy[(8 * 17 + 8) * 3] ~= cv.energy[(8 * 17 + 8) * 3])
check("the shifted stamp leans the way it moved",
      cv4.energy[(8 * 17 + 9) * 3] > cv4.energy[(8 * 17 + 7) * 3])

-- the border's whole point: a snapshot renders identically to the
-- pool it froze — a real simulated swarm, to the last float
local swarm = pool.new(1024)
local rng = emit.rng(21)
local recipe = emit.recipe({ rate = 800, jitter = 60 }, 0)
local carry = 0
for _ = 1, 12 do
    carry = emit.step(swarm, rng, recipe, "t", 32, 32, 0, -1, 1, 0.04, carry)
    physics.tick(swarm, rng, 0.04)
end
local snap = splat.snapshot(swarm.capacity)
splat.take(swarm, snap)
local from_pool = canvas.new(64, 64)
local from_snap = canvas.new(64, 64)
canvas.clear(from_pool)
canvas.clear(from_snap)
splat.render_pool(from_pool, swarm, colors)
splat.render_snapshot(from_snap, snap, colors)
local border_honest = true
for i = 0, 64 * 64 * 3 - 1 do
    if from_pool.energy[i] ~= from_snap.energy[i] then
        border_honest = false
    end
end
check("the snapshot border loses nothing, to the last float",
      border_honest)
check("the swarm was real (hundreds live)", swarm.live > 300)

-- an undersized snapshot refuses rather than truncating the moment
local tiny = splat.snapshot(4)
check("an undersized snapshot refuses to lie",
      not pcall(splat.take, swarm, tiny))

print(string.format("splat: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
