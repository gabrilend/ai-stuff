--[[
wowbuild - a WC3 map built into WoW 3.3.5a's files (issue W02)

The converter behind the editor's Test Map (issue 913) and the owner's one
command. Stage by stage it follows docs/datapath-wc3-map-into-wow-client.md;
built so far, stages 2 and 3:

  terrain      the WDT, the WDL and one ADT a 533-yard tile: heights,
               normals, up to four textures a chunk with blend maps, water
               (wowbuild.terrain decides the numbers, wowbuild.adt writes
               the bytes, wowbuild.coords places the map) (W02a)
  placements   doodads as model (M2) and building (WMO) placements in the
               ADTs, through the model table wowbuild/models.lua
               (wowbuild.placements); units as the server's creatures, one
               faction per WC3 force, written as SQL (wowbuild.creatures);
               the map's own imported models, which travel with it (W02b)

Still to come, each adding to convert() below: the map's table rows and
patch-W.MPQ (W02c), the server's extracted data (W02d), triggers on the
server (W02e), the rest of the empty world database (W02h).

The build folder is a loose overlay as the W client reads one (its issue
105a): files at the paths the client's archives use, so

  <build>/World/Maps/<dir>/<dir>.wdt
  <build>/World/Maps/<dir>/<dir>.wdl
  <build>/World/Maps/<dir>/<dir>_<tx>_<ty>.adt    tx west to east, ty north to south
  <build>/<the map's own file path>               its imported models and their textures
                                                  (war3mapImported\X.mdx ...), at their
                                                  own names, so a model finds its textures
  <build>/server/world.sql                        the creatures, for AzerothCore (W02h:
                                                  only what the map uses)
  <build>/placements.lua                          every doodad, unit and start location,
                                                  what became of it; the display ids and
                                                  factions W02c writes into client tables (data)
  <build>/conversion-report.lua                   what was done, counted (data)

<dir> is the map's directory name, "WC3_" and the map file's name with
everything but letters and digits made "_" (DAoW-2.1.w3x -> WC3_DAoW_2_1),
or opts.name. Nothing of Blizzard's is written: the ADTs name WoW's textures
and models by path; those files stay in the owner's client (or come from
the baseline model set). The only files copied are the map's own imports.

    local wowbuild = require("wowbuild")
    local report = wowbuild.convert("assets/DAoW-2.1.w3x", "tmp/test-map/build", { strict = false })
    print(wowbuild.summary(report))
]]

local mpq = require("mpq")
local w3e = require("parsers.w3e")
local doo = require("parsers.doo")
local unitsdoo = require("parsers.unitsdoo")
local w3i = require("parsers.w3i")
local wts = require("parsers.wts")
local objectdata = require("parsers.objectdata")
local wterrain = require("wowbuild.terrain")
local adt = require("wowbuild.adt")
local placements = require("wowbuild.placements")
local creatures = require("wowbuild.creatures")

local wowbuild = {}

wowbuild.REPORT = "conversion-report.lua"
wowbuild.PLACEMENTS = "placements.lua"
wowbuild.SQL = "server/world.sql"
wowbuild.STAGES_NOT_BUILT = {
    "W02c map registration and patch-W.MPQ",
    "W02d server data for new maps",
    "W02e triggers on the server",
    "W02h empty world database",
}

-- {{{ helpers
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function write_file(path, bytes)
    local f, err = io.open(path, "wb")
    if not f then error("can't write " .. path .. ": " .. tostring(err), 0) end
    f:write(bytes)
    f:close()
end

-- Lua source for plain data, keys sorted so reports diff cleanly
local function serialize(value, indent)
    indent = indent or ""
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" then
        if value == math.floor(value) and math.abs(value) < 2 ^ 53 then return string.format("%d", value) end
        return string.format("%.6g", value)
    end
    if kind == "boolean" then return tostring(value) end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    if #keys == 0 then return "{}" end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    local inner = indent .. "    "
    local parts = {}
    for _, k in ipairs(keys) do
        local key = type(k) == "number" and "" or
            ((type(k) == "string" and k:match("^[%a_][%w_]*$")) and (k .. " = ") or string.format("[%q] = ", k))
        parts[#parts + 1] = inner .. key .. serialize(value[k], inner)
    end
    return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. indent .. "}"
end
wowbuild.serialize = serialize
-- }}}

-- {{{ wowbuild.map_directory
-- The WoW map directory name for a map file path
function wowbuild.map_directory(map_path)
    local base = tostring(map_path):match("([^/\\]+)$") or "map"
    base = base:gsub("%.[wW]3[xXmM]$", "")
    base = base:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "" then base = "map" end
    return ("WC3_" .. base):sub(1, 48)
end

-- a name given by hand: letters, digits and _, 1-48 long
function wowbuild.valid_name(name)
    return type(name) == "string" and #name >= 1 and #name <= 48 and name:match("^[%w_]+$") ~= nil
end
-- }}}

-- {{{ wowbuild.read_terrain
function wowbuild.read_terrain(map_path)
    local f = io.open(map_path, "rb")
    if not f then error("no map file " .. tostring(map_path), 0) end
    f:close()
    local archive = mpq.open(map_path)
    local ok, data = pcall(function() return archive:extract("war3map.w3e") end)
    archive:close()
    if not ok or not data then error(map_path .. " holds no war3map.w3e (its terrain): " .. tostring(data), 0) end
    return w3e.parse(data)
end
-- }}}

-- {{{ wowbuild.read_map
-- The parts of a map W02b places, read with the project's own readers:
-- { doodads, units, info, strings, objects = { units, items, destructibles,
-- doodads }, has_file, read_file, close }. A part the map lacks is nil
-- (protected maps often carry no war3mapUnits.doo); a part that is there but
-- can't be read stops the conversion. The archive stays open until close().
function wowbuild.read_map(map_path)
    local archive = mpq.open(map_path)
    local function get(name) if archive:has(name) then return archive:extract(name) end end
    local function parse(name, fn)
        local bytes = get(name)
        if not bytes then return nil end
        local r, err = fn(bytes)
        if not r then archive:close() error(map_path .. ": " .. name .. ": " .. tostring(err), 0) end
        return r
    end
    local map = {}
    map.doodads = parse("war3map.doo", doo.parse)
    map.units = parse("war3mapUnits.doo", unitsdoo.parse)
    map.info = parse("war3map.w3i", w3i.parse)
    map.strings = parse("war3map.wts", function(b) return wts.parse(b) end)
    map.objects = {}
    for file, kind in pairs({ ["war3map.w3u"] = "units", ["war3map.w3t"] = "items",
                              ["war3map.w3b"] = "destructibles", ["war3map.w3d"] = "doodads" }) do
        map.objects[kind] = parse(file, function(b)
            return objectdata.parse(b, objectdata.FILE_CONFIG[file:match("(w3.)$")])
        end)
    end
    map.has_file = function(path) if archive:has(path) then return path end end
    map.read_file = function(path) return archive:extract(path) end
    map.close = function() archive:close() end
    return map
end
-- }}}

-- {{{ the map's own files the placements use
-- Each model, and the textures it names that the map also holds, copied to
-- <build>/<its own path>. Returns the list written.
local function carry_imports(map, build_dir, models, out)
    local done = {}
    local function copy(path)
        if done[path] or not map.read_file then return nil end
        local bytes = map.read_file(path)
        if not bytes then return nil end
        done[path] = true
        local rel = path:gsub("\\", "/")
        local dir = (build_dir .. "/" .. rel):match("^(.*)/[^/]*$")
        os.execute("mkdir -p " .. quote(dir))
        write_file(build_dir .. "/" .. rel, bytes)
        out[#out + 1] = { path = rel, bytes = #bytes, own = true }
        return bytes
    end
    for _, path in ipairs(models) do
        local bytes = copy(path)
        if bytes and bytes:sub(1, 4) == "MDLX" then
            local ok, m = pcall(require("parsers.mdx").parse, bytes)
            if ok and m and m.textures then
                for _, t in ipairs(m.textures) do
                    if t.path and t.path ~= "" and map.has_file(t.path) then copy(t.path) end
                end
            end
        end
    end
end
-- }}}

-- {{{ the placement list (data, for the W client and W02c)
local function placement_list(P, C)
    local displays = {}
    for _, d in ipairs(C.displays) do
        displays[#displays + 1] = { id = d.id, model = d.wow, scale = d.scale, own = d.own, checked = d.checked,
                                    baseline = d.baseline }
    end
    local factions = {}
    for _, f in ipairs(C.factions) do
        factions[#factions + 1] = { template = f.template, name = f.name, force = f.force, players = f.players,
                                    allied = f.allied, neutral = f.neutral, enemies = f.enemies }
    end
    local units = {}
    for _, s in ipairs(C.spawns) do
        units[#units + 1] = { guid = s.guid, entry = s.template.entry, id = s.id, player = s.player,
                              creation_number = s.creation_number, wc3 = s.wc3, world = s.world,
                              orientation = s.orientation, faction = s.faction.template, hero_level = s.hero_level }
    end
    local templates = {}
    for _, t in ipairs(C.templates) do
        templates[#templates + 1] = { entry = t.entry, id = t.id, base = t.base, name = t.name, level = t.level,
                                      display = t.display.id, faction = t.faction.template, model_from = t.source,
                                      wc3_model = t.wc3_model }
    end
    return {
        format = 1,
        doodads = P.list,
        units = units,
        templates = templates,
        displays = displays,
        factions = factions,
        start_locations = C.start_locations,
        ids = C:counts().ids,
    }
end
-- }}}

-- {{{ wowbuild.convert
-- opts: strict (a texture fold stops the build), name (map directory),
-- textures (another ground table's path), models (another model table's
-- path), map_id (the server's map id until W02c picks one), terrain (a
-- parsed terrain, for tests: map_path is then only a label), map (the
-- parts wowbuild.read_map gives, for tests; without terrain and map the
-- map file is read)
function wowbuild.convert(map_path, build_dir, opts)
    opts = opts or {}
    assert(type(build_dir) == "string" and build_dir ~= "", "convert: no build folder")
    local name = opts.name or wowbuild.map_directory(map_path)
    if not wowbuild.valid_name(name) then error("map directory name " .. tostring(name) .. ": letters, digits and _ only, 1-48 long", 0) end
    local terrain = opts.terrain or wowbuild.read_terrain(map_path)
    local map = opts.map or (opts.terrain and {}) or wowbuild.read_map(map_path)
    local started = os.clock()

    local job = wterrain.prepare(terrain, { strict = opts.strict, textures = opts.textures })
    local models, models_path = placements.load_models(opts.models)
    local P = placements.prepare(map, job.layout, models)
    local C = creatures.prepare(map, job.layout, job, models, { map_id = opts.map_id })

    -- this map's folder, emptied first: the converter owns the build folder
    local rel = "World/Maps/" .. name
    local out = build_dir .. "/" .. rel
    os.execute("rm -rf " .. quote(out))
    local made = os.execute("mkdir -p " .. quote(out))
    if made ~= 0 and made ~= true then error("can't make " .. out, 0) end

    local files = {}
    local tiles = job.layout:tiles()
    for _, t in ipairs(tiles) do
        local tile = job:tile(t)
        local file = string.format("%s/%s_%d_%d.adt", rel, name, t.tx, t.ty)
        local bytes = adt.tile_bytes(tile, P.tiles[t.ty * 64 + t.tx])
        write_file(build_dir .. "/" .. file, bytes)
        files[#files + 1] = { path = file, bytes = #bytes }
    end
    local wdt = adt.wdt_bytes(tiles)
    write_file(out .. "/" .. name .. ".wdt", wdt)
    table.insert(files, 1, { path = rel .. "/" .. name .. ".wdt", bytes = #wdt })
    local wdl = adt.wdl_bytes(job)
    write_file(out .. "/" .. name .. ".wdl", wdl)
    table.insert(files, 2, { path = rel .. "/" .. name .. ".wdl", bytes = #wdl })

    -- the map's own models (and their textures), the creatures' SQL, the placement list
    local own = {}
    local pc = P:counts()
    for _, path in ipairs(pc.own_models) do own[#own + 1] = path end
    for _, d in ipairs(C.displays) do if d.own then own[#own + 1] = d.wow end end
    carry_imports(map, build_dir, own, files)
    if map.close then map.close() end
    os.execute("mkdir -p " .. quote(build_dir .. "/server"))
    local sql = creatures.sql(C, { map_dir = name })
    write_file(build_dir .. "/" .. wowbuild.SQL, sql)
    files[#files + 1] = { path = wowbuild.SQL, bytes = #sql }
    local list = "-- W02b's placement list (src/wowbuild): data only\nreturn " .. serialize(placement_list(P, C)) .. "\n"
    write_file(build_dir .. "/" .. wowbuild.PLACEMENTS, list)
    files[#files + 1] = { path = wowbuild.PLACEMENTS, bytes = #list }

    local L = job.layout
    local report = {
        format = 1,
        map = tostring(map_path),
        map_directory = name,
        written = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        strict = opts.strict and true or false,
        seconds = os.clock() - started,
        files = files,
        placement = {
            rule = "one WC3 tile = one WoW cell (4.1667 yd); 30.72 WC3 units a yard",
            first_tile = { L.tx0, L.ty0 },
            wc3_offset = { L.offset_x, L.offset_y },
        },
        terrain = job:finish(),
        doodads = pc,
        units = C:counts(),
        model_table = models_path,
        not_built = wowbuild.STAGES_NOT_BUILT,
    }
    report.warnings = report.terrain.warnings + pc.unmapped_ids + #report.units.unmapped_ids
    write_file(build_dir .. "/" .. wowbuild.REPORT,
        "-- W02's conversion report (src/wowbuild): data only\nreturn " .. serialize(report) .. "\n")
    return report, job, P, C
end
-- }}}

-- {{{ wowbuild.summary
function wowbuild.summary(report)
    local t = report.terrain
    local lines = {
        string.format("converted %s -> World\\Maps\\%s (%d files)", report.map, report.map_directory, #report.files),
        string.format("  terrain: tileset %s, %d x %d tile points, %d x %d ADT tiles from %d_%d, %d chunks",
            t.tileset, t.tilepoints[1], t.tilepoints[2], t.adt_tiles.across, t.adt_tiles.down,
            t.adt_tiles.first[1], t.adt_tiles.first[2], t.chunks),
        string.format("  layers: %d chunks with 1, %d with 2, %d with 3, %d with 4",
            t.layers.one, t.layers.two, t.layers.three, t.layers.four),
        string.format("  water: %d chunks, %d cells", t.liquid.chunks, t.liquid.cells),
        string.format("  textures: %d used, %d of them not yet checked against the client", #t.textures, t.textures_unchecked),
        string.format("  warnings: %d (texture folds %d in %d chunks; unmapped ground types %d, %d tile points; unmapped doodad types %d; unmapped unit types %d)",
            report.warnings, t.folds, t.chunks_folded, t.unmapped_ids, t.unmapped_tilepoints,
            report.doodads and report.doodads.unmapped_ids or 0, report.units and #report.units.unmapped_ids or 0),
    }
    local pairs_list = {}
    for pair, n in pairs(t.fold_pairs) do pairs_list[#pairs_list + 1] = { pair, n } end
    table.sort(pairs_list, function(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end)
    for i = 1, math.min(5, #pairs_list) do
        lines[#lines + 1] = string.format("    fold x%d: %s", pairs_list[i][2], pairs_list[i][1])
    end
    for id, n in pairs(t.unmapped) do
        lines[#lines + 1] = string.format("    unmapped: %s (%d tile points)", id, n)
    end
    local d, u = report.doodads, report.units
    if d then
        lines[#lines + 1] = string.format("  doodads: %d placed (%d models, %d buildings) of %d; %d hidden, %d outside, %d unmapped (%d types)",
            d.placed_m2 + d.placed_wmo, d.placed_m2, d.placed_wmo, d.doodads, d.hidden, d.outside, d.unmapped, d.unmapped_ids)
        lines[#lines + 1] = string.format("    by the map's own model %d, by WC3 model %d, by type %d, by category %d; %d models used, %d unchecked; %d placements wait for a baseline model",
            d.by_source.map, d.by_source.model, d.by_source.type, d.by_source.class, d.models_used, d.models_unchecked, d.waiting_for_baseline)
        local top = {}
        for id, n in pairs(d.unmapped_by_id) do top[#top + 1] = { id, n } end
        table.sort(top, function(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end)
        for i = 1, math.min(5, #top) do
            lines[#lines + 1] = string.format("    unmapped doodad x%d: %s", top[i][2], top[i][1])
        end
    end
    if u then
        lines[#lines + 1] = string.format("  units: %d spawned as %d templates of %d types, %d factions, %d models (%d unchecked); %d start locations",
            u.spawned, u.templates, u.unit_types, u.factions, u.displays, u.displays_unchecked, u.start_locations)
        lines[#lines + 1] = string.format("    left out: %d start-location units, %d items, %d random, %d outside; unmapped types %d%s",
            u.sloc_units, u.items_left_out, u.random_left_out, u.outside, #u.unmapped_ids,
            #u.unmapped_ids > 0 and (" (" .. table.concat(u.unmapped_ids, " ", 1, math.min(8, #u.unmapped_ids)) .. (#u.unmapped_ids > 8 and " ..." or "") .. ")") or "")
    end
    lines[#lines + 1] = "  not built yet: " .. table.concat(report.not_built, "; ")
    return table.concat(lines, "\n")
end
-- }}}

return wowbuild
