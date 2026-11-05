--[[
light.lua - a converted map's own light in WoW's light tables (issue W02i)

WoW 3.3.5a lights a map by four tables. Light.dbc places lights on a map;
the one at position 0, 0, 0 is the map's default, used wherever no other
light reaches. Each light names parameter sets (LightParams.dbc), one for
clear weather, one under water, and three more (storm, storm under water,
the ghost world). A set's colours change through the day in
LightIntBand.dbc (18 bands a set: the sun's light, the shade's, five sky
colours from overhead to the horizon, the fog's colour, the sun and
clouds, the ocean's and the river's water) and its distances in
LightFloatBand.dbc (6 bands a set: where the fog ends, where it starts as
a share of that, and four the W client doesn't read). A band is up to 16
moments (half-minutes since midnight, 0-2880) with a value each, blended
between, round midnight.

A map with no default light of its own takes Light's row 1 in the stock
client and the W client (the W client's 026-light.h; its decision 147), a
light made for Eastern Kingdoms. So each converted map gets one default
light and two parameter sets:

  clear      the day palette below (LIGHT.PALETTE), with the map's own
             fog and water tint laid in where its war3map.w3i turns them on
  under      the same, but the fog is the river's deep colour, close
             (UNDER_FOG_END yards), from the eye

The war3map.w3i's fog is used when the file has its environment (version
25 and later) and the editor's "use terrain fog" flag (0x2000) is set,
the rule the W client's 084-map-fog.h draws a test map's fog by: its
distances from the eye in WC3 units times the map's yards per unit (the
start no closer than 0, the end no closer than the start), its colour the
file's first three bytes (red, green, blue, as the W client's 083-w3i.c
reads them), all day. The horizon takes the fog's colour by day so the
sky meets the fog. The water tint (flag 0x10000) colours the near water;
deep water is the same, darker; its alpha is the shallow water's opacity.
WC3 keeps no sky colour of its own in the file, so the sky is the palette's.

The ids are W02c's scheme (wowbuild.registration): the map's slot picks
its Light row and its parameter sets, and the band rows' numbers follow
from a set's (LightIntBand: set x 18 - 17 + band; LightFloatBand:
set x 6 - 5 + band; the W client's 026-light.h).

Every band's meaning past those the W client reads is from memory of the
community's 3.3.5a descriptions (unchecked), as are the palette's values,
picked here to look like a clear day.

    local light = require("wowbuild.light")
    local rows, said = light.rows(info, ids)   -- { Light = {...}, LightParams = ..., LightIntBand = ..., LightFloatBand = ... }
]]

local bit = require("bit")
local coords = require("wowbuild.coords")

local light = {}

light.FLAG_TERRAIN_FOG = 0x2000           -- the editor's "use terrain fog" (the W client's W3I_FLAG_TERRAIN_FOG)
light.FLAG_WATER_TINT = 0x10000           -- "use water tinting colour" (W3I_FLAG_WATER_TINT)
light.INT_BANDS, light.FLOAT_BANDS = 18, 6
light.SETS = 2                             -- clear, under water (W02c's scheme keeps 4 a slot)
light.FOG_END = 600                        -- yards, the default's fog end
light.FOG_SHARE = 0.25                     -- where it starts, as a share of its end
light.UNDER_FOG_END = 30                   -- yards, under water
light.GLOW = 0.5                           -- float band 2 (unchecked: the sun's glow through clouds)

-- the four moments of the day the palette gives, half-minutes since midnight
light.TIMES = { 0, 720, 1440, 2160 }       -- midnight, 6:00, noon, 18:00

-- {{{ the palette: each band's colour at each moment (0xRRGGBB)
-- bands as the W client's 026-light.h names them (0 sun, 1 shade, 2-6 sky
-- overhead to horizon, 7 fog, 14-15 ocean near and deep, 16-17 river near
-- and deep); 8-13 from memory (8 unknown, 9 the sun's disc, 10 its halo,
-- 11 the clouds' glow, 12 the clouds, 13 unknown)
light.PALETTE = {
    [0]  = { 0x3A4560, 0xC89070, 0xFFF0D8, 0xD08860 },
    [1]  = { 0x1E2638, 0x5A5058, 0x787068, 0x5A4C50 },
    [2]  = { 0x02040C, 0x28487A, 0x2A64B8, 0x2C3E70 },
    [3]  = { 0x060A18, 0x4A6C9A, 0x4482CE, 0x4A5C8C },
    [4]  = { 0x0C1424, 0x8A92A8, 0x6AA2DC, 0x8A80A0 },
    [5]  = { 0x121C2E, 0xC4A090, 0x8CBAE6, 0xC89480 },
    [6]  = { 0x18243A, 0xE0B080, 0xA8CCEC, 0xE0A070 },
    [7]  = { 0x101828, 0x8C8088, 0xA0B4CC, 0x8C7478 },
    [8]  = { 0x101828, 0x8C8088, 0xA0B4CC, 0x8C7478 },
    [9]  = { 0x000000, 0xFFC890, 0xFFFFE8, 0xFFB070 },
    [10] = { 0x000000, 0xC08060, 0xFFF0C0, 0xC07050 },
    [11] = { 0x101820, 0x806060, 0xE0E0E0, 0x806060 },
    [12] = { 0x182030, 0xB09090, 0xF0F4F8, 0xB08880 },
    [13] = { 0x000000, 0x000000, 0x000000, 0x000000 },
    [14] = { 0x0E2236, 0x2A5470, 0x3A7898, 0x2A5470 },
    [15] = { 0x040C16, 0x0E2236, 0x14344C, 0x0E2236 },
    [16] = { 0x10282E, 0x30605C, 0x44807A, 0x30605C },
    [17] = { 0x06141A, 0x10282E, 0x1A3C40, 0x10282E },
}
-- the water's opacity with no tint: river shallow, river deep, ocean
-- shallow, ocean deep (LightParams 6-9; Ashenvale's, the W client's 026-light.h)
light.ALPHA = { 0.5, 1, 0.75, 1 }
-- how the tint darkens through the day (a share of its colour) and with depth
light.TINT_DAY = { 0.35, 0.7, 1, 0.7 }
light.TINT_DEEP = 0.4
-- }}}

-- {{{ helpers
local function rgb(r, g, b) return r * 65536 + g * 256 + b end
local function scaled(c, k)
    local r, g, b = math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256
    local function s(v) return math.min(255, math.floor(v * k + 0.5)) end
    return rgb(s(r), s(g), s(b))
end
local function raw_flags(info)
    local f = info and info.flags
    if type(f) == "table" then return f.raw or 0 end
    return tonumber(f) or 0
end
-- the file's colour as its bytes come (red, green, blue, alpha: the W
-- client's 083-w3i.c); parsers.w3i keeps it as one little-endian u32
local function bytes_of(c)
    c = tonumber(c) or 0
    return bit.band(c, 0xFF), bit.band(bit.rshift(c, 8), 0xFF), bit.band(bit.rshift(c, 16), 0xFF), bit.band(bit.rshift(c, 24), 0xFF)
end
-- }}}

-- {{{ light.from_w3i: the map's fog and tint, or nil for each
-- Returns { fog = { start, ["end"], color, style } or nil, tint = { color,
-- alpha } or nil, why_no_fog = text }, distances in yards
function light.from_w3i(info, yards_per_unit)
    yards_per_unit = yards_per_unit or coords.YARDS_PER_UNIT
    local out = {}
    if not info then out.why_no_fog = "no war3map.w3i" return out end
    local version = tonumber(info.version) or 0
    if version < 25 or not info.fog then out.why_no_fog = "its war3map.w3i (Reign of Chaos) has no fog" return out end
    local flags = raw_flags(info)
    if bit.band(flags, light.FLAG_WATER_TINT) ~= 0 and info.water_color then
        local r, g, b, a = bytes_of(info.water_color)
        out.tint = { color = rgb(r, g, b), alpha = a / 255 }
    end
    if bit.band(flags, light.FLAG_TERRAIN_FOG) == 0 then out.why_no_fog = "its war3map.w3i turns no terrain fog on" return out end
    local s, e = tonumber(info.fog.start_z), tonumber(info.fog.end_z)
    if not s or not e or s ~= s or e ~= e or s == math.huge or e == math.huge or s == -math.huge or e == -math.huge then
        out.why_no_fog = "its fog's distances are not numbers"
        return out
    end
    local start, stop = s * yards_per_unit, e * yards_per_unit
    if start < 0 then start = 0 end
    if stop < start then stop = start end
    local r, g, b = bytes_of(info.fog.color)
    out.fog = { start = start, ["end"] = stop, color = rgb(r, g, b), style = info.fog.style or 0 }
    return out
end
-- }}}

-- {{{ bands
local function int_band(id, values)
    local row = { ID = id }
    local n = #values
    local same = true
    for k = 2, n do if values[k] ~= values[1] then same = false end end
    if same then n = 1 end
    row.Num = n
    for k = 1, n do row["Time" .. k] = light.TIMES[k] row["Data" .. k] = values[k] end
    return row
end
local function float_band(id, value)
    return { ID = id, Num = 1, Time1 = 0, Data1 = value }
end

-- one set's 18 colour bands, each a list of four colours (light.TIMES)
local function colours(env, under)
    local c = {}
    for b = 0, light.INT_BANDS - 1 do
        c[b] = { light.PALETTE[b][1], light.PALETTE[b][2], light.PALETTE[b][3], light.PALETTE[b][4] }
    end
    if env.tint then
        for k = 1, 4 do
            local near = scaled(env.tint.color, light.TINT_DAY[k])
            c[14][k], c[16][k] = near, near
            c[15][k], c[17][k] = scaled(near, light.TINT_DEEP), scaled(near, light.TINT_DEEP)
        end
    end
    if env.fog then
        for k = 1, 4 do
            c[7][k], c[8][k] = env.fog.color, env.fog.color
            if k > 1 then c[6][k] = env.fog.color end      -- the horizon meets the fog by day
        end
    end
    if under then
        for k = 1, 4 do c[7][k], c[8][k] = c[17][k], c[17][k] end
    end
    return c
end
-- }}}

-- {{{ light.rows
-- info: parsers.w3i's (or nil); ids: registration.ids(slot) (map,
-- light, light_params). Returns the rows of the four tables and what was
-- used ({ fog = "map" or "default", why_no_fog, tint = true/false, fog_start,
-- fog_end, sets }).
function light.rows(info, ids, yards_per_unit)
    local env = light.from_w3i(info, yards_per_unit)
    local clear, under = ids.light_params, ids.light_params + 1
    local rows = { Light = {}, LightParams = {}, LightIntBand = {}, LightFloatBand = {} }
    rows.Light[1] = {
        ID = ids.light, ContinentID = ids.map, X = 0, Y = 0, Z = 0, FalloffStart = 0, FalloffEnd = 0,
        -- clear, under water, storm, storm under water, the ghost world
        LightParamsID1 = clear, LightParamsID2 = under, LightParamsID3 = clear, LightParamsID4 = under,
        LightParamsID5 = clear,
    }
    local a = light.ALPHA
    local shallow = env.tint and env.tint.alpha
    for k, set in ipairs({ clear, under }) do
        rows.LightParams[#rows.LightParams + 1] = {
            ID = set, HighlightSky = 0, LightSkyboxID = 0, CloudTypeID = 0, Glow = light.GLOW,
            WaterShallowAlpha = shallow or a[1], WaterDeepAlpha = a[2],
            OceanShallowAlpha = shallow or a[3], OceanDeepAlpha = a[4],
        }
        local c = colours(env, k == 2)
        for b = 0, light.INT_BANDS - 1 do
            rows.LightIntBand[#rows.LightIntBand + 1] = int_band(set * 18 - 17 + b, c[b])
        end
        local fog_end, share
        if k == 2 then fog_end, share = light.UNDER_FOG_END, 0
        elseif env.fog then
            fog_end = env.fog["end"]
            share = fog_end > 0 and env.fog.start / fog_end or 0
        else fog_end, share = light.FOG_END, light.FOG_SHARE end
        local floats = { fog_end * 36, share, light.GLOW, 0, 0, 0 }
        for b = 0, light.FLOAT_BANDS - 1 do
            rows.LightFloatBand[#rows.LightFloatBand + 1] = float_band(set * 6 - 5 + b, floats[b + 1])
        end
    end
    local fog_end = env.fog and env.fog["end"] or light.FOG_END
    local said = {
        fog = env.fog and "map" or "default", why_no_fog = env.why_no_fog, tint = env.tint ~= nil,
        fog_start = env.fog and env.fog.start or fog_end * light.FOG_SHARE, fog_end = fog_end,
        light = ids.light, sets = { clear, under },
    }
    return rows, said
end
-- }}}

return light
