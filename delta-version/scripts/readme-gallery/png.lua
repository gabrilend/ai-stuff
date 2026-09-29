-- png.lua - writes a still picture as a PNG, with no compression library.
--
-- What this is, generally: a way to look at one frame of a candidate
-- animation in any image viewer. PNG wraps its pixels in the "deflate"
-- format, and deflate allows "stored" blocks -- the bytes as they are, with a
-- length in front -- so a correct PNG needs only two checksums and some
-- framing, not a compressor. The files are larger than a compressed PNG
-- would be; for a handful of approval stills in RAM that does not matter.
--
-- Data format: rgb is a Lua string of width*height*3 bytes, rows top first.

local bit = require("bit")

local png = {}

-- {{{ local function crc_table()
local CRC = {}
for n = 0, 255 do
    local c = n
    for _ = 1, 8 do
        if bit.band(c, 1) == 1 then
            c = bit.bxor(0xEDB88320, bit.rshift(c, 1))
        else
            c = bit.rshift(c, 1)
        end
    end
    CRC[n] = c
end
-- }}}

-- {{{ local function crc32()
local function crc32(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bit.bxor(CRC[bit.band(bit.bxor(c, s:byte(i)), 0xFF)], bit.rshift(c, 8))
    end
    return bit.bxor(c, 0xFFFFFFFF)
end
-- }}}

-- {{{ local function u32be()
local function u32be(n)
    n = n % 4294967296
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
                       math.floor(n / 256) % 256, n % 256)
end
-- }}}

-- {{{ local function chunk()
local function chunk(kind, data)
    return u32be(#data) .. kind .. data .. u32be(crc32(kind .. data))
end
-- }}}

-- {{{ function png.encode()
function png.encode(width, height, rgb)
    local rows = {}
    for y = 0, height - 1 do
        -- filter byte 0 (none) before every row
        rows[#rows + 1] = "\0" .. rgb:sub(y * width * 3 + 1, (y + 1) * width * 3)
    end
    local raw = table.concat(rows)

    -- zlib: header, stored deflate blocks of at most 65535 bytes, Adler-32
    local parts = { "\120\1" }
    local a, b = 1, 0
    for i = 1, #raw do
        a = (a + raw:byte(i)) % 65521
        b = (b + a) % 65521
    end
    local pos = 1
    while pos <= #raw do
        local take = math.min(65535, #raw - pos + 1)
        local final = (pos + take > #raw) and 1 or 0
        parts[#parts + 1] = string.char(final, take % 256, math.floor(take / 256),
                                        (65535 - take) % 256, math.floor((65535 - take) / 256))
        parts[#parts + 1] = raw:sub(pos, pos + take - 1)
        pos = pos + take
    end
    parts[#parts + 1] = u32be(b * 65536 + a)

    local header = u32be(width) .. u32be(height) .. "\8\2\0\0\0"
    return "\137PNG\r\n\26\n" .. chunk("IHDR", header)
        .. chunk("IDAT", table.concat(parts)) .. chunk("IEND", "")
end
-- }}}

return png
