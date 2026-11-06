--[[
Tests for the BLP1 texture reader (Issue 117).

In plain terms: builds small textures byte by byte, both kinds WC3 uses
(a 256-colour palette at every alpha depth, and JPEG), so no downloaded or
proprietary file is needed; checks every mipmap decodes to the pixels
written, with the JPEG's channels in the right order; then cuts the files
short and damages them, and checks each fails with an error naming the
part and its byte offset, never a Lua error from inside the reader.

Usage: luajit src/tests/test_blp.lua [DIR]
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local blp = require("parsers.blp")
local bw = require("parsers.binwrite")
local bit = require("bit")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

-- The pixel at (x, y) of a decoded level: r, g, b, a
local function pixel(img, x, y)
    local o = (y * img.width + x) * 4
    return img.rgba:byte(o + 1, o + 4)
end
-- }}}

-- {{{ The BLP1 header
-- levels: list of byte strings, one per mipmap; extra: what comes between
-- the header and the first mipmap (the JPEG header, or the palette)
local function blp_file(compression, alpha_bits, width, height, extra, levels)
    local b = bw.new()
    b:str("BLP1"):u32(compression):u32(alpha_bits):u32(width):u32(height):u32(4):u32(#levels > 1 and 1 or 0)
    local offset = 156 + #extra
    local offsets, sizes = {}, {}
    for i = 1, 16 do
        local lv = levels[i]
        offsets[i], sizes[i] = lv and offset or 0, lv and #lv or 0
        if lv then offset = offset + #lv end
    end
    for i = 1, 16 do b:u32(offsets[i]) end
    for i = 1, 16 do b:u32(sizes[i]) end
    return b:done() .. extra .. table.concat(levels)
end
-- }}}

-- {{{ Paletted textures
-- Palette entry i is B = i, G = 2i, R = 255 - i, A (unused by WC3) 0
local function palette()
    local b = bw.new()
    for i = 0, 255 do b:u8(i):u8((2 * i) % 256):u8(255 - i):u8(0) end
    return b:done()
end

-- The alpha a pixel i gets at each depth, as stored and as decoded
local function alpha_of(depth, i)
    if depth == 8 then return (i * 37) % 256, (i * 37) % 256 end
    if depth == 4 then local nib = (i * 5) % 16 return nib, nib * 17 end
    if depth == 1 then local on = i % 3 ~= 0 return on and 1 or 0, on and 255 or 0 end
    return nil, 255
end

-- One mipmap: an index per pixel (pixel i uses colour 10 + i), then alpha
local function palette_level(depth, count)
    local b = bw.new()
    for i = 0, count - 1 do b:u8(10 + i) end
    if depth == 8 then
        for i = 0, count - 1 do b:u8((alpha_of(8, i))) end
    elseif depth == 4 then
        for i = 0, count - 1, 2 do
            local lo = alpha_of(4, i)
            local hi = i + 1 < count and alpha_of(4, i + 1) or 0
            b:u8(lo + hi * 16)
        end
    elseif depth == 1 then
        for i = 0, count - 1, 8 do
            local byte = 0
            for k = 0, 7 do
                if i + k < count and alpha_of(1, i + k) == 1 then byte = byte + 2 ^ k end
            end
            b:u8(byte)
        end
    end
    return b:done()
end

local function palette_texture(depth)
    -- 4 x 2, then 2 x 1, then 1 x 1
    return blp_file(1, depth, 4, 2, palette(),
        { palette_level(depth, 8), palette_level(depth, 2), palette_level(depth, 1) })
end

test_section("Paletted textures, every alpha depth, every mipmap")

for _, depth in ipairs({ 0, 1, 4, 8 }) do
    local ok, all = pcall(blp.decode_all, palette_texture(depth))
    local right, why = ok, ok and nil or tostring(all)
    if ok then
        right = all.source_format == "palette" and all.width == 4 and all.height == 2 and #all.levels == 3
            and all.levels[2].width == 2 and all.levels[2].height == 1 and all.levels[3].width == 1
        for li, lv in ipairs(ok and all.levels or {}) do
            for i = 0, lv.width * lv.height - 1 do
                local r, g, b, a = pixel(lv, i % lv.width, math.floor(i / lv.width))
                local c = 10 + i
                local _, want_a = alpha_of(depth, i)
                if r ~= 255 - c or g ~= 2 * c or b ~= c or a ~= want_a then
                    right = false
                    why = why or string.format("level %d pixel %d: %d %d %d %d", li - 1, i, r, g, b, a)
                end
            end
        end
    end
    test("alpha depth " .. depth .. ": three mipmaps, every pixel's colour and alpha", right, why)
end

do
    local bytes = palette_texture(8)
    local one = blp.decode(bytes, 1)
    test("decode(level) gives the one mipmap", one.width == 2 and one.height == 1 and one.compression == "paletted"
        and select(1, pixel(one, 1, 0)) == 255 - 11)
    local ok, err = pcall(blp.decode, bytes, 3)
    test("a mipmap the file doesn't hold is named", not ok and tostring(err):find("no mipmap 3", 1, true))
end
-- }}}

-- {{{ JPEG textures
-- A baseline JPEG writer just big enough for the test: four components
-- (BLP's B, G, R, A, stored without a colour transform), no subsampling,
-- every quantizer 1, and each 8 x 8 block one solid value per component,
-- so each block is a DC coefficient alone and decodes back exactly.

-- {{{ canonical Huffman codes: symbol -> { code, len }
local function huffman_codes(counts, symbols)
    local codes, code, k = {}, 0, 1
    for len = 1, 16 do
        for _ = 1, counts[len] do
            codes[symbols[k]] = { code = code, len = len }
            code, k = code + 1, k + 1
        end
        code = code * 2
    end
    return codes
end
-- }}}

local DC_COUNTS = { 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 }   -- the standard luminance DC table
local DC_SYMBOLS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local AC_COUNTS = { 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }   -- one symbol: end of block
local AC_SYMBOLS = { 0 }
local DC = huffman_codes(DC_COUNTS, DC_SYMBOLS)
local AC = huffman_codes(AC_COUNTS, AC_SYMBOLS)

-- A marker segment: FF, the marker, a big-endian length counting itself, the body
local function segment(marker, body)
    local len = #body + 2
    return string.char(0xFF, marker, bit.rshift(len, 8), len % 256) .. body
end

-- {{{ jpeg_shared_header: SOI, the quantization table, the Huffman tables
local function jpeg_shared_header()
    local dqt = string.char(0) .. string.rep(string.char(1), 64)
    local dht = string.char(0x00) .. string.char(unpack(DC_COUNTS)) .. string.char(unpack(DC_SYMBOLS))
        .. string.char(0x10) .. string.char(unpack(AC_COUNTS)) .. string.char(unpack(AC_SYMBOLS))
    return string.char(0xFF, 0xD8) .. segment(0xDB, dqt) .. segment(0xC4, dht)
end
-- }}}

-- {{{ jpeg_level: the frame, the scan and EOI for one mipmap
-- blocks[by][bx] = { c1, c2, c3, c4 }: each 8 x 8 block's four values
local function jpeg_level(width, height, blocks)
    local sof = string.char(8, bit.rshift(height, 8), height % 256, bit.rshift(width, 8), width % 256, 4)
    local sos = string.char(4)
    for c = 1, 4 do
        sof = sof .. string.char(c, 0x11, 0)
        sos = sos .. string.char(c, 0x00)
    end
    sos = sos .. string.char(0, 63, 0)

    local out, acc, nbits = {}, 0, 0
    local function put(code, len)
        for k = len - 1, 0, -1 do
            acc = acc * 2 + bit.band(bit.rshift(code, k), 1)
            nbits = nbits + 1
            if nbits == 8 then
                out[#out + 1] = string.char(acc)
                if acc == 0xFF then out[#out + 1] = string.char(0) end
                acc, nbits = 0, 0
            end
        end
    end
    local pred = { 0, 0, 0, 0 }
    for by = 1, #blocks do
        for bx = 1, #blocks[by] do
            for c = 1, 4 do
                local dc = (blocks[by][bx][c] - 128) * 8
                local diff = dc - pred[c]
                pred[c] = dc
                local s, mag = 0, math.abs(diff)
                while mag > 0 do s, mag = s + 1, bit.rshift(mag, 1) end
                put(DC[s].code, DC[s].len)
                if s > 0 then put(diff >= 0 and diff or diff + 2 ^ s - 1, s) end
                put(AC[0].code, AC[0].len)
            end
        end
    end
    while nbits > 0 do put(1, 1) end
    return segment(0xC0, sof) .. segment(0xDA, sos) .. table.concat(out) .. string.char(0xFF, 0xD9)
end
-- }}}

-- Two blocks side by side at full size (16 x 8), one block at 8 x 4
local LEFT, RIGHT, SMALL = { 20, 60, 200, 255 }, { 240, 130, 10, 64 }, { 90, 91, 92, 128 }

local function jpeg_texture(alpha_bits)
    local header = jpeg_shared_header()
    return blp_file(0, alpha_bits, 16, 8, bw.new():u32(#header):done() .. header,
        { jpeg_level(16, 8, { { LEFT, RIGHT } }), jpeg_level(8, 4, { { SMALL } }) })
end

test_section("JPEG textures")

do
    local ok, all = pcall(blp.decode_all, jpeg_texture(8))
    test("a JPEG texture with two mipmaps decodes", ok and all.source_format == "jpeg" and #all.levels == 2
        and all.levels[1].width == 16 and all.levels[2].width == 8 and all.levels[2].height == 4,
        not ok and tostring(all) or nil)
    if ok then
        -- stored B, G, R, A: decoded R is the third value, B the first
        local r, g, b, a = pixel(all.levels[1], 3, 4)
        test("channels in the right order (left block)", r == LEFT[3] and g == LEFT[2] and b == LEFT[1] and a == LEFT[4],
            string.format("%d %d %d %d", r, g, b, a))
        r, g, b, a = pixel(all.levels[1], 12, 7)
        test("the right block is its own colour", r == RIGHT[3] and g == RIGHT[2] and b == RIGHT[1] and a == RIGHT[4],
            string.format("%d %d %d %d", r, g, b, a))
        r, g, b, a = pixel(all.levels[2], 7, 3)
        test("the second mipmap", r == SMALL[3] and g == SMALL[2] and b == SMALL[1] and a == SMALL[4],
            string.format("%d %d %d %d", r, g, b, a))
    end
    local opaque = blp.decode(jpeg_texture(0))
    test("alpha depth 0: every pixel opaque", select(4, pixel(opaque, 12, 7)) == 255)
end
-- }}}

-- {{{ Errors that name what and where
test_section("Bad files fail with errors that name the part and the byte")

local function reader_error(err)
    err = tostring(err)
    return err:match("^BLP: ") ~= nil and err:find("byte %d+") ~= nil and not err:find("attempt to", 1, true)
end

-- {{{ every truncation, both kinds
for _, case in ipairs({ { "paletted, 8-bit alpha", palette_texture(8) }, { "paletted, 1-bit alpha", palette_texture(1) },
                        { "JPEG", jpeg_texture(8) } }) do
    local bytes, bad, example = case[2], 0, nil
    for cut = 4, #bytes - 1 do
        local ok, err = pcall(blp.decode_all, bytes:sub(1, cut))
        if ok or not reader_error(err) then
            bad = bad + 1
            example = example or (cut .. ": " .. (ok and "decoded" or tostring(err)))
        end
    end
    test(case[1] .. ": cut at every byte, every cut is an error naming the byte", bad == 0,
        bad .. " wrong, first " .. tostring(example))
end
-- }}}

-- {{{ the errors name the mipmap
do
    local bytes = palette_texture(8)
    local ok, err = pcall(blp.decode_all, bytes:sub(1, #bytes - 1))
    print("    " .. tostring(err))
    test("a palette texture missing its last byte names mipmap 2 and its offset",
        not ok and tostring(err):find("mipmap 2 (1 x 1)", 1, true) and tostring(err):find("at byte 1200", 1, true))
    ok, err = pcall(blp.decode, bytes:sub(1, 600))
    print("    " .. tostring(err))
    test("one cut inside the palette names the palette", not ok and tostring(err):find("the palette at byte 156", 1, true))
    local jb = jpeg_texture(8)
    ok, err = pcall(blp.decode_all, jb:sub(1, #jb - 3))
    print("    " .. tostring(err))
    test("a JPEG texture cut short names mipmap 1", not ok and tostring(err):find("mipmap 1 (8 x 4)", 1, true))
end
-- }}}

-- {{{ a damaged JPEG mipmap
do
    local jb = jpeg_texture(8)
    local at = jb:find("\255\192", 1, true)                 -- the first mipmap's SOF0
    local broken = jb:sub(1, at + 1) .. "\255\255" .. jb:sub(at + 4)   -- its length: 65535
    local ok, err = pcall(blp.decode, broken)
    print("    " .. tostring(err))
    test("a JPEG segment longer than its mipmap: named, with the JPEG's own reason",
        not ok and reader_error(err) and tostring(err):find("mipmap 0", 1, true) and tostring(err):find("JPEG", 1, true))
end
-- }}}

-- {{{ every 4-byte window of a paletted texture overwritten
do
    local bytes = palette_texture(4)
    local bad, example, failures = 0, nil, 0
    for at = 5, #bytes - 3 do
        for _, fill in ipairs({ "\255\255\255\255", "\0\0\0\0" }) do
            local ok, err = pcall(blp.decode_all, bytes:sub(1, at - 1) .. fill .. bytes:sub(at + 4))
            if not ok then
                failures = failures + 1
                if not tostring(err):match("^BLP: ") or tostring(err):find("attempt to", 1, true) then
                    bad = bad + 1
                    example = example or (at .. ": " .. tostring(err))
                end
            end
        end
    end
    test("every 4-byte window damaged: only the reader's own errors (" .. failures .. " of them)",
        bad == 0 and failures > 0, tostring(example))
end
-- }}}

do
    local ok, err = pcall(blp.decode, "BLP2" .. string.rep("\0", 200))
    test("BLP2 (WoW's) is refused by name", not ok and tostring(err):find("BLP2", 1, true))
    ok, err = pcall(blp.decode, "BLP1" .. string.rep("\0", 20))
    test("a header cut short is named", not ok and tostring(err):find("the header at byte 0", 1, true))
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
