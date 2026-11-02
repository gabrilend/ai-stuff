--[[
BLP1 Textures (Issues 522a, 117)

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
    local all = blp.decode_all(bytes)      -- every mipmap the file holds
    -- all.width, all.height, all.source_format ("jpeg" or "palette"),
    -- all.levels[1..n] = { width, height, rgba }

A file that is cut short, or whose header points past its end, fails with
an error naming the part (header, palette, JPEG header, or the mipmap by
number) and its byte offset; nothing is read past the file (issue 117).

BLP2 (World of Warcraft's, DXT-compressed) is not read here: the WoW
bridge (Phase W) will want it, WC3 never uses it.
]]

local ffi = require("ffi")
local bit = require("bit")
local jpeg = require("parsers.jpeg")

local blp = {}

-- A side longer than this means a damaged header, not a texture: refusing
-- it stops a wrong size from asking for gigabytes of pixels
blp.MAX_SIDE = 16384

local HEADER = 156        -- bytes before the JPEG header size or the palette
local PALETTE = 1024      -- 256 colours, B G R A

local function u32(s, pos)
    local a, b, c, d = s:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

-- {{{ need
-- Raises unless bytes [offset, offset + count) lie inside the data
local function need(data, offset, count, what)
    if offset + count > #data then
        error(string.format("BLP: %s at byte %d needs %d bytes, but the file ends at byte %d",
            what, offset, count, #data), 0)
    end
end
-- }}}

-- {{{ blp.header
function blp.header(data)
    local magic = data:sub(1, 4)
    if magic == "BLP2" then error("BLP2 (World of Warcraft) isn't read here") end
    if magic ~= "BLP1" then error("not a BLP1 texture") end
    need(data, 0, HEADER, "the header")
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
    if h.width > blp.MAX_SIDE or h.height > blp.MAX_SIDE then
        error(string.format("BLP: %d x %d is larger than %d on a side; the header is damaged",
            h.width, h.height, blp.MAX_SIDE), 0)
    end
    if h.compression == 0 then
        need(data, HEADER, 4, "the JPEG header's size")
        h.jpeg_header_size = u32(data, HEADER + 1)
        need(data, HEADER + 4, h.jpeg_header_size, "the JPEG header")
    elseif h.compression == 1 then
        need(data, HEADER, PALETTE, "the palette")
    end
    return h
end
-- }}}

-- {{{ blp.decode
-- level: mipmap number (0 = full size)
function blp.decode(data, level)
    level = level or 0
    local h = blp.header(data)
    if level ~= math.floor(level) or level < 0 or level > 15 then error("BLP: no mipmap " .. tostring(level), 0) end
    local w = math.max(1, bit.rshift(h.width, level))
    local ht = math.max(1, bit.rshift(h.height, level))
    local off, size = h.offsets[level], h.sizes[level]
    if off == 0 or size == 0 then error("BLP: no mipmap " .. level, 0) end
    local what = string.format("mipmap %d (%d x %d)", level, w, ht)
    need(data, off, size, what)
    local count = w * ht

    if h.compression == 0 then
        -- the shared JPEG header, then this mipmap's own part
        local header = data:sub(HEADER + 5, HEADER + 4 + h.jpeg_header_size)
        local ok, img = pcall(jpeg.decode, header .. data:sub(off + 1, off + size))
        if not ok then
            -- (the JPEG reader's message, without its source file and line)
            local why = tostring(img):gsub("^[^:]*:%d+: ", "")
            error(string.format("BLP: %s, JPEG at byte %d: %s", what, off, why), 0)
        end
        if img.components ~= 4 and img.components ~= 3 then
            error(string.format("BLP: %s, JPEG at byte %d has %d components", what, off, img.components), 0)
        end
        local out = ffi.new("uint8_t[?]", count * 4)
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
        return { width = w, height = ht, rgba = ffi.string(out, count * 4),
                 alpha_bits = h.alpha_bits, compression = "jpeg" }
    elseif h.compression == 1 then
        local pal = HEADER + 1     -- palette: 256 x BGRA, 1-based position in data
        local base = off + 1       -- indices, then alpha
        local ab = h.alpha_bits
        local alpha_bytes = ({ [0] = 0, [1] = math.ceil(count / 8), [4] = math.ceil(count / 2), [8] = count })[ab]
        if not alpha_bytes then
            error(string.format("BLP: alpha depth %d isn't one of 0, 1, 4 or 8", ab), 0)
        end
        need(data, off, count + alpha_bytes, what .. "'s indices and alpha")
        local out = ffi.new("uint8_t[?]", count * 4)
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
        return { width = w, height = ht, rgba = ffi.string(out, count * 4),
                 alpha_bits = h.alpha_bits, compression = "paletted" }
    end
    error("BLP: unknown compression " .. tostring(h.compression), 0)
end
-- }}}

-- {{{ blp.decode_all
-- Every mipmap the file holds, largest first, down to the first level
-- with no data (or 1 x 1, or the sixteenth): the shape issue 117 asked for
function blp.decode_all(data)
    local h = blp.header(data)
    local all = { width = h.width, height = h.height, alpha_bits = h.alpha_bits,
                  source_format = h.compression == 0 and "jpeg" or "palette", levels = {} }
    for level = 0, 15 do
        if h.offsets[level] == 0 or h.sizes[level] == 0 then break end
        if level > 0 and h.has_mipmaps == 0 then break end
        local img = blp.decode(data, level)
        all.levels[#all.levels + 1] = { width = img.width, height = img.height, rgba = img.rgba }
        if img.width == 1 and img.height == 1 then break end
    end
    return all
end
-- }}}

return blp
