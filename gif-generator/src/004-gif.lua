-- 004-gif.lua — the GIF89a encoder, written by hand against a frozen
-- specification.
--
-- What this is, generally: takes a palette and a stack of
-- index-rectangles and emits a complete looping .gif as a string of
-- bytes. No library stands between us and the file; if something
-- breaks, it breaks loudly in our own house. The format froze in
-- 1989, which is precisely its charm.
--
-- Data-format notes worth knowing more than once (they mirror
-- docs/datapath-gif-encoding.md, which tells the longer story):
--   * every multi-byte number in a GIF is little-endian, 16 bits.
--   * frame delays are hundredths of a second — the reason this
--     project's default frame rate is 25 (exactly 4/100s per frame).
--   * LZW codes start at 9 bits (for 256-color data), grow a bit at
--     a time as the dictionary fills, and cap at 12; the dictionary
--     resets via a clear code when it would overflow.
--   * the bit-stream packs little-endian — the first code lives in
--     the LOW bits of the first byte.
--   * compressed bytes travel in sub-blocks of at most 255, each
--     prefixed by its length, ended by a zero-length block.
--   * the encoder's dictionary runs one entry ahead of the decoder's
--     (the decoder learns each entry one code later), which is why
--     the code-width bump happens immediately after an entry is
--     added — by the time the wider code arrives, the decoder has
--     caught up. Off-by-one here corrupts every browser's playback,
--     so the round-trip test decodes with an independent decoder.

local ffi = require("ffi")

local gif = {}

local CLEAR = 256          -- dictionary-reset code (256-color data)
local EOI = 257            -- end-of-information code
local FIRST_FREE = 258     -- first learnable dictionary entry
local MAX_CODE = 4096      -- the 12-bit ceiling

-- {{{ local function u16le()
-- One home for the format's only number shape.
local function u16le(n)
    return string.char(n % 256, math.floor(n / 256))
end
-- }}}

-- {{{ local function lzw_compress()
-- Pixels in, raw compressed bytes out (sub-blocking happens after).
-- The dictionary is flat — keyed by previous-code * 256 + next-byte —
-- so the hot loop never builds a string. This is the difference
-- between milliseconds and seconds per frame in a dynamic language.
local function lzw_compress(pixels, npix)
    -- worst case LZW *expands* (12 bits out per byte in, plus
    -- clears), so the buffer takes double and a little grace
    local cap = npix * 2 + 1024
    local out = ffi.new("uint8_t[?]", cap)
    local len = 0
    local acc, acc_bits = 0, 0
    local code_size = 9

    -- {{{ local function emit()
    -- Bits enter at the accumulator's top, bytes leave from its
    -- bottom — little-endian packing, as the format demands.
    local function emit(code)
        acc = acc + code * (2 ^ acc_bits)
        acc_bits = acc_bits + code_size
        while acc_bits >= 8 do
            out[len] = acc % 256
            len = len + 1
            acc = math.floor(acc / 256)
            acc_bits = acc_bits - 8
        end
    end
    -- }}}

    local dict = {}
    local next_code = FIRST_FREE

    emit(CLEAR)
    local prefix = pixels[0]
    for i = 1, npix - 1 do
        local k = pixels[i]
        local key = prefix * 256 + k
        local hit = dict[key]
        if hit then
            -- the string grows; stay quiet and keep matching
            prefix = hit
        else
            -- the longest match ends: speak it, learn its extension
            emit(prefix)
            if next_code == MAX_CODE then
                -- the dictionary is full: reset the conversation
                -- instead of learning a 13-bit entry that cannot be
                emit(CLEAR)
                dict = {}
                next_code = FIRST_FREE
                code_size = 9
            else
                -- width grows the moment the entry BEING ADDED needs
                -- more bits — checked before the add, after the emit.
                -- The decoder (one entry behind us) bumps after
                -- adding its 2^n-1st entry, which lands between the
                -- same two codes on the wire. Bumping after our add
                -- instead desyncs by exactly one code — the first
                -- version of this file did, and the round-trip test
                -- caught code 766 arriving one bit short.
                if next_code == 2 ^ code_size and code_size < 12 then
                    code_size = code_size + 1
                end
                dict[key] = next_code
                next_code = next_code + 1
            end
            prefix = k
        end
    end
    emit(prefix)
    emit(EOI)
    if acc_bits > 0 then
        out[len] = acc % 256
        len = len + 1
    end
    if len > cap then
        -- cannot happen by the sizing argument above; if it ever
        -- does, memory is already corrupt — say so and stop
        error("gif: compressed frame overran its worst-case buffer")
    end
    return ffi.string(out, len)
end
-- }}}

-- {{{ local function sub_blocks()
-- Chop raw bytes into length-prefixed blocks of at most 255,
-- ending with the zero-length terminator.
local function sub_blocks(raw)
    local parts = {}
    local pos = 1
    local n = #raw
    while pos <= n do
        local take = n - pos + 1
        if take > 255 then take = 255 end
        parts[#parts + 1] = string.char(take)
        parts[#parts + 1] = raw:sub(pos, pos + take - 1)
        pos = pos + take
    end
    parts[#parts + 1] = string.char(0)
    return table.concat(parts)
end
-- }}}

-- {{{ function gif.encode()
-- The whole file, block by block, in the order the datapath document
-- tells it: header, screen, palette, loop-forever, frames, trailer.
-- spec: { width, height, palette_bytes (uint8_t[768] ffi array),
--         frames (list of uint8_t[w*h] ffi arrays), delay_cs }
function gif.encode(spec)
    if #spec.frames < 1 then
        error("gif: a gif with no frames is not a gif")
    end
    if spec.delay_cs < 1 or spec.delay_cs % 1 ~= 0 then
        error("gif: frame delay must be a whole number of hundredths"
              .. " of a second, got " .. tostring(spec.delay_cs))
    end

    local w, h = spec.width, spec.height
    local parts = {}

    -- header and logical screen: 256-color global table announced
    parts[#parts + 1] = "GIF89a"
    parts[#parts + 1] = u16le(w)
    parts[#parts + 1] = u16le(h)
    -- packed: global table present, 8 bits color, table size 256
    parts[#parts + 1] = string.char(0xF7, 0, 0)

    -- the global color table: our purpose-built palette, verbatim
    parts[#parts + 1] = ffi.string(spec.palette_bytes, 768)

    -- loop forever: the Netscape extension, honored universally
    parts[#parts + 1] = string.char(0x21, 0xFF, 0x0B)
    parts[#parts + 1] = "NETSCAPE2.0"
    parts[#parts + 1] = string.char(0x03, 0x01, 0x00, 0x00, 0x00)

    for _, frame in ipairs(spec.frames) do
        -- graphic control: draw-over disposal, no transparency
        parts[#parts + 1] = string.char(0x21, 0xF9, 0x04, 0x04)
        parts[#parts + 1] = u16le(spec.delay_cs)
        parts[#parts + 1] = string.char(0x00, 0x00)
        -- image descriptor: always the full canvas
        parts[#parts + 1] = string.char(0x2C)
        parts[#parts + 1] = u16le(0)
        parts[#parts + 1] = u16le(0)
        parts[#parts + 1] = u16le(w)
        parts[#parts + 1] = u16le(h)
        parts[#parts + 1] = string.char(0x00)
        -- minimum LZW code size, then the compressed sub-blocks
        parts[#parts + 1] = string.char(8)
        parts[#parts + 1] = sub_blocks(lzw_compress(frame, w * h))
    end

    parts[#parts + 1] = string.char(0x3B)
    return table.concat(parts)
end
-- }}}

-- {{{ function gif.write()
-- Encode and land on disk. Returns the byte count so callers can
-- report honestly measured sizes, never estimates.
function gif.write(path, spec)
    local bytes = gif.encode(spec)
    local f, err = io.open(path, "wb")
    if not f then
        error("gif: cannot open '" .. path .. "' for writing: "
              .. tostring(err))
    end
    f:write(bytes)
    f:close()
    return #bytes
end
-- }}}

return gif
