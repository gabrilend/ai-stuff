-- 149-the-png-writer.lua
--
-- The .png end's writer (docs/067, issue 804, step 1): pixels in, a PNG
-- file's bytes out, with no compression library. PNG wraps its pixels in
-- zlib's "deflate", and deflate allows "stored" blocks — the bytes as they
-- are, with a length in front — so a correct PNG needs only two checksums,
-- CRC-32 and Adler-32, computed here by hand, and some framing. Modelled
-- on delta-version's readme-gallery png.lua, widened to RGBA (what 803's
-- painter reads back) as well as RGB. The files are larger than a
-- compressed PNG would be; they are exact and byte-reproducible: the same
-- pixels always give the same bytes (no time, no names, no text chunks).

local bit = require("bit")

local png = {}

-- PNG's own colour types for the two layouts written here.
png.COLOUR_TYPES = { [3] = 2, [4] = 6 }   -- channels -> colour type (RGB, RGBA)
-- The longest stored deflate block.
png.STORED_MAX = 65535
png.SIGNATURE = "\137PNG\r\n\26\n"

-- {{{ CRC-32 table
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

-- {{{ function png.crc32
-- CRC-32 (ISO-HDLC, as PNG uses) of a string, as a number 0 .. 2^32-1.
function png.crc32(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bit.bxor(CRC[bit.band(bit.bxor(c, s:byte(i)), 0xFF)], bit.rshift(c, 8))
    end
    return bit.bxor(c, 0xFFFFFFFF) % 4294967296
end
-- }}}

-- {{{ function png.adler32
-- Adler-32 of a string, as zlib's trailer holds it.
function png.adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
-- }}}

-- {{{ local function u32be
local function u32be(n)
    n = n % 4294967296
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
        math.floor(n / 256) % 256, n % 256)
end
-- }}}

-- {{{ local function chunk
local function chunk(kind, data)
    return u32be(#data) .. kind .. data .. u32be(png.crc32(kind .. data))
end
-- }}}

-- {{{ function png.zlib_stored
-- Bytes as a zlib stream of stored deflate blocks: the header (no
-- dictionary, fastest), blocks of at most STORED_MAX bytes, the last
-- marked final, and the Adler-32 of the bytes. An empty input is one empty
-- final block, which is still a valid stream.
function png.zlib_stored(raw)
    local parts = { "\120\1" }
    local pos = 1
    repeat
        local take = math.min(png.STORED_MAX, #raw - pos + 1)
        local final = (pos + take > #raw) and 1 or 0
        parts[#parts + 1] = string.char(final, take % 256, math.floor(take / 256),
            (65535 - take) % 256, math.floor((65535 - take) / 256))
        parts[#parts + 1] = raw:sub(pos, pos + take - 1)
        pos = pos + take
    until pos > #raw
    parts[#parts + 1] = u32be(png.adler32(raw))
    return table.concat(parts)
end
-- }}}

-- {{{ function png.encode
-- width, height: whole numbers, at least 1. pixels: a string of
-- width * height * channels bytes, rows top first, each pixel's channels in
-- order (R, G, B[, A]). channels: 4 (RGBA, the default — what the painter
-- reads back) or 3 (RGB). Returns the PNG file's bytes; refuses a size
-- that does not match the pixels, naming both.
function png.encode(width, height, pixels, channels)
    channels = channels or 4
    local colour_type = png.COLOUR_TYPES[channels]
    if not colour_type then
        error("png.encode: channels is 3 (RGB) or 4 (RGBA), got " .. tostring(channels))
    end
    for name, n in pairs({ width = width, height = height }) do
        if type(n) ~= "number" or n < 1 or n % 1 ~= 0 or n > 2147483647 then
            error("png.encode: " .. name .. " must be a whole number from 1, got " .. tostring(n))
        end
    end
    local stride = width * channels
    if type(pixels) ~= "string" or #pixels ~= stride * height then
        error(string.format("png.encode: %dx%d at %d channels is %d bytes, but %s bytes were given",
            width, height, channels, stride * height, type(pixels) == "string" and #pixels or "no"))
    end
    local rows = {}
    for y = 0, height - 1 do
        -- Filter type 0 (none) before every row: the bytes as they are.
        rows[#rows + 1] = "\0" .. pixels:sub(y * stride + 1, (y + 1) * stride)
    end
    local header = u32be(width) .. u32be(height) .. string.char(8, colour_type, 0, 0, 0)
    return png.SIGNATURE .. chunk("IHDR", header)
        .. chunk("IDAT", png.zlib_stored(table.concat(rows))) .. chunk("IEND", "")
end
-- }}}

-- {{{ function png.write
-- Writes the encoded file to `path` through a neighbour name and a rename,
-- so a reader never sees half a picture. Returns the bytes' length.
function png.write(path, width, height, pixels, channels)
    local bytes = png.encode(width, height, pixels, channels)
    local tmp = path .. ".writing"
    local file = assert(io.open(tmp, "wb"))
    file:write(bytes)
    file:close()
    assert(os.rename(tmp, path))
    return #bytes
end
-- }}}

return png
