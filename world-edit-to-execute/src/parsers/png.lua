--[[
PNG Images (Issue 522g)

PNG to RGBA, for textures that come as PNG: inside glTF models, in asset
packs, back from ComfyUI. Every colour type (grey, grey+alpha, RGB, RGBA,
palette with tRNS transparency), 1-16 bits a sample (16 rounded to 8),
the five row filters. Interlaced (Adam7) PNGs are refused with a
message.

Decompression is the monorepo's own inflate, in the
kanji-learning-image-generator project (src/017a-read-a-picture.lua),
which reads what any PNG writer produces.

    local png = require("parsers.png")
    local img = png.decode(bytes)    -- width, height, rgba (string, top row first)
]]

local ffi = require("ffi")

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local KANJI = HERE .. "/../../../kanji-learning-image-generator/src/017a-read-a-picture.lua"

local png = {}

local inflate
local function get_inflate()
    if not inflate then
        local ok, m = pcall(dofile, KANJI)
        if not ok then error("PNG: the monorepo's inflate isn't at " .. KANJI .. " (" .. tostring(m) .. ")") end
        inflate = m.inflate
    end
    return inflate
end

local function u32be(s, p)
    local a, b, c, d = s:byte(p, p + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
end

-- {{{ png.decode
function png.decode(data)
    if data:sub(1, 8) ~= "\137PNG\13\10\26\10" then error("not a PNG") end
    local pos = 9
    local w, h, depth, colour, interlace
    local idat, palette, trns = {}, nil, nil
    while pos <= #data do
        local len = u32be(data, pos)
        local kind = data:sub(pos + 4, pos + 7)
        local body = data:sub(pos + 8, pos + 7 + len)
        if kind == "IHDR" then
            w, h = u32be(body, 1), u32be(body, 5)
            depth, colour, interlace = body:byte(9), body:byte(10), body:byte(13)
        elseif kind == "PLTE" then palette = body
        elseif kind == "tRNS" then trns = body
        elseif kind == "IDAT" then idat[#idat + 1] = body
        elseif kind == "IEND" then break end
        pos = pos + 12 + len
    end
    if not w then error("PNG: no header") end
    if interlace ~= 0 then error("PNG: interlaced pictures aren't read") end
    local channels = ({ [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 })[colour]
    if not channels then error("PNG: colour type " .. tostring(colour)) end
    if depth ~= 8 and depth ~= 16 and not (colour == 3 and depth <= 8) and not (colour == 0 and depth < 8) then
        error("PNG: " .. depth .. "-bit samples in colour type " .. colour)
    end

    local raw = get_inflate()(table.concat(idat))
    if type(raw) == "table" then
        -- the kanji inflate returns a list of byte values
        local b = ffi.new("uint8_t[?]", #raw)
        for i = 1, #raw do b[i - 1] = raw[i] end
        raw = ffi.string(b, #raw)
    end

    -- bytes per pixel (for filtering) and per row
    local bits = channels * depth
    local bpp = math.max(1, math.floor(bits / 8))
    local stride = math.ceil(w * bits / 8)
    local cur = ffi.new("uint8_t[?]", stride)
    local prev = ffi.new("uint8_t[?]", stride)
    local out = ffi.new("uint8_t[?]", w * h * 4)
    local p = 1
    for y = 0, h - 1 do
        local filter = raw:byte(p)
        p = p + 1
        for i = 0, stride - 1 do
            local x = raw:byte(p + i) or 0
            local a = i >= bpp and cur[i - bpp] or 0
            local b = prev[i]
            local c = i >= bpp and prev[i - bpp] or 0
            if filter == 1 then x = x + a
            elseif filter == 2 then x = x + b
            elseif filter == 3 then x = x + math.floor((a + b) / 2)
            elseif filter == 4 then
                local pa, pb, pc = math.abs(b - c), math.abs(a - c), math.abs(a + b - 2 * c)
                if pa <= pb and pa <= pc then x = x + a elseif pb <= pc then x = x + b else x = x + c end
            end
            cur[i] = x % 256
        end
        p = p + stride
        -- to RGBA
        for x = 0, w - 1 do
            local o = (y * w + x) * 4
            local r, g, bl, al
            if depth < 8 then
                local bitpos = x * depth
                local byte = cur[math.floor(bitpos / 8)]
                local shift = 8 - depth - bitpos % 8
                local v = math.floor(byte / 2 ^ shift) % (2 ^ depth)
                if colour == 3 then
                    r, g, bl = palette:byte(v * 3 + 1, v * 3 + 3)
                    al = trns and trns:byte(v + 1) or 255
                else
                    local gv = math.floor(v * 255 / (2 ^ depth - 1))
                    r, g, bl, al = gv, gv, gv, 255
                end
            else
                local step = depth == 16 and 2 or 1
                local s = x * channels * step
                local function sample(k)
                    if step == 1 then return cur[s + k] end
                    -- 16 bits to 8, rounded (decoders differ by one here:
                    -- ImageMagick 6 truncates colour and rounds alpha)
                    local v = cur[s + k * 2] * 256 + cur[s + k * 2 + 1]
                    return math.floor((v * 255 + 32767) / 65535)
                end
                if colour == 0 then local v = sample(0) r, g, bl, al = v, v, v, 255
                elseif colour == 4 then local v = sample(0) r, g, bl, al = v, v, v, sample(1)
                elseif colour == 2 then r, g, bl, al = sample(0), sample(1), sample(2), 255
                elseif colour == 6 then r, g, bl, al = sample(0), sample(1), sample(2), sample(3)
                else
                    local v = sample(0)
                    r, g, bl = palette:byte(v * 3 + 1, v * 3 + 3)
                    al = trns and trns:byte(v + 1) or 255
                end
            end
            out[o], out[o + 1], out[o + 2], out[o + 3] = r or 0, g or 0, bl or 0, al or 255
        end
        cur, prev = prev, cur
    end
    return { width = w, height = h, rgba = ffi.string(out, w * h * 4) }
end
-- }}}

return png
