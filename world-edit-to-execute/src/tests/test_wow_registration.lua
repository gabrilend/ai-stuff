--[[
Tests for a converted map's registration and its output forms (Issue W02c):
the id scheme, the tables written (Map, AreaTable, LoadingScreens,
CreatureDisplayInfo, CreatureModelData, FactionTemplate, Faction), the merge
with the stock tables, the factions' hostility, the loading screen picture,
the area id in every ADT chunk, the server's SQL, patch-W.MPQ, map.lua (the
map Test Map opens) and the creature list for the W client, and several
maps in one build folder keeping their slots.

Everything written is read back through the W client's own readers by
LuaJIT's FFI where it has one: tables through 016-dbc (dbc_open, dbc_u32,
dbc_text), the archive through 015-mpq (mpq_open, mpq_read), the picture
through 017-blp (blp_decode_level), all in libwreaders.so; the creature
list through 035-creatures (creatures_read), which isn't in that library,
so it is compiled here from the W client's sources when $W_CLIENT_SRC names
its checkout (cc, into a scratch folder). Without them those checks are
skipped and counted.

The reader library is found in $W_CLIENT_BUILD (a folder holding
libwreaders.so and the wreaders.h its scripts/build writes), else the W
client's usual build folder. Real maps and the archive need StormLib
(src/mpq/stormlib.lua finds it, or $STORMLIB_PATH).

    luajit src/tests/test_wow_registration.lua [project folder]
]]

-- {{{ Setup paths
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local bit = require("bit")
local w3e = require("parsers.w3e")
local coords = require("wowbuild.coords")
local dbc = require("wowbuild.dbc")
local registration = require("wowbuild.registration")
local loadscreen = require("wowbuild.loadscreen")
local output = require("wowbuild.output")
local wowbuild = require("wowbuild")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count, skip_count = 0, 0, 0
local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end
local function skip(name, why)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. ": " .. why)
end
local function test_section(name) print("\n=== " .. name .. " ===") end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function u32(s, at) local a, b, c, d = s:byte(at + 1, at + 4) return a + b * 256 + c * 65536 + d * 16777216 end
local function tag_at(s, at) return s:sub(at + 1, at + 4):reverse() end
local function read_file(path) local f = io.open(path, "rb") if not f then return nil end local s = f:read("*a") f:close() return s end
local function load_data(path)
    local chunk = loadfile(path, "t", {})
    if chunk and setfenv then setfenv(chunk, {}) end
    local ok, t = pcall(chunk or error)
    return ok and t or nil
end
local function f32_of(n) local b = ffi.new("uint32_t[1]", n) return ffi.cast("float *", b)[0] end
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))
-- }}}

-- {{{ The W client's readers
local W, WHY
do
    local build = os.getenv("W_CLIENT_BUILD") or "/mnt/kaun/custom-client/tmp/tmp/build"
    local f = io.open(build .. "/wreaders.h", "r")
    if f then
        local ok, err = pcall(function()
            ffi.cdef(f:read("*a"))
            W = ffi.load(build .. "/libwreaders.so")
        end)
        if not ok then W = nil print("(the W client's reader library didn't load: " .. tostring(err) .. ")") end
        f:close()
    end
    if W then WHY = ffi.new("WWhy") print("(the W client's reader: " .. build .. ")")
    else print("(no W client reader library in " .. build .. "; its checks are skipped)") end
    pcall(ffi.cdef, "void free(void *);")
end

-- the W client's creature list reader (035), compiled from its sources
local WC
if W and os.getenv("W_CLIENT_SRC") then
    local src = os.getenv("W_CLIENT_SRC") .. "/src"
    local lib = TMP .. "/libwcreatures.so"
    local cmd = string.format("cc -std=c11 -D_POSIX_C_SOURCE=200809L -O2 -fPIC -shared %s %s %s -lm -lpthread -o %s 2>&1",
        quote(src .. "/013-errors.c"), quote(src .. "/018-maps.c"), quote(src .. "/035-creatures.c"), quote(lib))
    local p = io.popen(cmd)
    local said = p:read("*a")
    p:close()
    local ok, err = pcall(function()
        ffi.cdef[[
            typedef struct { uint32_t guid, entry; int display; float size; double x, y, z; float facing; char name[64]; int tile; } Spawn;
            typedef struct { Spawn *spawns; int n; } SpawnList;
            WErr creatures_read(const char *path, SpawnList *out, WWhy *why);
            void creatures_free(SpawnList *l);
        ]]
        WC = ffi.load(lib)
    end)
    if ok then print("(the W client's creature list reader, compiled from " .. src .. ")")
    else WC = nil print("(the creature list reader didn't build: " .. tostring(err) .. " " .. said .. ")") end
end

-- a table through the W client's 016-dbc: { rows, fields, u32(r, f), text(r, f) } or nil, why
local function w_table(bytes)
    local buf = ffi.new("unsigned char[?]", #bytes)
    ffi.copy(buf, bytes, #bytes)
    local d = ffi.new("Dbc")
    if W.dbc_open(d, buf, #bytes, WHY) ~= 0 then return nil, ffi.string(WHY.text) end
    return { rows = d.rows, fields = d.fields, keep = buf,
             u32 = function(r, f) return W.dbc_u32(d, r, f) end,
             text = function(r, f) return ffi.string(W.dbc_text(d, r, f)) end }
end

-- checks every column of every row of a written table against its rows,
-- through the W client's reader. Returns nil or the first difference.
local function compare_table(name, bytes, rows)
    local t, err = w_table(bytes)
    if not t then return "the W client can't open it: " .. err end
    local cols = dbc.columns(name)
    if t.rows ~= #rows then return string.format("%d rows read, %d written", t.rows, #rows) end
    if t.fields ~= #cols then return string.format("%d fields read, %d in the layout", t.fields, #cols) end
    for r, row in ipairs(rows) do
        for f, c in ipairs(cols) do
            local want, kind = row[c[1]], c[2]
            local got
            if kind == "str" or kind == "locstr" then got, want = t.text(r - 1, f), want or ""
            elseif kind == "locmask" then got, want = t.u32(r - 1, f), dbc.LOC_MASK
            elseif kind == "f32" then
                got = f32_of(t.u32(r - 1, f))
                want = tonumber(ffi.new("float", want or 0))
            elseif kind == "i32" then got = t.u32(r - 1, f); if got >= 2 ^ 31 then got = got - 2 ^ 32 end; want = want or 0
            else got, want = t.u32(r - 1, f), want or 0 end
            if got ~= want then return string.format("row %d field %d (%s): %s, written %s", r, f, c[1], tostring(got), tostring(want)) end
        end
    end
end
-- }}}

-- {{{ The id scheme
test_section("The id scheme")
do
    local a, z = registration.ids(0), registration.ids(99)
    test("slot 0: map 900, zone 9000, loading screen 900, looks from 50000, factions from 3000",
        a.map == 900 and a.area == 9000 and a.loading_screen == 900 and a.display == 50000 and a.faction == 3000)
    test("slot 0: templates from 9000000, spawns from 1000000, AreaBit 4095",
        a.entry == 9000000 and a.guid == 1000000 and a.area_bit == 4095)
    test("map ids keep three digits (AzerothCore's mmaps generator reads three)", z.map == 999 and #tostring(z.map) == 3)
    test("entries and guids stay under 2^24 (a creature's object id holds 24 bits of each)",
        z.entry_last < 2 ^ 24 and z.guid_last < 2 ^ 24)
    test("areas stay under 65536 (the server's map files keep 16 bits)", z.area_last < 65536)
    test("AreaBits stay under 4096 (128 x 32 explored-zone bits)", z.area_bit >= 0 and a.area_bit < 4096)
    local overlap = false
    for s = 0, 98 do
        local i, j = registration.ids(s), registration.ids(s + 1)
        for kind in pairs(registration.SCHEME) do
            if i[kind .. "_last"] >= j[kind] then overlap = true end
        end
    end
    test("no two slots share an id of any kind", not overlap)
    test("a slot's blocks hold W02b's limits: 10000 templates, 50000 spawns, 1000 looks, 100 factions",
        registration.SCHEME.entry.width == 10000 and registration.SCHEME.guid.width == 50000
        and registration.SCHEME.display.width == 1000 and registration.SCHEME.faction.width == 100)
    test("W02b's placeholders are gone: the SQL defaults are slot 0's",
        require("wowbuild.creatures").DEFAULTS.map_id == 900 and require("wowbuild.creatures").DEFAULTS.entry_base == 9000000)
    test("a map id names its slot; one outside the scheme names none",
        registration.slot_of_map(923) == 23 and registration.slot_of_map(9000) == nil and registration.slot_of_map(899) == nil)
    test("a WC3 map's colour codes and line breaks are taken out of its name",
        registration.clean_text("|cffff0000Red|r Wars|nof |CFF00FF00Doom|R\n") == "Red Wars of Doom")
    test("a model path becomes CreatureModelData's .mdx name; a map's own WC3 model keeps its name",
        registration.model_name("Creature\\Wolf\\Wolf.m2") == "Creature\\Wolf\\Wolf.mdx"
        and registration.model_name("war3mapImported\\X.mdx", true) == "war3mapImported\\X.mdx")
end
-- }}}

-- {{{ The tables
test_section("The tables: layouts and bytes")
do
    local counts = { Map = 66, AreaTable = 36, LoadingScreens = 4, CreatureDisplayInfo = 16, CreatureModelData = 28,
                     FactionTemplate = 14, Faction = 57 }
    local all = true
    for name, n in pairs(counts) do if #dbc.columns(name) ~= n then all = false end end
    test("every layout has its 3.3.5a column count (Map 66, AreaTable 36, LoadingScreens 4, CreatureDisplayInfo 16, CreatureModelData 28, FactionTemplate 14, Faction 57)", all)
    local seen_ok = true
    for name, layout in pairs(dbc.LAYOUTS) do
        for f, field in pairs(layout.seen or {}) do
            local c = dbc.columns(name)[f]
            if not c or c[1] ~= field then seen_ok = false end
        end
    end
    test("the columns the W client's readers use are where these layouts put them", seen_ok)
    local unchecked = true
    for _, layout in pairs(dbc.LAYOUTS) do if layout.checked ~= false then unchecked = false end end
    test("every layout is marked unchecked (from memory, not from a source here)", unchecked)

    local rows = { { ID = 900, Directory = "WC3_A", MapName = "Ä map's \"name\"", AreaTableID = 9000, LoadingScreenID = 900,
                     MinimapIconScale = 1, CorpseMapID = -1, TimeOfDayOverride = -1 },
                   { ID = 901, Directory = "WC3_B", MapName = "", CorpseMapID = -1 } }
    local bytes = dbc.write("Map", rows)
    local h = dbc.header(bytes)
    test("a written table's header: rows, fields, bytes a row", h.rows == 2 and h.fields == 66 and h.row_len == 264)
    test("its text block starts with the empty string", bytes:sub(21 + 2 * 264, 21 + 2 * 264) == "\0")
    test("a text used twice is stored once", select(2, bytes:gsub("WC3_A", "")) == 1)
    local bad_field = pcall(dbc.write, "Map", { { ID = 1, Nope = 2 } })
    local bad_u32 = pcall(dbc.write, "Map", { { ID = -1 } })
    test("a field the layout lacks, or a value out of its kind, is refused", not bad_field and not bad_u32)
    if W then
        test("the W client reads every column back as written", compare_table("Map", bytes, rows) == nil, compare_table("Map", bytes, rows))
        local t = w_table(bytes)
        test("the W client finds map 901's folder the way 043-main.c does (field 1 the id, 2 the folder)",
            t and t.u32(1, 1) == 901 and t.text(1, 2) == "WC3_B")
    else
        skip("the W client reads a written table", "no library")
    end
end

test_section("The tables: merged over the stock ones")
do
    -- a made stock table: three maps, one inside W02c's ids (an earlier build's)
    local stock = dbc.write("Map", { { ID = 0, Directory = "Azeroth", MapName = "Eastern Kingdoms", CorpseMapID = -1 },
                                     { ID = 1, Directory = "Kalimdor", MapName = "Kalimdor", CorpseMapID = -1 },
                                     { ID = 905, Directory = "WC3_Old", MapName = "old build", CorpseMapID = -1 } })
    local ours = { { ID = 900, Directory = "WC3_New", MapName = "new", CorpseMapID = -1 } }
    local merged, n = dbc.merge("Map", stock, ours, function(id) return registration.in_scheme("map", id) end)
    test("stock rows kept, the one inside W02c's ids dropped, ours added", n.stock == 3 and n.dropped == 1 and n.ours == 1
        and n.dropped_ids[1] == 905)
    local cols = dbc.column(merged, 1)
    test("the merged table's ids: 0, 1, 900", #cols == 3 and cols[1] == 0 and cols[2] == 1 and cols[3] == 900)
    if W then
        local t, err = w_table(merged)
        test("the W client opens the merged table", t ~= nil, err)
        if t then
            test("the stock rows' texts still read (their offsets kept)", t.text(0, 2) == "Azeroth" and t.text(1, 6) == "Kalimdor")
            test("our row's texts read (offsets after the stock text)", t.text(2, 2) == "WC3_New" and t.text(2, 6) == "new"
                and t.text(2, 24) == "")
        end
    else
        skip("the W client reads a merged table", "no library")
    end
    local narrow = "WDBC" .. string.char(0, 0, 0, 0, 65, 0, 0, 0, 4, 1, 0, 0, 1, 0, 0, 0) .. "\0"
    local ok, err = pcall(dbc.merge, "Map", narrow, ours)
    test("a stock table of another width (another client build) is refused, both widths named",
        not ok and tostring(err):find("65 fields") and tostring(err):find("66"), tostring(err))
    local cut = pcall(dbc.merge, "Map", stock:sub(1, -3), ours)
    test("a stock table cut short is refused", not cut)
end
-- }}}

-- {{{ The loading screen
test_section("The loading screen picture")
do
    -- a 4 x 2 picture: red, green, blue, white over four greys
    local px = {}
    local colours = { { 255, 0, 0 }, { 0, 255, 0 }, { 0, 0, 255 }, { 255, 255, 255 }, { 10, 10, 10 }, { 60, 60, 60 }, { 110, 110, 110 }, { 160, 160, 160 } }
    for _, c in ipairs(colours) do px[#px + 1] = string.char(c[1], c[2], c[3], 255) end
    local img = { width = 4, height = 2, rgba = table.concat(px) }
    local bytes, levels = loadscreen.blp2(img, 8)
    test("a BLP2 of 8 x 8 with its smaller copies down to 1 x 1 (4 levels)", bytes:sub(1, 4) == "BLP2" and levels == 4
        and bytes:byte(9) == 3 and u32(bytes, 12) == 8)
    if W then
        local buf = ffi.new("unsigned char[?]", #bytes)
        ffi.copy(buf, bytes, #bytes)
        local out = ffi.new("BlpImage")
        local ok = W.blp_decode_level(buf, #bytes, 0, out, WHY) == 0
        test("the W client decodes it", ok, not ok and ffi.string(WHY.text) or nil)
        if ok then
            local function at(x, y) local d = (y * out.width + x) * 4 return out.rgba[d], out.rgba[d + 1], out.rgba[d + 2], out.rgba[d + 3] end
            local r1, g1, b1 = at(0, 0)
            local r2, g2, b2 = at(5, 0)
            local r3, g3, b3, a3 = at(7, 7)
            test("its pixels are the picture's, in its colours (red top left, blue top right, light grey bottom right)",
                out.width == 8 and r1 == 255 and g1 == 0 and b1 == 0 and r2 == 0 and g2 == 0 and b2 == 255
                and r3 == 160 and g3 == 160 and b3 == 160 and a3 == 255)
            W.blp_free(out)
            local small = ffi.new("BlpImage")
            local ok3 = W.blp_decode_level(buf, #bytes, 3, small, WHY) == 0
            test("its smallest copy (1 x 1) decodes too", ok3 and small.width == 1 and small.height == 1)
            if ok3 then W.blp_free(small) end
        end
    else
        skip("the W client decodes the loading screen", "no library")
    end
end
-- }}}

-- {{{ A made map, converted
-- a 129 x 129 ground (one ADT tile), with a hill, water in one corner, two
-- players, three units; the model table made here
local function made_terrain(seed)
    local W3, H3 = 129, 129
    local tps = {}
    for j = 0, H3 - 1 do
        tps[j] = {}
        for i = 0, W3 - 1 do
            local hill = 200 * math.exp(-((i - 64) ^ 2 + (j - 64) ^ 2) / 400) + (seed or 0)
            tps[j][i] = { height = 8192 + hill, water_level = (i < 10 and j < 10) and 8300 or 0, has_water = i < 10 and j < 10,
                          layer_height = 2, ground_texture = (i > 64) and 1 or 0, texture_details = 0, cliff_texture = 15,
                          is_blight = false, is_ramp = false, is_boundary = false }
        end
    end
    return { width = W3, height = H3, offset_x = -8192, offset_y = -8192, tileset_code = "L",
             ground_tilesets = { "Ldrt", "Lgrs" }, tilepoints = tps }
end
local terrain = made_terrain()
local L0 = coords.layout(terrain)
local function at(i, j) return L0.offset_x + i * 128, L0.offset_y + j * 128 end
local function unit(id, player, i, j, angle)
    local x, y = at(i, j)
    return { id = id, variation = 0, position = { x = x, y = y, z = 0 }, angle = angle or 0, scale = { x = 1, y = 1, z = 1 },
             flags = 2, player = player, creation_number = 0 }
end
local made_models = TMP .. "/models.lua"
do
    local f = assert(io.open(made_models, "wb"))
    f:write([[
return { format = 1,
  doodads = { types = {}, classes = {} },
  units = {
    fallback = { name = "Unmapped unit", wow = "World\\Test\\Crate.m2", checked = false },
    types = { hfoo = { name = "Footman", wow = "Creature\\Test\\Footman.m2", scale = 1.5, radius = 1, reach = 2, checked = false },
              nwlf = { name = "Timber Wolf", wow = "Creature\\Test\\Wolf.m2", radius = 2, checked = false } },
  },
}
]])
    f:close()
end
local function made_map(name)
    local sx1, sy1 = at(20, 20)
    local sx2, sy2 = at(100, 100)
    return {
        units = { version = 8, units = { unit("hfoo", 0, 30, 30, 0.3), unit("hfoo", 1, 90, 90, 2), unit("nwlf", 12, 64, 64, 4) } },
        info = { version = 25, name = name, flags = { use_custom_forces = false },
                 players = { { number = 0, name = "Red", type = "computer", start_x = sx1, start_y = sy1 },
                             { number = 1, name = "Blue", type = "human", start_x = sx2, start_y = sy2 } } },
        objects = {},
    }
end

-- a made stock table folder (so the merge path runs without the owner's client)
local STOCK = TMP .. "/stock"
os.execute("mkdir -p " .. quote(STOCK))
do
    local function put(name, rows)
        local f = assert(io.open(STOCK .. "/" .. name .. ".dbc", "wb"))
        f:write(dbc.write(name, rows))
        f:close()
    end
    put("Map", { { ID = 0, Directory = "Azeroth", MapName = "Eastern Kingdoms", CorpseMapID = -1 },
                 { ID = 1, Directory = "Kalimdor", MapName = "Kalimdor", CorpseMapID = -1 } })
    -- AreaBit 4095 is taken by a stock zone: the map must move its own
    put("AreaTable", { { ID = 1, ContinentID = 0, AreaBit = 4095, AreaName = "Dun Morogh" },
                       { ID = 12, ContinentID = 0, AreaBit = 4094, AreaName = "Elwynn Forest" } })
    put("LoadingScreens", { { ID = 1, Name = "Kalimdor", FileName = "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor.blp" } })
    put("CreatureDisplayInfo", { { ID = 1, ModelID = 1, CreatureModelScale = 1 } })
    put("CreatureModelData", { { ID = 1, ModelName = "Creature\\Wolf\\Wolf.mdx", ModelScale = 1 } })
    put("FactionTemplate", { { ID = 1, Faction = 1, FactionGroup = 3, FriendGroup = 2, EnemyGroup = 12 } })
    -- (no Faction.dbc: a stock table missing is said, not fatal)
end

test_section("A made map: its rows")
local BUILD = TMP .. "/build"
local report, job, P, C = wowbuild.convert("made.w3x", BUILD, { terrain = terrain, map = made_map("|cffffcc00Made|r Map"),
    models = made_models, name = "WC3_made", stock_dbc = STOCK, ground = "W3E!made ground" })
local reg = report.registration
local ids = reg.ids
do
    test("the first map of a build folder takes slot 0: map 900", reg.slot == 0 and ids.map == 900)
    test("the stock table holds AreaBits 4095 and 4094: the map's zone takes 4093, with a warning",
        ids.area_bit == 4093 and #reg.warnings >= 1 and reg.warnings[1]:find("AreaBit 4095"))
    test("the map's name, without its colour codes", reg.map_name == "Made Map")
    test("the stock folder's missing Faction.dbc is said", (function()
        for _, w in ipairs(reg.warnings) do if w:find("no stock Faction.dbc") then return true end end
    end)())
    test("its creatures' looks: footman and wolf (two displays), factions: Red, Blue, the two neutrals",
        reg.tables.CreatureDisplayInfo.rows == 2 and reg.tables.CreatureModelData.rows == 2 and reg.tables.FactionTemplate.rows == 4
        and reg.tables.Faction.rows == 4)
    local r = load_data(BUILD .. "/World/Maps/WC3_made/registration.lua")
    test("registration.lua beside the ground reads as data, with its slot and rows", r and r.slot == 0 and r.rows.Map[1].ID == 900
        and r.rows.AreaTable[1].ContinentID == 900 and r.rows.Map[1].AreaTableID == ids.area
        and r.rows.Map[1].LoadingScreenID == ids.loading_screen)
    test("the loading screen row names the picture written beside the ground", r and r.rows.LoadingScreens[1].FileName
        == "World\\Maps\\WC3_made\\WC3_made_loading.blp" and read_file(BUILD .. "/World/Maps/WC3_made/WC3_made_loading.blp") ~= nil)
    test("the picture was drawn from the ground (the made map has no preview)", reg.loading_screen == "ground")
    test("display rows name W02b's display ids, their models as .mdx, their sizes", r and r.rows.CreatureDisplayInfo[1].ID == C.displays[1].id
        and r.rows.CreatureModelData[1].ModelName == "Creature\\Test\\Footman.mdx"
        and math.abs(r.rows.CreatureDisplayInfo[1].CreatureModelScale - 1.5) < 1e-9)
    local sql = read_file(BUILD .. "/server/world.sql") or ""
    test("world.sql names slot 0's blocks", sql:find("SET @MAP := 900;", 1, true) and sql:find("SET @ENTRY := 9000000;", 1, true)
        and sql:find("SET @GUID := 1000000;", 1, true))
    -- every faction and display the SQL names has its row in the tables
    local ft = {}
    for _, row in ipairs(r.rows.FactionTemplate) do ft[row.ID] = true end
    local di = {}
    for _, row in ipairs(r.rows.CreatureDisplayInfo) do di[row.ID] = true end
    local bad = 0
    for _, t in ipairs(C.templates) do if not ft[t.faction.template] or not di[t.display.id] then bad = bad + 1 end end
    test("every template's faction and look has its row in the client's tables", bad == 0)
end

test_section("A made map: the factions' hostility, as the client and server work it out")
do
    -- FactionTemplateEntry::IsHostileTo / IsFriendlyTo (3.3.5a): masks, and
    -- the four named enemies and friends (none here)
    local r = load_data(BUILD .. "/World/Maps/WC3_made/registration.lua")
    local by = {}
    for _, row in ipairs(r.rows.FactionTemplate) do by[row.ID] = row end
    local function hostile(a, b)
        if a.ID == b.ID then return false end
        return bit.band(a.EnemyGroup, b.FactionGroup) ~= 0
    end
    local function friendly(a, b)
        if a.ID == b.ID then return true end
        return bit.band(a.FriendGroup, b.FactionGroup) ~= 0 or bit.band(a.FactionGroup, b.FriendGroup) ~= 0
    end
    local red, blue, nh, np = by[ids.faction], by[ids.faction + 1], by[ids.faction + 2], by[ids.faction + 3]
    test("Red and Blue are hostile to each other", hostile(red, blue) and hostile(blue, red))
    test("Neutral Hostile is hostile to both, and they to it", hostile(nh, red) and hostile(nh, blue) and hostile(red, nh))
    test("Neutral Passive is hostile to no one, and no one to it",
        not hostile(np, red) and not hostile(np, nh) and not hostile(red, np) and not hostile(nh, np))
    test("each is friendly to itself, and no two are friends", friendly(red, red) and not friendly(red, blue) and not friendly(nh, np))
    local player = { ID = 1, FactionGroup = 1 + 2, FriendGroup = 2, EnemyGroup = 4 + 8 }   -- a stock Alliance player's
    local none = true
    for _, f in pairs(by) do if hostile(f, player) or hostile(player, f) then none = false end end
    test("a stock player's faction is neutral to every converted one (no group bit under 16 is used)", none)
    local faction_rows = r.rows.Faction
    test("each faction template has its Faction row: same number, no reputation", #faction_rows == 4
        and faction_rows[1].ID == red.Faction and faction_rows[1].ReputationIndex == -1 and faction_rows[1].Name == "Red")
end

test_section("A made map: the forms")
do
    -- the overlay's tables: these rows only, every column through the W client's reader
    local r = load_data(BUILD .. "/World/Maps/WC3_made/registration.lua")
    if W then
        local bad = {}
        for _, name in ipairs(dbc.TABLES) do
            local bytes = read_file(BUILD .. "/DBFilesClient/" .. name .. ".dbc")
            local why = "not written"
            if bytes then why = compare_table(name, bytes, r.rows[name]) end
            if why then bad[#bad + 1] = name .. ": " .. why end
        end
        test("DBFilesClient/ holds the seven tables with this map's rows only, every column as written (W client's reader)",
            #bad == 0, table.concat(bad, "; "))
        -- the client side the way Test Map would use it: the map's id from
        -- map.lua, its folder from the overlay's Map.dbc, the ground there
        local m = load_data(BUILD .. "/map.lua")
        local t = w_table(read_file(BUILD .. "/DBFilesClient/Map.dbc"))
        local dir
        for row = 0, t.rows - 1 do if t.u32(row, 1) == m.map.id then dir = t.text(row, 2) end end
        test("map.lua's id finds its folder in the overlay's Map.dbc, and the folder holds its WDT",
            dir == "WC3_made" and read_file(BUILD .. "/World/Maps/" .. dir .. "/" .. dir .. ".wdt") ~= nil)
    else
        skip("the overlay's tables through the W client's reader", "no library")
    end

    -- the area id in every chunk (MCNK header offset 52; the W client's reader doesn't keep it)
    local adt_bytes = read_file(BUILD .. "/World/Maps/WC3_made/WC3_made_32_32.adt") or ""
    local chunks, wrong = 0, 0
    local pos = 0
    while pos + 8 <= #adt_bytes do
        local tag, size = tag_at(adt_bytes, pos), u32(adt_bytes, pos + 4)
        if tag == "MCNK" then
            chunks = chunks + 1
            if u32(adt_bytes, pos + 8 + 52) ~= ids.area then wrong = wrong + 1 end
        end
        pos = pos + 8 + size
    end
    test("every chunk of the ADT stands in the map's zone (" .. ids.area .. ")", chunks == 256 and wrong == 0,
        chunks .. " chunks, " .. wrong .. " wrong")

    -- the server's copies
    local sql = read_file(BUILD .. "/server/dbc.sql") or ""
    local counts_ok, n_rows = true, 0
    for name in pairs({ Map = 1, AreaTable = 1, CreatureDisplayInfo = 1, CreatureModelData = 1, FactionTemplate = 1, Faction = 1 }) do
        local tbl = dbc.LAYOUTS[name].server_table
        local block = sql:match("REPLACE INTO `" .. tbl .. "` VALUES\n(.-)\n%-%- }}}")
        if not block then counts_ok = false
        else
            for line in block:gmatch("[^\n]+") do
                n_rows = n_rows + 1
                -- columns: split on ", " outside quotes
                local n, inq, k = 1, false, 1
                local body = line:match("^  %((.*)%)[,;]$") or ""
                while k <= #body do
                    local ch = body:sub(k, k)
                    if ch == "'" then
                        if inq and body:sub(k + 1, k + 1) == "'" then k = k + 1 else inq = not inq end
                    elseif ch == "," and not inq then n = n + 1 end
                    k = k + 1
                end
                if n ~= #dbc.columns(name) then counts_ok = false end
            end
        end
    end
    test("server/dbc.sql: every table but LoadingScreens (the server doesn't load it), each row with its table's column count",
        counts_ok and n_rows == 1 + 1 + 2 + 2 + 4 + 4 and not sql:find("loadingscreens", 1, true), n_rows .. " rows")
    local merged = read_file(BUILD .. "/server/dbc/Map.dbc")
    test("server/dbc/: the stock tables with this map's rows added (Map: 0, 1, 900)", merged and (function()
        local c = dbc.column(merged, 1)
        return #c == 3 and c[1] == 0 and c[2] == 1 and c[3] == 900
    end)())
    test("server/dbc/ has no LoadingScreens (the server's own list) and no Faction (no stock one given)",
        read_file(BUILD .. "/server/dbc/LoadingScreens.dbc") == nil and read_file(BUILD .. "/server/dbc/Faction.dbc") == nil)

    -- patch-W.MPQ, through StormLib and through the W client's archive reader
    local patch = BUILD .. "/patch-W.MPQ"
    local storm_here = not tostring(table.concat(reg.warnings, "\n")):find("StormLib not found", 1, true)
    if storm_here then
        test("patch-W.MPQ is written, with the ground, the picture and the six merged tables",
            reg.patch and reg.patch.tables and #reg.patch.files == 3 + 1 + 6, reg.patch and #reg.patch.files or "none")
    else
        test("without StormLib the build stands, without patch-W.MPQ, and says so",
            reg.patch == nil and read_file(patch) == nil)
    end
    local storm_ok, archive = pcall(require("mpq.stormlib").open, patch)
    if storm_ok then
        local names = {}
        for _, e in ipairs(archive:list("*")) do names[e.name] = true end
        test("StormLib lists its files by name (its listfile, which AzerothCore's extractor reads)", names["DBFilesClient\\Map.dbc"]
            and names["World\\Maps\\WC3_made\\WC3_made.wdt"] and names["World\\Maps\\WC3_made\\WC3_made_32_32.adt"])
        test("its ADT is the overlay's, byte for byte", archive:read("World\\Maps\\WC3_made\\WC3_made_32_32.adt") == adt_bytes)
        archive:close()
    else
        skip("patch-W.MPQ through StormLib", tostring(archive))
    end
    if W then
        local a = ffi.new("MpqArchive")
        local ok = W.mpq_open(a, patch, WHY) == 0
        test("the W client's archive reader opens patch-W.MPQ (version 2)", ok, not ok and ffi.string(WHY.text) or nil)
        if ok then
            local function read(name)
                local n = ffi.new("size_t[1]")
                local p = W.mpq_read(a, name, n, WHY)
                if p == nil then return nil end
                local s = ffi.string(p, n[0])
                ffi.C.free(p)
                return s
            end
            test("it reads the ADT out of it, byte for byte", read("World\\Maps\\WC3_made\\WC3_made_32_32.adt") == adt_bytes)
            local mt = read("DBFilesClient\\Map.dbc")
            local t = mt and w_table(mt)
            local found
            if t then for row = 0, t.rows - 1 do if t.u32(row, 1) == 900 then found = t.text(row, 2) end end end
            test("its Map.dbc is the merged one: the stock maps and map 900 in folder WC3_made", t and t.rows == 3 and found == "WC3_made")
            local blp = read("World\\Maps\\WC3_made\\WC3_made_loading.blp")
            local img = ffi.new("BlpImage")
            local buf = blp and ffi.new("unsigned char[?]", #blp)
            if buf then ffi.copy(buf, blp, #blp) end
            local dec = buf and W.blp_decode_level(buf, #blp, 0, img, WHY) == 0
            test("its loading screen decodes: 512 x 512", dec and img.width == 512 and img.height == 512)
            if dec then W.blp_free(img) end
            W.mpq_close(a)
        end
    else
        skip("patch-W.MPQ through the W client's archive reader", "no library")
    end

    -- map.lua
    local m = load_data(BUILD .. "/map.lua")
    test("map.lua reads as data: the map's id, folder, name, zone, loading screen", m and m.format == 1 and m.map.id == 900
        and m.map.directory == "WC3_made" and m.map.name == "Made Map" and m.map.area == ids.area and m.map.loading_screen == 900)
    local sx, sy = at(100, 100)
    local X, Y = L0:to_wow(sx, sy)
    test("its start is the human player's start location (Blue), on the converted ground", m and m.start.player == 1
        and math.abs(m.start.x - X) < 1e-3 and math.abs(m.start.y - Y) < 1e-3
        and math.abs(m.start.z - job:height_at(sx, sy)) < 1e-3)
    local worst = 0
    if m then
        local T = m.wc3_to_wow
        for _, s in ipairs(C.spawns) do
            local x = T.x0 + T.scale * s.wc3[2]
            local y = T.y0 - T.scale * s.wc3[1]
            worst = math.max(worst, math.abs(x - s.world[1]), math.abs(y - s.world[2]))
        end
    end
    test("its WC3 -> WoW transform puts every spawn where the converter did (within 0.01 yd)", m and worst < 0.01, tostring(worst))
    test("it lists the maps of the build folder and names the creature list", m and #m.maps == 1 and m.creatures == "world/creatures-900.tsv")
    test("the map's war3map.w3e lies beside map.lua, as the map holds it", read_file(BUILD .. "/" .. wowbuild.GROUND_FILE) == "W3E!made ground")

    -- the creature list, through the W client's own reader
    local tsv = BUILD .. "/world/creatures-900.tsv"
    if WC then
        local list = ffi.new("SpawnList")
        local ok = WC.creatures_read(tsv, list, WHY) == 0
        test("the W client's creature list reader reads world/creatures-900.tsv", ok, not ok and ffi.string(WHY.text) or nil)
        if ok then
            local byguid = {}
            for k = 0, list.n - 1 do byguid[list.spawns[k].guid] = list.spawns[k] end
            local bad = {}
            for _, s in ipairs(C.spawns) do
                local g = byguid[s.guid]
                if not g then bad[#bad + 1] = "no spawn " .. s.guid
                elseif g.entry ~= s.template.entry or g.display ~= s.template.display.id
                    or math.abs(g.x - s.world[1]) > 1e-3 or math.abs(g.y - s.world[2]) > 1e-3
                    or math.abs(g.facing - s.orientation) > 1e-3 then bad[#bad + 1] = "spawn " .. s.guid .. " differs"
                -- 035's tile counts x (north) first: the ADT's ty, then its tx
                elseif g.tile ~= 32 * 64 + 32 then bad[#bad + 1] = "spawn " .. s.guid .. " in tile " .. g.tile end
            end
            test("every spawn: its guid, template, look, place, facing, and the ADT tile it stands in", list.n == #C.spawns and #bad == 0,
                table.concat(bad, "; "))
            WC.creatures_free(list)
        end
    else
        skip("the creature list through the W client's reader", W and "no $W_CLIENT_SRC to compile 035-creatures from" or "no library")
    end
end

test_section("Several maps in one build folder")
do
    local r2 = wowbuild.convert("other.w3x", BUILD, { terrain = made_terrain(50), map = made_map("Other"), models = made_models,
        name = "WC3_other", stock_dbc = STOCK, patch = false })
    test("a map with no war3map.w3e leaves none beside map.lua (not the first map's)", read_file(BUILD .. "/" .. wowbuild.GROUND_FILE) == nil)
    test("a second map takes the next free slot: 1, map 901, its own blocks",
        r2.registration.slot == 1 and r2.registration.ids.map == 901 and r2.registration.ids.faction == 3100
        and r2.registration.ids.display == 51000 and r2.registration.ids.entry == 9010000)
    test("its AreaBit isn't one the stock table or the first map holds", r2.registration.ids.area_bit ~= 4095
        and r2.registration.ids.area_bit ~= 4094 and r2.registration.ids.area_bit ~= ids.area_bit)
    local r3 = wowbuild.convert("made.w3x", BUILD, { terrain = terrain, map = made_map("Made Map"), models = made_models,
        name = "WC3_made", stock_dbc = STOCK, patch = false, ground = "W3E!made ground" })
    test("the first map converted again keeps its slot (0)", r3.registration.slot == 0 and r3.registration.ids.map == 900)
    local ok, err = pcall(wowbuild.convert, "x.w3x", BUILD, { terrain = terrain, map = made_map("X"), models = made_models,
        name = "WC3_x", slot = 1, stock_dbc = false, patch = false })
    test("a slot another map holds is refused, naming that map", not ok and tostring(err):find("WC3_other"), tostring(err))
    local bad_id = pcall(wowbuild.convert, "x.w3x", BUILD, { terrain = terrain, map = made_map("X"), models = made_models,
        name = "WC3_x", map_id = 9000, stock_dbc = false, patch = false })
    test("a map id outside 900-999 is refused", not bad_id)
    if W then
        local t = w_table(read_file(BUILD .. "/DBFilesClient/Map.dbc"))
        test("the overlay's Map.dbc holds both maps, and nothing else", t and t.rows == 2 and t.u32(0, 1) == 900 and t.u32(1, 1) == 901
            and t.text(1, 2) == "WC3_other")
        local ft = w_table(read_file(BUILD .. "/DBFilesClient/FactionTemplate.dbc"))
        test("its FactionTemplate.dbc holds both maps' factions (4 + 4)", ft and ft.rows == 8)
    else
        skip("the overlay's tables hold both maps", "no library")
    end
    local m = load_data(BUILD .. "/map.lua")
    test("map.lua names the map just converted, and lists both", m and m.map.id == 900 and #m.maps == 2)
    test("... and the ground beside it is that map's again", read_file(BUILD .. "/" .. wowbuild.GROUND_FILE) == "W3E!made ground")
    local merged = read_file(BUILD .. "/server/dbc/Map.dbc")
    local c = merged and dbc.column(merged, 1) or {}
    test("the server's merged Map.dbc: the stock maps and both converted ones", #c == 4 and c[3] == 900 and c[4] == 901)
end
-- }}}

-- {{{ The maps in assets/
test_section("Maps in assets/")
local maps = {}
do
    local p = io.popen('ls ' .. quote(DIR .. "/assets") .. '/*.w3x 2>/dev/null')
    for line in p:lines() do maps[#maps + 1] = line end
    p:close()
end
local function pick(pattern) for _, m in ipairs(maps) do if m:match("[^/]*$"):find(pattern) then return m end end end
local mpq_ok, mpq_err = pcall(function()
    local a, e = require("mpq").open(maps[1] or "")
    if not a then error(e, 0) end
    a:close()
end)
if #maps == 0 then
    skip("maps in assets/", "none found in " .. DIR .. "/assets")
elseif not mpq_ok and tostring(mpq_err):find("StormLib") then
    skip("maps in assets/", "StormLib isn't built here")
else
    for _, path in ipairs({ pick("^DAoW%-2%.1"), pick("^Master%-Crafters") }) do
        local name = path:match("([^/]*)%.w3x$")
        local out = TMP .. "/real-" .. name:gsub("[^%w]", "_")
        local ok, rep, rjob, RP, RC = pcall(wowbuild.convert, path, out, { stock_dbc = false })
        test(name .. ": converts with its registration", ok and rep.registration and rep.registration.ids.map == 900,
            not ok and tostring(rep) or nil)
        if ok then
            local g = rep.registration
            print(string.format("  (%s: \"%s\", %d looks, %d factions, loading screen from the %s; patch-W.MPQ %d files)",
                name, g.map_name, g.tables.CreatureDisplayInfo.rows, g.tables.FactionTemplate.rows, g.loading_screen,
                g.patch and #g.patch.files or 0))
            test(name .. ": its name is plain text (no colour codes, no TRIGSTR)", not g.map_name:find("|c") and not g.map_name:find("TRIGSTR"))
            test(name .. ": a look a display and a faction template a faction, as W02b made them",
                g.tables.CreatureDisplayInfo.rows == #RC.displays and g.tables.FactionTemplate.rows == #RC.factions)
            if name:find("^DAoW") then
                test(name .. ": its loading screen is its own preview picture", g.loading_screen == "preview")
            end
            if W then
                local bad = {}
                local r = load_data(out .. "/World/Maps/" .. rep.map_directory .. "/registration.lua")
                for _, tname in ipairs(dbc.TABLES) do
                    local why = compare_table(tname, read_file(out .. "/DBFilesClient/" .. tname .. ".dbc") or "", r.rows[tname])
                    if why then bad[#bad + 1] = tname .. ": " .. why end
                end
                test(name .. ": the W client reads every table as written", #bad == 0, table.concat(bad, "; "))
                local a = ffi.new("MpqArchive")
                local opened = W.mpq_open(a, out .. "/patch-W.MPQ", WHY) == 0
                local all = opened
                if opened then
                    for _, f in ipairs(g.patch.files) do
                        local n = ffi.new("size_t[1]")
                        local p = W.mpq_read(a, f, n, WHY)
                        if p == nil then all = false
                        else
                            local disk = read_file(out .. "/" .. f:gsub("\\", "/"))
                            if ffi.string(p, n[0]) ~= disk then all = false end
                            ffi.C.free(p)
                        end
                    end
                    W.mpq_close(a)
                end
                test(name .. ": the W client's archive reader reads every file of patch-W.MPQ, the same as on disk", all)
            end
            if WC and rep.units.spawned > 0 then
                local list = ffi.new("SpawnList")
                local got = WC.creatures_read(out .. "/world/creatures-900.tsv", list, WHY) == 0
                test(name .. ": the W client reads its " .. rep.units.spawned .. " spawns", got and list.n == rep.units.spawned,
                    not got and ffi.string(WHY.text) or nil)
                if got then WC.creatures_free(list) end
            end
            os.execute("rm -rf " .. quote(out))
        end
    end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))
print(string.format("\nTests: %d passed, %d failed, %d skipped", pass_count, test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)
