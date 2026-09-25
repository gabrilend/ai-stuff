--[[
map_wrapper.lua - the 512-byte "HM3W" header in front of a Warcraft III map's archive

A .w3x/.w3m file isn't only an MPQ archive: its first 512 bytes are a small
wrapper the game shows in its map list before opening the archive. It isn't
part of MPQ, so StormLib skips it (it looks for the archive at 512-byte
steps); the map name and player count are read here. Kept from the project's
own MPQ reader when map reading moved to StormLib (issue 114).

Layout (little-endian):
  0    char[4]   "HM3W"
  4    uint32    unknown (0 in every map seen)
  8    cstring   map name (may be a TRIGSTR_ reference into war3map.wts)
  ..   uint32    map flags        (right after the name's terminating zero)
  ..   uint32    maximum players
  up to 512      padding (protected maps sometimes put a signature at the end)

Usage:
  local wrapper = require("mpq.map_wrapper")
  local w, err = wrapper.parse(first_512_bytes)   -- { map_name, map_flags, max_players } or nil, err
  local w, err = wrapper.read(path)                -- the same, from a file
]]

local M = {}

local MAGIC = "HM3W"
local SIZE = 512

-- {{{ local function u32
local function u32(data, pos)
    local a, b, c, d = data:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end
-- }}}

-- {{{ function M.parse
-- data: at least the first 512 bytes of a map file. Returns the fields, or
-- nil and a reason when the bytes aren't a map wrapper.
function M.parse(data)
    if #data < SIZE then
        return nil, "too small for the 512-byte map wrapper (" .. #data .. " bytes)"
    end
    if data:sub(1, 4) ~= MAGIC then
        return nil, "not a map wrapper (starts with " .. data:sub(1, 4):gsub("[^%w]", "?") .. ")"
    end
    local name_end = data:find("\0", 9, true)
    if not name_end or name_end + 8 > SIZE then
        return nil, "map wrapper's name has no end within 512 bytes"
    end
    return {
        map_name = data:sub(9, name_end - 1),
        map_flags = u32(data, name_end + 1),
        max_players = u32(data, name_end + 5),
    }
end
-- }}}

-- {{{ function M.read
-- The wrapper of the map file at path, as parse gives it.
function M.read(path)
    local f = io.open(path, "rb")
    if not f then
        return nil, "cannot open " .. path
    end
    local data = f:read(SIZE)
    f:close()
    return M.parse(data or "")
end
-- }}}

return M
