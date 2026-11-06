-- 032-the-gif-tests.test.lua - the GIF writer, checked by reading back.
--
-- In plain terms: an encoder can be confidently wrong in a way that mostly
-- works (a code widened one entry late garbles only long frames), so its
-- files are decoded here by a decoder written separately from it, and the
-- colour numbers read back must equal exactly those that went in --
-- including frames noisy enough to fill the compression table and make it
-- start over. ImageMagick, when installed, reads them too: two independent
-- readers agreeing is the proof.
--
-- Run with LuaJIT (scripts/run-tests does this):
--   luajit src/032-the-gif-tests.test.lua <project-dir>

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 032-the-gif-tests.test.lua <project-dir>", 0) end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local ffi = require("ffi")
local bit = require("bit")
local gif = require("030-gif-writer")

local SCRATCH = project_dir .. "/tmp/shared-memory/gif-tests"
os.execute("mkdir -p '" .. SCRATCH .. "'")
local tests = {}
local function test(name, body) tests[#tests + 1] = { name = name, body = body } end
local function expect(condition, message) if not condition then error(message, 2) end end

-- {{{ an independent decoder (shares nothing with 030)
-- {{{ local function decode()
-- A GIF's bytes -> { width, height, palette = list of {r,g,b},
-- frames = list of { indices = Lua list (1-based), delay } }.
local function decode(bytes)
    local at = 1
    local function u8() local v = bytes:byte(at); at = at + 1; return v end
    local function u16() local lo, hi = bytes:byte(at, at + 1); at = at + 2; return lo + hi * 256 end
    assert(bytes:sub(1, 6) == "GIF89a", "signature")
    at = 7
    local width, height = u16(), u16()
    local flags = u8(); u8(); u8()
    local palette = {}
    if bit.band(flags, 0x80) ~= 0 then
        local size = 2 ^ (bit.band(flags, 7) + 1)
        for i = 1, size do palette[i] = { u8(), u8(), u8() } end
    end
    local frames, delay = {}, 0
    while true do
        local kind = u8()
        if kind == 0x3B then break
        elseif kind == 0x21 then
            local label = u8()
            if label == 0xF9 then u8(); u8(); delay = u16(); u8(); u8()
            else
                -- any other extension: skip its sub-blocks
                while true do local n = u8(); if n == 0 then break end; at = at + n end
            end
        elseif kind == 0x2C then
            u16(); u16()
            local w, h = u16(), u16()
            u8()
            local min_size = u8()
            local stream = {}
            while true do local n = u8(); if n == 0 then break end; stream[#stream + 1] = bytes:sub(at, at + n - 1); at = at + n end
            stream = table.concat(stream)
            -- {{{ LZW, as the GIF specification describes it
            local clear, stop = 2 ^ min_size, 2 ^ min_size + 1
            local size, bit_at = min_size + 1, 0
            local function read_code()
                local code = 0
                for b = 0, size - 1 do
                    local byte = stream:byte(math.floor((bit_at + b) / 8) + 1) or 0
                    if bit.band(bit.rshift(byte, (bit_at + b) % 8), 1) == 1 then code = code + 2 ^ b end
                end
                bit_at = bit_at + size
                return code
            end
            local dictionary, next_code, previous = {}, stop + 1, nil
            local function reset()
                dictionary = {}
                for i = 0, clear - 1 do dictionary[i] = { i } end
                next_code, size, previous = stop + 1, min_size + 1, nil
            end
            reset()
            local out = {}
            while true do
                local code = read_code()
                if code == clear then reset()
                elseif code == stop then break
                else
                    local entry
                    if dictionary[code] then entry = dictionary[code]
                    elseif code == next_code and previous then
                        entry = { unpack(previous) }; entry[#entry + 1] = previous[1]
                    else error("bad LZW code " .. code .. " (next " .. next_code .. ")") end
                    for _, v in ipairs(entry) do out[#out + 1] = v end
                    if previous and next_code < 4096 then
                        local new = { unpack(previous) }; new[#new + 1] = entry[1]
                        dictionary[next_code] = new
                        next_code = next_code + 1
                        if next_code == 2 ^ size and size < 12 then size = size + 1 end
                    end
                    previous = entry
                end
            end
            -- }}}
            assert(#out == w * h, "frame has " .. #out .. " pixels, wanted " .. w * h)
            frames[#frames + 1] = { indices = out, delay = delay }
        else error("unknown block " .. tostring(kind)) end
    end
    return { width = width, height = height, palette = palette, frames = frames }
end
-- }}}
-- }}}

-- {{{ local function make_frames()
-- `count` RGBA frames: a smooth gradient with a noisy band, so colours
-- repeat (long codes) and vary (many codes).
local function make_frames(width, height, count, seed)
    local frames, state = {}, seed
    local function random() state = (state * 1103515245 + 12345) % 2147483648; return state end
    for f = 1, count do
        local frame = ffi.new("uint8_t[?]", width * height * 4)
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                local p = (y * width + x) * 4
                local noisy = y > height / 2
                frame[p] = noisy and random() % 256 or (x * 255 / width)
                frame[p + 1] = noisy and random() % 256 or (y * 255 / height)
                frame[p + 2] = (f * 40) % 256
                frame[p + 3] = 255
            end
        end
        frames[f] = frame
    end
    return frames
end
-- }}}

-- {{{ local function encode()
local function encode(frames, width, height)
    local palette = gif.palette(frames, width, height, 256, 3)
    local map = gif.mapper(palette)
    local parts, expected = { gif.header(width, height, palette) }, {}
    for i, frame in ipairs(frames) do
        local indices = map(frame, width, height)
        expected[i] = indices
        parts[#parts + 1] = gif.frame_block(width, height, gif.lzw(indices, width * height), 8)
    end
    parts[#parts + 1] = gif.trailer()
    return table.concat(parts), palette, expected
end
-- }}}

test("a GIF reads back exactly, frame by frame, including a full table", function()
    -- 128 x 96 with its lower half noise: over 6000 codes a frame, more than
    -- the 4096 the table holds, so the table must fill and start over
    local width, height = 128, 96
    local bytes, palette, expected = encode(make_frames(width, height, 3, 7), width, height)
    local decoded = decode(bytes)
    expect(decoded.width == width and decoded.height == height, "size")
    expect(#decoded.frames == 3, "frames: " .. #decoded.frames)
    for f, frame in ipairs(decoded.frames) do
        for p = 1, width * height do
            if frame.indices[p] ~= expected[f][p - 1] then
                error(string.format("frame %d pixel %d: read %d, wrote %d", f, p - 1, frame.indices[p], expected[f][p - 1]))
            end
        end
        expect(frame.delay == 8, "delay")
    end
    for i, c in ipairs(palette) do
        local d = decoded.palette[i]
        expect(d[1] == c[1] and d[2] == c[2] and d[3] == c[3], "palette colour " .. i)
    end
end)

test("one colour, and a single pixel, still make whole frames", function()
    local flat = ffi.new("uint8_t[?]", 40 * 30 * 4, 200)
    local bytes = encode({ flat }, 40, 30)
    expect(#decode(bytes).frames[1].indices == 1200, "flat frame")
    local one = ffi.new("uint8_t[4]", 10, 20, 30, 255)
    expect(#decode(encode({ one }, 1, 1)).frames[1].indices == 1, "one pixel")
end)

test("the colour table is never more than 256", function()
    local palette = gif.palette(make_frames(64, 64, 2, 3), 64, 64, 256, 1)
    expect(#palette <= 256 and #palette > 1, "palette size " .. #palette)
end)

test("ImageMagick reads the same colours (when installed)", function()
    local width, height = 96, 80
    local bytes, palette, expected = encode(make_frames(width, height, 2, 11), width, height)
    local path = SCRATCH .. "/check.gif"
    local file = io.open(path, "wb"); file:write(bytes); file:close()
    local probe = io.popen("command -v magick")
    local found = probe:read("*l")
    probe:close()
    if not found then print("      (ImageMagick not installed: outside check skipped)"); return end
    local pipe = io.popen("magick '" .. path .. "[1]' -depth 8 rgb:-")
    local raw = pipe:read("*a")
    pipe:close()
    expect(#raw == width * height * 3, "ImageMagick gave " .. #raw .. " bytes")
    for p = 0, width * height - 1 do
        local c = palette[expected[2][p] + 1]
        local r, g, b = raw:byte(p * 3 + 1, p * 3 + 3)
        if r ~= c[1] or g ~= c[2] or b ~= c[3] then error(string.format("pixel %d: ImageMagick read %d,%d,%d", p, r, g, b)) end
    end
end)

-- {{{ run them
local failed = 0
for _, entry in ipairs(tests) do
    local ok, problem = pcall(entry.body)
    if ok then print("pass  " .. entry.name) else failed = failed + 1; print("FAIL  " .. entry.name .. "\n      " .. tostring(problem)) end
end
print(string.format("%d of %d passed", #tests - failed, #tests))
os.exit(failed == 0 and 0 or 1)
-- }}}
