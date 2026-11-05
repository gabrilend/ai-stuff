--[[
Tests for the doodads and units placed in a converted map (Issue W02b): the
doodad and unit readers' fixes, the model table, the lookup a placement
takes to its WoW model, facing, the ADT's placement blocks (MMDX, MMID,
MDDF, MWMO, MWID, MODF and each chunk's MCRF), the creatures' SQL, the
factions, the placement list, and the map's own models travelling with it.

Made maps (a small ground with doodads and units built here) and the maps
in assets/ are converted, and every written ADT is read back through the
W client's own reader (libwreaders.so, its src/020-adt.c) by LuaJIT's FFI:
model names, positions, rotations, sizes and building boxes must come back
as placed, and the W client's own placement matrix (adt_place_matrix) must
turn a model to face where the WC3 unit faced. The W client's reader skips
MCRF (it draws every placement of a tile), so the chunk references are
walked here, by this test.

The reader library is found in $W_CLIENT_BUILD (a folder holding
libwreaders.so and the wreaders.h its scripts/build writes), else the W
client's usual build folder. Without it those checks are skipped and
counted as skipped. Real maps need StormLib (src/mpq/stormlib.lua finds it,
or $STORMLIB_PATH).

    luajit src/tests/test_wow_placements.lua [project folder]
]]

-- {{{ Setup paths
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local w3e = require("parsers.w3e")
local doo = require("parsers.doo")
local unitsdoo = require("parsers.unitsdoo")
local coords = require("wowbuild.coords")
local placements = require("wowbuild.placements")
local creatures = require("wowbuild.creatures")
local wowbuild = require("wowbuild")
-- the made map converts as map 923: slot 23 of W02c's id scheme
local IDS = require("wowbuild.registration").ids(23)
local F0 = IDS.faction
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

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function u32(s, at) local a, b, c, d = s:byte(at + 1, at + 4) return a + b * 256 + c * 65536 + d * 16777216 end
local function tag_at(s, at) return s:sub(at + 1, at + 4):reverse() end
local function i32(n) if n < 0 then n = n + 2 ^ 32 end return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256) end
local function f32(x) local b = ffi.new("float[1]", x) return ffi.string(b, 4) end
local function read_file(path) local f = io.open(path, "rb") if not f then return nil end local s = f:read("*a") f:close() return s end
local function write_file(path, s) local f = assert(io.open(path, "wb")) f:write(s) f:close() end
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))
-- }}}

-- {{{ The W client's reader library
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
local wtile = W and ffi.new("AdtTile")
local function why_text() return ffi.string(WHY.text) end
-- }}}

-- {{{ read_adt: an ADT's placements, through the W client's reader
-- Returns { models, doodads, buildings, places } (plain Lua copies) or nil, why
local function read_adt(bytes)
    local buf = ffi.new("unsigned char[?]", #bytes)
    ffi.copy(buf, bytes, #bytes)
    if W.adt_read(buf, #bytes, 1, wtile, WHY) ~= 0 then return nil, why_text() end
    local r = { models = {}, doodads = {}, buildings = {}, places = {} }
    for k = 0, wtile.nmodels - 1 do r.models[k] = ffi.string(wtile.models[k]) end
    for k = 0, wtile.nbuildings - 1 do r.buildings[k] = ffi.string(wtile.buildings[k]) end
    local function copy(p)
        return { name = p.name, uid = p.uid, x = p.x, y = p.y, z = p.z, rot = { p.rot[0], p.rot[1], p.rot[2] },
                 scale = p.scale, lo = { p.lo[0], p.lo[1], p.lo[2] }, hi = { p.hi[0], p.hi[1], p.hi[2] }, raw = p }
    end
    for k = 0, wtile.ndoodads - 1 do r.doodads[k] = copy(wtile.doodads[k]) end
    for k = 0, wtile.nplaces - 1 do r.places[k] = copy(wtile.places[k]) end
    r.n_doodads, r.n_places = wtile.ndoodads, wtile.nplaces
    W.adt_free(wtile)
    return r
end
-- }}}

-- {{{ walk_mcrf: each chunk's references, read by this test (the W client skips MCRF)
-- Returns chunks[k] = { d = { MDDF indices }, w = { MODF indices }, ix, iy } and
-- the placements' counts read from MDDF and MODF, or nil, why
local function walk_mcrf(bytes)
    local chunks, n_mddf, n_modf = {}, 0, 0
    local at = 0
    while at + 8 <= #bytes do
        local tag, size = tag_at(bytes, at), u32(bytes, at + 4)
        if tag == "MDDF" then n_mddf = size / 36 end
        if tag == "MODF" then n_modf = size / 64 end
        if tag == "MCNK" then
            local h = at + 8
            local ix, iy = u32(bytes, h + 4), u32(bytes, h + 8)
            local nd, nw = u32(bytes, h + 16), u32(bytes, h + 56)
            local off = u32(bytes, h + 32)          -- MCRF, from the MCNK's own start
            if tag_at(bytes, at + off) ~= "MCRF" then return nil, "chunk " .. ix .. "," .. iy .. ": no MCRF at its offset" end
            local rsize = u32(bytes, at + off + 4)
            if rsize ~= (nd + nw) * 4 then return nil, "chunk " .. ix .. "," .. iy .. ": MCRF holds " .. rsize .. " bytes, the header counts " .. (nd + nw) end
            local c = { d = {}, w = {}, ix = ix, iy = iy }
            for n = 0, nd + nw - 1 do
                local v = u32(bytes, at + off + 8 + n * 4)
                if n < nd then c.d[#c.d + 1] = v else c.w[#c.w + 1] = v end
            end
            chunks[iy * 16 + ix] = c
        end
        at = at + 8 + size
    end
    return chunks, n_mddf, n_modf
end
-- }}}

-- {{{ The doodad and unit readers (parsers/doo.lua, parsers/unitsdoo.lua)
test_section("The doodad reader: version 8's item drops")
do
    -- one doodad with two item sets: the drops come before the creation number
    local entry = "LTbr" .. i32(1) .. f32(100) .. f32(-200) .. f32(5) .. f32(1.5) .. f32(1) .. f32(1) .. f32(1)
        .. string.char(2, 100) .. i32(-1) .. i32(2)
        .. i32(1) .. "ratc" .. i32(100)
        .. i32(2) .. "rde1" .. i32(60) .. "pghe" .. i32(40)
        .. i32(77)
    local bytes = "W3do" .. i32(8) .. i32(11) .. i32(1) .. entry .. i32(0) .. i32(0)
    local r, err = doo.parse(bytes)
    test("a version 8 doodad with item sets reads", r ~= nil, err)
    if r then
        local d = r.doodads[1]
        test("its creation number is the one after the drops (77)", d.creation_number == 77, tostring(d.creation_number))
        test("its item table pointer is -1", d.item_table_pointer == -1, tostring(d.item_table_pointer))
        test("its two item sets read, 1 and 2 items", d.item_sets and #d.item_sets == 2 and #d.item_sets[1].items == 1
            and #d.item_sets[2].items == 2 and d.item_sets[2].items[2].id == "pghe" and d.item_sets[2].items[2].chance == 40)
        test("written back, the same bytes", doo.write(r) == bytes)
    end
    local short = doo.parse("W3do" .. i32(8) .. i32(11) .. i32(1) .. entry:sub(1, 60))
    test("a doodad cut short is an error, not a wrong doodad", short == nil)
end

test_section("The unit reader: random units")
do
    local function unit(id, random)
        return id .. i32(0) .. f32(0) .. f32(0) .. f32(0) .. f32(0) .. f32(1) .. f32(1) .. f32(1) .. string.char(2)
            .. i32(0) .. string.char(0, 0) .. i32(-1) .. i32(-1)
            .. i32(-1) .. i32(0)                                            -- item drops
            .. i32(12500) .. f32(-1)                                        -- gold, target acquisition
            .. i32(1) .. i32(0) .. i32(0) .. i32(0) .. i32(0)              -- hero section
            .. i32(0)                                                       -- abilities
            .. random .. i32(-1) .. i32(-1) .. i32(9)                      -- colour, waygate, creation number
    end
    local group = unit("YYU0", i32(1) .. i32(3) .. i32(2))                  -- group 3, position 2
    local choices = unit("uDNR", i32(2) .. i32(2) .. "hfoo" .. i32(50) .. "hkni" .. i32(50))
    local level = unit("YYU#", i32(0) .. string.char(5, 0, 0, 1))           -- any level-5 unit
    local bytes = "W3do" .. i32(8) .. i32(11) .. i32(3) .. group .. choices .. level
    local r, err = unitsdoo.parse(bytes)
    test("three random units of the three kinds read", r ~= nil and #r.units == 3, err)
    if r then
        local a, b, c = r.units[1].random_unit, r.units[2].random_unit, r.units[3].random_unit
        test("a unit from a random group: its group and position", a and a.group_index == 3 and a.position == 2)
        test("a unit from a list: its two choices", b and b.choices and #b.choices == 2 and b.choices[2].id == "hkni")
        test("a random unit by level: level 5", c and c.level == 5)
        test("every creation number read (9)", r.units[1].creation_number == 9 and r.units[3].creation_number == 9)
    end
end
-- }}}

-- {{{ The model table (src/wowbuild/models.lua)
test_section("The model table")
local models, models_path = placements.load_models()
do
    test("loads as data", type(models) == "table" and models.format == 1, models_path)
    local rows, bad, checked = 0, {}, 0
    local function check(where, row, unit)
        rows = rows + 1
        if type(row.wow) ~= "string" or not row.wow:match("%.[mM]2$") and not row.wow:match("%.[wW][mM][oO]$") then
            bad[#bad + 1] = where .. ": its path names no M2 or WMO"
        elseif row.wow:find("/") then bad[#bad + 1] = where .. ": forward slashes (the archives name paths with \\)"
        elseif row.wow:lower():match("%.md[xl]$") then bad[#bad + 1] = where .. ": a WC3 path" end
        if type(row.name) ~= "string" then bad[#bad + 1] = where .. ": no name" end
        if row.scale ~= nil and not (type(row.scale) == "number" and row.scale > 0) then bad[#bad + 1] = where .. ": scale" end
        if type(row.checked) ~= "boolean" then bad[#bad + 1] = where .. ": checked is not true or false" end
        if row.checked then checked = checked + 1 end
        if unit and row.wow:lower():match("%.wmo$") then bad[#bad + 1] = where .. ": a unit can't be a building" end
        for _, k in ipairs({ "radius", "reach" }) do
            if row[k] ~= nil and not (type(row[k]) == "number" and row[k] > 0) then bad[#bad + 1] = where .. ": " .. k end
        end
    end
    for id, row in pairs(models.doodads.types) do check("doodads.types." .. id, row) end
    for key, row in pairs(models.doodads.by_model) do
        check("doodads.by_model " .. key, row)
        if key ~= placements.wc3_key(key) then bad[#bad + 1] = "by_model " .. key .. ": not lower case .mdx" end
    end
    for letter, c in pairs(models.doodads.classes) do
        for ts, row in pairs(c) do check("doodads.classes." .. letter .. "." .. ts, row) end
    end
    for id, row in pairs(models.units.types) do check("units.types." .. id, row, true) end
    check("units.fallback", models.units.fallback, true)
    test("every row names a WoW M2 or WMO, a name, and whether it was checked (" .. rows .. " rows)", #bad == 0,
        table.concat(bad, "; "))
    test("no row claims to be checked yet (nothing here was looked up in a client)", checked == 0, checked .. " checked")
    local ok, err = pcall(placements.load_models, DIR .. "/src/wowbuild/no-such-table.lua")
    test("a missing model table is an error naming it", not ok and tostring(err):find("no%-such%-table"))
    local code = TMP .. "/code.lua"
    write_file(code, "os.exit(3) return {}")
    ok, err = pcall(placements.load_models, code)
    test("a model table is read as data: no os, no io", not ok, tostring(err))
end

test_section("Which model a placement takes")
do
    local mt = {
        types = { LTlt = { name = "tree", wow = "A.m2" }, LTbr = { name = "barrel", wow = "B.m2" } },
        by_model = { ["doodads\\x\\x.mdx"] = { name = "by model", wow = "C.m2" } },
        classes = { R = { L = { name = "summer rock", wow = "D.m2" }, any = { name = "rock", wow = "E.m2" } } },
    }
    local objects = {
        custom = { X001 = { parent_id = "LTlt" }, X002 = { parent_id = "LTlt" }, X003 = { parent_id = "LTlt" } },
        get_modification = function(_, id, field)
            if field ~= "dfil" then return nil end
            if id == "X001" then return "war3mapImported\\Hut.mdl" end
            if id == "X002" then return "Doodads\\X\\X.mdl" end
            if id == "X003" then return "Doodads\\Nowhere\\Y.mdl" end
        end,
    }
    local function has(path) if path == "war3mapImported\\Hut.mdx" then return path end end
    local function pick(id) local row, source = placements.find_row(id, mt, objects, "dfil", has) return row and row.wow, source end
    local w, s = pick("X001")
    test("1. the map's own model, when the map holds the file (.mdl named, .mdx stored)", w == "war3mapImported\\Hut.mdx" and s == "map", tostring(w))
    w, s = pick("X002")
    test("2. by the stock WC3 model a custom type points at", w == "C.m2" and s == "model", tostring(w))
    w, s = pick("X003")
    test("3. else the stock type the custom type copies", w == "A.m2" and s == "type", tostring(w))
    w, s = pick("LTbr")
    test("3. a stock type by its own id", w == "B.m2" and s == "type")
    w, s = pick("LRrk")
    test("4. by category and tileset letter", w == "D.m2" and s == "class")
    w, s = pick("BRrk")
    test("4. by category, any tileset", w == "E.m2" and s == "class")
    w, s = pick("LZzz")
    test("5. nothing", w == nil and s == nil)
end
-- }}}

-- {{{ Facing
test_section("Facing: WC3's angle as WoW's")
do
    -- a WC3 angle turns from east, anticlockwise; in WoW's world x is north
    -- and y west, so facing angle a is the direction (sin a, -cos a)
    local worst_o = 0
    for k = 0, 35 do
        local a = k * math.pi / 18
        local o = placements.orientation(a)
        local e = math.abs(math.cos(o) - math.sin(a)) + math.abs(math.sin(o) + math.cos(a))
        if e > worst_o then worst_o = e end
    end
    test("a creature's orientation faces where the WC3 unit faced", worst_o < 1e-9, tostring(worst_o))
    if not W then
        skip("the W client turns a placed model the same way", "no library")
    else
        local p, m = ffi.new("AdtPlace"), ffi.new("float[16]")
        local worst, worst_up = 0, 0
        for k = 0, 35 do
            local a = k * math.pi / 18 + 0.1
            p.rot[0], p.rot[1], p.rot[2], p.scale = 0, placements.rotation_y(a), 0, 1
            W.adt_place_matrix(p, 0, 0, m)
            -- the model's own +x (an M2 faces +x) after the W client's matrix
            local e = math.abs(m[0] - math.sin(a)) + math.abs(m[1] + math.cos(a)) + math.abs(m[2])
            if e > worst then worst = e end
            local up = math.abs(m[8]) + math.abs(m[9]) + math.abs(m[10] - 1)
            if up > worst_up then worst_up = up end
        end
        test("the W client's placement matrix turns a model to face where the WC3 doodad faced", worst < 1e-4, tostring(worst))
        test("and keeps it upright", worst_up < 1e-4, tostring(worst_up))
    end
    local r = placements.rotation_y(-math.pi / 2)
    test("a rotation is written 0 to 360 degrees", r >= 0 and r < 360 and math.abs(r) < 1e-9, tostring(r))
end
-- }}}

-- {{{ A made map
-- 200 x 65 tile points: two ADT tiles across, one down; flat ground at 0
local function made_terrain(w, h)
    local t = setmetatable({
        width = w, height = h, offset_x = -64 * (w - 1), offset_y = -64 * (h - 1),
        tileset_code = "L", ground_tilesets = { "Ldrt" }, cliff_tilesets = {}, tilepoints = {},
    }, w3e.Terrain)
    for j = 0, h - 1 do
        t.tilepoints[j] = {}
        for i = 0, w - 1 do
            t.tilepoints[j][i] = { height = 0, layer_height = 2, ground_texture = 0, texture_details = 0,
                                   has_water = false, water_level = 0, is_blight = false, is_ramp = false }
        end
    end
    return t
end

local terrain = made_terrain(200, 65)
local L0 = coords.layout(terrain)
-- a WC3 point at tile point (i, j)
local function at(i, j) return L0.offset_x + i * 128, L0.offset_y + j * 128 end
local function doodad(id, i, j, extra)
    local x, y = at(i, j)
    local d = { id = id, variation = 0, position = { x = x, y = y, z = 0 }, angle = 0.7, scale = { x = 1, y = 1, z = 1 },
                flags = 2, life = 100, creation_number = 0 }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end
local function unit(id, player, i, j, angle)
    local x, y = at(i, j)
    return { id = id, variation = 0, position = { x = x, y = y, z = 0 }, angle = angle or 0, scale = { x = 1, y = 1, z = 1 },
             flags = 2, player = player, creation_number = 0 }
end

local made_models = TMP .. "/models.lua"
write_file(made_models, [[
return { format = 1,
  doodads = {
    types = { LTlt = { name = "tree", wow = "World\\Test\\Tree.m2", scale = 0.5, checked = false },
              LTwm = { name = "a hut", wow = "World\\Test\\Hut.wmo", size = { 20, 10 }, checked = false } },
    classes = { R = { any = { name = "rock", wow = "World\\Test\\Rock.m2", checked = false } } },
  },
  units = {
    fallback = { name = "Unmapped unit", wow = "World\\Test\\Crate.m2", checked = false },
    types = { hfoo = { name = "Footman", wow = "Creature\\Test\\Footman.m2", scale = 1.5, radius = 1, reach = 2, checked = false },
              nwlf = { name = "Timber Wolf", wow = "Creature\\Test\\Wolf.m2", checked = false } },
  },
}
]])

local made_doodads = {
    doodad("LTlt", 10, 20, { angle = 1.0, creation_number = 1 }),                  -- 1: M2 (type), west tile
    doodad("LRrk", 150, 30, { scale = { x = 2, y = 2, z = 2 }, creation_number = 2 }), -- 2: M2 (class), east tile
    doodad("LTlt", 20, 20, { flags = 0, creation_number = 3 }),                    -- 3: hidden
    doodad("ZZzz", 30, 20, { creation_number = 4 }),                               -- 4: unmapped
    doodad("LTlt", 400, 20, { creation_number = 5 }),                              -- 5: outside the map
    doodad("LTwm", 128, 32, { angle = 0, creation_number = 6 }),                   -- 6: WMO on the tiles' edge
    doodad("X001", 60, 40, { creation_number = 7 }),                               -- 7: the map's own model
    doodad("LTlt", 64, 8, { scale = { x = 1, y = 2, z = 1 }, creation_number = 8 }), -- 8: scale not the same each way
}
local made_units = {
    unit("hfoo", 0, 12, 12, 0.3), unit("hfoo", 0, 13, 12), unit("hfoo", 1, 140, 50, 2.0),
    unit("sloc", 0, 5, 5), unit("ZZuu", 1, 150, 50), unit("nwlf", 12, 100, 30, 4.0),
    unit("YYU1", 0, 6, 6), unit("YYI1", 0, 7, 7), unit("hfoo", 0, 500, 500),
}
local hut = "MDLX" .. string.rep("\0", 12)
local made_map = {
    doodads = { version = 8, doodads = made_doodads },
    units = { version = 8, units = made_units },
    info = { version = 25, flags = { use_custom_forces = false },
             players = { { number = 0, name = "Red", start_x = at(5, 5) }, { number = 1, name = "Blue", start_x = at(190, 60) } } },
    objects = { doodads = {
        has = function(_, id) return id == "X001" end,
        custom = { X001 = { parent_id = "LTlt" } },
        get_modification = function(_, id, field) if id == "X001" and field == "dfil" then return "war3mapImported\\Hut.mdl" end end,
    } },
    has_file = function(path) if path == "war3mapImported\\Hut.mdx" then return path end end,
    read_file = function(path) if path == "war3mapImported\\Hut.mdx" then return hut end end,
}
made_map.info.players[1].start_y = select(2, at(5, 5))
made_map.info.players[2].start_y = select(2, at(190, 60))

test_section("A made map: doodads in the ADTs")
local build = TMP .. "/build"
local report, job, P, C = wowbuild.convert("made.w3x", build, { terrain = terrain, map = made_map, models = made_models,
                                                               name = "WC3_made", map_id = 923, stock_dbc = false })
local pc = report.doodads
do
    test("8 doodads: 4 placed as models (one the map's own), 1 building", pc.doodads == 8 and pc.placed_m2 == 4 and pc.placed_wmo == 1,
        string.format("%d, %d M2, %d WMO", pc.doodads, pc.placed_m2, pc.placed_wmo))
    test("the hidden one, the unmapped one and the one outside are left out and counted",
        pc.hidden == 1 and pc.unmapped == 1 and pc.outside == 1 and P.list[3].left_out == "hidden"
        and P.list[4].left_out == "unmapped" and P.list[5].left_out == "outside")
    test("the unmapped type is named for the report", pc.unmapped_ids == 1 and report.warnings >= 1)
    test("a scale not the same each way is counted", pc.nonuniform_scales == 1)
    test("by source: 1 the map's own, 4 by type or class (the building too)", pc.by_source.map == 1 and pc.by_source.type + pc.by_source.class == 4)
end

local tiles_read = {}
if not W then
    skip("a made map's ADTs through the W client's reader", "no library")
else
    local names = { [0] = "WC3_made_31_32.adt", [1] = "WC3_made_32_32.adt" }
    local bytes = {}
    for k = 0, 1 do
        bytes[k] = read_file(build .. "/World/Maps/WC3_made/" .. names[k])
        local r, err = read_adt(bytes[k])
        test("the W client reads " .. names[k] .. " with its placements", r ~= nil, err)
        tiles_read[k] = r
    end
    local west, east = tiles_read[0], tiles_read[1]
    if west and east then
        -- every placed M2 comes back where it was placed, its model, turn and size
        local bad, found = {}, 0
        for k, e in pairs(P.list) do
            if e.kind == "m2" then
                local r = (e.world[2] > select(2, L0:vertex_world(0, 128))) and west or east
                local hit
                for n = 0, r.n_doodads - 1 do if r.doodads[n].uid == e.uid then hit = r.doodads[n] end end
                if not hit then bad[#bad + 1] = "doodad " .. k .. " not found"
                else
                    found = found + 1
                    if r.models[hit.name] ~= e.wow then bad[#bad + 1] = k .. ": model " .. tostring(r.models[hit.name]) end
                    if math.abs(hit.x - e.world[1]) > 0.01 or math.abs(hit.y - e.world[2]) > 0.01 or math.abs(hit.z - e.world[3]) > 0.01 then
                        bad[#bad + 1] = string.format("%d: at %.3f %.3f %.3f, placed %.3f %.3f %.3f", k, hit.x, hit.y, hit.z, e.world[1], e.world[2], e.world[3])
                    end
                    if math.abs(hit.rot[2] - placements.rotation_y(e.angle)) > 1e-3 or hit.rot[1] ~= 0 or hit.rot[3] ~= 0 then
                        bad[#bad + 1] = k .. ": turned " .. hit.rot[2]
                    end
                end
            end
        end
        test("every placed model comes back: its model, place (0.01 yd) and turn", #bad == 0 and found == 4, table.concat(bad, "; "))
        local tree
        for n = 0, west.n_doodads - 1 do if west.doodads[n].uid == 1 then tree = west.doodads[n] end end
        test("a tree's size: its own (1) times its row's (0.5)", tree and math.abs(tree.scale - 0.5) < 1e-6, tree and tostring(tree.scale))
        local rock
        for n = 0, east.n_doodads - 1 do if east.doodads[n].uid == 2 then rock = east.doodads[n] end end
        test("a rock placed twice its size comes back twice its size", rock and math.abs(rock.scale - 2) < 1e-6)
        test("the map's own model is named by its own path", (function()
            for n = 0, west.n_doodads - 1 do
                if west.doodads[n].uid == 7 then return west.models[west.doodads[n].name] == "war3mapImported\\Hut.mdx" end
            end
        end)())
        test("the tree model is named once in the tile for its placements",
            (function() local c = 0 for _, m in pairs(west.models) do if m == "World\\Test\\Tree.m2" then c = c + 1 end end return c == 1 end)())

        -- the building on the tiles' edge: in both tiles, one uid, one box
        local hw, he = west.places[0], east.places[0]
        test("a building on two tiles is placed in both", west.n_places == 1 and east.n_places == 1)
        if hw and he then
            local e = P.list[6]
            test("with the same uid (so a client draws it once)", hw.uid == 6 and he.uid == 6)
            test("named in both tiles' MWMO", west.buildings[hw.name] == "World\\Test\\Hut.wmo" and east.buildings[he.name] == "World\\Test\\Hut.wmo")
            test("where it was placed (0.01 yd)", math.abs(hw.x - e.world[1]) < 0.01 and math.abs(hw.y - e.world[2]) < 0.01
                and math.abs(he.x - hw.x) < 1e-3)
            local ok = math.abs(hw.lo[1] - (e.world[1] - 10)) < 0.01 and math.abs(hw.hi[1] - (e.world[1] + 10)) < 0.01
                and math.abs(hw.lo[2] - (e.world[2] - 10)) < 0.01 and math.abs(hw.hi[2] - (e.world[2] + 10)) < 0.01
                and math.abs(hw.lo[3] - e.world[3]) < 0.01 and math.abs(hw.hi[3] - (e.world[3] + 10)) < 0.01
            test("its box: 20 yards across, 10 high, round where it stands", ok,
                string.format("lo %.2f %.2f %.2f hi %.2f %.2f %.2f", hw.lo[1], hw.lo[2], hw.lo[3], hw.hi[1], hw.hi[2], hw.hi[3]))
        end
    end

    -- MCRF, walked here: each placement is referenced from the chunk it stands in
    local bad = {}
    for k = 0, 1 do
        local chunks, nd, nw = walk_mcrf(bytes[k])
        if not chunks then bad[#bad + 1] = nd
        else
            local seen_d, seen_w = {}, {}
            for ci, c in pairs(chunks) do
                for _, v in ipairs(c.d) do
                    if v >= nd then bad[#bad + 1] = "chunk " .. ci .. " names model placement " .. v .. " of " .. nd end
                    seen_d[v] = (seen_d[v] or 0) + 1
                    local r = tiles_read[k]
                    local p = r and r.doodads[v]
                    if p then
                        -- the chunk holding the placement's point
                        local t = (k == 0) and { bx = 0 } or { bx = 1 }
                        local row = (coords.ORIGIN - p.x) / coords.CELL - L0.ty0 * 128
                        local col = (coords.ORIGIN - p.y) / coords.CELL - L0.tx0 * 128 - t.bx * 128
                        if math.floor(row / 8) ~= c.iy or math.floor(col / 8) ~= c.ix then
                            bad[#bad + 1] = string.format("model placement %d is referenced from chunk %d,%d but stands in %d,%d", v, c.ix, c.iy,
                                math.floor(col / 8), math.floor(row / 8))
                        end
                    end
                end
                for _, v in ipairs(c.w) do
                    if v >= nw then bad[#bad + 1] = "chunk " .. ci .. " names building " .. v .. " of " .. nw end
                    seen_w[v] = (seen_w[v] or 0) + 1
                end
            end
            for v = 0, nd - 1 do if seen_d[v] ~= 1 then bad[#bad + 1] = names[k] .. ": model placement " .. v .. " referenced " .. (seen_d[v] or 0) .. " times" end end
            for v = 0, nw - 1 do if not seen_w[v] then bad[#bad + 1] = names[k] .. ": building " .. v .. " referenced from no chunk" end end
            if nw == 1 then
                local n = 0
                for _ in pairs(seen_w) do n = n + 1 end
                if (seen_w[0] or 0) < 2 then bad[#bad + 1] = names[k] .. ": the building is referenced from " .. (seen_w[0] or 0) .. " chunks (it spans at least 2 here)" end
            end
        end
    end
    test("each chunk's MCRF names the model placements standing in it, each once, and the building's chunks", #bad == 0, table.concat(bad, "; "))
end

test_section("A made map: the map's own model travels with it")
do
    local copied = read_file(build .. "/war3mapImported/Hut.mdx")
    test("copied into the build at its own path", copied == hut)
    test("and listed among the written files", (function()
        for _, f in ipairs(report.files) do if f.path == "war3mapImported/Hut.mdx" and f.own then return true end end
    end)())
    test("the report names it", pc.own_models and #pc.own_models == 1 and pc.own_models[1] == "war3mapImported\\Hut.mdx")
end

test_section("A made map: units as the server's creatures")
local sql = read_file(build .. "/" .. wowbuild.SQL) or ""
do
    local uc = report.units
    test("9 units: 5 spawned; the start location, the random unit, the item and the one outside left out",
        uc.units == 9 and uc.spawned == 5 and uc.sloc_units == 1 and uc.random_left_out == 1 and uc.items_left_out == 1
        and uc.outside == 1, string.format("%d units, %d spawned", uc.units, uc.spawned))
    test("4 templates: red's footmen, blue's footmen, blue's unmapped unit, the neutral wolf", uc.templates == 4, tostring(uc.templates))
    test("one display per model and size: footman, crate, wolf", uc.displays == 3, tostring(uc.displays))
    test("the unmapped unit type is named", #uc.unmapped_ids == 1 and uc.unmapped_ids[1] == "ZZuu")
    test("two start locations, from war3map.w3i", uc.start_locations == 2)

    -- factions: one per player slot here (no custom forces), then the neutrals
    local f = C.factions
    test("factions: Red, Blue, Neutral Hostile, Neutral Passive", #f == 4 and f[1].name == "Red" and f[2].name == "Blue"
        and f[3].name == "Neutral Hostile" and f[4].name == "Neutral Passive")
    test("faction templates numbered from the slot's first (" .. F0 .. ")", f[1].template == F0 and f[4].template == F0 + 3)
    local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end end
    test("Red and Blue are enemies; Neutral Hostile is everyone's; Neutral Passive no one's",
        has(f[1].enemies, F0 + 1) and has(f[1].enemies, F0 + 2) and has(f[3].enemies, F0) and #f[4].enemies == 0
        and not has(f[1].enemies, F0 + 3))
    local wolf
    for _, t in ipairs(C.templates) do if t.id == "nwlf" then wolf = t end end
    test("player 12's wolf is Neutral Hostile's", wolf and wolf.faction.template == F0 + 2)

    -- the SQL: its rows hang together
    test("the map id is the one asked for, in one line", sql:find("SET @MAP := 923;", 1, true) ~= nil)
    test("the template and spawn blocks are the slot's",
        sql:find("SET @ENTRY := " .. IDS.entry .. ";", 1, true) ~= nil and sql:find("SET @GUID := " .. IDS.guid .. ";", 1, true) ~= nil)
    test("it deletes this map's old rows first (it can be run again)", sql:find("DELETE FROM `creature` WHERE `map` = @MAP;", 1, true)
        and sql:find("DELETE FROM `creature`") < sql:find("INSERT INTO `creature`"))
    local entries, guids, bad = {}, {}, {}
    for n, faction in sql:gmatch("\n  %(@ENTRY %+ (%d+), 0, 0, 0, 0, 0, '[^\n]-', '', NULL, 0, %d+, %d+, 0, (%d+),") do
        n = tonumber(n)
        if entries[n] then bad[#bad + 1] = "template " .. n .. " twice" end
        entries[n] = tonumber(faction)
    end
    local n_entries = 0
    for _ in pairs(entries) do n_entries = n_entries + 1 end
    test("4 creature_template rows, each a faction the map has", n_entries == 4 and (function()
        for _, fa in pairs(entries) do if fa < F0 or fa > F0 + 3 then return false end end
        return true
    end)(), n_entries .. " rows")
    local n_spawns = 0
    for g, e in sql:gmatch("\n  %(@GUID %+ (%d+), @ENTRY %+ (%d+), @MAP,") do
        n_spawns = n_spawns + 1
        g, e = tonumber(g), tonumber(e)
        if guids[g] then bad[#bad + 1] = "guid " .. g .. " twice" end
        guids[g] = true
        if not entries[e] then bad[#bad + 1] = "spawn " .. g .. " names template " .. e .. ", not written" end
    end
    test("5 creature rows, each guid once, each naming a written template", n_spawns == 5 and #bad == 0, table.concat(bad, "; "))
    local models_rows = select(2, sql:gsub("\n  %(@ENTRY %+ %d+, 0, 73%d%d%d, 1, 1%)", ""))
    local info_rows = select(2, sql:gsub("\n  %(73%d%d%d, [%d.]+, [%d.]+, 2, 0%)", ""))
    test("each template has its model, and each display id its creature_model_info row", models_rows == 4 and info_rows == 3,
        models_rows .. " models, " .. info_rows .. " infos")
    local foot = C.spawns[1]
    local X, Y = L0:to_wow(foot.wc3[1], foot.wc3[2])
    test("a spawn stands where the WC3 unit stood, facing its way",
        math.abs(foot.world[1] - X) < 1e-6 and math.abs(foot.world[2] - Y) < 1e-6 and math.abs(foot.orientation - placements.orientation(0.3)) < 1e-9)
    test("the SQL writes nothing of a stock world database: only this map's tables",
        not sql:find("INSERT INTO `[^`]*`", 1) or (function()
            for t in sql:gmatch("INSERT INTO `([^`]*)`") do
                if t ~= "creature_template" and t ~= "creature_template_model" and t ~= "creature_model_info" and t ~= "creature" then return false end
            end
            return true
        end)())
end

test_section("A made map: a name the map maker wrote can't break the SQL")
do
    local m2 = {}
    for k, v in pairs(made_map) do m2[k] = v end
    m2.doodads = nil
    m2.info = { version = 25, flags = { use_custom_forces = true },
                forces = { { name = "Bad\n'); DROP TABLE creature; --", players = { 0, 1 }, flags = { allied = true } } },
                players = { { number = 0, name = "Red" }, { number = 1, name = "Blue" } } }
    m2.objects = { units = {
        has = function(_, id) return id == "hfoo" end, custom = {},
        get_modification = function(_, id, field) if id == "hfoo" and field == "unam" then return "Foot'man\\\n" end end,
    } }
    local _, _, _, C2 = wowbuild.convert("made.w3x", TMP .. "/build2", { terrain = terrain, map = m2, models = made_models, name = "WC3_made2", stock_dbc = false })
    local s = read_file(TMP .. "/build2/" .. wowbuild.SQL) or ""
    local stray = false
    for line in s:gmatch("[^\n]+") do
        local at = line:find("DROP TABLE", 1, true)
        if at and not line:sub(1, at):find("%-%-") then stray = true end
    end
    test("a force name with a line break stays inside its comment", not stray and s:find("DROP TABLE creature", 1, true) ~= nil)
    test("one faction for the one force, its players allied", C2.factions[1].allied == true and #C2.factions[1].players == 2
        and C2.faction_of[0] == C2.factions[1] and C2.faction_of[1] == C2.factions[1])
    test("a quote and a backslash in a unit's name are escaped, a line break made a space", s:find("'Foot''man\\\\ '", 1, true) ~= nil)
end

test_section("A made map: the placement list")
do
    local list = loadfile(build .. "/" .. wowbuild.PLACEMENTS, "t", {})
    if list and setfenv then setfenv(list, {}) end
    local ok, t = pcall(list or error)
    test("placements.lua reads as data", ok and type(t) == "table" and t.format == 1)
    if ok and type(t) == "table" then
        test("every doodad listed, with what became of it", #t.doodads == 8 and t.doodads[3].left_out == "hidden" and t.doodads[1].kind == "m2"
            and t.doodads[6].kind == "wmo")
        test("every spawn, template, display and faction listed", #t.units == 5 and #t.templates == 4 and #t.displays == 3 and #t.factions == 4)
        test("the ids the SQL starts from: slot 23's", t.ids.map == 923 and t.ids.entry == IDS.entry and t.ids.display == IDS.display
            and IDS.display == 73000)
    end
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
local mpq_ok, mpq_err = pcall(function() require("mpq").open(maps[1] or ""):close() end)
if #maps == 0 then
    skip("maps in assets/", "none found in " .. DIR .. "/assets")
elseif not mpq_ok and tostring(mpq_err):find("StormLib") then
    skip("maps in assets/", "StormLib isn't built here")
else
    -- every map's doodads and units read, to the last byte, and write back the same
    local doo_bad, units_bad, n_doo, n_units = {}, {}, 0, 0
    for _, path in ipairs(maps) do
        local name = path:match("[^/]*$")
        local ok, a = pcall(require("mpq").open, path)
        if ok then
            if a:has("war3map.doo") then
                n_doo = n_doo + 1
                local bytes = a:extract("war3map.doo")
                local r, err = doo.parse(bytes)
                if not r then doo_bad[#doo_bad + 1] = name .. ": " .. tostring(err)
                elseif doo.write(r) ~= bytes then doo_bad[#doo_bad + 1] = name .. ": written back, not the same bytes"
                elseif r.version >= 8 then
                    local seen = {}
                    for _, d in ipairs(r.doodads) do
                        if seen[d.creation_number] then doo_bad[#doo_bad + 1] = name .. ": creation number " .. d.creation_number .. " twice" break end
                        seen[d.creation_number] = true
                    end
                end
            end
            if a:has("war3mapUnits.doo") then
                n_units = n_units + 1
                local bytes = a:extract("war3mapUnits.doo")
                local ok2, r, err = pcall(unitsdoo.parse, bytes)
                if not ok2 or not r then units_bad[#units_bad + 1] = name .. ": " .. tostring(ok2 and err or r)
                elseif unitsdoo.write(r) ~= bytes then units_bad[#units_bad + 1] = name .. ": written back, not the same bytes"
                end
            end
            a:close()
        end
    end
    test("every map's war3map.doo reads and writes back the same (" .. n_doo .. " maps); version 8's creation numbers each once",
        #doo_bad == 0, table.concat(doo_bad, "; "))
    test("every map's war3mapUnits.doo reads to its last byte and writes back the same (" .. n_units .. " maps)",
        #units_bad == 0, table.concat(units_bad, "; "))

    local function pick(pattern) for _, m in ipairs(maps) do if m:match("[^/]*$"):find(pattern) then return m end end end
    local chosen = { pick("^DAoW%-2%.1"), pick("^Master%-Crafters"), pick("Plaguelands") }
    for _, path in ipairs(chosen) do
        local name = path:match("([^/]*)%.w3x$")
        local out = TMP .. "/real-" .. name:gsub("[^%w]", "_")
        local ok, rep, rjob, RP, RC = pcall(wowbuild.convert, path, out, { stock_dbc = false, patch = false })
        test(name .. ": converts", ok, not ok and tostring(rep) or nil)
        if ok then
            local c = rep.doodads
            print(string.format("  (%s: %d doodads, %d models and %d buildings placed, %d unmapped in %d types, %d hidden; %d units, %d spawned, %d templates)",
                name, c.doodads, c.placed_m2, c.placed_wmo, c.unmapped, c.unmapped_ids, c.hidden, rep.units.units, rep.units.spawned, rep.units.templates))
            test(name .. ": every doodad placed or counted as left out",
                c.placed_m2 + c.placed_wmo + c.hidden + c.unmapped + c.outside == c.doodads)
            -- the doodads stand on the converted ground: a WC3 doodad carries its
            -- own height, kept as it is, so this checks the two agree. Not all:
            -- War in the Plaguelands raises and sinks a ninth of its doodads
            -- (most of them its own types) on purpose
            local near, n = 0, 0
            for _, e in ipairs(RP.list) do
                if e.world then
                    n = n + 1
                    if math.abs(e.world[3] - rjob:height_at(e.wc3[1], e.wc3[2])) < 1 then near = near + 1 end
                end
            end
            test(name .. ": most placed doodads (85 in 100) stand within a yard of the converted ground", n == 0 or near / n >= 0.85,
                string.format("%d of %d", near, n))
            if W then
                local got, bad = 0, {}
                for _, f in ipairs(rep.files) do
                    if f.path:match("%.adt$") then
                        local bytes = read_file(out .. "/" .. f.path)
                        local r, err = read_adt(bytes)
                        if not r then bad[#bad + 1] = f.path .. ": " .. err
                        else
                            got = got + r.n_doodads
                            local chunks, why = walk_mcrf(bytes)
                            if not chunks then bad[#bad + 1] = f.path .. ": " .. why end
                        end
                    end
                end
                test(name .. ": the W client reads every ADT, with every placed model (" .. got .. ")",
                    #bad == 0 and got == c.placed_m2, table.concat(bad, "; "))
            else
                skip(name .. ": the W client reads its ADTs", "no library")
            end
            if rep.units.spawned > 0 then
                local s = read_file(out .. "/" .. wowbuild.SQL) or ""
                local entries, bad = {}, 0
                for e in s:gmatch("\n  %(@ENTRY %+ (%d+), 0, 0, 0, 0, 0,") do entries[tonumber(e)] = true end
                local spawns = 0
                for e in s:gmatch("\n  %(@GUID %+ %d+, @ENTRY %+ (%d+), @MAP,") do
                    spawns = spawns + 1
                    if not entries[tonumber(e)] then bad = bad + 1 end
                end
                test(name .. ": every spawn's template is written (" .. spawns .. " spawns)", spawns == rep.units.spawned and bad == 0)
                local names_ok = true
                for _, f in ipairs(RC.factions) do if f.name:match("^TRIGSTR_") then names_ok = false end end
                test(name .. ": force names read from the map's strings", names_ok)
            end
            -- the map's own models: copied, and nothing else of the map's
            local own = c.own_models
            if #own > 0 then
                local missing = 0
                for _, p in ipairs(own) do if not read_file(out .. "/" .. p:gsub("\\", "/")) then missing = missing + 1 end end
                test(name .. ": its own models travel with it (" .. #own .. ")", missing == 0, missing .. " missing")
                local p = io.popen("find " .. quote(out) .. " -type f")
                local other = {}
                for line in p:lines() do
                    local rel = line:sub(#out + 2)
                    -- W02c's registration files are made, not copied
                    local made = rel:match("^DBFilesClient/") or rel:match("^world/creatures%-%d+%.tsv$") or rel == wowbuild.MAP_FILE
                        or rel == "server/dbc.sql" or rel == "patch-W.MPQ"
                        -- and W02e's: the script transpiled, the shim's data, the coverage report
                        or rel:match("^server/triggers/[%w_]+/[%w%-]+%.lua$")
                    if not (made or rel:match("^World/Maps/") or rel == wowbuild.SQL or rel == wowbuild.PLACEMENTS or rel == wowbuild.REPORT
                            or rel:lower():match("%.mdx$") or rel:lower():match("%.blp$") or rel:lower():match("%.tga$")) then
                        other[#other + 1] = rel
                    end
                end
                p:close()
                test(name .. ": nothing else is copied from the map (models and their textures only)", #other == 0, table.concat(other, " "))
            end
            os.execute("rm -rf " .. quote(out))
        end
    end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))
print(string.format("\nTests: %d passed, %d failed, %d skipped", pass_count, test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)
