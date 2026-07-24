-- 005-gif-test.lua — proof for the gif encoder: an independent
-- decoder round-trips every frame byte-for-byte.
--
-- What this is, generally: contains a minimal, deliberately dumb
-- GIF/LZW *decoder* that lives only here (never in the pipeline),
-- plus a block-walker that rulers the file structure. The encoder is
-- proven by decoding what it encoded and comparing every byte.
-- Honesty note: if encoder and decoder shared a mirrored
-- off-by-one they could agree while browsers glitch — which is why
-- the phase demo (a human watching the loop in a real browser)
-- remains part of the proof.
-- Run directly: luajit src/005-gif-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local gif = require("004-gif")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- {{{ local function lzw_decode()
-- The dumb decoder: strings for entries, no cleverness, so its
-- correctness is legible at a glance. Mirrors a browser's timing:
-- width grows when the entry count reaches the width's ceiling.
local function lzw_decode(data)
    local entries
    -- {{{ local function reset_entries()
    local function reset_entries()
        entries = {}
        for i = 0, 255 do entries[i] = string.char(i) end
    end
    -- }}}
    reset_entries()
    local width, next_code, prev = 9, 258, nil
    local acc, bits, pos = 0, 0, 1
    local out = {}
    while true do
        while bits < width do
            acc = acc + data:byte(pos) * (2 ^ bits)
            bits = bits + 8
            pos = pos + 1
        end
        local code = acc % (2 ^ width)
        acc = math.floor(acc / (2 ^ width))
        bits = bits - width

        if code == 256 then
            reset_entries()
            width, next_code, prev = 9, 258, nil
        elseif code == 257 then
            break
        else
            local s
            if entries[code] then
                s = entries[code]
            elseif code == next_code and prev then
                -- the KwKwK case: the one code a decoder must infer
                s = entries[prev] .. entries[prev]:sub(1, 1)
            else
                error("decoder: impossible code " .. code)
            end
            out[#out + 1] = s
            if prev then
                entries[next_code] = entries[prev] .. s:sub(1, 1)
                next_code = next_code + 1
                if next_code == 2 ^ width and width < 12 then
                    width = width + 1
                end
            end
            prev = code
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ local function walk_gif()
-- The offset ruler: parses every block, refuses anything unknown,
-- returns dimensions, delays, decoded frames, and whether the
-- loop-forever extension was seen.
local function walk_gif(bytes)
    local pos = 1
    -- {{{ local function take()
    local function take(n)
        local s = bytes:sub(pos, pos + n - 1)
        pos = pos + n
        return s
    end
    -- }}}
    -- {{{ local function u16()
    local function u16()
        local lo, hi = bytes:byte(pos, pos + 1)
        pos = pos + 2
        return lo + hi * 256
    end
    -- }}}
    -- {{{ local function subblocks()
    local function subblocks()
        local parts = {}
        while true do
            local n = bytes:byte(pos)
            pos = pos + 1
            if n == 0 then break end
            parts[#parts + 1] = take(n)
        end
        return table.concat(parts)
    end
    -- }}}

    local file = { frames = {}, delays = {}, saw_loop = false }
    assert(take(6) == "GIF89a", "walker: bad header")
    file.width = u16()
    file.height = u16()
    local packed = bytes:byte(pos)
    pos = pos + 3
    assert(packed == 0xF7, "walker: expected a 256-color global table")
    take(768)

    while true do
        local marker = bytes:byte(pos)
        pos = pos + 1
        if marker == 0x3B then
            file.saw_trailer = true
            break
        elseif marker == 0x21 then
            local label = bytes:byte(pos)
            pos = pos + 1
            if label == 0xFF then
                local body = subblocks()
                if body:sub(1, 11) == "NETSCAPE2.0" then
                    file.saw_loop = true
                end
            elseif label == 0xF9 then
                assert(bytes:byte(pos) == 4, "walker: odd control size")
                pos = pos + 2
                file.delays[#file.delays + 1] = u16()
                pos = pos + 2
            else
                subblocks()
            end
        elseif marker == 0x2C then
            local left, top, w, h = u16(), u16(), u16(), u16()
            assert(left == 0 and top == 0, "walker: offset frame")
            assert(bytes:byte(pos) == 0, "walker: unexpected local table")
            pos = pos + 1
            assert(bytes:byte(pos) == 8, "walker: odd min code size")
            pos = pos + 1
            local decoded = lzw_decode(subblocks())
            assert(#decoded == w * h, "walker: frame length wrong")
            file.frames[#file.frames + 1] = decoded
        else
            error("walker: unknown block marker " .. tostring(marker))
        end
    end
    return file
end
-- }}}

-- {{{ local function make_frame()
-- Deterministic pixels from a formula — no clocks, no dice.
local function make_frame(w, h, formula)
    local f = ffi.new("uint8_t[?]", w * h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            f[y * w + x] = formula(x, y) % 256
        end
    end
    return f
end
-- }}}

local flat_palette = ffi.new("uint8_t[?]", 768)
for i = 0, 767 do flat_palette[i] = i % 256 end

-- three patterned frames round-trip byte-for-byte
local W, H = 64, 48
local frames = {}
for n = 1, 3 do
    frames[n] = make_frame(W, H, function(x, y)
        return x * 3 + y * 5 + n * 7
    end)
end
local bytes = gif.encode{
    width = W, height = H, palette_bytes = flat_palette,
    frames = frames, delay_cs = 4,
}
local file = walk_gif(bytes)
check("dimensions survive the trip",
      file.width == W and file.height == H)
check("all three frames arrive", #file.frames == 3)
check("the loop-forever extension is present", file.saw_loop)
check("the trailer closes the file", file.saw_trailer)
check("every frame delay reads four hundredths",
      file.delays[1] == 4 and file.delays[2] == 4 and file.delays[3] == 4)
local all_equal = true
for n = 1, 3 do
    if ffi.string(frames[n], W * H) ~= file.frames[n] then
        all_equal = false
    end
end
check("all frames round-trip byte-for-byte", all_equal)

-- noisy pixels force dictionary growth to the ceiling and a reset;
-- a formula-driven xorshift keeps it deterministic
local state = 2463534242
local function xorshift()
    state = bit.bxor(state, bit.lshift(state, 13)) % 4294967296
    state = bit.bxor(state, bit.rshift(state, 17)) % 4294967296
    state = bit.bxor(state, bit.lshift(state, 5)) % 4294967296
    return state % 4294967296
end
local NW, NH = 128, 128
local noisy = ffi.new("uint8_t[?]", NW * NH)
for i = 0, NW * NH - 1 do noisy[i] = xorshift() % 256 end
local noisy_bytes = gif.encode{
    width = NW, height = NH, palette_bytes = flat_palette,
    frames = { noisy }, delay_cs = 10,
}
local noisy_file = walk_gif(noisy_bytes)
check("noise (dictionary resets and all) round-trips",
      ffi.string(noisy, NW * NH) == noisy_file.frames[1])

-- a full-size gradient frame, the project's real workload shape
local big = make_frame(256, 256, function(x, y)
    return math.floor(x / 2) + math.floor(y / 2)
end)
local big_bytes = gif.encode{
    width = 256, height = 256, palette_bytes = flat_palette,
    frames = { big }, delay_cs = 4,
}
local big_file = walk_gif(big_bytes)
check("a 256x256 gradient round-trips",
      ffi.string(big, 256 * 256) == big_file.frames[1])
-- the assertion is that compression HAPPENS, not any exact ratio —
-- measured today at ~4x for this pattern, but ratios are statistics
-- and statistics belong to measuring tools, not to test constants
check("gradients compress to well under half of raw",
      #big_bytes < 256 * 256 / 2)

-- the walls: no frames, fractional delays
check("a gif with no frames is refused",
      not pcall(gif.encode, { width = 4, height = 4,
                              palette_bytes = flat_palette,
                              frames = {}, delay_cs = 4 }))
check("a fractional delay is refused",
      not pcall(gif.encode, { width = 4, height = 4,
                              palette_bytes = flat_palette,
                              frames = { make_frame(4, 4, function() return 0 end) },
                              delay_cs = 3.33 }))

print(string.format("gif: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
