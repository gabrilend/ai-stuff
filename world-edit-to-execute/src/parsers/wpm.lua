-- war3map.wpm Parser (issue 119)
-- The pathing map: one byte of flags for every quarter of a terrain cell
-- (four per cell each way, so a 256 x 256 map is 1024 x 1024). The editor
-- writes it from the terrain, cliffs, water and the pathing textures of the
-- doodads and buildings placed on the map; the game reads it at load.
-- Compatible with LuaJIT and Lua 5.3+.
--
--   "MP3W", int32 version (0), int32 width, int32 height, then width x
--   height bytes, row 0 the south edge, each row west to east.
--
--     local wpm = require("parsers.wpm")
--     local p = wpm.parse(bytes)             -- raises on a damaged file
--     p.width, p.height                      -- 1024, 1024
--     p:walkable(x, y)  p:flyable(x, y)  p:buildable(x, y)  p:water(x, y)  p:blighted(x, y)
--     p:flags(x, y)                          -- the raw byte; x, y from 0 at the south-west
--     p:counts()                             -- how many cells have each flag

local compat = require("compat")
local band = compat.band

local wpm = {}

-- {{{ Constants
wpm.MAGIC = "MP3W"
wpm.VERSION = 0
wpm.HEADER = 16
-- The largest map is 480 x 480 cells; a little room above that, so a
-- damaged size can't ask for gigabytes.
wpm.MAX_SIDE = 4 * 512

-- What each bit means when set. 0x01 and 0x10 are never set by the editor;
-- 0x80 is set where nothing can stand (cliff faces, the map's edge), and
-- has no published meaning.
wpm.FLAGS = {
    NO_WALK  = 0x02,
    NO_FLY   = 0x04,
    NO_BUILD = 0x08,
    BLIGHT   = 0x20,
    NO_WATER = 0x40,
    UNKNOWN  = 0x80,
}
-- }}}

local PathingMap = {}
PathingMap.__index = PathingMap

-- {{{ PathingMap:flags
-- The byte for the cell at (x, y), counted from 0 at the south-west corner;
-- nil outside the map.
function PathingMap:flags(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height or x % 1 ~= 0 or y % 1 ~= 0 then
        return nil
    end
    return self.cells:byte(y * self.width + x + 1)
end
-- }}}

-- {{{ the yes-or-no questions
local function asks(bit, when_set)
    return function(self, x, y)
        local f = self:flags(x, y)
        if not f then return nil end
        return (band(f, bit) ~= 0) == when_set
    end
end
PathingMap.walkable  = asks(wpm.FLAGS.NO_WALK, false)
PathingMap.flyable   = asks(wpm.FLAGS.NO_FLY, false)
PathingMap.buildable = asks(wpm.FLAGS.NO_BUILD, false)
PathingMap.water     = asks(wpm.FLAGS.NO_WATER, false)
PathingMap.blighted  = asks(wpm.FLAGS.BLIGHT, true)
-- }}}

-- {{{ PathingMap:counts
-- How many cells have each flag set, by name, and the total.
function PathingMap:counts()
    local by_byte = {}
    for i = 1, #self.cells do
        local b = self.cells:byte(i)
        by_byte[b] = (by_byte[b] or 0) + 1
    end
    local out = { cells = #self.cells }
    for name in pairs(wpm.FLAGS) do out[name] = 0 end
    for b, n in pairs(by_byte) do
        for name, bit in pairs(wpm.FLAGS) do
            if band(b, bit) ~= 0 then out[name] = out[name] + n end
        end
    end
    return out
end
-- }}}

-- {{{ wpm.parse
function wpm.parse(data)
    if type(data) ~= "string" then
        error("WPM: wants the file's bytes as a string, got " .. type(data), 2)
    end
    if #data < wpm.HEADER then
        error(string.format("WPM: the header needs %d bytes, but the file is %d bytes long", wpm.HEADER, #data), 2)
    end
    if data:sub(1, 4) ~= wpm.MAGIC then
        error(string.format("WPM: starts with %q, not %q", data:sub(1, 4), wpm.MAGIC), 2)
    end
    local version = compat.unpack_int32(data, 5)
    if version ~= wpm.VERSION then
        error(string.format("WPM: version %d; only version %d is known", version, wpm.VERSION), 2)
    end
    local width = compat.unpack_int32(data, 9)
    local height = compat.unpack_int32(data, 13)
    if width < 1 or height < 1 or width > wpm.MAX_SIDE or height > wpm.MAX_SIDE then
        error(string.format("WPM: a size of %d x %d (each side 1 to %d)", width, height, wpm.MAX_SIDE), 2)
    end
    local want = wpm.HEADER + width * height
    if #data ~= want then
        error(string.format("WPM: %d x %d cells need a file of %d bytes, but it is %d (%s)", width, height,
            want, #data, #data < want and "cut short" or "bytes left over"), 2)
    end
    return setmetatable({
        version = version,
        width = width,
        height = height,
        cells = data:sub(wpm.HEADER + 1),
    }, PathingMap)
end
-- }}}

-- {{{ wpm.size_for
-- The pathing map's size for a terrain of W x H tilepoints (w3e.parse's
-- width and height): four cells per terrain cell each way.
function wpm.size_for(tilepoints_w, tilepoints_h)
    return (tilepoints_w - 1) * 4, (tilepoints_h - 1) * 4
end
-- }}}

return wpm
