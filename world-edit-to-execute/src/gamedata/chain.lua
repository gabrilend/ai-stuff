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
Custom_V0 (Reign of Chaos custom games, frozen at 1.01), Custom_V1 (Frozen
Throne custom games, frozen at 1.07) and Melee_V0 (Reign of Chaos melee).
Each holds only the tables that differ, which is why a data set's copy is
tried first and the plain path second. The plain Units\ tables are Frozen
Throne melee: the only ones the balance patches change (1.22a's Knight is
28 damage there and still 25 in Custom_V1).

The map chooses its set in war3map.w3i ("game data set", issue 112b):
0 Default (the map's melee flag decides), 1 Custom, 2 Melee (latest patch).
Seven of the sixteen test maps choose Melee; before this was read, every
Frozen Throne map got Custom_V1.

Layers. Each Blizzard patch rebuilds its whole data archive, so a layer is
complete by itself and a chain uses at most one. The map's editor version
picks it through editor_versions.lua; a build with no entry, or whose layer
isn't built, is an error naming what to fetch (never a guess). An install
layer (1.28 on, manifest kind "install") carries that version's own data
archives, which replace the disc's.

Usage:
  local chain = require("gamedata.chain")
  local c = chain.open({ install = ..., layers = ..., w3i = parsed_w3i, map = "path/to/map.w3x" })
  local bytes, source = c:read("Units\\UnitWeapons.slk")
  local bytes = c:read("Units\\UnitWeapons.slk", { below_map = true })   -- the stock copy the map's hides
  c:report()   -- data set, layer, and why
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
        -- By every number in the name: "1.21b" is 1, 21, b(2), 0 and "1.29.2"
        -- is 1, 29, 0, 2, so a letter release and a dotted one compare
        -- correctly (the old two-number key sorted 1.29.2 first).
        local function key(v)
            local major, minor, letter, patch = v:match("^(%d+)%.(%d+)(%a?)%.?(%d*)$")
            if not major then
                error("layer folder " .. v .. " isn't named like a version (1.21b, 1.29.2)")
            end
            return { tonumber(major), tonumber(minor), letter ~= "" and letter:byte() - 96 or 0,
                tonumber(patch) or 0 }
        end
        local ka, kb = key(a), key(b)
        for i = 1, 4 do
            if ka[i] ~= kb[i] then return ka[i] < kb[i] end
        end
        return false
    end)
    return names
end
-- }}}

-- {{{ DATA_SETS
-- Which folder each choice reads, per game: false means the plain path only
-- (Frozen Throne melee, the patched tables). w3i format 18 is Reign of Chaos.
local DATA_SETS = {
    custom = { roc = "Custom_V0", tft = "Custom_V1" },
    melee  = { roc = "Melee_V0",  tft = false },
}
-- The stored "game data set" values, as the editor names them
-- (UI\WorldEditStrings.txt: WESTRING_GAMEDATASET_*).
local CHOICES = {
    [0] = function(w3i) return w3i.flags.melee_map and "melee" or "custom" end,   -- Default (based on map melee status)
    [1] = function() return "custom" end,                                          -- Custom (TFT 1.07, RoC 1.01)
    [2] = function() return "melee" end,                                           -- Melee (Latest Patch)
}
-- }}}

-- {{{ function M.data_set_for
-- The data-set folder for a parsed war3map.w3i, or false for the plain
-- melee tables; plus the choice's name ("custom" or "melee"). Needs the
-- w3i's version, game_data_set and flags.melee_map; a value the editor
-- doesn't offer is an error.
function M.data_set_for(w3i)
    local choose = CHOICES[w3i.game_data_set]
    if not choose then
        error("war3map.w3i game data set " .. tostring(w3i.game_data_set)
            .. " isn't one the editor offers (0 Default, 1 Custom, 2 Melee)")
    end
    local choice = choose(w3i)
    local game = w3i.version == 18 and "roc" or "tft"
    return DATA_SETS[choice][game], choice
end
-- }}}

-- {{{ function M.choose_layer
-- Returns the layer name (or nil for none) and a reason string.
-- options.layer = false forces no layer (unpatched);
-- options.layer = "1.21b" forces that one.
function M.choose_layer(w3i, layers_root, options)
    options = options or {}
    if options.layer == false then
        return nil, "unpatched (asked for no layer)"
    end
    local available = available_layers(layers_root)
    if options.layer then
        for _, name in ipairs(available) do
            if name == options.layer then
                return name, "asked for " .. name
            end
        end
        error("patch layer " .. options.layer .. " not found under " .. layers_root)
    end
    -- The map's editor build names its version (editor_versions.lua). There
    -- is no guessing: a build with no entry, or whose layer isn't built, is
    -- missing data, and the answer is its row in wc3-installs/patch-sources.tsv
    -- (this once fell back to the newest layer; the owner: "this sounds like
    -- a problem we could solve with code").
    local versions = options.editor_versions or require("gamedata.editor_versions")
    local known = versions[w3i.editor_version]
    if not known then
        error(string.format("editor build %s has no known game version: add its patch program or game"
            .. " copy to wc3-installs/patch-sources.tsv and its evidence to editor_versions.lua",
            tostring(w3i.editor_version)))
    end
    for _, name in ipairs(available) do
        if name == known.layer then
            return name, string.format("editor %d belongs to %s (%s)",
                w3i.editor_version, known.layer, known.evidence)
        end
    end
    error(string.format("editor build %d needs layer %s, which isn't built:"
        .. " scripts/fetch-patch-programs.sh, then build-patch-layer.lua", w3i.editor_version, known.layer))
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
    self.data_set, self.data_set_choice = M.data_set_for(options.w3i)
    self.layer, self.layer_reason = M.choose_layer(options.w3i, options.layers, options)
    self.layer_index = {}
    -- Base archives: the disc install's, unless the layer is an install layer
    -- (1.28 on: that version's own rebuilt archives, which replace the disc's).
    local base_folder, base_names = options.install, BASE_ARCHIVES
    if self.layer then
        local layer_folder = options.layers .. "/" .. self.layer
        local manifest = assert(loadfile(layer_folder .. "/manifest.lua"))()
        if manifest.kind == "install" then
            base_folder, base_names = layer_folder .. "/archives", manifest.archive_order
        else
            self.layer_root = layer_folder .. "/archive"
            self.layer_index = index_folder(self.layer_root)
        end
    end
    self.archives = {}
    if options.map then
        self.map = { name = "map", archive = stormlib.open(options.map) }
    end
    for _, name in ipairs(base_names) do
        self.archives[#self.archives + 1] = { name = name, archive = stormlib.open(base_folder .. "/" .. name) }
    end
    return self
end
-- }}}

-- {{{ function Chain:find
-- Returns where a path would be read from: "map", "layer <name>", an archive
-- name, or nil; plus the exact path that matched (data-set copy or plain).
-- options.below_map skips the map, giving the stock copy it hides.
function Chain:find(path, options)
    local candidates = self.data_set and { self.data_set .. "\\" .. path, path } or { path }
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
        "data set: " .. (self.data_set or "plain melee tables") .. " (" .. self.data_set_choice .. ")",
        "patch layer: " .. tostring(self.layer or "none") .. " (" .. self.layer_reason .. ")",
    }
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
