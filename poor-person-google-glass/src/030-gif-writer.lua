-- 030-gif-writer.lua - moving pictures as GIF files, written from scratch.
--
-- In plain terms: a GIF is a file format frozen since 1989: a short header,
-- one table of up to 256 colours, then each frame as a list of colour
-- numbers squeezed by LZW compression (repeated runs of numbers become
-- single codes). This file chooses the colour table from the frames
-- themselves (median cut: split the colours seen into 256 boxes of similar
-- colours, one colour per box), turns each frame's pixels into colour
-- numbers, compresses them, and writes the file. Written here rather than
-- borrowed, so a fault in it is a fault in code this project can read; the
-- tests decode its files with a decoder written separately.
--
-- Frames are ffi byte arrays of RGBA pixels (4 bytes each), width x height.
-- A frame's colour numbers are an ffi uint8 array, one per pixel.

local ffi = require("ffi")
local bit = require("bit")

local M = {}

-- {{{ function M.palette()
-- Up to `limit` (at most 256) colours that stand for every pixel of the
-- frames, chosen by median cut over a sample (every `step`-th pixel).
-- Returns a list of { r, g, b } (whole numbers 0..255).
function M.palette(frames, width, height, limit, step)
    limit = math.min(limit or 256, 256)
    step = step or 7
    -- the sample, counted by colour so repeated colours weigh more
    local counts, colours = {}, {}
    for _, frame in ipairs(frames) do
        for p = 0, width * height - 1, step do
            local r, g, b = frame[p * 4], frame[p * 4 + 1], frame[p * 4 + 2]
            local key = r * 65536 + g * 256 + b
            if counts[key] == nil then colours[#colours + 1] = key; counts[key] = 0 end
            counts[key] = counts[key] + 1
        end
    end
    table.sort(colours)
    -- {{{ median cut
    -- A box is a list of colour keys; the box with the widest channel spread
    -- (weighted by how many pixels it holds) is split at that channel's
    -- weighted median, until there are `limit` boxes or none can split.
    local function channel(key, c) return bit.band(bit.rshift(key, 16 - 8 * c), 255) end
    local function spread(box)
        local best_channel, best_range = 0, -1
        for c = 0, 2 do
            local lo, hi = 255, 0
            for _, key in ipairs(box) do
                local v = channel(key, c)
                if v < lo then lo = v end
                if v > hi then hi = v end
            end
            if hi - lo > best_range then best_channel, best_range = c, hi - lo end
        end
        return best_channel, best_range
    end
    local boxes = { colours }
    while #boxes < limit do
        local pick, pick_score, pick_channel = nil, 0, 0
        for index, box in ipairs(boxes) do
            if #box > 1 then
                local c, range = spread(box)
                local weight = 0
                for _, key in ipairs(box) do weight = weight + counts[key] end
                local score = range * math.sqrt(weight)
                if score > pick_score then pick, pick_score, pick_channel = index, score, c end
            end
        end
        if pick == nil then break end
        local box = boxes[pick]
        table.sort(box, function(a, b)
            local va, vb = channel(a, pick_channel), channel(b, pick_channel)
            if va ~= vb then return va < vb end
            return a < b
        end)
        local total, half, cut = 0, 0, 1
        for _, key in ipairs(box) do total = total + counts[key] end
        for i, key in ipairs(box) do
            half = half + counts[key]
            if half * 2 >= total then cut = i; break end
        end
        cut = math.max(1, math.min(#box - 1, cut))
        local left, right = {}, {}
        for i, key in ipairs(box) do
            if i <= cut then left[#left + 1] = key else right[#right + 1] = key end
        end
        boxes[pick] = left
        boxes[#boxes + 1] = right
    end
    -- }}}
    local palette = {}
    for _, box in ipairs(boxes) do
        local r, g, b, n = 0, 0, 0, 0
        for _, key in ipairs(box) do
            local w = counts[key]
            r, g, b, n = r + channel(key, 0) * w, g + channel(key, 1) * w, b + channel(key, 2) * w, n + w
        end
        palette[#palette + 1] = { math.floor(r / n + 0.5), math.floor(g / n + 0.5), math.floor(b / n + 0.5) }
    end
    return palette
end
-- }}}

-- {{{ function M.mapper()
-- A function from a frame to its colour numbers: each pixel to the nearest
-- palette colour (remembered per colour, as a frame repeats colours often).
function M.mapper(palette)
    local nearest = {}
    return function(frame, width, height)
        local out = ffi.new("uint8_t[?]", width * height)
        for p = 0, width * height - 1 do
            local r, g, b = frame[p * 4], frame[p * 4 + 1], frame[p * 4 + 2]
            local key = r * 65536 + g * 256 + b
            local index = nearest[key]
            if index == nil then
                local best = math.huge
                for i, c in ipairs(palette) do
                    local d = (c[1] - r) ^ 2 + (c[2] - g) ^ 2 + (c[3] - b) ^ 2
                    if d < best then best, index = d, i - 1 end
                end
                nearest[key] = index
            end
            out[p] = index
        end
        return out
    end
end
-- }}}

-- {{{ function M.lzw()
-- One frame's colour numbers compressed as GIF's LZW asks: codes start 9
-- bits wide (8-bit colours), grow as the table fills, the table is
-- cleared when it reaches 4096 codes; codes are packed lowest bit first and
-- cut into sub-blocks of at most 255 bytes. Returns the bytes (a string),
-- starting with the minimum code size and ending with the empty block.
function M.lzw(indices, count)
    local CLEAR, STOP = 256, 257
    local out, out_length = ffi.new("uint8_t[?]", count * 2 + 1024), 0
    local accumulator, held = 0, 0
    local width = 9
    local function emit(code)
        accumulator = accumulator + code * 2 ^ held
        held = held + width
        while held >= 8 do
            out[out_length] = accumulator % 256
            out_length = out_length + 1
            accumulator = math.floor(accumulator / 256)
            held = held - 8
        end
    end
    local table_of_codes, next_code = {}, 258
    emit(CLEAR)
    local prefix = indices[0]
    for p = 1, count - 1 do
        local k = indices[p]
        local key = prefix * 256 + k
        local code = table_of_codes[key]
        if code then
            prefix = code
        else
            emit(prefix)
            -- the table grows one entry per emitted code; the width grows
            -- when the next code would not fit, until 12 bits
            if next_code < 4096 then
                table_of_codes[key] = next_code
                next_code = next_code + 1
                if next_code > 2 ^ width and width < 12 then width = width + 1 end
            else
                emit(CLEAR)
                table_of_codes, next_code, width = {}, 258, 9
            end
            prefix = k
        end
    end
    emit(prefix)
    emit(STOP)
    if held > 0 then out[out_length] = accumulator % 256; out_length = out_length + 1 end
    -- sub-blocks
    local pieces = { string.char(8) }
    local data = ffi.string(out, out_length)
    for start = 1, #data, 255 do
        local piece = data:sub(start, start + 254)
        pieces[#pieces + 1] = string.char(#piece) .. piece
    end
    pieces[#pieces + 1] = string.char(0)
    return table.concat(pieces)
end
-- }}}

-- {{{ local function word()
local function word(n) return string.char(n % 256, math.floor(n / 256) % 256) end
-- }}}

-- {{{ function M.header()
-- The file's start: signature, picture size, the colour table (padded to
-- 256), and the looping extension (loop forever).
function M.header(width, height, palette)
    local parts = { "GIF89a", word(width), word(height), string.char(0xF7, 0, 0) }
    for i = 1, 256 do
        local c = palette[i] or { 0, 0, 0 }
        parts[#parts + 1] = string.char(c[1], c[2], c[3])
    end
    parts[#parts + 1] = "\33\255\11NETSCAPE2.0\3\1" .. word(0) .. "\0"
    return table.concat(parts)
end
-- }}}

-- {{{ function M.frame_block()
-- One frame: its delay (hundredths of a second) and its compressed colours.
function M.frame_block(width, height, compressed, delay)
    return "\33\249\4\0" .. word(delay) .. "\0\0" .. "\44" .. word(0) .. word(0) .. word(width) .. word(height) .. "\0" .. compressed
end
-- }}}

-- {{{ function M.trailer()
function M.trailer() return ";" end
-- }}}

return M
