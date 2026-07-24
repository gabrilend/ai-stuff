-- 001-canvas-test.lua — proof for the light buffer and tone-mapper.
--
-- What this is, generally: deposits known light into a small canvas
-- and asserts the promises from docs/datapath-rendering.md — black
-- stays black, energy sums, the shoulder never clips, more light
-- never reads darker. Run it directly: luajit src/001-canvas-test.lua

-- Scripts run from anywhere: hard-coded home, overridable by argument.
local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local canvas = require("000-canvas")

local passed, failed = 0, 0

-- {{{ local function check()
-- One assertion with a name; failures speak, successes count.
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- untouched canvas: every pixel maps to exact zero (black is sacred)
local cv = canvas.new(8, 8)
canvas.clear(cv)
canvas.tonemap(cv)
local all_black = true
for p = 0, 8 * 8 * 3 - 1 do
    if cv.mapped[p] ~= 0 then all_black = false end
end
check("untouched canvas maps to pure black everywhere", all_black)

-- energies sum: two half-deposits equal one whole deposit
local a = canvas.new(2, 1)
canvas.clear(a)
canvas.add(a, 0, 0, 0.4, 0.1, 0.0)
canvas.add(a, 0, 0, 0.4, 0.1, 0.0)
canvas.add(a, 1, 0, 0.8, 0.2, 0.0)
check("deposits sum: twice half equals once whole (red)",
      a.energy[0] == a.energy[3])
check("deposits sum: twice half equals once whole (green)",
      a.energy[1] == a.energy[4])

-- the shoulder never clips: absurd energy stays within a byte
local hot = canvas.new(1, 1)
canvas.clear(hot)
canvas.add(hot, 0, 0, 1e6, 1e6, 1e6)
canvas.tonemap(hot)
check("a million suns still fits in a byte",
      canvas.mapped_byte(hot, 0, 0, 0) <= 255)
check("a million suns is nearly white",
      canvas.mapped_byte(hot, 0, 0, 0) >= 250)

-- monotonicity: same-color deposits never get darker as energy grows,
-- judged by mapped luminance (the eye's verdict, not one channel's)
local last_lum = -1
local mono = true
for step = 1, 40 do
    local c = canvas.new(1, 1)
    canvas.clear(c)
    canvas.add(c, 0, 0, step * 0.25, step * 0.1, 0.0)
    canvas.tonemap(c)
    local lum = c.mapped[0] + c.mapped[1] + c.mapped[2]
    if lum < last_lum then mono = false end
    last_lum = lum
end
check("more light never reads darker", mono)

-- white-shift: a pure hue bleaches toward white as it blazes
local dim = canvas.new(1, 1)
canvas.clear(dim)
canvas.add(dim, 0, 0, 0.5, 0.0, 0.0)
canvas.tonemap(dim)
local dim_spread = dim.mapped[0] - dim.mapped[2]
local blaze = canvas.new(1, 1)
canvas.clear(blaze)
canvas.add(blaze, 0, 0, 50.0, 0.0, 0.0)
canvas.tonemap(blaze)
local blaze_spread = blaze.mapped[0] - blaze.mapped[2]
check("dim light keeps its hue (channels far apart)",
      dim_spread > 0.3)
check("blazing light surrenders to white (channels close)",
      blaze_spread < 0.1)

-- the walls hold: out-of-bounds deposits and nonsense sizes refuse
local oob = pcall(canvas.add, cv, 8, 0, 1, 1, 1)
check("deposit beyond the east wall is refused", not oob)
local zero = pcall(canvas.new, 0, 8)
check("a zero-width canvas is refused", not zero)

print(string.format("canvas: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
