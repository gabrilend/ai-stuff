-- war3map.shd Parser (issue 119)
-- The shadow map: the shadows the editor bakes onto the ground under trees
-- and buildings, one byte per quarter of a terrain cell, on the same grid
-- as the pathing map (war3map.wpm). Compatible with LuaJIT and Lua 5.3+.
--
--   No header: width x height bytes, row 0 the south edge, each row west
--   to east; 0x00 no shadow, 0xFF shadow. The size comes from the terrain
--   (wpm.size_for, or the pathing map's own header).
--
--     local shd = require("parsers.shd")
--     local s = shd.parse(bytes, 1024, 1024)   -- raises when the size disagrees
--     s:shadowed(x, y)                         -- x, y from 0 at the south-west
--     s.shadowed_cells                         -- how many have a shadow
--     shd.parse(bytes)                         -- without a size: counts only (no lookups)

local shd = {}

shd.NONE = 0
shd.SHADOW = 255

local ShadowMap = {}
ShadowMap.__index = ShadowMap

-- {{{ ShadowMap:shadowed
-- True for a shadowed cell, false for a clear one, nil outside the map (or
-- when the map was read without its size).
function ShadowMap:shadowed(x, y)
    if not self.width or x < 0 or y < 0 or x >= self.width or y >= self.height or x % 1 ~= 0 or y % 1 ~= 0 then
        return nil
    end
    return self.cells:byte(y * self.width + x + 1) ~= shd.NONE
end
-- }}}

-- {{{ shd.parse
-- BYTES, and the grid's WIDTH and HEIGHT when known. Any byte other than
-- 0x00 counts as a shadow; bytes other than 0x00 and 0xFF are counted in
-- odd_bytes rather than refused (no map seen has one).
function shd.parse(data, width, height)
    if type(data) ~= "string" then
        error("SHD: wants the file's bytes as a string, got " .. type(data), 2)
    end
    if (width == nil) ~= (height == nil) then
        error("SHD: give both the width and the height, or neither", 2)
    end
    if width then
        if width < 1 or height < 1 or width % 1 ~= 0 or height % 1 ~= 0 then
            error(string.format("SHD: a size of %s x %s", tostring(width), tostring(height)), 2)
        end
        if #data ~= width * height then
            error(string.format("SHD: %d x %d cells need %d bytes, but the file is %d (%s)", width, height,
                width * height, #data, #data < width * height and "cut short" or "bytes left over"), 2)
        end
    end
    local shadowed, odd = 0, 0
    -- Count runs of zeros quickly: most maps' shadow maps are mostly clear.
    local pos = 1
    while true do
        local s = data:find("[\1-\255]", pos)
        if not s then break end
        local e = (data:find("\0", s, true) or #data + 1) - 1
        shadowed = shadowed + (e - s + 1)
        for i = s, e do
            if data:byte(i) ~= shd.SHADOW then odd = odd + 1 end
        end
        pos = e + 1
    end
    return setmetatable({
        width = width,
        height = height,
        cells = data,
        shadowed_cells = shadowed,
        odd_bytes = odd,
    }, ShadowMap)
end
-- }}}

return shd
