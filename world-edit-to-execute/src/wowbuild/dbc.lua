--[[
dbc.lua - WoW 3.3.5a's data tables (DBC) written, and merged over the stock ones (issue W02c)

A DBC file ("WDBC") is a header of five u32 (the mark, rows, fields a row,
bytes a row, bytes of text), then the rows, all the same width, then one
block of text the rows point into (byte offsets; offset 0 is always the
empty string). Every field of the tables here is 4 bytes: u32, i32, f32, a
text offset (str), or a localised text (loc: 16 offsets, one a client
language, then a mask: 17 fields).

The layouts are data (dbc.LAYOUTS), one per table W02c writes (and the
four light tables W02i writes: wowbuild.light), for build
12340 (3.3.5a). Field order and counts come from memory of AzerothCore's
DBCfmt.h and the community's 3.3.5a table descriptions; no source in this
project or the W client's lists them. So every layout is `checked = false`,
except the columns the W client's own readers use (`seen`: field numbers
from 1, as its 016-dbc.h counts), which agree with these layouts. The
test reads every table written here back through the W client's
dbc_open/dbc_u32/dbc_text by LuaJIT's FFI.

This module writes and merges; it never reads a table's fields beyond the
header, the id column and the columns a merge must keep apart (dbc.column),
because the one DBC reader is the W client's (W01: no second reader here).

    local dbc = require("wowbuild.dbc")
    local bytes = dbc.write("Map", { { ID = 900, Directory = "WC3_X", MapName = "X", ... } })
    local merged, n = dbc.merge("Map", stock_bytes, rows, function(id) return id >= 900 and id <= 999 end)
    local bits = dbc.column(stock_bytes, 4)        -- every row's field 4 (u32)
]]

local bw = require("parsers.binwrite")

local dbc = {}

-- the mask after a localised text's 16 offsets, as the 3.3.5a files carry
-- it (unchecked: from memory of the stock tables' dumps)
dbc.LOC_MASK = 0xFF01FE

-- {{{ the layouts
-- each field: { name, kind } with kind u32 i32 f32 str loc; arrays as
-- name1..nameN
local function L(fields)
    local out = {}
    for _, f in ipairs(fields) do
        local name, kind, n = f[1], f[2], f[3]
        if n then
            for i = 1, n do out[#out + 1] = { name .. i, kind } end
        else
            out[#out + 1] = { name, kind }
        end
    end
    return out
end

dbc.LAYOUTS = {
    Map = {
        fields = L({ { "ID", "u32" }, { "Directory", "str" }, { "InstanceType", "u32" }, { "Flags", "u32" },
                     { "PVP", "u32" }, { "MapName", "loc" }, { "AreaTableID", "u32" },
                     { "MapDescription0", "loc" }, { "MapDescription1", "loc" }, { "LoadingScreenID", "u32" },
                     { "MinimapIconScale", "f32" }, { "CorpseMapID", "i32" }, { "CorpseX", "f32" },
                     { "CorpseY", "f32" }, { "TimeOfDayOverride", "i32" }, { "ExpansionID", "u32" },
                     { "RaidOffset", "u32" }, { "MaxPlayers", "u32" } }),
        count = 66, checked = false, seen = { [1] = "ID", [2] = "Directory" },
        seen_by = "the W client's 043-main.c (the map's folder from its id)",
        server_table = "map_dbc",
    },
    AreaTable = {
        fields = L({ { "ID", "u32" }, { "ContinentID", "u32" }, { "ParentAreaID", "u32" }, { "AreaBit", "u32" },
                     { "Flags", "u32" }, { "SoundProviderPref", "u32" }, { "SoundProviderPrefUnderwater", "u32" },
                     { "AmbienceID", "u32" }, { "ZoneMusic", "u32" }, { "IntroSound", "u32" },
                     { "ExplorationLevel", "u32" }, { "AreaName", "loc" }, { "FactionGroupMask", "u32" },
                     { "LiquidTypeID", "u32", 4 }, { "MinElevation", "f32" }, { "AmbientMultiplier", "f32" },
                     { "LightID", "u32" } }),
        count = 36, checked = false, server_table = "areatable_dbc",
    },
    LoadingScreens = {
        fields = L({ { "ID", "u32" }, { "Name", "str" }, { "FileName", "str" }, { "HasWideScreen", "u32" } }),
        count = 4, checked = false,           -- the client's only: the server doesn't load it
    },
    CreatureDisplayInfo = {
        fields = L({ { "ID", "u32" }, { "ModelID", "u32" }, { "SoundID", "u32" }, { "ExtendedDisplayInfoID", "u32" },
                     { "CreatureModelScale", "f32" }, { "CreatureModelAlpha", "u32" }, { "TextureVariation", "str", 3 },
                     { "PortraitTextureName", "str" }, { "SizeClass", "u32" }, { "BloodID", "u32" },
                     { "NPCSoundID", "u32" }, { "ParticleColorID", "u32" }, { "CreatureGeosetData", "u32" },
                     { "ObjectEffectPackageID", "u32" } }),
        count = 16, checked = false,
        seen = { [1] = "ID", [2] = "ModelID", [4] = "ExtendedDisplayInfoID", [5] = "CreatureModelScale",
                 [7] = "TextureVariation1", [8] = "TextureVariation2", [9] = "TextureVariation3" },
        seen_by = "the W client's 041-figure.c (figure_from_display)",
        server_table = "creaturedisplayinfo_dbc",
    },
    CreatureModelData = {
        fields = L({ { "ID", "u32" }, { "Flags", "u32" }, { "ModelName", "str" }, { "SizeClass", "u32" },
                     { "ModelScale", "f32" }, { "BloodID", "u32" }, { "FootprintTextureID", "u32" },
                     { "FootprintTextureLength", "f32" }, { "FootprintTextureWidth", "f32" },
                     { "FootprintParticleScale", "f32" }, { "FoleyMaterialID", "u32" },
                     { "FootstepShakeSize", "u32" }, { "DeathThudShakeSize", "u32" }, { "SoundID", "u32" },
                     { "CollisionWidth", "f32" }, { "CollisionHeight", "f32" }, { "MountHeight", "f32" },
                     { "GeoBoxMinX", "f32" }, { "GeoBoxMinY", "f32" }, { "GeoBoxMinZ", "f32" },
                     { "GeoBoxMaxX", "f32" }, { "GeoBoxMaxY", "f32" }, { "GeoBoxMaxZ", "f32" },
                     { "WorldEffectScale", "f32" }, { "AttachedEffectScale", "f32" },
                     { "MissileCollisionRadius", "f32" }, { "MissileCollisionPush", "f32" },
                     { "MissileCollisionRaise", "f32" } }),
        count = 28, checked = false, seen = { [1] = "ID", [3] = "ModelName" },
        seen_by = "the W client's 041-figure.c (figure_from_display)",
        server_table = "creaturemodeldata_dbc",
    },
    FactionTemplate = {
        fields = L({ { "ID", "u32" }, { "Faction", "u32" }, { "Flags", "u32" }, { "FactionGroup", "u32" },
                     { "FriendGroup", "u32" }, { "EnemyGroup", "u32" }, { "Enemies", "u32", 4 },
                     { "Friend", "u32", 4 } }),
        count = 14, checked = false, server_table = "factiontemplate_dbc",
    },
    Faction = {
        fields = L({ { "ID", "u32" }, { "ReputationIndex", "i32" }, { "ReputationRaceMask", "u32", 4 },
                     { "ReputationClassMask", "u32", 4 }, { "ReputationBase", "i32", 4 },
                     { "ReputationFlags", "u32", 4 }, { "ParentFactionID", "u32" },
                     { "ParentFactionMod", "f32", 2 }, { "ParentFactionCap", "u32", 2 },
                     { "Name", "loc" }, { "Description", "loc" } }),
        count = 57, checked = false, server_table = "faction_dbc",
    },
    -- the light (W02i, wowbuild.light): the client's only, as written here
    -- (no server_table: whether AzerothCore reads them is unchecked); the
    -- W client's 026-light.c reads them through its 074 tables, by its 097
    -- layouts, which give the same widths (15, 9, 34, 34)
    Light = {
        fields = L({ { "ID", "u32" }, { "ContinentID", "u32" }, { "X", "f32" }, { "Y", "f32" }, { "Z", "f32" },
                     { "FalloffStart", "f32" }, { "FalloffEnd", "f32" }, { "LightParamsID", "u32", 8 } }),
        count = 15, checked = false,
        seen = { [1] = "ID", [2] = "ContinentID", [3] = "X", [4] = "Y", [5] = "Z", [6] = "FalloffStart",
                 [7] = "FalloffEnd", [8] = "LightParamsID1", [9] = "LightParamsID2", [10] = "LightParamsID3",
                 [11] = "LightParamsID4", [12] = "LightParamsID5" },
        seen_by = "the W client's 026-light.c (light_open: a light's place, radii and five sets)",
    },
    LightParams = {
        fields = L({ { "ID", "u32" }, { "HighlightSky", "u32" }, { "LightSkyboxID", "u32" }, { "CloudTypeID", "u32" },
                     { "Glow", "f32" }, { "WaterShallowAlpha", "f32" }, { "WaterDeepAlpha", "f32" },
                     { "OceanShallowAlpha", "f32" }, { "OceanDeepAlpha", "f32" } }),
        count = 9, checked = false,
        seen = { [1] = "ID", [3] = "LightSkyboxID", [6] = "WaterShallowAlpha", [7] = "WaterDeepAlpha",
                 [8] = "OceanShallowAlpha", [9] = "OceanDeepAlpha" },
        seen_by = "the W client's 026-light.c (params_at: the water's opacity; light_at: the skybox)",
    },
    LightIntBand = {
        fields = L({ { "ID", "u32" }, { "Num", "u32" }, { "Time", "u32", 16 }, { "Data", "u32", 16 } }),
        count = 34, checked = false,
        seen = { [1] = "ID", [2] = "Num", [3] = "Time1", [18] = "Time16", [19] = "Data1", [34] = "Data16" },
        seen_by = "the W client's 026-light.c (band_at: moments and colours)",
    },
    LightFloatBand = {
        fields = L({ { "ID", "u32" }, { "Num", "u32" }, { "Time", "u32", 16 }, { "Data", "f32", 16 } }),
        count = 34, checked = false,
        seen = { [1] = "ID", [2] = "Num", [3] = "Time1", [18] = "Time16", [19] = "Data1", [34] = "Data16" },
        seen_by = "the W client's 026-light.c (band_at: moments and distances)",
    },
}

-- the order tables are written in, and their files' names
dbc.TABLES = { "Map", "AreaTable", "LoadingScreens", "CreatureDisplayInfo", "CreatureModelData",
               "FactionTemplate", "Faction", "Light", "LightParams", "LightIntBand", "LightFloatBand" }
function dbc.file(name) return "DBFilesClient\\" .. name .. ".dbc" end

-- {{{ expand: a layout's 4-byte columns (a loc field is 17)
local expanded = {}
local function columns(name)
    if expanded[name] then return expanded[name] end
    local layout = dbc.LAYOUTS[name]
    if not layout then error("dbc: no layout for table " .. tostring(name), 0) end
    local cols = {}
    for _, f in ipairs(layout.fields) do
        if f[2] == "loc" then
            for i = 1, 16 do cols[#cols + 1] = { f[1], "locstr", i } end
            cols[#cols + 1] = { f[1], "locmask" }
        else
            cols[#cols + 1] = { f[1], f[2] }
        end
    end
    if #cols ~= layout.count then
        error(string.format("dbc: layout %s has %d columns, %d expected", name, #cols, layout.count), 0)
    end
    expanded[name] = cols
    return cols
end
dbc.columns = columns
-- }}}
-- }}}

-- {{{ the text block
local function new_text()
    local T = { parts = { "\0" }, size = 1, at = { [""] = 0 } }
    function T:add(s)
        s = tostring(s or "")
        if s:find("%z") then error("dbc: a text holds a zero byte", 0) end
        local at = self.at[s]
        if at then return at end
        at = self.size
        self.parts[#self.parts + 1] = s .. "\0"
        self.size = self.size + #s + 1
        self.at[s] = at
        return at
    end
    function T:done() return table.concat(self.parts) end
    return T
end
-- }}}

-- {{{ rows to bytes (records and text, the text's offsets starting at `base`)
local function encode(name, rows, text, base)
    local cols = columns(name)
    local layout = dbc.LAYOUTS[name]
    local known = {}
    for _, f in ipairs(layout.fields) do known[f[1]] = f[2] end
    local B = bw.new()
    for r, row in ipairs(rows) do
        for k in pairs(row) do
            if not known[k] then error(string.format("dbc: %s row %d has a field %s the layout doesn't", name, r, tostring(k)), 0) end
        end
        for _, c in ipairs(cols) do
            local v = row[c[1]]
            local kind = c[2]
            if kind == "u32" then
                v = v or 0
                if type(v) ~= "number" or v < 0 or v >= 2 ^ 32 or v ~= math.floor(v) then
                    error(string.format("dbc: %s.%s = %s isn't a u32", name, c[1], tostring(v)), 0)
                end
                B:u32(v)
            elseif kind == "i32" then
                v = v or 0
                if type(v) ~= "number" or v < -2 ^ 31 or v >= 2 ^ 31 or v ~= math.floor(v) then
                    error(string.format("dbc: %s.%s = %s isn't an i32", name, c[1], tostring(v)), 0)
                end
                B:i32(v)
            elseif kind == "f32" then
                B:f32(tonumber(v) or 0)
            elseif kind == "str" or kind == "locstr" then
                -- a localised text is written in every language's slot, so
                -- a client of any language shows it
                B:u32(base + text:add(v))
            elseif kind == "locmask" then
                B:u32(dbc.LOC_MASK)
            end
        end
    end
    return B:done()
end
-- }}}

-- {{{ dbc.write
-- rows: a list of { field name = value }; loc fields take one string. A
-- field left out is 0 (or ""). Returns the file's bytes.
function dbc.write(name, rows)
    local cols = columns(name)
    local text = new_text()
    local records = encode(name, rows, text, 0)
    local block = text:done()
    return bw.new():str("WDBC"):u32(#rows):u32(#cols):u32(#cols * 4):u32(#block):done() .. records .. block
end
-- }}}

-- {{{ dbc.sql_values
-- One row as SQL literals, one a column in the table's own order (a loc
-- field is its 16 texts and its mask), for AzerothCore's <table>_dbc
-- copies in the world database, which hold the same columns as the file
-- (unchecked: from memory of AzerothCore's schema)
local function sql_text(s)
    return "'" .. tostring(s or ""):gsub("\\", "\\\\"):gsub("'", "''") .. "'"
end
function dbc.sql_values(name, row)
    local out = {}
    for _, c in ipairs(columns(name)) do
        local v, kind = row[c[1]], c[2]
        if kind == "u32" or kind == "i32" then out[#out + 1] = string.format("%d", v or 0)
        elseif kind == "f32" then out[#out + 1] = string.format("%.6g", tonumber(v) or 0)
        elseif kind == "str" or kind == "locstr" then out[#out + 1] = sql_text(v)
        elseif kind == "locmask" then out[#out + 1] = string.format("%d", dbc.LOC_MASK) end
    end
    return out
end
-- }}}

-- {{{ header
local function u32(s, at)
    local a, b, c, d = s:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end
function dbc.header(bytes, name)
    local label = name or "a table"
    if type(bytes) ~= "string" or #bytes < 20 or bytes:sub(1, 4) ~= "WDBC" then
        error("dbc: " .. label .. " is not a WDBC table", 0)
    end
    local h = { rows = u32(bytes, 4), fields = u32(bytes, 8), row_len = u32(bytes, 12), text_len = u32(bytes, 16) }
    if 20 + h.rows * h.row_len + h.text_len ~= #bytes then
        error(string.format("dbc: %s's header says %d rows of %d bytes and %d bytes of text, but the file is %d bytes",
            label, h.rows, h.row_len, h.text_len, #bytes), 0)
    end
    return h
end
-- }}}

-- {{{ dbc.column
-- Every row's field n (from 1) as a u32, in row order.
function dbc.column(bytes, n)
    local h = dbc.header(bytes)
    local out = {}
    for r = 0, h.rows - 1 do out[#out + 1] = u32(bytes, 20 + r * h.row_len + (n - 1) * 4) end
    return out
end
-- }}}

-- {{{ dbc.merge
-- The stock table's rows (bytes as the client's archives hold them) with
-- `rows` added. A stock row whose id `drop(id)` names is left out (an
-- earlier build's row, or one in this project's id ranges). The stock
-- table must have the layout's width (106's rule: another width means
-- another client build), else it is an error naming both. Returns the
-- bytes and { stock, dropped, ours, dropped_ids }.
function dbc.merge(name, stock, rows, drop)
    local cols = columns(name)
    local h = dbc.header(stock, name .. ".dbc")
    if h.fields ~= #cols or h.row_len ~= #cols * 4 then
        error(string.format("dbc: the stock %s.dbc has %d fields (%d bytes a row); this layout for build 12340 has %d (%d bytes): another client build?",
            name, h.fields, h.row_len, #cols, #cols * 4), 0)
    end
    local kept, dropped = {}, {}
    for r = 0, h.rows - 1 do
        local at = 20 + r * h.row_len
        local id = u32(stock, at)
        if drop and drop(id) then dropped[#dropped + 1] = id
        else kept[#kept + 1] = stock:sub(at + 1, at + h.row_len) end
    end
    local stock_text = stock:sub(20 + h.rows * h.row_len + 1)
    local text = new_text()
    -- our text goes after the stock text; offset 0 of ours (the empty string)
    -- is never used (the stock block's own offset 0 is), so skip its byte
    text.parts, text.size = {}, 0
    text.at = { [""] = -#stock_text }       -- "" points at the stock block's 0
    local records = encode(name, rows, text, #stock_text)
    local block = stock_text .. text:done()
    local n = #kept + #rows
    local bytes = bw.new():str("WDBC"):u32(n):u32(#cols):u32(#cols * 4):u32(#block):done()
        .. table.concat(kept) .. records .. block
    return bytes, { stock = h.rows, dropped = #dropped, ours = #rows, dropped_ids = dropped }
end
-- }}}

return dbc
