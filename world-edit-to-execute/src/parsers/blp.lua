--[[
BLP1 Textures (Issue 522a)

Warcraft III's texture format. The header, then up to sixteen mipmaps,
each one of:

  JPEG (compression 0)  a shared JPEG header, then per mipmap the rest of a
                        JPEG whose four components are B, G, R, A as they
                        are (parsers/jpeg.lua leaves them unconverted)
  paletted (1)          a 256-colour BGRA palette, one index byte per
                        pixel, then alpha at 0, 1, 4 or 8 bits a pixel

Layout (all little-endian 32-bit):
  "BLP1", compression, alpha bits, width, height, picture type,
  has mipmaps, 16 mipmap offsets, 16 mipmap sizes;
  JPEG:     header size, header bytes
  paletted: 256 x BGRA

    local blp = require("parsers.blp")
    local img = blp.decode(bytes)          -- the full-size image
    local small = blp.decode(bytes, 2)     -- mipmap 2 (a quarter across)
    -- img.width, img.height, img.rgba (a Lua string, 4 bytes a pixel)

BLP2 (World of Warcraft's, DXT-compressed) is not read here: the WoW
bridge (Phase W) will want it, WC3 never uses it.
]]

local ffi = require("ffi")
local bit = require("bit")
local jpeg = require("parsers.jpeg")

local blp = {}

local function u32(s, pos)
    local a, b, c, d = s:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

-- {{{ blp.header
function blp.header(data)
    local magic = data:sub(1, 4)
    if magic == "BLP2" then error("BLP2 (World of Warcraft) isn't read here") end
    if magic ~= "BLP1" then error("not a BLP1 texture") end
    local h = {
        compression = u32(data, 5), alpha_bits = u32(data, 9),
        width = u32(data, 13), height = u32(data, 17),
        picture_type = u32(data, 21), has_mipmaps = u32(data, 25),
        offsets = {}, sizes = {},
    }
    for i = 0, 15 do
        h.offsets[i] = u32(data, 29 + i * 4)
        h.sizes[i] = u32(data, 93 + i * 4)
    end
    return h
end
-- }}}

-- {{{ blp.decode
-- level: mipmap number (0 = full size)
function blp.decode(data, level)
    level = level or 0
    local h = blp.header(data)
    local w = math.max(1, bit.rshift(h.width, level))
    local ht = math.max(1, bit.rshift(h.height, level))
    local off, size = h.offsets[level], h.sizes[level]
    if not off or off == 0 or size == 0 then error("BLP: no mipmap " .. level) end
    local out = ffi.new("uint8_t[?]", w * ht * 4)

    if h.compression == 0 then
        -- the shared JPEG header, then this mipmap's own part
        local header_size = u32(data, 157)
        local header = data:sub(161, 160 + header_size)
        local img = jpeg.decode(header .. data:sub(off + 1, off + size))
        if img.components ~= 4 and img.components ~= 3 then
            error("BLP: JPEG with " .. img.components .. " components")
        end
        local iw, ih = math.min(w, img.width), math.min(ht, img.height)
        local src, nc = img.pixels, img.components
        for y = 0, ih - 1 do
            for x = 0, iw - 1 do
                local s, d = (y * img.width + x) * nc, (y * w + x) * 4
                -- stored B, G, R, A
                out[d], out[d + 1], out[d + 2] = src[s + 2], src[s + 1], src[s]
                out[d + 3] = (nc == 4 and h.alpha_bits > 0) and src[s + 3] or 255
            end
        end
    elseif h.compression == 1 then
        local pal = 157            -- palette: 256 x BGRA, 1-based position in data
        local base = off + 1       -- indices, then alpha
        local count = w * ht
        local ab = h.alpha_bits
        for i = 0, count - 1 do
            local idx = data:byte(base + i)
            local p = pal + idx * 4
            local b, g, r = data:byte(p, p + 2)
            local d = i * 4
            out[d], out[d + 1], out[d + 2] = r, g, b
            local a = 255
            if ab == 8 then
                a = data:byte(base + count + i)
            elseif ab == 4 then
                local byte = data:byte(base + count + bit.rshift(i, 1))
                local nib = (i % 2 == 0) and bit.band(byte, 15) or bit.rshift(byte, 4)
                a = nib * 17
            elseif ab == 1 then
                local byte = data:byte(base + count + bit.rshift(i, 3))
                a = bit.band(bit.rshift(byte, i % 8), 1) == 1 and 255 or 0
            end
            out[d + 3] = a
        end
    else
        error("BLP: unknown compression " .. tostring(h.compression))
    end
    return { width = w, height = ht, rgba = ffi.string(out, w * ht * 4),
             alpha_bits = h.alpha_bits, compression = h.compression == 0 and "jpeg" or "paletted" }
end
-- }}}

return blp
