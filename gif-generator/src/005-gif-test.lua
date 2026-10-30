-- 005-gif-test.lua — proof for the gif encoder: an independent
-- decoder round-trips every frame byte-for-byte.
--
-- What this is, generally: the encoder is proven by decoding what it
-- encoded and comparing every byte. The decoder is the studio's one
-- reader (040-gif-decode.lua), which was written for the viewer and
-- shares no code with the encoder; until 701b this file kept a small
-- private decoder of its own. Honesty note: if encoder and decoder
-- shared a mirrored off-by-one they could agree while browsers glitch —
-- which is why the phase demo (a human watching the loop in a real
-- browser) remains part of the proof, and why 041 checks the reader
-- against ImageMagick.
-- Run directly: luajit src/005-gif-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local gif = require("004-gif")
local reader = dofile(DIR .. "/src/040-gif-decode.lua")

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

-- {{{ local function walk_gif()
-- The offset ruler, now asked of the studio's one reader
-- (040-gif-decode.lua, written for the viewer and sharing no code with
-- the encoder): every block parsed, every frame's raw indices handed
-- back, and anything the encoder never writes refused, as the private
-- walker that lived here used to (701b).
local function walk_gif(bytes)
    local info = reader.facts(bytes, { structure = true })
    assert(info.signature == "GIF89a", "walker: bad header")
    assert(info.global_colours == 256, "walker: expected a 256-color global table")
    local file = { frames = {}, delays = {}, saw_loop = info.loop,
                   saw_trailer = info.trailer_at_end,
                   width = info.source_width, height = info.source_height }
    for _, frame in ipairs(info.structure) do
        assert(frame.left == 0 and frame.top == 0, "walker: offset frame")
        assert(not frame.local_palette, "walker: unexpected local table")
        assert(frame.minimum_size == 8, "walker: odd min code size")
        assert(frame.ended and frame.written == frame.width * frame.height,
               "walker: frame length wrong")
        file.delays[#file.delays + 1] = frame.delay_cs
        file.frames[#file.frames + 1] = frame.indices
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
