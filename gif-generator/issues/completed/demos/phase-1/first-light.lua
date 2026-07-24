-- first-light.lua — the phase-1 demo: a single glowing dot orbits on
-- black, proving canvas → tone-map → palette → encoder end to end.
--
-- What this is, generally: the first gif this project ever draws. No
-- particle system exists yet, so the glow is moved by hand, frame by
-- frame — which is exactly the point: the demo proves the substrate
-- the particles will later land on. It prints measured numbers, not
-- descriptions.

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local canvas = require("000-canvas")
local palette = require("002-palette")
local gif = require("004-gif")

-- the shape of the piece: 4 seconds at 25 fps on a 256 canvas
local SIZE = 256
local FPS = 25
local SECONDS = 4.0
local FRAMES = math.floor(SECONDS * FPS)

-- {{{ local function splat_glow()
-- A hand-held radial glow: energy falls off as a squared bell from
-- the (fractional) center. The phase-2 splatter will do this for
-- thousands of particles; here one is enough to light the house.
local function splat_glow(cv, cx, cy, radius, er, eg, eb)
    local x0 = math.max(0, math.floor(cx - radius))
    local x1 = math.min(cv.width - 1, math.ceil(cx + radius))
    local y0 = math.max(0, math.floor(cy - radius))
    local y1 = math.min(cv.height - 1, math.ceil(cy + radius))
    local r2 = radius * radius
    for y = y0, y1 do
        for x = x0, x1 do
            local dx, dy = x - cx, y - cy
            local d2 = dx * dx + dy * dy
            if d2 < r2 then
                local w = 1 - d2 / r2
                w = w * w
                canvas.add(cv, x, y, er * w, eg * w, eb * w)
            end
        end
    end
end
-- }}}

local pal = palette.build({ "ember" })
local er, eg, eb = palette.hue_color("ember")
local cv = canvas.new(SIZE, SIZE)

local frames = {}
local seen = {}   -- which palette seats actually get used

for f = 0, FRAMES - 1 do
    local t = f / FRAMES
    canvas.clear(cv)
    -- one full orbit; the pulse keeps the eye honest about additive
    -- light (the core brightens without ever clipping)
    local angle = t * 2 * math.pi - math.pi / 2
    local cx = SIZE / 2 + math.cos(angle) * 80
    local cy = SIZE / 2 + math.sin(angle) * 80
    local pulse = 2.0 + 1.5 * math.sin(t * 4 * math.pi)
    splat_glow(cv, cx, cy, 7, er * pulse, eg * pulse, eb * pulse)

    local mapped = canvas.tonemap(cv)
    local frame = ffi.new("uint8_t[?]", SIZE * SIZE)
    for p = 0, SIZE * SIZE - 1 do
        local i = p * 3
        local idx = palette.index_of(pal, mapped[i], mapped[i + 1],
                                     mapped[i + 2])
        frame[p] = idx
        seen[idx] = true
    end
    frames[#frames + 1] = frame
end

local spec = {
    width = SIZE, height = SIZE, palette_bytes = pal.bytes,
    frames = frames, delay_cs = math.floor(100 / FPS),
}
local here = DIR .. "/issues/completed/demos/phase-1/first-light.gif"
local out = DIR .. "/output/first-light.gif"
local bytes = gif.write(here, spec)
gif.write(out, spec)

local occupancy = 0
for _ in pairs(seen) do occupancy = occupancy + 1 end

print("first light:")
print("  frames:            " .. #frames)
print("  bytes:             " .. bytes)
print("  bytes per frame:   " .. math.floor(bytes / #frames))
print("  palette seats lit: " .. occupancy .. " of 256")
print("  written to:        " .. here)
print("  and to:            " .. out)
