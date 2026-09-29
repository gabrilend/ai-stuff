-- gif-decode-test.lua - Proves the viewer's decoder reads gifs correctly.
--
-- In general terms: three independent witnesses check the decoder.
--   1. Round trip: frames written by the gif-generator's own encoder are
--      read back, and every pixel must come out as the colour that was put in.
--   2. A gif built by hand, byte by byte, using the features the shape
--      renderer never writes (a frame's own palette, a frame covering part of
--      the screen, see-through pixels, clearing after display, rows stored out
--      of order), with every expected pixel worked out in advance.
--   3. The real gifs in the folder: the frame count and size must match an
--      independent block walker, one frame must match ImageMagick pixel for
--      pixel, and shrinking and frame-skipping must keep each loop's length.
--
-- Usage: luajit gif-decode-test.lua <monorepo dir> <gif folder> <scratch dir>
-- Prints one line per check and a summary; exits 1 if any check failed.

local ROOT = arg[1] or "/mnt/mtwo/programming/ai-stuff"
local FOLDER = arg[2] or "/home/ritz/pictures/shape-gifs"
local SCRATCH = arg[3] or "/tmp"

local ffi = require("ffi")
local gif = dofile(ROOT .. "/delta-version/scripts/gif-viewer/gif-decode.lua")
local encoder = dofile(ROOT .. "/gif-generator/src/004-gif.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function pixel()
local function pixel(frame, width, x, y)
    local p = frame.pixels
    local i = (y * width + x) * 4
    return p[i], p[i + 1], p[i + 2], p[i + 3]
end
-- }}}

-- {{{ Witness 1: round trip through the gif-generator's encoder
do
    -- Odd sizes and all 256 colours in noisy order, so the compression
    -- dictionary fills, its code width climbs to 12 bits, and it is cleared
    -- and restarted -- the paths a small tidy picture would never reach.
    local width, height, frame_count = 67, 43, 4
    local palette = ffi.new("uint8_t[768]")
    local seed = 12345
    local function random_byte()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return math.floor(seed / 65536) % 256
    end
    for i = 0, 767 do palette[i] = random_byte() end
    local frames = {}
    for f = 1, frame_count do
        local indices = {}
        for i = 0, width * height - 1 do
            -- mostly noise, with runs, so both short and long codes occur
            indices[i] = (i % 7 == 0) and indices[i - 1] or random_byte()
        end
        indices[0] = random_byte()
        frames[f] = indices
    end
    local bytes = encoder.encode({ width = width, height = height, palette_bytes = palette,
                                   frames = frames, delay_cs = 7 })
    local decoded = gif.decode(bytes)
    check("round trip: frame count survives", decoded.frame_count == frame_count)
    local all_match = true
    for f = 1, frame_count do
        for i = 0, width * height - 1 do
            local index = frames[f][i]
            local r, g, b, a = pixel(decoded.frames[f], width, i % width, math.floor(i / width))
            if r ~= palette[index * 3] or g ~= palette[index * 3 + 1]
               or b ~= palette[index * 3 + 2] or a ~= 255 then
                all_match = false
            end
        end
    end
    check("round trip: every pixel of every frame is the colour put in", all_match)
    check("round trip: delays survive", decoded.frames[1].delay_cs == 7)
end
-- }}}

-- {{{ Witness 2: a gif built by hand

-- {{{ local function literal_lzw()
-- The simplest valid compressed stream: every pixel written as its own code,
-- with a "clear" before the dictionary would need wider codes, so the code
-- width never changes. Sharing nothing with either encoder or decoder.
local function literal_lzw(indices, minimum_size)
    local clear = 2 ^ minimum_size
    local code_size = minimum_size + 1
    local codes = {}
    for i = 1, #indices, 2 do
        codes[#codes + 1] = clear
        codes[#codes + 1] = indices[i]
        if indices[i + 1] then codes[#codes + 1] = indices[i + 1] end
    end
    codes[#codes + 1] = clear + 1
    local out, accumulator, bits = {}, 0, 0
    for _, code in ipairs(codes) do
        accumulator = accumulator + code * 2 ^ bits
        bits = bits + code_size
        while bits >= 8 do
            out[#out + 1] = string.char(accumulator % 256)
            accumulator = math.floor(accumulator / 256)
            bits = bits - 8
        end
    end
    if bits > 0 then out[#out + 1] = string.char(accumulator % 256) end
    local data = table.concat(out)
    return string.char(minimum_size) .. string.char(#data) .. data .. "\0"
end
-- }}}

do
    local function u16(n) return string.char(n % 256, math.floor(n / 256)) end
    local global = "\0\0\0" .. "\255\0\0" .. "\0\255\0" .. "\0\0\255"     -- black, red, green, blue
    local own    = "\9\9\9" .. "\200\100\0" .. "\0\100\200" .. "\250\250\0" -- a frame's own palette
    local parts = {
        "GIF89a", u16(8), u16(6), string.char(0x81), "\0\0", global,         -- 4-colour global table
        -- frame 1: the whole 8x6 screen in red
        "\33\249\4", string.char(0), u16(5), "\0\0",
        "\44", u16(0), u16(0), u16(8), u16(6), "\0",
        literal_lzw((function() local t = {} for i = 1, 48 do t[i] = 1 end return t end)(), 2),
        -- frame 2: a 3x3 patch at (2,1) with its own palette, interlaced,
        -- index 0 see-through, cleared after display (disposal 2)
        "\33\249\4", string.char(2 * 4 + 1), u16(5), "\0\0",
        "\44", u16(2), u16(1), u16(3), u16(3), string.char(0x80 + 0x40 + 1), own,
        -- rows arrive in interlaced order 0, 2, 1; row 0 = 1 0 2, row 1 = 3 3 3, row 2 = 0 1 0
        literal_lzw({ 1, 0, 2,   0, 1, 0,   3, 3, 3 }, 2),
        -- frame 3: one blue pixel at (0,0), nothing else drawn
        "\33\249\4", string.char(0), u16(5), "\0\0",
        "\44", u16(0), u16(0), u16(1), u16(1), "\0",
        literal_lzw({ 3 }, 2),
        ";",
    }
    local decoded = gif.decode(table.concat(parts))
    check("hand-built: three frames", decoded.frame_count == 3)

    local f2 = decoded.frames[2]
    local function is(frame, x, y, r, g, b, a)
        local pr, pg, pb, pa = pixel(frame, 8, x, y)
        return pr == r and pg == g and pb == b and pa == a
    end
    check("hand-built: outside the patch stays red", is(f2, 0, 0, 255, 0, 0, 255))
    check("hand-built: the patch uses its own palette", is(f2, 2, 1, 200, 100, 0, 255))
    check("hand-built: a see-through pixel shows the red beneath", is(f2, 3, 1, 255, 0, 0, 255))
    -- stored order 0, 2, 1: the third stored row (3 3 3) belongs on the
    -- patch's middle row (y = 2), the second (0 1 0) on its bottom row (y = 3).
    -- Read without de-interlacing, (2,2) would be see-through and show red.
    check("hand-built: interlaced rows land in their true places",
        is(f2, 2, 2, 250, 250, 0, 255) and is(f2, 3, 3, 200, 100, 0, 255)
        and is(f2, 2, 3, 255, 0, 0, 255))

    local f3 = decoded.frames[3]
    check("hand-built: after clearing, the patch is see-through", is(f3, 2, 1, 0, 0, 0, 0))
    check("hand-built: outside the cleared patch is untouched", is(f3, 7, 5, 255, 0, 0, 255))
    check("hand-built: the next frame draws on top", is(f3, 0, 0, 0, 0, 255, 255))

    local truncated = pcall(gif.decode, table.concat(parts):sub(1, 40))
    check("a truncated gif is refused", not truncated)
    local foreign = pcall(gif.decode, "PNG not a gif at all")
    check("a file that is not a gif is refused", not foreign)
end
-- }}}

-- {{{ Witness 3: the real gifs
do
    local walker = ROOT .. "/delta-version/scripts/readme-gallery/tests/gif-facts.lua"
    local listing = io.popen("ls -1 '" .. FOLDER .. "'")
    local names = {}
    for line in listing:lines() do
        if line:match("%.gif$") then names[#names + 1] = line end
    end
    listing:close()
    check("the folder holds gifs (" .. #names .. ")", #names > 0)

    local mismatched = {}
    for _, name in ipairs(names) do
        local path = FOLDER .. "/" .. name
        local facts_pipe = io.popen("luajit '" .. walker .. "' '" .. path .. "'")
        local facts = facts_pipe:read("*a")
        facts_pipe:close()
        local frames = tonumber(facts:match("frames=(%d+)"))
        local width = tonumber(facts:match("width=(%d+)"))
        local info = gif.decode_file(path, { on_frame = function() end })
        if info.frame_count ~= frames or info.width ~= width then
            mismatched[#mismatched + 1] = name
        end
    end
    check("every gif's frame count and size match the independent walker"
          .. (#mismatched > 0 and (" (not: " .. table.concat(mismatched, ", ") .. ")") or ""),
          #mismatched == 0)

    -- one frame against ImageMagick, pixel for pixel
    if #names > 0 then
        local path = FOLDER .. "/" .. names[1]
        local raw_path = SCRATCH .. "/gif-viewer-frame.rgba"
        os.execute(string.format("magick '%s[5]' -depth 8 rgba:'%s'", path, raw_path))
        local handle = io.open(raw_path, "rb")
        local reference = handle and handle:read("*a")
        if handle then handle:close() end
        os.remove(raw_path)
        local info = gif.decode_file(path)
        local frame = info.frames[6]
        local same = reference ~= nil and #reference == info.width * info.height * 4
        if same then
            same = ffi.string(frame.pixels, #reference) == reference
        end
        check("frame 6 of " .. names[1] .. " matches ImageMagick exactly", same)

        local full_total, step_total = 0, 0
        for _, f in ipairs(info.frames) do full_total = full_total + f.delay_cs end
        local stepped = gif.decode_file(path, { max_size = 128, frame_step = 2 })
        for _, f in ipairs(stepped.frames) do step_total = step_total + f.delay_cs end
        check("grid copies are shrunk to fit 128", math.max(stepped.width, stepped.height) == 128)
        check("grid copies keep every second frame", stepped.frame_count == math.ceil(info.frame_count / 2))
        check("grid copies loop exactly as long as the original", step_total == full_total)
    end
end
-- }}}

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
