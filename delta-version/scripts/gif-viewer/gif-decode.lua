-- gif-decode.lua - Turns a gif file into its frames, as plain pictures.
--
-- In general terms: a gif is a stack of small pictures, each squeezed with
-- a compression scheme (LZW) and drawn on top of the one before. This reads
-- the stack back out, undoes the squeezing, and hands over each frame as a
-- complete full-colour picture ready to show -- the same pictures a browser
-- would show, one after another.
--
-- Plain LuaJIT with ffi; it needs no LÖVE, so it can be tested on its own.
-- The viewer's worker threads call it; nothing here draws to a screen.
--
-- It is written for any gif, not only the shape renderer's (which writes the
-- simplest kind: one palette, full-size frames, no transparency), so that
-- anything dropped into the folder plays:
--   * a frame may bring its own palette (local colour table)
--   * a frame may cover only part of the screen (a sub-rectangle)
--   * a frame may leave some pixels see-through (transparency)
--   * a frame says what happens after it is shown (disposal):
--       0, 1 -- leave it in place for the next frame to draw over
--       2    -- clear its rectangle back to see-through
--       3    -- put back what was there before it was drawn
--   * a frame's rows may be stored out of order (interlacing)
--
-- Usage:
--   local gif = dofile(".../gif-decode.lua")
--   local info = gif.decode_file(path, {
--       max_size   = 128,   -- optional: shrink so neither side exceeds this
--       frame_step = 2,     -- optional: keep every 2nd frame, delays summed
--       on_frame   = function(index, pixels, width, height, delay_cs) end,
--   })
-- `pixels` is an ffi uint8_t array of width*height*4 bytes (R, G, B, A),
-- valid only during the call -- copy it to keep it. Without on_frame, the
-- frames are collected into info.frames as { pixels, delay_cs }.
-- Returns { width, height, frame_count }. A malformed file is an error that
-- names the byte where it went wrong.

local ffi = require("ffi")
local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local M = {}

-- Browsers treat a delay of 0 or 1 hundredths as "as fast as possible" and
-- slow it to 10 (a tenth of a second); matching them keeps the viewer's
-- timing the same as the web page's.
local MINIMUM_DELAY_CS = 2
local BROWSER_DELAY_CS = 10

-- {{{ local function reader()
-- A cursor over the file's bytes. Every read checks the end of the file, so
-- a truncated gif fails with the byte position rather than reading garbage.
local function reader(data)
    local self = { data = data, pos = 1 }
    function self.byte()
        local b = data:byte(self.pos)
        if not b then error("gif ends early, at byte " .. self.pos, 0) end
        self.pos = self.pos + 1
        return b
    end
    function self.u16()
        local lo = self.byte()
        return lo + 256 * self.byte()
    end
    function self.bytes(count)
        local text = data:sub(self.pos, self.pos + count - 1)
        if #text < count then error("gif ends early, at byte " .. self.pos, 0) end
        self.pos = self.pos + count
        return text
    end
    -- Data in a gif comes in sub-blocks: a length byte, that many bytes,
    -- repeated until a zero length. Returns them joined.
    function self.sub_blocks()
        local parts = {}
        while true do
            local length = self.byte()
            if length == 0 then break end
            parts[#parts + 1] = self.bytes(length)
        end
        return table.concat(parts)
    end
    return self
end
-- }}}

-- {{{ local function read_palette()
-- A colour table: `count` entries of three bytes, returned as an ffi array
-- of RGB bytes so the drawing loop can index it without Lua strings.
local function read_palette(input, count)
    local text = input.bytes(count * 3)
    local palette = ffi.new("uint8_t[?]", 256 * 3)
    ffi.copy(palette, text, count * 3)
    return palette
end
-- }}}

-- {{{ local function lzw_decode()
-- Undoes the compression. The dictionary is kept as two arrays -- each entry
-- is "an earlier entry, plus one more colour index" -- and a string is read
-- out backwards onto a stack, then copied forward. That keeps Lua strings out
-- of the inner loop entirely.
--
-- The one subtle case: a code may name the very entry the decoder is about
-- to create (the encoder is always one entry ahead). Its string must then be
-- the previous string plus that string's own first index.
--
-- Code width grows when the next free entry needs one more bit, up to 12
-- bits; a "clear" code resets the dictionary; "end" stops. Output beyond the
-- frame's pixel count is ignored, and a short stream leaves the remaining
-- pixels at index 0, as browsers do.
local prefix = ffi.new("uint16_t[4096]")
local suffix = ffi.new("uint8_t[4096]")
local stack = ffi.new("uint8_t[4097]")

local function lzw_decode(data, minimum_size, output, pixel_count)
    if minimum_size < 2 or minimum_size > 8 then
        error("gif frame has an impossible code size " .. minimum_size, 0)
    end
    local bytes = ffi.cast("const uint8_t *", data)
    local byte_count = #data
    local clear = lshift(1, minimum_size)
    local finish = clear + 1
    for i = 0, clear - 1 do prefix[i] = 0; suffix[i] = i end

    local code_size = minimum_size + 1
    local next_code = finish + 1
    local previous = -1
    local first = 0
    local written = 0

    -- bit_buffer never holds more than code_size + 7 < 20 bits
    local bit_buffer, bit_count, byte_index = 0, 0, 0
    while true do
        -- read one code, least significant bits first
        while bit_count < code_size do
            if byte_index >= byte_count then return written end
            bit_buffer = bor(bit_buffer, lshift(bytes[byte_index], bit_count))
            byte_index = byte_index + 1
            bit_count = bit_count + 8
        end
        local code = band(bit_buffer, lshift(1, code_size) - 1)
        bit_buffer = rshift(bit_buffer, code_size)
        bit_count = bit_count - code_size

        if code == clear then
            code_size = minimum_size + 1
            next_code = finish + 1
            previous = -1
        elseif code == finish then
            return written
        elseif previous == -1 then
            -- the first code after a clear is always a single colour index
            if code >= clear then error("gif frame starts with an impossible code " .. code, 0) end
            if written < pixel_count then output[written] = code; written = written + 1 end
            first = code
            previous = code
        else
            local depth = 0
            local walk = code
            if code >= next_code then
                if code > next_code then error("gif frame uses a code before it exists: " .. code, 0) end
                stack[depth] = first; depth = depth + 1
                walk = previous
            end
            while walk >= clear do
                stack[depth] = suffix[walk]; depth = depth + 1
                walk = prefix[walk]
            end
            stack[depth] = walk; depth = depth + 1
            first = walk
            for i = depth - 1, 0, -1 do
                if written < pixel_count then output[written] = stack[i]; written = written + 1 end
            end
            if next_code < 4096 then
                prefix[next_code] = previous
                suffix[next_code] = first
                next_code = next_code + 1
                if next_code == lshift(1, code_size) and code_size < 12 then
                    code_size = code_size + 1
                end
            end
            previous = code
        end
    end
end
-- }}}

-- {{{ local function interlaced_rows()
-- The order an interlaced frame's rows arrive in: every 8th row from 0, then
-- every 8th from 4, every 4th from 2, every 2nd from 1. Returns a map from
-- arrival position to real row.
local function interlaced_rows(height)
    local rows = {}
    for _, pass in ipairs({ { 0, 8 }, { 4, 8 }, { 2, 4 }, { 1, 2 } }) do
        for row = pass[1], height - 1, pass[2] do rows[#rows + 1] = row end
    end
    return rows
end
-- }}}

-- {{{ local function shrink()
-- A smaller copy of the screen, by nearest sampling: each output pixel takes
-- the source pixel under its centre. Crisp, and cheap enough to run on every
-- kept frame. Returns the source unchanged when no shrinking is needed.
local function shrink(source, width, height, target_width, target_height, scratch)
    if target_width == width and target_height == height then return source end
    for y = 0, target_height - 1 do
        local sy = math.floor((y + 0.5) * height / target_height)
        for x = 0, target_width - 1 do
            local sx = math.floor((x + 0.5) * width / target_width)
            local s = (sy * width + sx) * 4
            local d = (y * target_width + x) * 4
            scratch[d] = source[s]; scratch[d + 1] = source[s + 1]
            scratch[d + 2] = source[s + 2]; scratch[d + 3] = source[s + 3]
        end
    end
    return scratch
end
-- }}}

-- {{{ function M.decode()
function M.decode(data, options)
    options = options or {}
    local input = reader(data)

    local signature = input.bytes(6)
    if signature ~= "GIF89a" and signature ~= "GIF87a" then
        error("not a gif (signature " .. string.format("%q", signature) .. ")", 0)
    end
    local width, height = input.u16(), input.u16()
    local packed = input.byte()
    input.byte()   -- background colour index: see-through is used instead, as browsers do
    input.byte()   -- pixel aspect ratio, ignored
    local global_palette = nil
    if packed >= 128 then
        global_palette = read_palette(input, 2 ^ (packed % 8 + 1))
    end

    -- the output size, shrunk to fit max_size with the proportions kept
    local out_width, out_height = width, height
    if options.max_size and math.max(width, height) > options.max_size then
        local factor = options.max_size / math.max(width, height)
        out_width = math.max(1, math.floor(width * factor + 0.5))
        out_height = math.max(1, math.floor(height * factor + 0.5))
    end
    local frame_step = options.frame_step or 1

    local screen = ffi.new("uint8_t[?]", width * height * 4)      -- starts see-through
    local saved = ffi.new("uint8_t[?]", width * height * 4)
    local shrunk = ffi.new("uint8_t[?]", out_width * out_height * 4)
    local indices = ffi.new("uint8_t[?]", width * height)

    local frames = {}
    local kept = 0
    local seen = 0
    local control = { disposal = 0, delay_cs = 0, transparent = -1 }

    -- A kept frame is held back until the next kept frame (or the end)
    -- arrives, so the delays of the frames skipped after it can be added to
    -- its own: with frame_step above 1 the loop still lasts exactly as long
    -- as the original.
    local out_bytes = out_width * out_height * 4
    local pending = ffi.new("uint8_t[?]", out_bytes)
    local pending_delay = nil

    -- {{{ local function release()
    local function release()
        if not pending_delay then return end
        kept = kept + 1
        if options.on_frame then
            options.on_frame(kept, pending, out_width, out_height, pending_delay)
        else
            local copy = ffi.new("uint8_t[?]", out_bytes)
            ffi.copy(copy, pending, out_bytes)
            frames[kept] = { pixels = copy, delay_cs = pending_delay }
        end
        pending_delay = nil
    end
    -- }}}

    -- {{{ local function emit()
    -- Two paths per finished screen: kept (the held frame is released and
    -- this one is held), or skipped (its delay joins the held frame's).
    local function emit(delay_cs)
        seen = seen + 1
        if (seen - 1) % frame_step == 0 then
            release()
            ffi.copy(pending, shrink(screen, width, height, out_width, out_height, shrunk), out_bytes)
            pending_delay = delay_cs
        else
            pending_delay = pending_delay + delay_cs
        end
    end
    -- }}}

    while true do
        local introducer = input.byte()
        if introducer == 0x3B then
            break                                                   -- trailer: the end
        elseif introducer == 0x21 then
            local label = input.byte()
            if label == 0xF9 then
                -- graphic control: how the next frame is timed and disposed
                local block = input.sub_blocks()
                if #block < 4 then error("gif graphic control block too short", 0) end
                local flags = block:byte(1)
                control.disposal = math.floor(flags / 4) % 8
                control.delay_cs = block:byte(2) + 256 * block:byte(3)
                control.transparent = (flags % 2 == 1) and block:byte(4) or -1
            else
                input.sub_blocks()                                  -- comments, looping, etc.
            end
        elseif introducer == 0x2C then
            local left, top = input.u16(), input.u16()
            local frame_width, frame_height = input.u16(), input.u16()
            local frame_packed = input.byte()
            local palette = global_palette
            if frame_packed >= 128 then
                palette = read_palette(input, 2 ^ (frame_packed % 8 + 1))
            end
            if not palette then error("gif frame has no colour table", 0) end
            local interlaced = math.floor(frame_packed / 64) % 2 == 1

            local minimum_size = input.byte()
            local frame_pixels = frame_width * frame_height
            if frame_pixels > width * height * 4 then
                error("gif frame is larger than the screen can hold", 0)
            end
            local frame_indices = frame_pixels <= width * height and indices
                or ffi.new("uint8_t[?]", frame_pixels)
            ffi.fill(frame_indices, frame_pixels, 0)
            lzw_decode(input.sub_blocks(), minimum_size, frame_indices, frame_pixels)

            if control.disposal == 3 then ffi.copy(saved, screen, width * height * 4) end

            -- draw the frame's rectangle onto the screen
            local rows = interlaced and interlaced_rows(frame_height) or nil
            local transparent = control.transparent
            for arrival = 0, frame_height - 1 do
                local y = top + (rows and rows[arrival + 1] or arrival)
                if y < height then
                    local source_row = arrival * frame_width
                    for x = 0, frame_width - 1 do
                        local sx = left + x
                        if sx < width then
                            local index = frame_indices[source_row + x]
                            if index ~= transparent then
                                local d = (y * width + sx) * 4
                                screen[d] = palette[index * 3]
                                screen[d + 1] = palette[index * 3 + 1]
                                screen[d + 2] = palette[index * 3 + 2]
                                screen[d + 3] = 255
                            end
                        end
                    end
                end
            end

            local delay = control.delay_cs
            if delay < MINIMUM_DELAY_CS then delay = BROWSER_DELAY_CS end
            emit(delay)

            -- what the frame leaves behind for the next one
            if control.disposal == 2 then
                for y = top, math.min(height, top + frame_height) - 1 do
                    for x = left, math.min(width, left + frame_width) - 1 do
                        local d = (y * width + x) * 4
                        screen[d], screen[d + 1], screen[d + 2], screen[d + 3] = 0, 0, 0, 0
                    end
                end
            elseif control.disposal == 3 then
                ffi.copy(screen, saved, width * height * 4)
            end
            control = { disposal = 0, delay_cs = 0, transparent = -1 }
        else
            error(string.format("gif has an unknown block 0x%02X at byte %d", introducer, input.pos - 1), 0)
        end
    end

    release()
    if kept == 0 then error("gif has no frames", 0) end
    return { width = out_width, height = out_height, frame_count = kept,
             frames = not options.on_frame and frames or nil,
             source_width = width, source_height = height }
end
-- }}}

-- {{{ function M.decode_file()
function M.decode_file(path, options)
    local handle = io.open(path, "rb")
    if not handle then error("cannot open " .. path, 0) end
    local data = handle:read("*a")
    handle:close()
    return M.decode(data, options)
end
-- }}}

return M
