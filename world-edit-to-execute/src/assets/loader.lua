--[[
Loader: Any Asset by Its Path, Player's Packs First (Issue 601)

One call for any file a map names, looked up in the order decided on
2026-09-26 (issue 516): the player's own asset packs (their overrides),
then the map itself (what it imports), then the player's own Warcraft III
install (stock files, through gamedata/chain.lua, as assets/init.lua reads
it). Nothing is found: nil and a message, and the caller draws its
placeholder (602); the misses are counted.

Loaded assets are kept in a least-recently-used cache with a byte limit
(assets/cache.lua).

    local loader = require("assets.loader")
    local L = loader.new({
        map = "assets/Daow4.4.w3x",      -- or assets = an assets.open() handle already open
        packs = { "my-overrides", "medieval" },  -- first wins; default: every pack, by name
        data = folder,                   -- the player data folder (default: assets/player_data.lua's)
        limit_mb = 256,                  -- the cache's limit
        root = ROOT,                     -- the project, for the install and the player data folder
    })
    local tex, from = L:get("Textures\\Footman.blp")   -- { width, height, rgba }, "pack:medieval"
    local model = L:get("units\\human\\Footman\\Footman.mdx")  -- parsed MDX
    local bytes = L:read("Sound\\Music\\mp3Music\\Comradeship.mp3")  -- the file, not decoded
    L:exists(path)   L:preload({ ... })   L:stats()   L:clear()   L:close()

For hot-reload (assets/hotreload.lua, issue 606), which tells the loader
when a pack's file changed and asks it to read one asset again:

    L:reload(path)                  -- read again; a broken new file keeps the old value
    L:file_changed(dir, rel)        -- a pack's file changed: its key, and whether to reload it
    L:wants(path)   L:reindex()   loader.key_of(path)

The renderer reads through a loader the same way it read through
assets.open's handle (issue 606a): texture, model, table, model_for and
scale_for, so gpu.lua and ground.lua draw the player's packs first.

    local L = loader.new({ assets = A })     -- A: assets.open(map)
    gpu.new(render, L)   ground.apply(render, L, scene)   L:model_for("unit", "hfoo", nil, od)

A layer for one game, above every pack (a shared map-and-model list,
share/profile.lua, issue 609), and taken off again after:

    L:push_layer("game-2026-11-02", dir)   -- its files come first; source "layer:NAME"
    L:pop_layer("game-2026-11-02")         -- gone; what it served is read again from the packs

Paths match without regard to case or slash direction, as the game's do:
"Textures\Footman.blp" finds a pack's textures/footman.blp.

What get() gives, by extension:
  .blp .tga .png   a decoded image { width, height, rgba } (top row first)
  .mdx             the parsed model (parsers/mdx.lua)
  anything else    the file's bytes (sounds wait on the audio library)
]]

local assets = require("assets")
local cache_mod = require("assets.cache")
local player_data = require("assets.player_data")

local loader = {}

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
loader.ROOT = HERE .. "/../.."
loader.DEFAULT_LIMIT_MB = 256

-- {{{ decoders
-- Each gives the value and the bytes the cache charges for it. A parsed
-- model is charged its file's size: Lua tables can't be measured exactly,
-- and the file's size moves with the model's.
local function image(mod)
    return function(data)
        local img = require(mod).decode(data)
        return img, #img.rgba
    end
end

loader.DECODERS = {
    blp = image("parsers.blp"),
    tga = image("parsers.tga"),
    png = image("parsers.png"),
    mdx = function(data) return require("parsers.mdx").parse(data), #data end,
}
-- }}}

-- {{{ local helpers
local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- "Textures\Footman.BLP" -> "textures/footman.blp"
local function key_of(path)
    return (path:gsub("\\", "/"):gsub("^/+", ""):lower())
end
loader.key_of = key_of

-- Every file in a pack's folder, by key: its real path.
local function index_pack(dir)
    local index, count = {}, 0
    local p = io.popen("find -L " .. sh(dir) .. " -mindepth 1 -type f -printf '%P\\n' 2>/dev/null")
    for rel in p:lines() do
        local key = key_of(rel)
        if not index[key] then
            index[key] = dir .. "/" .. rel
            count = count + 1
        end
    end
    p:close()
    return index, count
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end
-- }}}

local L = {}
L.__index = L

-- {{{ function loader.new
function loader.new(opts)
    opts = opts or {}
    local root = opts.root or loader.ROOT
    local data = opts.data or player_data.folder(root)
    local self = setmetatable({
        root = root,
        data = data,
        packs = {},
        cache = cache_mod.new(math.floor((opts.limit_mb or loader.DEFAULT_LIMIT_MB) * 1024 * 1024)),
        missing = {},
        failed = {},
        loaded = 0,
    }, L)

    -- the packs, in the order asked for, else every pack by name
    local names = opts.packs
    if not names then
        names = {}
        local p = io.popen("find -L " .. sh(data .. "/asset-packs") .. " -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' 2>/dev/null")
        for name in p:lines() do names[#names + 1] = name end
        p:close()
        table.sort(names)
    end
    for _, name in ipairs(names) do
        local dir = data .. "/asset-packs/" .. name
        if not os.rename(dir, dir) then
            error("loader: no asset pack named " .. name .. " in " .. data .. "/asset-packs", 2)
        end
        local index, count = index_pack(dir)
        self.packs[#self.packs + 1] = { name = name, dir = dir, index = index, files = count }
    end

    -- the map and the install
    if opts.assets then
        self.assets = opts.assets
    elseif opts.map then
        self.assets = assets.open(opts.map, { root = root, install = opts.install, layers = opts.layers })
        self.owns_assets = true
        if not self.assets.map then
            error("loader: can't open the map " .. tostring(opts.map), 2)
        end
    end
    return self
end
-- }}}

-- {{{ function L:read
-- The file's bytes and where they came from ("pack:NAME", "map", or the
-- install's archive), not cached; nil and a message when nothing has it.
function L:read(path)
    if type(path) ~= "string" or path == "" then
        return nil, "loader: no path given"
    end
    local key = key_of(path)
    for _, pack in ipairs(self.packs) do
        local real = pack.index[key]
        if real then
            local data = read_file(real)
            if data then return data, pack.source or ("pack:" .. pack.name) end
        end
    end
    if self.assets then
        local data, source = self.assets:read(path)
        if data then return data, source end
    end
    local looked = {}
    for _, pack in ipairs(self.packs) do looked[#looked + 1] = "pack " .. pack.name end
    if self.assets and self.assets.map then looked[#looked + 1] = "the map" end
    if self.assets and self.assets.chain then looked[#looked + 1] = "the install" end
    return nil, "not found: " .. path .. " (looked in " .. (#looked > 0 and table.concat(looked, ", ") or "nothing") .. ")"
end
-- }}}

-- {{{ function L:get
-- The asset, decoded by its extension, and where it came from; cached.
-- nil and a message when it is missing or can't be read (each counted).
function L:get(path)
    if type(path) ~= "string" or path == "" then
        return nil, "loader: no path given"
    end
    local key = key_of(path)
    local hit = self.cache:get(key)
    if hit then
        return hit.value, hit.source
    end
    if self.missing[key] then
        return nil, self.missing[key]
    end
    local data, source = self:read(path)
    if not data then
        self.missing[key] = source
        return nil, source
    end
    local ext = key:match("%.([%w]+)$")
    local decode = ext and loader.DECODERS[ext]
    local value, bytes = data, #data
    if decode then
        local ok, v, b = pcall(decode, data)
        if not ok then
            local msg = "can't read " .. path .. " from " .. source .. ": " .. tostring(v)
            self.failed[key] = msg
            self.missing[key] = msg
            return nil, msg
        end
        value, bytes = v, b
    end
    self.loaded = self.loaded + 1
    self.cache:put(key, { value = value, source = source }, bytes)
    return value, source
end
-- }}}

-- {{{ function L:exists
-- True when some source has the file (nothing is decoded).
function L:exists(path)
    if type(path) ~= "string" or path == "" then return false end
    local key = key_of(path)
    if self.cache:has(key) then return true end
    for _, pack in ipairs(self.packs) do
        if pack.index[key] then return true end
    end
    if self.assets then
        local map = self.assets.map
        if map and map:has((path:gsub("/", "\\"))) then return true end
        if self.assets.chain then return self.assets:read(path) ~= nil end
    end
    return false
end
-- }}}

-- {{{ function L:preload
-- Loads each path now (in this thread: the loader has none of its own).
-- Returns how many loaded, and the messages of those that didn't.
function L:preload(paths)
    local ok, problems = 0, {}
    for _, path in ipairs(paths) do
        local v, msg = self:get(path)
        if v ~= nil then ok = ok + 1 else problems[#problems + 1] = msg end
    end
    return ok, problems
end
-- }}}

-- {{{ function L:reload
-- Reads the asset again from wherever it is now found, as get() would.
-- When that fails and the old value was loaded, the old value stays in
-- the cache (a broken save in an editor doesn't take a texture away).
-- Returns the new value and its source; or nil, the message, and true
-- when the old value was kept.
function L:reload(path)
    if type(path) ~= "string" or path == "" then
        return nil, "loader: no path given", false
    end
    local key = key_of(path)
    local old, old_bytes = self.cache:peek(key)
    self.cache:remove(key)
    self.missing[key], self.failed[key] = nil, nil
    local value, source = self:get(path)
    if value ~= nil then
        return value, source
    end
    if old then
        self.cache:put(key, old, old_bytes)
        return nil, source, true
    end
    return nil, source, false
end
-- }}}

-- {{{ function L:wants
-- True when the loader has the asset loaded, or has looked for it and
-- not found it: either way a new file under that path is worth reading.
function L:wants(path)
    local key = key_of(path)
    return self.cache:has(key) or self.missing[key] ~= nil
end
-- }}}

-- {{{ function L:file_changed
-- A file in a pack's folder was written, added or removed: DIR is the
-- pack's folder as the loader holds it (pack.dir), REL the file's path
-- within it. Keeps the pack's file list right and gives the asset's key,
-- and whether the change matters: the loader wants that asset and no pack
-- before this one has it (a pack lower down is hidden by the one above).
function L:file_changed(dir, rel)
    local key = key_of(rel)
    local before = false
    for _, pack in ipairs(self.packs) do
        if pack.dir == dir then
            local real = dir .. "/" .. rel
            local f = io.open(real, "rb")
            if f then
                f:close()
                if not pack.index[key] then pack.files = pack.files + 1 end
                pack.index[key] = real
            elseif pack.index[key] == real then
                pack.index[key] = nil
                pack.files = pack.files - 1
            end
            return key, (not before) and self:wants(key)
        end
        if pack.index[key] then before = true end
    end
    return key, false
end
-- }}}

-- {{{ function L:reindex
-- Reads every pack's file list again; the cache is kept.
function L:reindex()
    for _, pack in ipairs(self.packs) do
        pack.index, pack.files = index_pack(pack.dir)
    end
end
-- }}}

-- {{{ the renderer's calls: L:texture / L:model / L:table / L:model_for / L:scale_for
-- As assets.open's handle answers them (assets/init.lua), so the renderer
-- (gpu.lua, ground.lua, the map viewer and the editor) can be handed a
-- loader instead and draw the player's packs first (issue 606a).

-- A decoded texture, or nil. Like A:texture, a path with no extension, or
-- a .tga that isn't there, is tried again as .blp.
function L:texture(path)
    if type(path) ~= "string" or path == "" then return nil end
    local key = key_of(path)
    local tries = { path }
    if key:match("%.tga$") then tries[2] = path:sub(1, -5) .. ".blp"
    elseif not key:match("%.blp$") then tries[2] = path .. ".blp" end
    for _, p in ipairs(tries) do
        local v = self:get(p)
        if type(v) == "table" and v.rgba then return v end
    end
    return nil
end

-- A parsed model, or nil; the path is made a .mdx as A:model makes it.
function L:model(path)
    local p = assets.model_path(path)
    if not p then return nil end
    local v = self:get(p)
    if type(v) == "table" and not v.rgba then return v end
    return nil
end

-- A stock table: the install's, through the assets handle (packs hold art).
function L:table(path)
    if not self.assets then return nil end
    return self.assets:table(path)
end

-- model_for and scale_for are the assets handle's own, run with the loader
-- as `self`, so the model they name is looked up packs first.
local function borrowed(self, name)
    local mt = self.assets and getmetatable(self.assets)
    local methods = mt and (type(mt.__index) == "table" and mt.__index or mt)
    local f = methods and methods[name]
    if type(f) ~= "function" then
        error("loader: " .. name .. " needs an assets handle (assets.open) to read object data", 3)
    end
    return f
end

function L:model_for(kind, id, variation, object_data)
    return borrowed(self, "model_for")(self, kind, id, variation, object_data)
end

function L:scale_for(kind, id, object_data)
    return borrowed(self, "scale_for")(self, kind, id, object_data)
end
-- }}}

-- {{{ function L:push_layer / L:pop_layer
-- A folder whose files come before every pack's, until it is popped (a
-- shared list applied for one game). What it holds that was loaded or
-- missed is read again on the next get. Returns how many files it has.
function L:push_layer(name, dir)
    if type(name) ~= "string" or name == "" then error("loader: a layer needs a name", 2) end
    for _, pack in ipairs(self.packs) do
        if pack.layer and pack.name == name then error("loader: a layer named " .. name .. " is already on", 2) end
    end
    local index, count = index_pack(dir)
    table.insert(self.packs, 1, { name = name, dir = dir, index = index, files = count,
                                  layer = true, source = "layer:" .. name })
    for key in pairs(index) do
        self.cache:remove(key)
        self.missing[key], self.failed[key] = nil, nil
    end
    return count
end

-- Takes the layer off; everything it served is read again from the packs,
-- the map or the install on the next get. True when it was on.
function L:pop_layer(name)
    for i, pack in ipairs(self.packs) do
        if pack.layer and pack.name == name then
            table.remove(self.packs, i)
            for key in pairs(pack.index) do
                self.cache:remove(key)
                self.missing[key], self.failed[key] = nil, nil
            end
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function L:stats
function L:stats()
    local c = self.cache:stats()
    local missing, failed = 0, 0
    for _ in pairs(self.missing) do missing = missing + 1 end
    for _ in pairs(self.failed) do failed = failed + 1 end
    return {
        loaded_count = c.count,          -- in the cache now
        loads = self.loaded,             -- decoded since the start (or clear)
        memory_bytes = c.bytes,
        memory_mb = c.bytes / (1024 * 1024),
        limit_bytes = c.limit,
        cache_hits = c.hits,
        cache_misses = c.misses,
        evictions = c.evictions,
        missing = missing - failed,      -- in no source
        failed = failed,                 -- found, but the reader refused it
        packs = #self.packs,
    }
end
-- }}}

-- {{{ function L:clear / L:close
-- Empties the cache and forgets the misses (a pack may have gained them).
function L:clear()
    self.cache:clear()
    self.missing, self.failed, self.loaded = {}, {}, 0
    for _, pack in ipairs(self.packs) do
        pack.index, pack.files = index_pack(pack.dir)
    end
end

function L:close()
    if self.owns_assets and self.assets then self.assets:close() end
end
-- }}}

return loader
