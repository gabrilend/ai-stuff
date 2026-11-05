--[[
The WoW Layer of a Map (Issue W10a)

The owner, 2026-11-04: "we are unifying them" — one map holds WC3 parts
and WoW parts side by side (issue W10, open question 1). A map project
(issue 911c, editor/mapfile.lua) keeps its WoW parts under wow/, at the
paths the WoW client uses, so the folder is also a loose overlay the W
client reads as it is (its issue 105a):

    MyMap.wex/wow/World/Maps/<dir>/<dir>.wdt         which tiles exist, the blend maps' form
    MyMap.wex/wow/World/Maps/<dir>/<dir>.wdl         far-off heights (when the map has them)
    MyMap.wex/wow/World/Maps/<dir>/<dir>_<tx>_<ty>.adt   a 533-yard tile (tx west to east)

The files are kept byte for byte (mapfile.add_wow copies them in,
mapfile.build_wow copies them out), so a WoW map saved without changes
is the map that was opened. This module reads them for the editor's
tools: a map's tiles, and each tile's ground (heights, holes, texture
layers with their blend maps, shadow, tints), its placed models and
buildings, and its water, as plain Lua data.

Reading goes through the W client's own reader (libwreaders.so, its
020-adt.c), by LuaJIT's FFI: one reader per format (decided 2026-10-07),
none written here. The library is found where $W_CLIENT_BUILD says (a
folder holding libwreaders.so and the wreaders.h its scripts/build
writes), else the W client's own default (its scripts/libs/wreaders.lua).
Without it a map's files are still listed, kept and copied; only reading
a tile says why it can't.

Positions are the reader's: world yards, x north, y west, z up; a tile is
533.33 yards, a chunk 33.33, its 145 heights above the chunk's base z in
the file's order (a row of 9 corners, then 8 centres, ...).

    local wowmap = require("editor.wowmap")
    wowmap.maps(root)                    -- { "WC3_X", ... }: folders under World/Maps with a .wdt
    local M, why = wowmap.open(root, "WC3_X")
    M.tiles                              -- { { tx, ty, file }, ... } sorted, from the files present
    local t, why = M:tile(31, 32)        -- the tile, read (and kept); nil and why
    t.chunks[1].heights[1], t.doodads[1].model, t.liquids[1].kind
]]

local ffi = require("ffi")

local wowmap = {}

wowmap.MAPS = "World/Maps"
wowmap.DEFAULT_BUILD = "/mnt/kaun/custom-client/tmp/tmp/build"   -- the W client's own default

-- {{{ files
local function sh(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function list(dir)
    local out = {}
    local p = io.popen("ls -1 " .. sh(dir) .. " 2>/dev/null")
    if p then for name in p:lines() do out[#out + 1] = name end p:close() end
    table.sort(out)
    return out
end

-- a map's directory name: what the client's tables and paths can hold
function wowmap.valid_name(dir)
    return type(dir) == "string" and dir:match("^[%w_]+$") ~= nil and #dir <= 64
end

-- the map folders under root/World/Maps that hold their <dir>.wdt
function wowmap.maps(root)
    local out = {}
    for _, dir in ipairs(list(root .. "/" .. wowmap.MAPS)) do
        if wowmap.valid_name(dir) and read(root .. "/" .. wowmap.MAPS .. "/" .. dir .. "/" .. dir .. ".wdt") then
            out[#out + 1] = dir
        end
    end
    return out
end

-- a map folder's files, by kind: { wdt, wdl, tiles = { { tx, ty, file } }, other = { names } }
-- (file names relative to the map folder)
function wowmap.files(root, dir)
    local folder = root .. "/" .. wowmap.MAPS .. "/" .. dir
    local out = { tiles = {}, other = {} }
    local lower_dir = dir:lower()
    for _, name in ipairs(list(folder)) do
        local lower = name:lower()
        if lower == lower_dir .. ".wdt" then out.wdt = name
        elseif lower == lower_dir .. ".wdl" then out.wdl = name
        else
            local tx, ty = lower:match("^" .. lower_dir:gsub("%W", "%%%0") .. "_(%d+)_(%d+)%.adt$")
            tx, ty = tonumber(tx), tonumber(ty)
            if tx and ty and tx < 64 and ty < 64 then
                out.tiles[#out.tiles + 1] = { tx = tx, ty = ty, file = name }
            else
                out.other[#out.other + 1] = name
            end
        end
    end
    table.sort(out.tiles, function(a, b) if a.ty ~= b.ty then return a.ty < b.ty end return a.tx < b.tx end)
    return out
end
-- }}}

-- {{{ wowmap.reader: the W client's reader library, once
local L, L_why
function wowmap.reader(build_dir)
    if L then return L end
    build_dir = build_dir or os.getenv("W_CLIENT_BUILD") or wowmap.DEFAULT_BUILD
    local ok, err = pcall(function()
        -- the declarations once a process: another part (a test) may have
        -- given them already
        if not pcall(ffi.typeof, "AdtTile") then
            local f = io.open(build_dir .. "/wreaders.h", "r")
            if not f then error("no " .. build_dir .. "/wreaders.h (the W client's scripts/build writes it)", 0) end
            local text = f:read("*a")
            f:close()
            ffi.cdef(text)
        end
        L = ffi.load(build_dir .. "/libwreaders.so")
    end)
    if not ok then
        L = nil
        L_why = "the W client's reader library didn't load: " .. tostring(err)
        return nil, L_why
    end
    return L
end
-- }}}

-- {{{ a tile, as Lua data
local function floats(p, n)
    local t = {}
    for i = 0, n - 1 do t[i + 1] = p[i] end
    return t
end

local function tile_data(c_tile)
    local t = { textures = {}, chunks = {}, doodads = {}, buildings = {}, liquids = {}, models = {}, building_models = {} }
    for k = 0, c_tile.ntextures - 1 do t.textures[k + 1] = ffi.string(c_tile.textures[k]) end
    for k = 0, c_tile.nmodels - 1 do t.models[k + 1] = ffi.string(c_tile.models[k]) end
    for k = 0, c_tile.nbuildings - 1 do t.building_models[k + 1] = ffi.string(c_tile.buildings[k]) end
    for k = 0, 255 do
        local c = c_tile.chunks[k]
        local layers = {}
        for l = 0, c.nlayers - 1 do
            layers[l + 1] = { texture = t.textures[c.tex[l] + 1], texture_index = c.tex[l] + 1,
                              alpha = l > 0 and ffi.string(c.alpha[l], 4096) or nil }
        end
        local tint = {}
        for i = 0, 144 do tint[i + 1] = { c.tint[i][0], c.tint[i][1], c.tint[i][2] } end
        t.chunks[k + 1] = { ix = c.ix, iy = c.iy, x = c.x, y = c.y, z = c.z, heights = floats(c.heights, 145),
                            holes = c.holes, layers = layers, shadow = ffi.string(c.shadow, 4096), tint = tint }
    end
    for k = 0, c_tile.ndoodads - 1 do
        local p = c_tile.doodads[k]
        t.doodads[k + 1] = { model = t.models[p.name + 1], model_index = p.name + 1, uid = p.uid,
                             x = p.x, y = p.y, z = p.z, rot = floats(p.rot, 3), scale = p.scale }
    end
    for k = 0, c_tile.nplaces - 1 do
        local p = c_tile.places[k]
        t.buildings[k + 1] = { model = t.building_models[p.name + 1], model_index = p.name + 1, uid = p.uid,
                               x = p.x, y = p.y, z = p.z, rot = floats(p.rot, 3), doodad_set = p.doodad_set,
                               lo = floats(p.lo, 3), hi = floats(p.hi, 3) }
    end
    for k = 0, c_tile.nliquids - 1 do
        local q = c_tile.liquids[k]
        local height, wet, depth = {}, {}, {}
        for r = 0, 8 do for col = 0, 8 do height[#height + 1] = q.height[r][col] end end
        for r = 0, 7 do wet[#wet + 1] = ffi.string(q.wet[r], 8) end
        for r = 0, 8 do depth[#depth + 1] = ffi.string(q.depth[r], 9) end
        t.liquids[k + 1] = { chunk = q.chunk + 1, kind = q.kind, col = q.col, row = q.row, w = q.w, h = q.h,
                             wet = table.concat(wet), height = height, depth = table.concat(depth) }
    end
    return t
end
-- }}}

-- {{{ wowmap.open
local M = {}
M.__index = M

-- root: a folder holding World/Maps/<dir>/ (a map project's wow/, a W02
-- build folder, any loose overlay). opts.reader: the library (else
-- wowmap.reader()), opts.build_dir: where to find it
function wowmap.open(root, dir, opts)
    opts = opts or {}
    if not wowmap.valid_name(dir) then return nil, "map folder " .. tostring(dir) .. ": letters, digits and _ only" end
    local files = wowmap.files(root, dir)
    if not files.wdt then
        return nil, "no " .. wowmap.MAPS .. "/" .. dir .. "/" .. dir .. ".wdt in " .. root
    end
    local self = setmetatable({ root = root, directory = dir, folder = root .. "/" .. wowmap.MAPS .. "/" .. dir,
                                tiles = files.tiles, wdt = files.wdt, wdl = files.wdl, other = files.other,
                                read_tiles = {}, opts = opts }, M)
    self.by_key = {}
    for _, t in ipairs(self.tiles) do self.by_key[t.tx .. "_" .. t.ty] = t end
    return self
end

-- the reader, with the map's blend-map form from its WDT (once)
function M:reader()
    if self.lib then return self.lib end
    local lib, why = self.opts.reader, nil
    if not lib then lib, why = wowmap.reader(self.opts.build_dir) end
    if not lib then return nil, why end
    local bytes = read(self.folder .. "/" .. self.wdt) or ""
    local buf = ffi.new("unsigned char[?]", math.max(#bytes, 1))
    ffi.copy(buf, bytes, #bytes)
    local w = ffi.new("WWhy")
    local big = lib.adt_wdt_big_alpha(buf, #bytes, w)
    if big ~= 0 and big ~= 1 then
        return nil, self.wdt .. ": " .. ffi.string(w.text)
    end
    self.big_alpha = big == 1
    self.lib = lib
    return lib
end

-- the tile at (tx, ty), read through the W client's reader and kept;
-- nil and why when the map has no such tile or it can't be read
function M:tile(tx, ty)
    local key = tx .. "_" .. ty
    if self.read_tiles[key] then return self.read_tiles[key] end
    local entry = self.by_key[key]
    if not entry then return nil, string.format("%s has no tile %d, %d", self.directory, tx, ty) end
    local lib, why = self:reader()
    if not lib then return nil, why end
    local bytes = read(self.folder .. "/" .. entry.file)
    if not bytes then return nil, "can't read " .. entry.file end
    local buf = ffi.new("unsigned char[?]", math.max(#bytes, 1))
    ffi.copy(buf, bytes, #bytes)
    local c_tile = ffi.new("AdtTile")       -- about 5 MB: on the heap, freed with it
    local w = ffi.new("WWhy")
    if lib.adt_read(buf, #bytes, self.big_alpha and 1 or 0, c_tile, w) ~= 0 then
        return nil, entry.file .. ": " .. ffi.string(w.text)
    end
    local t = tile_data(c_tile)
    lib.adt_free(c_tile)
    t.tx, t.ty, t.file = tx, ty, entry.file
    self.read_tiles[key] = t
    return t
end

-- every tile, read; the tiles that couldn't be, with why
function M:read_all()
    local bad = {}
    for _, e in ipairs(self.tiles) do
        local t, why = self:tile(e.tx, e.ty)
        if not t then bad[#bad + 1] = why end
    end
    return #bad == 0, bad
end
-- }}}

-- {{{ wowmap.attach: the editor's side (E:wow_maps, E:wow_map)
-- A map opened from a project (editor.open on a project folder or .wex)
-- has its WoW layer at <project>/wow; any other map has none.
function wowmap.attach(E)
    function E:wow_root()
        return self.project_dir and (self.project_dir .. "/wow") or nil
    end
    function E:wow_maps()
        local root = self:wow_root()
        return root and wowmap.maps(root) or {}
    end
    function E:wow_map(dir, opts)
        local root = self:wow_root()
        if not root then return nil, "this map has no WoW layer (it wasn't opened from a map project)" end
        self.wow_opened = self.wow_opened or {}
        if self.wow_opened[dir] then return self.wow_opened[dir] end
        local m, why = wowmap.open(root, dir, opts)
        if m then self.wow_opened[dir] = m end
        return m, why
    end
end
-- }}}

return wowmap
