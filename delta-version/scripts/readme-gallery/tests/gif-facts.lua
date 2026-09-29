-- gif-facts.lua - reads a GIF back and reports what is actually in it.
--
-- What this is, generally: a second pair of eyes for the test. It does not
-- share any code with the encoder; it walks the file block by block the way
-- a browser would, and prints what it found: whether the signature is right,
-- whether the loop-forever block is there, how many frames there are, and
-- whether the file ends where a GIF must end. Any structural surprise is an
-- error that names the byte where it happened.
--
-- Usage: luajit gif-facts.lua file.gif
-- Prints: signature=GIF89a width=W height=H loop=yes|no frames=N trailer=yes|no

local path = arg[1]
local handle = assert(io.open(path, "rb"))
local data = handle:read("*a")
handle:close()

local pos = 1
-- {{{ local function byte()
local function byte()
    local b = data:byte(pos)
    if not b then error("ran off the end of the file at byte " .. pos, 0) end
    pos = pos + 1
    return b
end
-- }}}
-- {{{ local function u16()
local function u16() local lo = byte(); return lo + 256 * byte() end
-- }}}
-- {{{ local function skip_sub_blocks()
local function skip_sub_blocks()
    while true do
        local length = byte()
        if length == 0 then return end
        pos = pos + length
    end
end
-- }}}

local signature = data:sub(1, 6)
pos = 7
local width, height = u16(), u16()
local packed = byte()
pos = pos + 2 -- background colour, aspect
-- a global colour table follows when the top bit of the packed byte is set
if packed >= 128 then pos = pos + 3 * 2 ^ ((packed % 8) + 1) end

local frames, loop, trailer = 0, false, false
-- Block walk: each block announces its kind in its first byte. Three paths:
-- an extension (0x21), an image (0x2C), the end (0x3B); anything else is a
-- broken file.
while pos <= #data do
    local kind = byte()
    if kind == 0x21 then
        local label = byte()
        if label == 0xFF then
            local size = byte()
            if data:sub(pos, pos + size - 1) == "NETSCAPE2.0" then loop = true end
            pos = pos + size
        end
        skip_sub_blocks()
    elseif kind == 0x2C then
        pos = pos + 8
        local image_packed = byte()
        if image_packed >= 128 then pos = pos + 3 * 2 ^ ((image_packed % 8) + 1) end
        pos = pos + 1 -- minimum code size
        skip_sub_blocks()
        frames = frames + 1
    elseif kind == 0x3B then
        trailer = (pos == #data + 1)
        break
    else
        error(string.format("unexpected block 0x%02X at byte %d", kind, pos - 1), 0)
    end
end

print(string.format("signature=%s width=%d height=%d loop=%s frames=%d trailer=%s",
    signature, width, height, loop and "yes" or "no", frames, trailer and "yes" or "no"))
