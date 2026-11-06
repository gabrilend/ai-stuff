-- 150-checking-the-png-writer.lua
--
-- Checks issue 804, step 1: an independent decoder, written here and
-- sharing no code with the writer, reads every file back to exactly the
-- pixels written, checking every chunk's CRC-32, the zlib header, every
-- stored block's length and its complement, and the Adler-32; `file`
-- recognises the result as a PNG of the right size and layout; the same
-- pixels give byte-identical files.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local png = require("149-the-png-writer")

local scratch = kit.scratch("png-writer")

-- {{{ local function be32
local function be32(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end
-- }}}

-- {{{ local function crc
-- CRC-32, bit by bit (no table), so it shares nothing with the writer's.
local function crc(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bit.bxor(c, s:byte(i))
        for _ = 1, 8 do
            local low = bit.band(c, 1)
            c = bit.rshift(c, 1)
            if low == 1 then
                c = bit.bxor(c, 0xEDB88320)
            end
        end
    end
    return bit.bxor(c, 0xFFFFFFFF) % 4294967296
end
-- }}}

-- {{{ local function decode
-- The file's bytes back to width, height, channels and pixels; or nil and
-- what is wrong. Understands only what a stored-block PNG holds, and says
-- so when it meets anything else rather than guess.
local function decode(bytes)
    if bytes:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil, "no PNG signature" end
    local i, chunks = 9, {}
    while i <= #bytes do
        local length = be32(bytes, i)
        local kind = bytes:sub(i + 4, i + 7)
        local data = bytes:sub(i + 8, i + 7 + length)
        if crc(kind .. data) ~= be32(bytes, i + 8 + length) then return nil, kind .. " has a bad CRC" end
        chunks[#chunks + 1] = { kind = kind, data = data }
        i = i + 12 + length
    end
    if chunks[1].kind ~= "IHDR" or chunks[#chunks].kind ~= "IEND" then return nil, "chunks out of order" end
    local h = chunks[1].data
    local width, height = be32(h, 1), be32(h, 5)
    local depth, colour = h:byte(9), h:byte(10)
    if depth ~= 8 or h:byte(11) ~= 0 or h:byte(12) ~= 0 or h:byte(13) ~= 0 then return nil, "an unexpected header" end
    local channels = ({ [2] = 3, [6] = 4 })[colour]
    if not channels then return nil, "colour type " .. colour end
    local z = {}
    for _, c in ipairs(chunks) do
        if c.kind == "IDAT" then z[#z + 1] = c.data end
    end
    z = table.concat(z)
    if (z:byte(1) * 256 + z:byte(2)) % 31 ~= 0 or z:byte(1) % 16 ~= 8 then return nil, "a bad zlib header" end
    local pos, raw, final = 3, {}, 0
    while final == 0 do
        local head = z:byte(pos)
        final = head % 2
        if math.floor(head / 2) % 4 ~= 0 then return nil, "a block that is not stored" end
        local len = z:byte(pos + 1) + z:byte(pos + 2) * 256
        local nlen = z:byte(pos + 3) + z:byte(pos + 4) * 256
        if len + nlen ~= 65535 then return nil, "a stored length and its complement disagree" end
        raw[#raw + 1] = z:sub(pos + 5, pos + 4 + len)
        pos = pos + 5 + len
    end
    raw = table.concat(raw)
    local a, b = 1, 0
    for k = 1, #raw do
        a = (a + raw:byte(k)) % 65521
        b = (b + a) % 65521
    end
    if be32(z, pos) ~= b * 65536 + a then return nil, "a bad Adler-32" end
    if pos + 4 ~= #z + 1 then return nil, "bytes after the zlib stream" end
    local stride = width * channels
    if #raw ~= height * (stride + 1) then return nil, "the image data is the wrong length" end
    local rows = {}
    for y = 0, height - 1 do
        local at = y * (stride + 1) + 1
        if raw:byte(at) ~= 0 then return nil, "row " .. y .. " has filter " .. raw:byte(at) end
        rows[#rows + 1] = raw:sub(at + 1, at + stride)
    end
    return width, height, channels, table.concat(rows)
end
-- }}}

-- {{{ local function pattern
-- width * height pixels that differ from each other and from their
-- neighbours, so a misplaced row or swapped channel shows.
local function pattern(width, height, channels)
    local out = {}
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            for ch = 0, channels - 1 do
                out[#out + 1] = string.char((x * 7 + y * 13 + ch * 61) % 256)
            end
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ local function round_trip
local function round_trip(label, width, height, channels)
    local pixels = pattern(width, height, channels)
    local path = scratch .. "/" .. label .. ".png"
    png.write(path, width, height, pixels, channels)
    local f = assert(io.open(path, "rb"))
    local bytes = f:read("*a")
    f:close()
    local w, h, c, back = decode(bytes)
    kit.check(w ~= nil, label .. " decodes: " .. tostring(h))
    kit.equal(w, width, label .. " keeps its width")
    kit.equal(h, height, label .. " keeps its height")
    kit.equal(c, channels, label .. " keeps its channels")
    kit.check(back == pixels, label .. " reads back to exactly the pixels written")
    return path, bytes
end
-- }}}

local one = string.char(255, 255, 255, 255)
local w, h, c, back = decode(png.encode(1, 1, one))
kit.check(w == 1 and h == 1 and c == 4 and back == one, "one white pixel reads back exactly")

local rgba_path = round_trip("rgba-3x2", 3, 2, 4)
local rgb_path = round_trip("rgb-5x4", 5, 4, 3)
-- 200 * 120 * 4 bytes of rows: several stored blocks, the last one short.
local big_path, big_bytes = round_trip("rgba-200x120", 200, 120, 4)

local described = kit.fs.capture("file -b " .. kit.fs.quote(rgba_path))
kit.check(described:find("PNG image data, 3 x 2, 8%-bit/color RGBA") ~= nil, "`file` reads it as a 3x2 RGBA PNG: " .. described)
described = kit.fs.capture("file -b " .. kit.fs.quote(rgb_path))
kit.check(described:find("PNG image data, 5 x 4, 8%-bit/color RGB,") ~= nil, "`file` reads it as a 5x4 RGB PNG: " .. described)

kit.check(png.encode(200, 120, pattern(200, 120, 4)) == big_bytes, "the same pixels give byte-identical files")
kit.equal(png.crc32("IEND"), 0xAE426082, "CRC-32 matches the known IEND checksum")
kit.equal(png.adler32("Wikipedia"), 0x11E60398, "Adler-32 matches the known value for 'Wikipedia'")
kit.check(not kit.fs.exists(big_path .. ".writing"), "no neighbour file is left behind")

kit.raises(function() png.encode(2, 2, "short") end, "is 16 bytes, but 5 bytes", "pixels that do not fill the size are refused")
kit.raises(function() png.encode(0, 1, "") end, "width must be a whole number", "a zero width is refused")
kit.raises(function() png.encode(1, 1, "abcd", 2) end, "channels is 3", "two channels are refused")

kit.finish()
