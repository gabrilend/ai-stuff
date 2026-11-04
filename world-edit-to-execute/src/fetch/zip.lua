--[[
Zip: Reading a Downloaded .zip (Issue 603)

A model posted with its textures usually comes as one .zip. It is stored
as it came (issue 603, open question 3) and read from: this lists its
files and gives one back. Stored and deflated entries are read (the two a
.zip of models holds); deflate is the monorepo's own inflate, in the
kanji-learning-image-generator project, as parsers/png.lua uses it. Each
file's CRC-32 is checked.

    local zip = require("fetch.zip")
    local z = zip.open(bytes)                  -- raises on a damaged archive
    for _, e in ipairs(z.entries) do print(e.name, e.size) end
    local data = z:read("Textures/Foo.blp")    -- by name; nil if absent
    z:find("textures\\foo.BLP")                -- the entry, matched without regard to case or slashes
]]

local bit = require("bit")
local ffi = require("ffi")

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local KANJI = HERE .. "/../../../kanji-learning-image-generator/src/017a-read-a-picture.lua"

local zip = {}

-- {{{ local helpers
local function u16(s, p)
    local a, b = s:byte(p, p + 1)
    return a + b * 256
end

local function u32(s, p)
    local a, b, c, d = s:byte(p, p + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

local inflate
local function get_inflate()
    if not inflate then
        local ok, m = pcall(dofile, KANJI)
        if not ok then error("zip: the monorepo's inflate isn't at " .. KANJI .. " (" .. tostring(m) .. ")") end
        inflate = m.inflate
    end
    return inflate
end

local CRC
local function crc32(s)
    if not CRC then
        CRC = {}
        for i = 0, 255 do
            local c = i
            for _ = 1, 8 do
                if bit.band(c, 1) ~= 0 then c = bit.bxor(0xEDB88320, bit.rshift(c, 1)) else c = bit.rshift(c, 1) end
            end
            CRC[i] = c
        end
    end
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bit.bxor(CRC[bit.band(bit.bxor(c, s:byte(i)), 0xFF)], bit.rshift(c, 8))
    end
    c = bit.bxor(c, 0xFFFFFFFF)
    return c < 0 and c + 4294967296 or c
end
zip.crc32 = crc32

local function key_of(name)
    return (name:gsub("\\", "/"):lower())
end
-- }}}

local Z = {}
Z.__index = Z

-- {{{ function zip.open
function zip.open(data)
    if type(data) ~= "string" then
        error("zip: wants the archive's bytes as a string, got " .. type(data), 2)
    end
    -- The end record is in the last 22 + 65,535 bytes (its comment's limit).
    local eocd
    for p = #data - 21, math.max(1, #data - 21 - 65535), -1 do
        if data:sub(p, p + 3) == "PK\5\6" then eocd = p break end
    end
    if not eocd then
        error("zip: no end-of-archive record; not a .zip, or cut short", 2)
    end
    local count = u16(data, eocd + 10)
    local cd_size, cd_at = u32(data, eocd + 12), u32(data, eocd + 16) + 1
    if cd_at < 1 or cd_at + cd_size > eocd then
        error(string.format("zip: the file list (at byte %d, %d bytes) runs past the end record", cd_at - 1, cd_size), 2)
    end
    local self = setmetatable({ data = data, entries = {}, by_key = {} }, Z)
    local p = cd_at
    for i = 1, count do
        if data:sub(p, p + 3) ~= "PK\1\2" or p + 45 > #data then
            error(string.format("zip: file list entry %d (at byte %d) is damaged", i, p - 1), 2)
        end
        local flags, method = u16(data, p + 8), u16(data, p + 10)
        local crc, csize, size = u32(data, p + 16), u32(data, p + 20), u32(data, p + 24)
        local nlen, xlen, clen = u16(data, p + 28), u16(data, p + 30), u16(data, p + 32)
        local local_at = u32(data, p + 42) + 1
        local name = data:sub(p + 46, p + 45 + nlen)
        if bit.band(flags, 1) ~= 0 then
            error("zip: " .. name .. " is encrypted", 2)
        end
        local e = { name = name, method = method, crc = crc, compressed = csize, size = size, at = local_at }
        if name:sub(-1) ~= "/" then
            self.entries[#self.entries + 1] = e
            self.by_key[key_of(name)] = self.by_key[key_of(name)] or e
        end
        p = p + 46 + nlen + xlen + clen
    end
    return self
end
-- }}}

-- {{{ function Z:find / Z:read
function Z:find(name)
    return self.by_key[key_of(name)]
end

-- The file's bytes (nil when the archive has no such file); raises when
-- the entry is damaged, compressed some other way, or fails its CRC.
function Z:read(name)
    local e = type(name) == "table" and name or self:find(name)
    if not e then return nil end
    local d = self.data
    if d:sub(e.at, e.at + 3) ~= "PK\3\4" then
        error("zip: " .. e.name .. ": no file header at byte " .. (e.at - 1), 2)
    end
    local start = e.at + 30 + u16(d, e.at + 26) + u16(d, e.at + 28)
    if start + e.compressed - 1 > #d then
        error("zip: " .. e.name .. " runs past the end of the archive", 2)
    end
    local out
    if e.method == 0 then
        out = d:sub(start, start + e.compressed - 1)
    elseif e.method == 8 then
        local bytes = get_inflate()(d:sub(start, start + e.compressed - 1), 1)
        if type(bytes) == "table" then
            local b = ffi.new("uint8_t[?]", #bytes)
            for i = 1, #bytes do b[i - 1] = bytes[i] end
            out = ffi.string(b, #bytes)
        else
            out = bytes
        end
    else
        error("zip: " .. e.name .. " is compressed by method " .. e.method .. "; only stored (0) and deflate (8) are read", 2)
    end
    if #out ~= e.size then
        error(string.format("zip: %s should be %d bytes, but reads as %d", e.name, e.size, #out), 2)
    end
    if crc32(out) ~= e.crc then
        error("zip: " .. e.name .. " fails its CRC check", 2)
    end
    return out
end
-- }}}

return zip
