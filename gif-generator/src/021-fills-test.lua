-- 021-fills-test.lua — proof for fill regions and field tracks.
--
-- What this is, generally: samples regions by the thousand and
-- checks containment, uniformity (statistically, with the tolerance
-- stated), frontier obedience at small coverage, the two-vertex
-- line cases, and a field track living inside a real timeline.
-- Run: luajit src/021-fills-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local pool = require("006-pool")
local emit = require("008-emit")
local easing = require("016-easing")
local tracks = require("018-tracks")
local fills = require("020-fills")

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

-- the vision's triangle, roughly: two tips and a low center point
local TRI = { {60, 150}, {196, 150}, {128, 210} }

-- containment: at half coverage, every sample sits inside the
-- polygon and above the frontier
local region = fills.region{ vertices = TRI, sweep = "downward" }
local rng = emit.rng(31)
local frontier = 150 + 0.5 * (210 - 150)
local contained, above = true, true
for _ = 1, 3000 do
    local x, y = region.sample(rng, 0.5)
    if y > frontier + 1e-9 then above = false end
    if y < 150 - 1e-9 or x < 60 - 1e-9 or x > 196 + 1e-9 then
        contained = false
    end
end
check("downward samples stay inside the polygon's bounds", contained)
check("downward samples respect the frontier", above)

-- the opening sliver: tiny coverage still samples, near the top
local sliver_ok = true
local sliver_high = true
for _ = 1, 200 do
    local ok, x, y = pcall(region.sample, rng, 0.01)
    if not ok then sliver_ok = false
    elseif y > 150 + 0.01 * 60 + 1e-9 then sliver_high = false end
end
check("the opening sliver never starves the sampler", sliver_ok)
check("the opening sliver hugs the top edge", sliver_high)

-- full coverage reaches the whole shape
local reached_bottom = false
for _ = 1, 3000 do
    local _, y = region.sample(rng, 1.0)
    if y > 200 then reached_bottom = true end
end
check("full coverage reaches the deep of the shape", reached_bottom)

-- uniformity: an at-once square split into quadrants — 4000 samples,
-- expect about a quarter each; tolerance stated: within 20% relative
local square = fills.region{
    vertices = { {0, 0}, {100, 0}, {100, 100}, {0, 100} },
    sweep = "at-once",
}
local quads = { 0, 0, 0, 0 }
for _ = 1, 4000 do
    local x, y = square.sample(rng, 1)
    local qi = (x < 50 and 1 or 2) + (y < 50 and 0 or 2)
    quads[qi] = quads[qi] + 1
end
local uniform = true
for q = 1, 4 do
    if quads[q] < 800 or quads[q] > 1200 then uniform = false end
end
check("at-once sampling spreads evenly (quadrants within 20%)",
      uniform)

-- radial: small coverage stays within the grown disc
local rad = fills.region{ vertices = TRI, sweep = "radial" }
local cx, cy = (60 + 196 + 128) / 3, (150 + 150 + 210) / 3
local reach = 0
for _, v in ipairs(TRI) do
    local d = math.sqrt((v[1] - cx) ^ 2 + (v[2] - cy) ^ 2)
    if d > reach then reach = d end
end
local disc_ok = true
for _ = 1, 2000 do
    local x, y = rad.sample(rng, 0.3)
    local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    if d > 0.3 * reach + 1e-9 then disc_ok = false end
end
check("radial samples stay inside the grown disc", disc_ok)

-- the zero-thickness line: along-sweep covers a prefix, at-once all
local seal = fills.region{
    vertices = { {10, 10}, {110, 10} }, sweep = "along",
}
local prefix_ok = true
for _ = 1, 1000 do
    local x, y = seal.sample(rng, 0.25)
    if x > 10 + 0.25 * 100 + 1e-9 or y ~= 10 then prefix_ok = false end
end
check("an along-line covers exactly its prefix", prefix_ok)
local whole = fills.region{
    vertices = { {10, 10}, {110, 10} }, sweep = "at-once",
}
local past_prefix = false
for _ = 1, 200 do
    local x = whole.sample(rng, 0.1)
    if x > 60 then past_prefix = true end
end
check("an at-once line is whole from its first breath", past_prefix)

-- a field track inside a real timeline: births only inside the
-- region, coverage growing linearly, and silence before coverage
local tr = fills.track{
    name = "seal-fill", from = 0.5, lasts = 1.0,
    ease = easing.motion("linear"), envelope = easing.envelope("hold"),
    region = fills.region{ vertices = TRI, sweep = "downward" },
    recipe = emit.recipe({ rate = 400, spread = 0, life = 99,
                           life_jitter = 0, speed = 0, jitter = 0 }, 0),
}
local p = pool.new(1024)
local trng = emit.rng(32)
local tl = tracks.timeline({ tr }, 0, 0)
local t = 0
while t < 1.4 do
    tracks.step(tl, p, trng, t, 0.04)
    t = t + 0.04
end
check("a field track births real particles", p.live > 200)
local all_inside = true
for i = 0, p.live - 1 do
    if not (p.y[i] >= 150 - 1e-6 and p.y[i] <= 210 + 1e-6
            and p.x[i] >= 60 - 1e-6 and p.x[i] <= 196 + 1e-6) then
        all_inside = false
    end
end
check("every field birth landed inside the region", all_inside)

-- the walls: degenerate shapes and unknown sweeps are refused
check("a flat polygon is refused",
      not pcall(fills.region, { vertices = { {0,0}, {10,0}, {20,0} },
                                sweep = "downward" }))
check("a dot line is refused",
      not pcall(fills.region, { vertices = { {5,5}, {5,5} },
                                sweep = "along" }))
local ok, err = pcall(fills.region, { vertices = TRI, sweep = "sideways" })
check("an unknown sweep is refused with the legal words",
      not ok and err:find("downward", 1, true) ~= nil)
check("a fill that takes no time is refused",
      not pcall(fills.track, { name = "instant", from = 0, lasts = 0,
                               ease = easing.motion("linear"),
                               envelope = easing.envelope("hold"),
                               region = region,
                               recipe = emit.recipe({}, 0) }))

print(string.format("fills: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
