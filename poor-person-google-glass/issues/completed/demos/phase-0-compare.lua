-- phase-0-compare.lua - the numbers half of the phase 0 demo.
--
-- In plain terms: reads each test-shape file the demo wrote (the same crown
-- in four formats), times the reading, and prints one row per file: how big
-- it is on disk, how many parts and triangles came back, how tall it stands,
-- and whether every corner came back where it was made, to within the
-- rounding of the file's numbers. Prints, writes nothing.
--
-- Usage: luajit phase-0-compare.lua <project-dir>

local DIR = "/mnt/mtwo/programming/ai-stuff/poor-person-google-glass"
if arg[1] ~= nil then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path

local shapes = require("002-the-test-shapes")
local any_file = require("006-read-any-cad-file")
local camera_math = require("009-the-orbit-camera")

local SHAPES = DIR .. "/tmp/shared-memory/shapes/"
local original = shapes.crown()

-- {{{ local function all_corners()
-- Every corner of a shape, stood upright the way the viewer stands it, as
-- one flat list (part boundaries dropped: binary STL has none).
local function all_corners(shape)
    local m = camera_math.upright(shape.up_axis)
    local out = {}
    for _, part in ipairs(shape.parts) do
        local p = part.positions
        for k = 1, #p, 3 do
            local x, y, z = camera_math.transform(m, { p[k], p[k + 1], p[k + 2] })
            -- three separate slots: "out[#out+1], out[#out+1] = ..." would
            -- measure #out once and write every value into the same slot
            local n = #out
            out[n + 1], out[n + 2], out[n + 3] = x, y, z
        end
    end
    return out
end
-- }}}

-- {{{ local function largest_shift()
-- The farthest any corner moved between two lists, in millimetres.
local function largest_shift(a, b)
    if #a ~= #b then return math.huge end
    local largest = 0
    for k = 1, #a do largest = math.max(largest, math.abs(a[k] - b[k])) end
    return largest
end
-- }}}

local made = all_corners(original)
print(string.format("the crown sketch, made by formula: %d parts, %d triangles", #original.parts, original.triangle_count))
print("")
print(string.format("%-26s %-5s %10s %6s %10s %9s %9s %14s", "file", "kind", "bytes", "parts", "triangles", "read ms", "tall mm", "largest shift"))
for _, name in ipairs({ "crown-sketch.gltf", "crown-sketch.obj", "crown-sketch-text.stl", "crown-sketch-binary.stl" }) do
    local shape, seconds = any_file.read(SHAPES .. name)
    local back = all_corners(shape)
    local tall = 0
    do
        local low, high = math.huge, -math.huge
        for k = 2, #back, 3 do low, high = math.min(low, back[k]), math.max(high, back[k]) end
        tall = high - low
    end
    print(string.format("%-26s %-5s %10d %6d %10d %9.2f %9.2f %11.2g mm",
        name, shape.source_format, shape.bytes_on_disk, #shape.parts, shape.triangle_count,
        seconds * 1000, tall, largest_shift(made, back)))
end
