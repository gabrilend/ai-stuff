--[[
loadscreen.lua - a converted map's loading screen picture, as a BLP2 (issue W02c)

The client shows a map's loading screen (LoadingScreens.dbc's FileName)
while the map loads. A converted map's picture is made from the map
itself, so nothing of Blizzard's is used:

  1. war3mapPreview.tga, the picture WC3 shows for the map in its lists,
     when the map holds one;
  2. otherwise its ground, drawn from above: each tile point in its WC3
     ground's colour (the ground table's rgb), water blue, lit from the
     north-west by the slope.

Written as a BLP2 of 512 x 512 with every smaller copy down to 1 x 1,
encoding 3 (plain BGRA, 4 bytes a pixel, no compression), alpha 8 bits.
The W client's reader (017-blp.c) decodes that encoding; whether the stock
3.3.5a client shows encoding 3 is unchecked (its own loading screens are
DXT, from memory). The picture is square and the screen isn't, so it is
stretched across it.

    local loadscreen = require("wowbuild.loadscreen")
    local img, source = loadscreen.picture(map, job)     -- { width, height, rgba }, "preview" | "ground"
    local bytes = loadscreen.blp2(img)                   -- 512 x 512 and its smaller copies
]]

local ffi = require("ffi")
local bw = require("parsers.binwrite")

local loadscreen = {}

loadscreen.SIZE = 512
loadscreen.PREVIEW = "war3mapPreview.tga"

-- {{{ the ground drawn from above
local function from_ground(job)
    local L = job.layout
    local W, H, cols = L.W, L.H, job.cols
    local n = W * H
    local px = ffi.new("uint8_t[?]", n * 4)
    local function h(r, c)
        r = math.max(0, math.min(H - 1, r)); c = math.max(0, math.min(W - 1, c))
        return job.gh[r * cols + c]
    end
    for r = 0, H - 1 do                     -- row 0 is the map's north edge
        for c = 0, W - 1 do
            local at = r * cols + c
            local key = job.keys[job.gkey[at]]
            local rgb = key and key.rgb or { 128, 128, 128 }
            local light = 1 + ((h(r, c) - h(r - 1, c - 1)) / 4.1667) * 0.35
            light = math.max(0.55, math.min(1.35, light))
            local R, G, B = rgb[1] * light, rgb[2] * light, rgb[3] * light
            if job.gflag[at] >= 2 then R, G, B = R * 0.3 + 30, G * 0.3 + 70, B * 0.3 + 140 end
            local d = (r * W + c) * 4
            px[d] = math.max(0, math.min(255, math.floor(R + 0.5)))
            px[d + 1] = math.max(0, math.min(255, math.floor(G + 0.5)))
            px[d + 2] = math.max(0, math.min(255, math.floor(B + 0.5)))
            px[d + 3] = 255
        end
    end
    return { width = W, height = H, rgba = ffi.string(px, n * 4) }
end
-- }}}

-- {{{ loadscreen.picture
-- map: wowbuild.read_map's (read_file may be nil); job: wowbuild.terrain's
function loadscreen.picture(map, job)
    if map and map.has_file and map.read_file and map.has_file(loadscreen.PREVIEW) then
        local ok, img = pcall(function() return require("parsers.tga").decode(map.read_file(loadscreen.PREVIEW)) end)
        if ok and img and img.width > 0 and img.height > 0 then return img, "preview" end
    end
    return from_ground(job), "ground"
end
-- }}}

-- {{{ resample: a picture to size x size (box average when shrinking, nearest when growing)
local function resample(img, size)
    local src, sw, sh = img.rgba, img.width, img.height
    local s = ffi.new("const uint8_t *", src)
    local out = ffi.new("uint8_t[?]", size * size * 4)
    for y = 0, size - 1 do
        local y0 = math.floor(y * sh / size)
        local y1 = math.max(y0 + 1, math.floor((y + 1) * sh / size))
        for x = 0, size - 1 do
            local x0 = math.floor(x * sw / size)
            local x1 = math.max(x0 + 1, math.floor((x + 1) * sw / size))
            local acc0, acc1, acc2, acc3, n = 0, 0, 0, 0, 0
            for yy = y0, y1 - 1 do
                for xx = x0, x1 - 1 do
                    local d = (yy * sw + xx) * 4
                    acc0, acc1, acc2, acc3 = acc0 + s[d], acc1 + s[d + 1], acc2 + s[d + 2], acc3 + s[d + 3]
                    n = n + 1
                end
            end
            local o = (y * size + x) * 4
            out[o], out[o + 1], out[o + 2], out[o + 3] =
                math.floor(acc0 / n + 0.5), math.floor(acc1 / n + 0.5), math.floor(acc2 / n + 0.5), math.floor(acc3 / n + 0.5)
        end
    end
    return { width = size, height = size, rgba = ffi.string(out, size * size * 4) }
end
loadscreen.resample = resample
-- }}}

-- {{{ loadscreen.blp2
-- img: { width, height, rgba }; written at loadscreen.SIZE (or size) square
function loadscreen.blp2(img, size)
    size = size or loadscreen.SIZE
    local levels = {}
    local cur = resample(img, size)
    local n = size
    while true do
        -- RGBA -> BGRA
        local p = ffi.new("uint8_t[?]", n * n * 4)
        ffi.copy(p, cur.rgba, n * n * 4)
        for i = 0, n * n - 1 do p[i * 4], p[i * 4 + 2] = p[i * 4 + 2], p[i * 4] end
        levels[#levels + 1] = ffi.string(p, n * n * 4)
        if n == 1 or #levels == 16 then break end
        n = n / 2
        cur = resample(cur, n)
    end
    local B = bw.new():str("BLP2"):u32(1)          -- type 1: not JPEG
    B:u8(3):u8(8):u8(0):u8(1)                     -- encoding 3 (BGRA), 8 alpha bits, alpha kind 0, has smaller copies
    B:u32(size):u32(size)
    local at = 148 + 1024
    local offsets, sizes = {}, {}
    for i = 1, 16 do
        if levels[i] then offsets[i], sizes[i] = at, #levels[i]; at = at + #levels[i]
        else offsets[i], sizes[i] = 0, 0 end
    end
    for i = 1, 16 do B:u32(offsets[i]) end
    for i = 1, 16 do B:u32(sizes[i]) end
    B:str(string.rep("\0", 1024))                 -- the palette, unused by encoding 3
    return B:done() .. table.concat(levels), #levels
end
-- }}}

return loadscreen
