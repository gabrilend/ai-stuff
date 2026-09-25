--[[
chain.lua - the game data a map sees: installs + one patch layer + a data set

When the game loads a map it reads its stock data (unit, ability and item
tables and so on) through a chain of sources, and this module rebuilds that
chain per map so patches are applied or left off per map, in memory only:

  0. the map's own archive, for either path below (when a map is given)
  1. the data set's own copy:  "Custom_V1\Units\UnitWeapons.slk"
  2. the plain path:           "Units\UnitWeapons.slk"
each looked up, highest priority first, in
  a. the chosen patch layer's files (none if the map runs unpatched)
  b. War3xlocal.mpq, War3x.mpq, war3.mpq

The map. The game opens a map's archive above every other source, which is
how maps import models over stock ones, and also how map optimizers ship
whole object tables: DAoW-5.2 carries its own Units\AbilityData.slk, and its
custom abilities are defined only there. Custom_V1 holds an ItemData.slk
too, and a map's own copy must beat it, so the map is tried first for both
the data-set path and the plain path.

Data sets. The Frozen Throne install keeps separate copies of some tables:
Custom_V0 (Reign of Chaos custom games), Custom_V1 (Frozen Throne custom
games) and Melee_V0 (Reign of Chaos melee). Each holds only the tables that
differ, which is why a data set's copy is tried first and the plain path
second. A map saved in Reign of Chaos format (w3i version 18) uses
Custom_V0; a Frozen Throne map (version 25 and later) uses Custom_V1. This
matches the folder names and contents; how the game itself picks is still an
open question in issue 112b.

Layers. Each Blizzard patch rebuilds its whole data archive, so a layer is
complete by itself and a chain uses at most one. The map's editor version
picks it through editor_versions.lua; without an entry, the newest layer
available is used and the fallback is counted and reported.

Usage:
  local chain = require("gamedata.chain")
  local c = chain.open({ install = ..., layers = ..., w3i = parsed_w3i, map = "path/to/map.w3x" })
  local bytes, source = c:read("Units\\UnitWeapons.slk")
  local bytes = c:read("Units\\UnitWeapons.slk", { below_map = true })   -- the stock copy the map's hides
  c:report()   -- data set, layer, and why; warnings
  c:close()

Issue: issues/112b-game-version-layers-per-map.md
]]

local stormlib = require("mpq.stormlib")

local M = {}

local BASE_ARCHIVES = { "War3xlocal.mpq", "War3x.mpq", "war3.mpq" }   -- highest priority first

-- {{{ local function shell_quote
local function shell_quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function index_folder
-- Lower-cased backslash path -> real path, for every file under root.
local function index_folder(root)
    local index = {}
    local listing = io.popen("find " .. shell_quote(root .. "/") .. " -type f")
    for path in listing:lines() do
        index[path:sub(#root + 2):gsub("/", "\\"):lower()] = path
    end
    listing:close()
    return index
end
-- }}}

-- {{{ local function available_layers
-- Layer names found under the layers folder, newest last by version order.
local function available_layers(layers_root)
    local names = {}
    local listing = io.popen("ls " .. shell_quote(layers_root))
    for name in listing:lines() do
        local f = io.open(layers_root .. "/" .. name .. "/manifest.lua", "r")
        if f then
            f:close()
            names[#names + 1] = name
        end
    end
    listing:close()
    table.sort(names, function(a, b)
        local function key(v)
            local major, minor, letter = v:match("^(%d+)%.(%d+)(%a?)$")
            return (tonumber(major) or 0) * 10000 + (tonumber(minor) or 0) * 100
                + (letter ~= "" and letter:byte() - 96 or 0)
        end
        return key(a) < key(b)
    end)
    return names
end
-- }}}

-- {{{ function M.data_set_for
-- The data-set folder for a parsed war3map.w3i.
function M.data_set_for(w3i)
    if w3i.version == 18 then
        return "Custom_V0"
    end
    return "Custom_V1"
end
-- }}}

-- {{{ function M.choose_layer
-- Returns layer name (or nil for none), and a reason string, and whether it
-- was a fallback. options.layer = false forces no layer (unpatched);
-- options.layer = "1.21b" forces that one.
function M.choose_layer(w3i, layers_root, options)
    options = options or {}
    if options.layer == false then
        return nil, "unpatched (asked for no layer)", false
    end
    local available = available_layers(layers_root)
    if options.layer then
        for _, name in ipairs(available) do
            if name == options.layer then
                return name, "asked for " .. name, false
            end
        end
        error("patch layer " .. options.layer .. " not found under " .. layers_root)
    end
    local versions = options.editor_versions or require("gamedata.editor_versions")
    local known = versions[w3i.editor_version]
    if known then
        return known.layer, string.format("editor %d belongs to %s (%s)",
            w3i.editor_version, known.layer, known.evidence), false
    end
    local newest = available[#available]
    if not newest then
        return nil, string.format("editor %d has no known layer and no layers are built",
            w3i.editor_version), true
    end
    return newest, string.format("editor %d has no known layer; using %s, the newest built",
        w3i.editor_version, newest), true
end
-- }}}

local Chain = {}
Chain.__index = Chain

-- {{{ function M.open
-- options: install (Frozen Throne folder), layers (folder of layers),
-- w3i (parsed war3map.w3i), and optionally map (the map file, searched
-- first), layer (name or false) and editor_versions (a table like
-- editor_versions.lua, for tests).
function M.open(options)
    local self = setmetatable({}, Chain)
    self.data_set = M.data_set_for(options.w3i)
    self.layer, self.layer_reason, self.fallback =
        M.choose_layer(options.w3i, options.layers, options)
    self.warnings = {}
    if self.fallback then
        self.warnings[#self.warnings + 1] = self.layer_reason
    end
    if self.layer then
        self.layer_root = options.layers .. "/" .. self.layer .. "/archive"
        self.layer_index = index_folder(self.layer_root)
    else
        self.layer_index = {}
    end
    self.archives = {}
    if options.map then
        self.map = { name = "map", archive = stormlib.open(options.map) }
    end
    for _, name in ipairs(BASE_ARCHIVES) do
        self.archives[#self.archives + 1] = { name = name, archive = stormlib.open(options.install .. "/" .. name) }
    end
    return self
end
-- }}}

-- {{{ function Chain:find
-- Returns where a path would be read from: "map", "layer <name>", an archive
-- name, or nil; plus the exact path that matched (data-set copy or plain).
-- options.below_map skips the map, giving the stock copy it hides.
function Chain:find(path, options)
    local candidates = { self.data_set .. "\\" .. path, path }
    if self.map and not (options and options.below_map) then
        for _, candidate in ipairs(candidates) do
            if self.map.archive:has(candidate) then
                return "map", candidate
            end
        end
    end
    for _, candidate in ipairs(candidates) do
        if self.layer_index[candidate:lower()] then
            return "layer " .. self.layer, candidate
        end
        for _, a in ipairs(self.archives) do
            if a.archive:has(candidate) then
                return a.name, candidate
            end
        end
    end
    return nil
end
-- }}}

-- {{{ function Chain:read
-- Returns the bytes and a description of where they came from, or raises an
-- error naming the path when nothing in the chain has it. options as find.
function Chain:read(path, options)
    local source, matched = self:find(path, options)
    if not source then
        error("not in the game data chain: " .. path)
    end
    if source == "map" then
        return self.map.archive:read(matched), "map: " .. matched
    end
    if source:match("^layer ") then
        local f = assert(io.open(self.layer_index[matched:lower()], "rb"))
        local bytes = f:read("*a")
        f:close()
        return bytes, source .. ": " .. matched
    end
    for _, a in ipairs(self.archives) do
        if a.name == source then
            return a.archive:read(matched), source .. ": " .. matched
        end
    end
end
-- }}}

-- {{{ function Chain:report
-- A short description of this chain, for logs and demos.
function Chain:report()
    local lines = {
        "data set: " .. self.data_set,
        "patch layer: " .. tostring(self.layer or "none") .. " (" .. self.layer_reason .. ")",
    }
    for _, w in ipairs(self.warnings) do
        lines[#lines + 1] = "WARNING: " .. w
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function Chain:close
function Chain:close()
    for _, a in ipairs(self.archives) do
        a.archive:close()
    end
    self.archives = {}
    if self.map then
        self.map.archive:close()
        self.map = nil
    end
end
-- }}}

return M
