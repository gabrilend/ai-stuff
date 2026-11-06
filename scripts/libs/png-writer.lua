-- png-writer.lua - Writes a PNG picture from raw red-green-blue bytes, with
-- no library.
--
-- In plain terms: a PNG file is a signature and three labelled chunks -- the
-- picture's size, the pixel data, and an end marker -- each followed by a
-- checksum. The pixel data is normally squeezed with "deflate", but deflate
-- also allows "stored" blocks: the bytes as they are, in pieces of up to
-- 65535, each with its length written twice. This writes stored blocks only.
-- Files are larger than a compressing writer's (about the raw size), and in
-- exchange the whole encoder is short enough to read, and fails loudly in code
-- that can be read rather than quietly in someone else's.
--
-- Two checksums the format requires: CRC-32 over each chunk (table built once)
-- and Adler-32 over the uncompressed pixel data (the zlib wrapper's).
--
-- Format notes for whoever edits this: every multi-byte number in PNG is
-- big-endian; each pixel row starts with a filter byte (0 = none, used here);
-- colour type 2 is RGB, 8 bits per channel.

local bit = require("bit")
local M = {}

-- {{{ local crc_table
local crc_table = {}
for n = 0, 255 do
    local c = n
    for _ = 1, 8 do
        if bit.band(c, 1) == 1 then c = bit.bxor(0xEDB88320, bit.rshift(c, 1)) else c = bit.rshift(c, 1) end
    end
    crc_table[n] = c
end
-- }}}

-- {{{ M.crc32(text)
function M.crc32(text)
    local c = 0xFFFFFFFF
    for i = 1, #text do
        c = bit.bxor(crc_table[bit.band(bit.bxor(c, text:byte(i)), 0xFF)], bit.rshift(c, 8))
    end
    return bit.bxor(c, 0xFFFFFFFF)
end
-- }}}

-- {{{ M.adler32(text)
function M.adler32(text)
    local a, b = 1, 0
    for i = 1, #text do
        a = (a + text:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
-- }}}

-- {{{ local function be32()
-- A number as four big-endian bytes.
local function be32(n)
    n = n % 4294967296
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
-- }}}

-- {{{ local function chunk()
local function chunk(kind, data)
    return be32(#data) .. kind .. data .. be32(M.crc32(kind .. data))
end
-- }}}

-- {{{ M.encode(width, height, rgb)
-- The PNG file's bytes, from width x height pixels given as a string of
-- red, green, blue bytes, row by row from the top.
function M.encode(width, height, rgb)
    if #rgb ~= width * height * 3 then
        error(string.format("png-writer: %dx%d needs %d bytes, got %d", width, height, width * height * 3, #rgb), 0)
    end
    local rows = {}
    local stride = width * 3
    for y = 0, height - 1 do rows[#rows + 1] = "\0" .. rgb:sub(y * stride + 1, (y + 1) * stride) end
    local raw = table.concat(rows)
    local blocks = { "\120\1" }   -- zlib header: deflate, 32K window, no preset dictionary
    local position = 1
    repeat
        local piece = raw:sub(position, position + 65534)
        position = position + #piece
        local last = (position > #raw) and 1 or 0
        local len = #piece
        local nlen = 65535 - len
        blocks[#blocks + 1] = string.char(last, len % 256, math.floor(len / 256), nlen % 256, math.floor(nlen / 256)) .. piece
    until position > #raw
    blocks[#blocks + 1] = be32(M.adler32(raw))
    local header = be32(width) .. be32(height) .. string.char(8, 2, 0, 0, 0)
    return "\137PNG\r\n\26\n" .. chunk("IHDR", header) .. chunk("IDAT", table.concat(blocks)) .. chunk("IEND", "")
end
-- }}}

-- {{{ M.write(path, width, height, rgb)
function M.write(path, width, height, rgb)
    local handle = io.open(path, "wb")
    if not handle then error("png-writer: cannot write " .. path, 0) end
    handle:write(M.encode(width, height, rgb))
    handle:close()
end
-- }}}

return M
