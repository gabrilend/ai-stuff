--[[
TGA Images (Issue 522a)

Truevision TGA as WC3 uses it (map previews, some interface art and
imported textures): true-colour 24/32-bit and greyscale 8-bit,
uncompressed (types 2, 3) or run-length encoded (10, 11), either origin.

    local tga = require("parsers.tga")
    local img = tga.decode(bytes)    -- width, height, rgba (string, top row first)
]]

local ffi = require("ffi")
local bit = require("bit")

local tga = {}

function tga.decode(data)
    local id_len, cmap_type, kind = data:byte(1, 3)
    local cmap_len = data:byte(6) + data:byte(7) * 256
    local cmap_bits = data:byte(8)
    local w = data:byte(13) + data:byte(14) * 256
    local h = data:byte(15) + data:byte(16) * 256
    local bpp, desc = data:byte(17, 18)
    if kind ~= 2 and kind ~= 3 and kind ~= 10 and kind ~= 11 then
        error("TGA: image type " .. tostring(kind) .. " not supported")
    end
    if bpp ~= 8 and bpp ~= 24 and bpp ~= 32 then error("TGA: " .. tostring(bpp) .. " bits a pixel not supported") end
    local pos = 19 + id_len + (cmap_type == 1 and cmap_len * math.ceil(cmap_bits / 8) or 0)
    local px = bpp / 8
    local count = w * h
    local out = ffi.new("uint8_t[?]", count * 4)
    local top_first = bit.band(desc, 0x20) ~= 0

    local function put(i, p)
        local row = math.floor(i / w)
        local x = i % w
        local y = top_first and row or (h - 1 - row)
        local d = (y * w + x) * 4
        if px == 1 then
            local g = data:byte(p)
            out[d], out[d + 1], out[d + 2], out[d + 3] = g, g, g, 255
        else
            local b, g, r = data:byte(p, p + 2)
            out[d], out[d + 1], out[d + 2] = r, g, b
            out[d + 3] = px == 4 and data:byte(p + 3) or 255
        end
    end

    if kind == 2 or kind == 3 then
        for i = 0, count - 1 do put(i, pos + i * px) end
    else
        local i = 0
        while i < count do
            local head = data:byte(pos)
            pos = pos + 1
            local n = bit.band(head, 0x7F) + 1
            if head >= 128 then
                for k = 0, n - 1 do if i + k < count then put(i + k, pos) end end
                pos = pos + px
            else
                for k = 0, n - 1 do if i + k < count then put(i + k, pos + k * px) end end
                pos = pos + n * px
            end
            i = i + n
        end
    end
    return { width = w, height = h, rgba = ffi.string(out, count * 4) }
end

return tga
