--[[
Tests for a converted map's own light (Issue W02i): the default light, its
two parameter sets and their bands (wowbuild.light) in Light,
LightParams, LightIntBand and LightFloatBand, the map's war3map.w3i fog
and water tint laid in, the ids W02c's scheme gives them, and the tables
the converter writes.

Everything written is read back through the W client's table reader
(016-dbc, in libwreaders.so, by LuaJIT's FFI). When $W_CLIENT_SRC names
the W client's checkout, its light itself is compiled from its sources
(013, 014, 015, 016, 059, 060, 074, 097, 026, 083, 084, with
src/tests/c/light_probe.c) and asked what the light is on the converted
map, as its headless run asks: the build folder an overlay, the tables
through it, the light from them, and the map's own fog laid over. Without
them those checks are skipped and counted.

The reader library is found in $W_CLIENT_BUILD (a folder holding
libwreaders.so and the wreaders.h its scripts/build writes), else the W
client's usual build folder.

    luajit src/tests/test_wow_light.lua [project folder]
]]

-- {{{ Setup paths
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local coords = require("wowbuild.coords")
local dbc = require("wowbuild.dbc")
local registration = require("wowbuild.registration")
local light = require("wowbuild.light")
local w3i = require("parsers.w3i")
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
local function read_file(path) local f = io.open(path, "rb") if not f then return nil end local s = f:read("*a") f:close() return s end
local function load_data(path)
    local chunk = loadfile(path, "t", {})
    if chunk and setfenv then setfenv(chunk, {}) end
    local ok, t = pcall(chunk or error)
    return ok and t or nil
end
local function f32(v) return tonumber(ffi.new("float", v)) end
local function f32_of(n) local b = ffi.new("uint32_t[1]", n) return ffi.cast("float *", b)[0] end
local function near(a, b, e) return a and b and math.abs(a - b) <= (e or 1e-4) end
local function rgb_of(c) return math.floor(c / 65536) % 256 / 255, math.floor(c / 256) % 256 / 255, c % 256 / 255 end
local function same_rgb(out, at, c, e)
    local r, g, b = rgb_of(c)
    return near(out[at], r, e or 1e-3) and near(out[at + 1], g, e or 1e-3) and near(out[at + 2], b, e or 1e-3)
end
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
end

-- the W client's light (026 on 074, with 084's map fog), compiled from its sources
local LP
if os.getenv("W_CLIENT_SRC") then
    local src = os.getenv("W_CLIENT_SRC") .. "/src"
    local lib = TMP .. "/liblightprobe.so"
    local parts = {}
    for _, p in ipairs({ "013-errors", "014-settings", "015-mpq", "016-dbc", "059-loose-folders", "060-resolver",
                         "074-tables", "097-table-layouts", "026-light", "083-w3i", "084-map-fog" }) do
        parts[#parts + 1] = quote(src .. "/" .. p .. ".c")
    end
    local cmd = string.format("cc -std=c11 -D_FILE_OFFSET_BITS=64 -D_POSIX_C_SOURCE=200809L -O2 -fPIC -shared -I%s %s %s -lz -lm -lpthread -o %s 2>&1",
        quote(src), table.concat(parts, " "), quote(DIR .. "/src/tests/c/light_probe.c"), quote(lib))
    local p = io.popen(cmd)
    local said = p:read("*a")
    p:close()
    local ok, err = pcall(function()
        ffi.cdef[[
            int wete_light_probe(const char *build, int map, float x, float y, float z, float hours, int kind,
                                 double yards_per_unit, double *out, char *said, size_t said_len);
        ]]
        LP = ffi.load(lib)
    end)
    if ok then print("(the W client's light, compiled from " .. src .. ")")
    else LP = nil print("(the W client's light didn't build: " .. tostring(err) .. " " .. said .. ")") end
end

-- a table through the W client's 016-dbc: { rows, fields, u32(r, f) } or nil, why
local function w_table(bytes)
    local buf = ffi.new("unsigned char[?]", #bytes)
    ffi.copy(buf, bytes, #bytes)
    local d = ffi.new("Dbc")
    if W.dbc_open(d, buf, #bytes, WHY) ~= 0 then return nil, ffi.string(WHY.text) end
    return { rows = d.rows, fields = d.fields, keep = buf, u32 = function(r, f) return W.dbc_u32(d, r, f) end }
end
-- every column of every row, through the W client's reader: nil or the first difference
local function compare_table(name, bytes, rows)
    local t, err = w_table(bytes)
    if not t then return "the W client can't open it: " .. err end
    local cols = dbc.columns(name)
    if t.rows ~= #rows then return string.format("%d rows read, %d written", t.rows, #rows) end
    if t.fields ~= #cols then return string.format("%d fields read, %d in the layout", t.fields, #cols) end
    for r, row in ipairs(rows) do
        for f, c in ipairs(cols) do
            local want, got = row[c[1]], nil
            if c[2] == "f32" then got, want = f32_of(t.u32(r - 1, f)), f32(want or 0)
            else got, want = t.u32(r - 1, f), want or 0 end
            if got ~= want then return string.format("row %d field %d (%s): %s, written %s", r, f, c[1], tostring(got), tostring(want)) end
        end
    end
end

-- the light at a place through the W client (out: see light_probe.c)
local function probe(build, map, x, y, z, hours, kind)
    local out = ffi.new("double[32]")
    local said = ffi.new("char[300]")
    local rc = LP.wete_light_probe(build, map, x, y, z, hours, kind or 0, coords.YARDS_PER_UNIT, out, said, 300)
    local t = {}
    for i = 0, 31 do t[i] = out[i] end
    return rc == 0 and t or nil, ffi.string(said)
end
-- }}}

-- {{{ The map's fog and tint from its war3map.w3i
test_section("The fog and the tint from war3map.w3i")
do
    local Y = coords.YARDS_PER_UNIT
    local function info(flags, fog, water)
        return { version = 25, flags = { raw = flags }, fog = fog or { style = 0, start_z = 1000, end_z = 4000, color = 0xFF204060 },
                 water_color = water or 0x80A0C0E0 }
    end
    local none = light.from_w3i(nil)
    test("no war3map.w3i: no fog, no tint, said", not none.fog and not none.tint and none.why_no_fog == "no war3map.w3i")
    local roc = light.from_w3i({ version = 18, flags = { raw = 0x12000 } })
    test("a Reign of Chaos file (version 18) has no fog and no tint", not roc.fog and not roc.tint and roc.why_no_fog:find("Reign of Chaos"))
    local off = light.from_w3i(info(0))
    test("the terrain fog flag unset: no fog, said; the tint flag unset: no tint", not off.fog and not off.tint
        and off.why_no_fog == "its war3map.w3i turns no terrain fog on")
    local on = light.from_w3i(info(0x2000))
    test("the fog flag (0x2000): its distances in yards (times 1/30.72), from the eye", on.fog
        and near(on.fog.start, 1000 * Y, 1e-9) and near(on.fog["end"], 4000 * Y, 1e-9) and not on.tint)
    test("its colour is the file's bytes in order, red, green, blue (0xFF204060 is 60 40 20: red 0x60)",
        on.fog and on.fog.color == 0x604020)
    local tint = light.from_w3i(info(0x10000))
    test("the tint flag (0x10000): the tint's colour (E0 C0 A0) and its alpha (0x80) as an opacity",
        tint.tint and tint.tint.color == 0xE0C0A0 and near(tint.tint.alpha, 128 / 255, 1e-9) and not tint.fog)
    local raw = light.from_w3i({ version = 28, flags = 0x2000, fog = { start_z = -50, end_z = -100, color = 0 } })
    test("flags as a plain number too; a start behind the eye is 0, an end before the start is the start (the W client's rule)",
        raw.fog and raw.fog.start == 0 and raw.fog["end"] == 0)
    local nan = light.from_w3i(info(0x2000, { start_z = 0 / 0, end_z = 100, color = 0 }))
    test("distances that aren't numbers: no fog, said", not nan.fog and nan.why_no_fog:find("not numbers"))
end
-- }}}

-- {{{ The rows
test_section("The rows: one default light, two sets, their bands")
local Y = coords.YARDS_PER_UNIT
local FOGGY = { version = 25, flags = { raw = 0x12000 }, fog = { style = 0, start_z = 1000, end_z = 4000, color = 0xFF204060 },
                water_color = 0x80A0C0E0 }
do
    local a, z = registration.ids(0), registration.ids(99)
    test("slot 0: light 20000, sets from 20000, int bands from 359983 (20000 x 18 - 17), float bands from 119995 (20000 x 6 - 5)",
        a.light == 20000 and a.light_params == 20000 and a.light_int_band == 359983 and a.light_float_band == 119995)
    local ok = true
    for s = 0, 99 do
        local i = registration.ids(s)
        if i.light_int_band ~= i.light_params * 18 - 17 or i.light_float_band ~= i.light_params * 6 - 5
            or i.light_int_band_last ~= (i.light_params + 3) * 18 or i.light_float_band_last ~= (i.light_params + 3) * 6 then ok = false end
    end
    test("every slot's band blocks are its four sets' bands exactly", ok)
    test("slot 99: light 20099, sets to 20399", z.light == 20099 and z.light_params_last == 20399)
    test("each light table's ids are in the scheme a merge drops stock rows by",
        registration.TABLE_KIND.Light == "light" and registration.in_scheme("light_int_band", 359983)
        and not registration.in_scheme("light_int_band", 359982) and registration.in_scheme("light_float_band", 122394)
        and not registration.in_scheme("light_float_band", 122395))

    local ids = registration.ids(3)
    local rows, said = light.rows(FOGGY, ids)
    local L = rows.Light[1]
    test("one Light row, the map's default: at 0, 0, 0 with no radius, on the map's id", #rows.Light == 1 and L.ID == 20003
        and L.ContinentID == 903 and L.X == 0 and L.Y == 0 and L.Z == 0 and L.FalloffStart == 0 and L.FalloffEnd == 0)
    test("its sets: clear and under water, storm as clear, the ghost world as clear",
        L.LightParamsID1 == 20012 and L.LightParamsID2 == 20013 and L.LightParamsID3 == 20012 and L.LightParamsID4 == 20013
        and L.LightParamsID5 == 20012 and L.LightParamsID6 == nil)
    test("two LightParams rows, 36 LightIntBand rows (18 a set) and 12 LightFloatBand rows (6 a set)",
        #rows.LightParams == 2 and #rows.LightIntBand == 36 and #rows.LightFloatBand == 12)
    local ib_ok, fb_ok = true, true
    for k, r in ipairs(rows.LightIntBand) do
        local set, b = k <= 18 and 20012 or 20013, (k - 1) % 18
        if r.ID ~= set * 18 - 17 + b then ib_ok = false end
    end
    for k, r in ipairs(rows.LightFloatBand) do
        local set, b = k <= 6 and 20012 or 20013, (k - 1) % 6
        if r.ID ~= set * 6 - 5 + b then fb_ok = false end
    end
    test("each band row's id is its set's x 18 - 17 + band (int) and x 6 - 5 + band (float), as the W client looks them up", ib_ok and fb_ok)
    local sun = rows.LightIntBand[1]
    test("a changing band has four moments (midnight, 6:00, noon, 18:00) and the palette's colours",
        sun.Num == 4 and sun.Time1 == 0 and sun.Time2 == 720 and sun.Time3 == 1440 and sun.Time4 == 2160
        and sun.Data3 == light.PALETTE[0][3])
    local fog = rows.LightIntBand[8]
    test("the map's fog colour all day: one moment", fog.Num == 1 and fog.Time1 == 0 and fog.Data1 == 0x604020)
    local horizon = rows.LightIntBand[7]
    test("the horizon meets the fog by day, the palette's at night", horizon.Num == 4 and horizon.Data1 == light.PALETTE[6][1]
        and horizon.Data2 == 0x604020 and horizon.Data3 == 0x604020 and horizon.Data4 == 0x604020)
    local ocean = rows.LightIntBand[15]
    test("the tint colours the near water: the tint at noon, darker at dawn, dusk and night; deep water darker still",
        ocean.Data3 == 0xE0C0A0 and ocean.Data2 == 0x9D8670 and rows.LightIntBand[16].Data3 == 0x5A4D40
        and rows.LightIntBand[17].Data3 == 0xE0C0A0)
    local f0, f1 = rows.LightFloatBand[1], rows.LightFloatBand[2]
    test("the clear set's fog ends where the map's does (times 36) and starts at its share",
        f0.Num == 1 and near(f0.Data1, 4000 * Y * 36, 1e-6) and near(f1.Data1, 0.25, 1e-9))
    local u0, u1 = rows.LightFloatBand[7], rows.LightFloatBand[8]
    test("under water: the fog close (30 yards), from the eye, in the river's deep colour",
        near(u0.Data1, 30 * 36) and u1.Data1 == 0 and rows.LightIntBand[18 + 8].Data3 == rows.LightIntBand[18 + 18].Data3)
    local P = rows.LightParams[1]
    test("the tint's alpha is the shallow water's opacity; deep water opaque; no skybox",
        near(P.WaterShallowAlpha, 128 / 255, 1e-9) and near(P.OceanShallowAlpha, 128 / 255, 1e-9)
        and P.WaterDeepAlpha == 1 and P.OceanDeepAlpha == 1 and P.LightSkyboxID == 0)
    test("what was used is said", said.fog == "map" and said.tint == true and said.light == 20003
        and near(said.fog_end, 4000 * Y, 1e-9) and said.sets[1] == 20012 and said.sets[2] == 20013)

    local plain, psaid = light.rows(nil, ids)
    test("no war3map.w3i: the palette's fog (600 yards, from a quarter), Ashenvale's water opacity, said",
        plain.LightIntBand[8].Num == 4 and plain.LightIntBand[8].Data3 == light.PALETTE[7][3]
        and near(plain.LightFloatBand[1].Data1, 600 * 36) and near(plain.LightFloatBand[2].Data1, 0.25)
        and plain.LightParams[1].WaterShallowAlpha == 0.5 and plain.LightParams[1].OceanShallowAlpha == 0.75
        and psaid.fog == "default" and psaid.why_no_fog == "no war3map.w3i" and psaid.tint == false)

    -- the layouts, and every table through the W client's reader
    local widths = { Light = 15, LightParams = 9, LightIntBand = 34, LightFloatBand = 34 }
    local wok = true
    for name, n in pairs(widths) do if #dbc.columns(name) ~= n or dbc.LAYOUTS[name].checked ~= false then wok = false end end
    test("the four layouts have the W client's widths (Light 15, LightParams 9, both bands 34), unchecked", wok)
    if W then
        local bad = {}
        for name in pairs(widths) do
            local why = compare_table(name, dbc.write(name, rows[name]), rows[name])
            if why then bad[#bad + 1] = name .. ": " .. why end
        end
        test("each table written reads back through the W client's 016-dbc, every column", #bad == 0, table.concat(bad, "; "))
    else
        skip("the tables through the W client's reader", "no library")
    end
end
-- }}}

-- {{{ A made map, converted
-- a 129 x 129 ground (one ADT tile), with a hill; two players, one unit
local function made_terrain()
    local tps = {}
    for j = 0, 128 do
        tps[j] = {}
        for i = 0, 128 do
            tps[j][i] = { height = 8192 + 200 * math.exp(-((i - 64) ^ 2 + (j - 64) ^ 2) / 400), water_level = 0, has_water = false,
                          layer_height = 2, ground_texture = 0, texture_details = 0, cliff_texture = 15,
                          is_blight = false, is_ramp = false, is_boundary = false }
        end
    end
    return { width = 129, height = 129, offset_x = -8192, offset_y = -8192, tileset_code = "L",
             ground_tilesets = { "Ldrt", "Lgrs" }, tilepoints = tps }
end
local terrain = made_terrain()
local L0 = coords.layout(terrain)
local function at(i, j) return L0.offset_x + i * 128, L0.offset_y + j * 128 end
local made_models = TMP .. "/models.lua"
do
    local f = assert(io.open(made_models, "wb"))
    f:write([[
return { format = 1,
  doodads = { types = {}, classes = {} },
  units = { fallback = { name = "Unmapped unit", wow = "World\\Test\\Crate.m2", checked = false },
            types = { hfoo = { name = "Footman", wow = "Creature\\Test\\Footman.m2", radius = 1, checked = false } } },
}
]])
    f:close()
end
-- the map's settings, written as war3map.w3i bytes and read back, as a real map's
local function made_info(name, flags)
    local sx1, sy1 = at(20, 20)
    local sx2, sy2 = at(100, 100)
    local info = {
        version = 25, name = name, author = "", description = "", players_recommended = "",
        camera_bounds = { 0, 0, 0, 0, 0, 0, 0, 0 }, margins = { 6, 6, 4, 8 }, playable_width = 116, playable_height = 116,
        flags = flags, tileset_code = "L",
        fog = { style = 0, start_z = 1000, end_z = 4000, density = 0.5, color = 0xFF204060 }, water_color = 0x80A0C0E0,
        players = { { number = 0, name = "Red", type = "computer", race = "human", start_x = sx1, start_y = sy1 },
                    { number = 1, name = "Blue", type = "human", race = "human", start_x = sx2, start_y = sy2 } },
        forces = {},
    }
    local bytes = w3i.write(info)
    return w3i.parse(bytes), bytes
end
local function made_map(name, flags)
    local info, bytes = made_info(name, flags)
    local x, y = at(64, 64)
    return {
        units = { version = 8, units = { { id = "hfoo", variation = 0, position = { x = x, y = y, z = 0 }, angle = 0,
                                           scale = { x = 1, y = 1, z = 1 }, flags = 2, player = 1, creation_number = 0 } } },
        info = info, objects = {},
    }, bytes
end

-- a made stock folder: Light with the stock default (row 1) and a row in W02i's block
local STOCK = TMP .. "/stock"
os.execute("mkdir -p " .. quote(STOCK))
do
    local function put(name, rows)
        local f = assert(io.open(STOCK .. "/" .. name .. ".dbc", "wb"))
        f:write(dbc.write(name, rows))
        f:close()
    end
    put("Map", { { ID = 0, Directory = "Azeroth", MapName = "Eastern Kingdoms", CorpseMapID = -1 } })
    put("Light", { { ID = 1, ContinentID = 0, LightParamsID1 = 12 }, { ID = 20000, ContinentID = 900, LightParamsID1 = 20000 } })
    put("LightParams", { { ID = 12 } })
    put("LightIntBand", { { ID = 12 * 18 - 17, Num = 1 } })
    put("LightFloatBand", { { ID = 12 * 6 - 5, Num = 1 } })
end

test_section("A made map with its own fog, converted")
local BUILD = TMP .. "/build"
local map1, info1 = made_map("Foggy", 0x12000)
local report = wowbuild.convert("foggy.w3x", BUILD, { terrain = terrain, map = map1, models = made_models, name = "WC3_foggy",
    stock_dbc = STOCK, patch = false, ground = "W3E!made ground", info_bytes = info1 })
local reg = report.registration
local ids1 = reg.ids
do
    test("the map takes slot 0: light 20000, sets 20000 and 20001", reg.slot == 0 and ids1.light == 20000 and ids1.light_params == 20000)
    test("the report says the light took the map's fog and tint", reg.light and reg.light.fog == "map" and reg.light.tint == true
        and near(reg.light.fog_end, 4000 * Y, 1e-9))
    local r = load_data(BUILD .. "/World/Maps/WC3_foggy/registration.lua")
    test("registration.lua keeps the light's rows beside the others", r and r.rows.Light and r.rows.Light[1].ID == 20000
        and #r.rows.LightIntBand == 36 and r.rows.LightIntBand[8].Data1 == 0x604020)
    test("the build's war3map.w3i is the map's own (what the W client's 084 reads)", read_file(BUILD .. "/war3map.w3i") == info1)
    if W then
        local bad = {}
        for _, name in ipairs({ "Light", "LightParams", "LightIntBand", "LightFloatBand" }) do
            local why = compare_table(name, read_file(BUILD .. "/DBFilesClient/" .. name .. ".dbc") or "", r.rows[name])
            if why then bad[#bad + 1] = name .. ": " .. why end
        end
        test("DBFilesClient/ holds the four light tables with this map's rows only (the W client's reader)", #bad == 0, table.concat(bad, "; "))
    else
        skip("the overlay's light tables through the W client's reader", "no library")
    end
    local st = reg.stock and reg.stock.tables
    test("merged with the stock tables: the stock rows kept, the one in W02i's block replaced, said",
        st and st.Light and st.Light.stock == 2 and st.Light.dropped == 1 and st.Light.ours == 1
        and st.LightIntBand.stock == 1 and st.LightIntBand.dropped == 0 and st.LightIntBand.ours == 36 and (function()
            for _, w in ipairs(reg.warnings) do if w:find("^Light%.dbc: 1 stock rows inside") then return true end end
        end)())
    test("the light tables aren't the server's: no server/dbc/Light.dbc, nothing in server/dbc.sql",
        read_file(BUILD .. "/server/dbc/Light.dbc") == nil and not (read_file(BUILD .. "/server/dbc.sql") or ""):find("light", 1, true))
end

test_section("The W client's light on the converted map (026 through 074, 084's fog)")
local start1 = reg.start
if LP then
    local x, y, z = start1.x, start1.y, start1.z
    local o, said = probe(BUILD, 900, x, y, z, 12)
    test("the light at the start at noon is the map's own default (20000), from its four tables", o and o[0] == 20000
        and o[1] == 0 and o[2] == 1, said)
    if o then
        test("its fog is the map's: from " .. string.format("%.1f to %.1f yards", o[3], o[4]) .. ", the map's colour",
            near(o[3], 1000 * Y, 1e-3) and near(o[4], 4000 * Y, 1e-3) and same_rgb(o, 5, 0x604020))
        test("the sky overhead is the palette's noon, the horizon the fog's", same_rgb(o, 8, light.PALETTE[2][3])
            and same_rgb(o, 11, 0x604020))
        test("the water: the tint's opacity shallow, opaque deep, the tint near (ocean shallow, deep, river shallow, deep)",
            near(o[14], 128 / 255, 1e-6) and o[15] == 1 and near(o[16], 128 / 255, 1e-6) and o[17] == 1 and same_rgb(o, 27, 0xE0C0A0))
        test("the map's own fog laid over it (as the window and the headless run do) changes nothing: the light already has it",
            o[21] == 1 and near(o[22], o[3], 1e-4) and near(o[23], o[4], 1e-4) and near(o[24], o[5], 1e-6) and near(o[26], o[7], 1e-6), said)
    end
    local m = probe(BUILD, 900, x, y, z, 0)
    local d = probe(BUILD, 900, x, y, z, 3)
    test("at midnight the night sky; at 3:00 half way to dawn's (the bands blend through the day)",
        m and same_rgb(m, 8, light.PALETTE[2][1]) and d and near(d[8], (rgb_of(light.PALETTE[2][1]) + rgb_of(light.PALETTE[2][2])) / 2, 0.003))
    local u = probe(BUILD, 900, x, y, z, 12, 1)
    test("under water: the fog 30 yards from the eye, the river's deep colour", u and near(u[4], 30, 1e-3) and u[3] == 0
        and same_rgb(u, 5, 0x5A4D40))
else
    skip("the W client's light on the converted map", "no $W_CLIENT_SRC")
end

test_section("A second map, with no fog of its own, in the same build")
do
    local map2, info2 = made_map("Plain", 0)
    local r2 = wowbuild.convert("plain.w3x", BUILD, { terrain = terrain, map = map2, models = made_models, name = "WC3_plain",
        stock_dbc = false, patch = false, ground = "W3E!made ground", info_bytes = info2 })
    local g = r2.registration
    test("slot 1: light 20001, sets 20004 and 20005", g.slot == 1 and g.ids.light == 20001 and g.ids.light_params == 20004)
    test("its light took the palette's fog, said", g.light.fog == "default" and g.light.why_no_fog == "its war3map.w3i turns no terrain fog on"
        and g.light.tint == false)
    local t = W and w_table(read_file(BUILD .. "/DBFilesClient/Light.dbc") or "")
    if t then
        test("Light.dbc holds both maps' default lights, in id order", t.rows == 2 and t.u32(0, 1) == 20000 and t.u32(0, 2) == 900
            and t.u32(1, 1) == 20001 and t.u32(1, 2) == 901)
        local ib = w_table(read_file(BUILD .. "/DBFilesClient/LightIntBand.dbc") or "")
        test("LightIntBand.dbc: both maps' 36 bands", ib and ib.rows == 72)
    else
        skip("both maps' lights through the W client's reader", "no library")
    end
    if LP then
        local s = g.start
        local o, said = probe(BUILD, 901, s.x, s.y, s.z, 12)
        test("the W client lights it by its own default (20001): the palette's fog, 150 to 600 yards, and lays no map fog over it",
            o and o[0] == 20001 and near(o[3], 150, 1e-3) and near(o[4], 600, 1e-3) and same_rgb(o, 5, light.PALETTE[7][3])
            and o[21] == 0 and said == "its war3map.w3i turns no terrain fog on", said)
        local f = probe(BUILD, 900, start1.x, start1.y, start1.z, 12)
        test("the first map keeps its own fog in its light, though the build's war3map.w3i is now the second's",
            f and f[0] == 20000 and near(f[4], 4000 * Y, 1e-3) and same_rgb(f, 5, 0x604020) and f[21] == 0)
        local n = probe(BUILD, 950, 0, 0, 0, 12)
        test("a map with no light of its own, and no Light row 1 in the build: the W client's grey day", n and n[0] == -1)
    else
        skip("the W client's light on the second map", "no $W_CLIENT_SRC")
    end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))
print(string.format("\nTests: %d passed, %d failed, %d skipped", pass_count, test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)
