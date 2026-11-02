-- war3map.mmp Parser (issue 119)
-- The minimap's icons: where the editor marks gold mines, neutral buildings
-- and players' start points on the preview map. Compatible with LuaJIT and
-- Lua 5.3+.
--
--   int32 version (0), int32 count, then count entries of 16 bytes:
--   int32 icon type, int32 x, int32 y (on the 256 x 256 minimap, 0 at the
--   left and the top), then the colour as blue, green, red, alpha bytes.
--
--     local mmp = require("parsers.mmp")
--     local m = mmp.parse(bytes)              -- raises on a damaged file
--     for _, icon in ipairs(m.icons) do
--         -- icon.kind ("gold_mine", "neutral_building", "player_start", or
--         -- "unknown"), icon.type (the number), icon.x, icon.y,
--         -- icon.color = { r, g, b, a } (0-255)
--     end
--     m.by_kind.player_start                  -- how many of each kind

local compat = require("compat")

local mmp = {}

mmp.VERSION = 0
mmp.HEADER = 8
mmp.ENTRY = 16

mmp.KINDS = {
    [0] = "gold_mine",
    [1] = "neutral_building",
    [2] = "player_start",
}

-- {{{ mmp.parse
-- An icon type with no known name is kept, as kind "unknown", rather than
-- refused: the minimap only draws it.
function mmp.parse(data)
    if type(data) ~= "string" then
        error("MMP: wants the file's bytes as a string, got " .. type(data), 2)
    end
    if #data < mmp.HEADER then
        error(string.format("MMP: the header needs %d bytes, but the file is %d bytes long", mmp.HEADER, #data), 2)
    end
    local version = compat.unpack_int32(data, 1)
    if version ~= mmp.VERSION then
        error(string.format("MMP: version %d; only version %d is known", version, mmp.VERSION), 2)
    end
    local count = compat.unpack_int32(data, 5)
    if count < 0 then
        error(string.format("MMP: a count of %d icons", count), 2)
    end
    local want = mmp.HEADER + count * mmp.ENTRY
    if #data ~= want then
        error(string.format("MMP: %d icons need a file of %d bytes, but it is %d (%s)", count, want, #data,
            #data < want and "cut short" or "bytes left over"), 2)
    end
    local icons, by_kind = {}, {}
    for i = 0, count - 1 do
        local at = mmp.HEADER + i * mmp.ENTRY + 1
        local t = compat.unpack_int32(data, at)
        local kind = mmp.KINDS[t] or "unknown"
        local b, g, r, a = data:byte(at + 12, at + 15)
        icons[i + 1] = {
            type = t,
            kind = kind,
            x = compat.unpack_int32(data, at + 4),
            y = compat.unpack_int32(data, at + 8),
            color = { r = r, g = g, b = b, a = a },
        }
        by_kind[kind] = (by_kind[kind] or 0) + 1
    end
    return { version = version, icons = icons, by_kind = by_kind }
end
-- }}}

return mmp
