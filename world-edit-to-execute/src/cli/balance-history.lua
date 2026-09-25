#!/usr/bin/env luajit
-- balance-history.lua - every stock number of Warcraft III, across every version
--
-- In plain terms: the project keeps a copy of the game's data tables for
-- every version from the discs to 1.29.2 (the patch layers). This tool reads
-- the same tables from each version in turn and writes down, for every unit,
-- ability, item and upgrade, each number that ever changed, version by
-- version. The page src/viewers/balance-history.html draws it. The data is
-- made from the player's own install and stays on this machine.
--
-- Usage:
--   luajit src/cli/balance-history.lua [--dir DIR] <output folder>
--
-- Writes <output folder>/history.js (window.HISTORY = {...}), so the page
-- opens straight from disk. scripts/balance-history.sh runs it and copies the
-- page beside it.
--
-- Issue: issues/completed/115-balance-history-explorer.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local chain = require("gamedata.chain")
local slk = require("parsers.slk")
local profile = require("parsers.profile_txt")

-- {{{ GAMES
-- Each game's install, layers folder, base archives and disc version, as the
-- chain reads them (issue 112b). The map-info stand-in asks for the melee
-- tables (game data set 2): the ones balance patches change.
local GAMES = {
    { key = "tft", title = "The Frozen Throne", install = DIR .. "/wc3-installs/frozen-throne",
      layers = DIR .. "/wc3-installs/patch-layers", disc = "1.07", w3i_version = 25 },
    { key = "roc", title = "Reign of Chaos", install = DIR .. "/wc3-installs/reign-of-chaos",
      layers = DIR .. "/wc3-installs/patch-layers-roc", disc = "1.00", w3i_version = 18,
      base_archives = { "war3.mpq" } },
}
-- }}}

-- {{{ TABLES
-- Which stock tables hold which kind of object. A unit's numbers are spread
-- over two tables, so every field is named table.column ("UnitWeapons.dmgplus1").
local TABLES = {
    { kind = "unit", name = "UnitBalance", path = "Units\\UnitBalance.slk" },
    { kind = "unit", name = "UnitWeapons", path = "Units\\UnitWeapons.slk" },
    { kind = "ability", name = "AbilityData", path = "Units\\AbilityData.slk" },
    { kind = "item", name = "ItemData", path = "Units\\ItemData.slk" },
    { kind = "upgrade", name = "UpgradeData", path = "Units\\UpgradeData.slk" },
}
-- }}}

-- {{{ NAME_FILES
-- Profile text holding the objects' names (Blizzard's text, borrowed: read
-- from the newest version, shown only on this machine; issue 112c).
local NAME_FILES = {}
for _, race in ipairs({ "Human", "Orc", "Undead", "NightElf", "Neutral", "Campaign" }) do
    NAME_FILES[#NAME_FILES + 1] = "Units\\" .. race .. "UnitStrings.txt"
    NAME_FILES[#NAME_FILES + 1] = "Units\\" .. race .. "AbilityStrings.txt"
    NAME_FILES[#NAME_FILES + 1] = "Units\\" .. race .. "UpgradeStrings.txt"
end
NAME_FILES[#NAME_FILES + 1] = "Units\\ItemStrings.txt"
NAME_FILES[#NAME_FILES + 1] = "Units\\CommonAbilityStrings.txt"
NAME_FILES[#NAME_FILES + 1] = "Units\\ItemAbilityStrings.txt"
-- }}}

-- {{{ local function versions_of
-- A game's versions in order: its disc first (no layer), then every built
-- layer, oldest first by every number in the name.
local function versions_of(game)
    local names = {}
    local listing = io.popen("ls '" .. game.layers .. "'")
    for name in listing:lines() do
        local f = io.open(game.layers .. "/" .. name .. "/manifest.lua", "r")
        if f then
            f:close()
            names[#names + 1] = name
        end
    end
    listing:close()
    table.sort(names, function(a, b) return chain.version_below(chain.version_key(a), chain.version_key(b)) end)
    table.insert(names, 1, game.disc)
    return names
end
-- }}}

-- {{{ local function open_version
local function open_version(game, version)
    -- The disc is read with no layer (layer = false); anything else is its layer.
    local layer = version
    if version == game.disc then
        layer = false
    end
    return chain.open({
        install = game.install, layers = game.layers, base_archives = game.base_archives,
        disc_version = game.disc,
        layer = layer,
        w3i = { version = game.w3i_version, editor_version = 0, game_data_set = 2, flags = { melee_map = true } },
    })
end
-- }}}

-- {{{ local function history_of
-- One game's history: versions, and objects[id] = { kind, name, fields =
-- { ["Table.column"] = { value per version, nil where absent } } }, keeping
-- only numeric fields whose value changes between versions it appears in.
local function history_of(game)
    local versions = versions_of(game)
    local objects = {}
    for vi, version in ipairs(versions) do
        local c = open_version(game, version)
        for _, t in ipairs(TABLES) do
            if c:find(t.path) then
                local sheet = slk.parse((c:read(t.path)))
                for id, row in pairs(sheet.rows) do
                    local object = objects[id]
                    if not object then
                        object = { kind = t.kind, fields = {} }
                        objects[id] = object
                    end
                    for column, value in pairs(row) do
                        if type(value) == "number" then
                            local key = t.name .. "." .. column
                            object.fields[key] = object.fields[key] or {}
                            object.fields[key][vi] = value
                        end
                    end
                end
            end
        end
        -- Names from the newest version's text.
        if vi == #versions then
            local names = {}
            for _, path in ipairs(NAME_FILES) do
                if c:find(path) then
                    profile.parse((c:read(path)), names)
                end
            end
            for id, object in pairs(objects) do
                local entry = names[id]
                local name = entry and (entry.Name or entry.Bufftip or entry.Tip)
                if type(name) == "string" then
                    object.name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                end
            end
        end
        c:close()
        io.stderr:write(string.format("  %s %s\n", game.key, version))
    end

    -- Keep fields that change; drop objects left with none.
    local kept = {}
    for id, object in pairs(objects) do
        local fields = {}
        for key, values in pairs(object.fields) do
            local first, changes = nil, false
            for vi = 1, #versions do
                local v = values[vi]
                if v ~= nil then
                    if first == nil then first = v elseif v ~= first then changes = true end
                end
            end
            if changes then
                fields[key] = values
            end
        end
        if next(fields) then
            kept[id] = { kind = object.kind, name = object.name, fields = fields }
        end
    end
    return { title = game.title, versions = versions, objects = kept }
end
-- }}}

-- {{{ local function quote
-- A JSON string: Lua's %q writes decimal escapes (\13) that JavaScript would
-- read as octal, so control characters become \u escapes instead.
local function quote(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
-- }}}

-- {{{ local function to_js
-- A small serializer for the data file: tables with string keys become
-- objects, value-per-version lists become arrays with null for gaps.
local function to_js(value, length)
    local kind = type(value)
    if kind == "string" then
        return quote(value)
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "null" end
        return string.format("%.10g", value)
    elseif kind == "nil" then
        return "null"
    elseif kind == "boolean" then
        return tostring(value)
    end
    if length then
        local parts = {}
        for i = 1, length do parts[i] = to_js(value[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = quote(k) .. ":" .. to_js(value[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
-- }}}

-- {{{ function build (exported for tests)
local M = {}
function M.build(game_keys)
    local out = { games = {} }
    for _, game in ipairs(GAMES) do
        if not game_keys or game_keys[game.key] then
            out.games[game.key] = history_of(game)
        end
    end
    return out
end
-- }}}

-- {{{ function M.write
function M.write(history, folder)
    local parts = { "window.HISTORY = {\"games\":{" }
    local first = true
    for key, game in pairs(history.games) do
        local objects = {}
        local ids = {}
        for id in pairs(game.objects) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local o = game.objects[id]
            local fields = {}
            local keys = {}
            for k in pairs(o.fields) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                fields[#fields + 1] = quote(k) .. ":" .. to_js(o.fields[k], #game.versions)
            end
            objects[#objects + 1] = string.format("%s:{\"kind\":%s,\"name\":%s,\"fields\":{%s}}",
                quote(id), quote(o.kind), to_js(o.name), table.concat(fields, ","))
        end
        parts[#parts + 1] = (first and "" or ",") .. string.format("%s:{\"title\":%s,\"versions\":%s,\"objects\":{%s}}",
            quote(key), quote(game.title), to_js(game.versions, #game.versions), table.concat(objects, ","))
        first = false
    end
    parts[#parts + 1] = "}};\n"
    os.execute("mkdir -p '" .. folder .. "'")
    local f = assert(io.open(folder .. "/history.js", "w"))
    f:write(table.concat(parts))
    f:close()
end
-- }}}

-- {{{ main
-- Run directly (not loaded by a test with require): generate and write.
if arg and arg[0] and arg[0]:match("balance%-history%.lua$") then
    local folder = arg[1]
    if not folder or folder == "--help" then
        print("Usage: luajit src/cli/balance-history.lua [--dir DIR] <output folder>")
        os.exit(folder and 0 or 1)
    end
    local history = M.build()
    M.write(history, folder)
    for key, game in pairs(history.games) do
        local n = 0
        for _ in pairs(game.objects) do n = n + 1 end
        print(string.format("%s: %d versions, %d objects with changed numbers", game.title, #game.versions, n))
    end
    print("written to " .. folder .. "/history.js")
end
-- }}}

return M
