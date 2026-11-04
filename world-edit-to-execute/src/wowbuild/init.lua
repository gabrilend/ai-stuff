--[[
wowbuild - a WC3 map built into WoW 3.3.5a's files (issue W02)

The converter behind the editor's Test Map (issue 913) and the owner's one
command. Stage by stage it follows docs/datapath-wc3-map-into-wow-client.md;
today only stage 2, the terrain (W02a), is built:

  terrain      the WDT, the WDL and one ADT a 533-yard tile: heights,
               normals, up to four textures a chunk with blend maps, water
               (wowbuild.terrain decides the numbers, wowbuild.adt writes
               the bytes, wowbuild.coords places the map)

Still to come, each adding to convert() below: doodads and units (W02b),
the map's table rows and patch-W.MPQ (W02c), the server's extracted data
(W02d), triggers on the server (W02e), the empty world database (W02h).

The build folder is a loose overlay as the W client reads one (its issue
105a): files at the paths the client's archives use, so

  <build>/World/Maps/<dir>/<dir>.wdt
  <build>/World/Maps/<dir>/<dir>.wdl
  <build>/World/Maps/<dir>/<dir>_<tx>_<ty>.adt    tx west to east, ty north to south
  <build>/conversion-report.lua                   what was done, counted (data)

<dir> is the map's directory name, "WC3_" and the map file's name with
everything but letters and digits made "_" (DAoW-2.1.w3x -> WC3_DAoW_2_1),
or opts.name. Nothing proprietary is written: the ADTs name WoW's textures
by path; the textures stay in the owner's client.

    local wowbuild = require("wowbuild")
    local report = wowbuild.convert("assets/DAoW-2.1.w3x", "tmp/test-map/build", { strict = false })
    print(wowbuild.summary(report))
]]

local mpq = require("mpq")
local w3e = require("parsers.w3e")
local wterrain = require("wowbuild.terrain")
local adt = require("wowbuild.adt")

local wowbuild = {}

wowbuild.REPORT = "conversion-report.lua"
wowbuild.STAGES_NOT_BUILT = {
    "W02b doodads and units",
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

-- {{{ wowbuild.convert
-- opts: strict (a texture fold stops the build), name (map directory),
-- textures (another ground table's path), terrain (a parsed terrain, for
-- tests: map_path is then only a label)
function wowbuild.convert(map_path, build_dir, opts)
    opts = opts or {}
    assert(type(build_dir) == "string" and build_dir ~= "", "convert: no build folder")
    local name = opts.name or wowbuild.map_directory(map_path)
    if not wowbuild.valid_name(name) then error("map directory name " .. tostring(name) .. ": letters, digits and _ only, 1-48 long", 0) end
    local terrain = opts.terrain or wowbuild.read_terrain(map_path)
    local started = os.clock()

    local job = wterrain.prepare(terrain, { strict = opts.strict, textures = opts.textures })

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
        local bytes = adt.tile_bytes(tile)
        write_file(build_dir .. "/" .. file, bytes)
        files[#files + 1] = { path = file, bytes = #bytes }
    end
    local wdt = adt.wdt_bytes(tiles)
    write_file(out .. "/" .. name .. ".wdt", wdt)
    table.insert(files, 1, { path = rel .. "/" .. name .. ".wdt", bytes = #wdt })
    local wdl = adt.wdl_bytes(job)
    write_file(out .. "/" .. name .. ".wdl", wdl)
    table.insert(files, 2, { path = rel .. "/" .. name .. ".wdl", bytes = #wdl })

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
        not_built = wowbuild.STAGES_NOT_BUILT,
    }
    report.warnings = report.terrain.warnings
    write_file(build_dir .. "/" .. wowbuild.REPORT,
        "-- W02's conversion report (src/wowbuild): data only\nreturn " .. serialize(report) .. "\n")
    return report, job
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
        string.format("  warnings: %d (texture folds %d in %d chunks; unmapped ground types %d, %d tile points)",
            report.warnings, t.folds, t.chunks_folded, t.unmapped_ids, t.unmapped_tilepoints),
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
    lines[#lines + 1] = "  not built yet: " .. table.concat(report.not_built, "; ")
    return table.concat(lines, "\n")
end
-- }}}

return wowbuild
