-- 003-palette-test.lua — proof for the glow palette and indexer.
--
-- What this is, generally: builds palettes and asserts the seating
-- chart — black is alone at zero, ramps brighten monotonically, hues
-- land in their own ramps, grays land among the grays, and the walls
-- refuse unknown hues and overcrowded declarations.
-- Run directly: luajit src/003-palette-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local palette = require("002-palette")

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

local pal = palette.build({ "ember", "violet" })

-- black's seat: entry 0 is pure black, and darkness maps there
check("entry zero is pure black",
      pal.bytes[0] == 0 and pal.bytes[1] == 0 and pal.bytes[2] == 0)
check("darkness maps to index zero",
      palette.index_of(pal, 0, 0, 0) == 0)
check("faint but real light does not map to black",
      palette.index_of(pal, 0.3, 0.1, 0.02) ~= 0)

-- ramp brightness is monotonic: walking up the ember ramp, the
-- byte-sum never decreases (banding guards live elsewhere; order
-- of brightness is the palette's own promise)
local ramp = pal.ramps.ember
local mono = true
local last = -1
for j = 0, ramp.count - 1 do
    local i = (ramp.first + j) * 3
    local sum = pal.bytes[i] + pal.bytes[i + 1] + pal.bytes[i + 2]
    if sum < last then mono = false end
    last = sum
end
check("the ember ramp only ever brightens", mono)

-- hues find their own ramps: an orange pixel seats among embers,
-- a purple pixel among violets, at any believable brightness
local function in_ramp(idx, r)
    return idx >= r.first and idx < r.first + r.count
end
check("an orange pixel seats among the embers",
      in_ramp(palette.index_of(pal, 0.8, 0.35, 0.08), pal.ramps.ember))
check("a purple pixel seats among the violets",
      in_ramp(palette.index_of(pal, 0.45, 0.2, 0.85), pal.ramps.violet))

-- grays keep to the gray ramp, dark or bright
check("a dim gray seats among the grays",
      in_ramp(palette.index_of(pal, 0.2, 0.2, 0.2), pal.white))
check("a near-white seats among the grays",
      in_ramp(palette.index_of(pal, 0.97, 0.95, 0.96), pal.white))

-- brighter same-hue pixels never seat lower in the ramp
local order_ok = true
local last_idx = -1
for step = 1, 20 do
    local v = step / 20
    local idx = palette.index_of(pal, v, v * 0.42, v * 0.1)
    if idx < last_idx then order_ok = false end
    last_idx = idx
end
check("brighter ember light never seats lower", order_ok)

-- the walls: unknown hues and overcrowded declarations are refused
local unknown = pcall(palette.hue_color, "strok")
check("an unknown hue is refused", not unknown)
local crowd = {}
for i = 1, 40 do crowd[i] = "ember" end
local seated = pcall(palette.build, crowd)
check("forty hues cannot be seated", not seated)
local empty = pcall(palette.build, {})
check("a score with no hues is refused", not empty)

print(string.format("palette: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
