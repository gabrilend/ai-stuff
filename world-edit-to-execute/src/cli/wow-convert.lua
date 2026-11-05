#!/usr/bin/env luajit
-- wow-convert.lua - builds a WC3 map into WoW 3.3.5a's files (issue W02)
--
-- In plain terms: takes a Warcraft III map and writes the files the World of
-- Warcraft client (the W client, or the original 3.3.5a one) needs to stand
-- on it, into a build folder. This is the converter the map editor's Test
-- Map button runs (issue 913), and the owner's "one command" of W02.
--
-- Usage:
--   luajit src/cli/wow-convert.lua [options] <map.w3x> <build folder>
--
-- Options (before the two paths):
--   --strict        a chunk needing more than four textures stops the build
--                   (without it each fold is counted as a warning)
--   --name NAME     the WoW map directory name (letters, digits, _; at most
--                   48); default "WC3_" and the map file's name
--   --textures FILE another ground texture table (default
--                   src/wowbuild/ground_textures.lua)
--   --models FILE   another model table (default src/wowbuild/models.lua)
--   --slot N        the map's slot in W02c's id scheme, 0-99 (every id the
--                   map takes follows from it: map id 900 + N, ...); default
--                   the slot it held in this build folder, else the lowest
--                   free one
--   --map-id N      the same, given as the map id (900-999)
--   --stock-dbc DIR a folder of the client's stock .dbc files (AzerothCore's
--                   extracted dbc folder is one) to merge this build's rows
--                   into, for server/dbc/ and patch-W.MPQ; default the
--                   owner's AzerothCore dbc folder when it is there
--   --no-stock      merge with no stock tables (patch-W.MPQ then holds no
--                   tables)
--   --no-patch      don't write patch-W.MPQ
--   --dir DIR       this project's folder (default: found from this file)
--   --help
--
-- Builds today the terrain (W02a), the placements (W02b), the map's
-- registration (W02c) and the first step of its triggers (W02e): the map's
-- WDT, WDL and ADT files under
-- <build folder>/World/Maps/<name>/, its doodads in those ADTs, its units as
-- the server's creatures in <build folder>/server/world.sql, the map's own
-- imported models at their own paths, its rows in the client's tables
-- (DBFilesClient/, the W client's overlay; server/dbc.sql and server/dbc/
-- for AzerothCore; patch-W.MPQ for the stock client and the extractors),
-- map.lua (the map Test Map opens) and the map's war3map.w3e, .w3i and .wpm beside it,
-- world/creatures-<id>.tsv, its loading screen, placements.lua and conversion-report.lua; and for the server's
-- trigger shim (server-side/ale/wc3shim/), server/triggers/<name>/: the
-- script transpiled, the data the shim reads, and natives-report.lua, the
-- natives the script calls and which of them the shim has. The later parts
-- of W02 add to this same command as they are built: server data (W02d),
-- the rest of the triggers (W02e), the world database (W02h).
--
-- Exit status: 0 built; 1 the map couldn't be converted (the reason on
-- stderr); 2 the options were wrong. A summary goes to stdout.
--
-- Issues: issues/W02a-terrain-to-adt-writer.md, issues/W02b-doodads-and-units-to-placements.md,
-- issues/W02c-map-registration-and-output-forms.md, issues/W02e-triggers-on-the-server.md

local function usage(out)
    out:write([[
usage: wow-convert.lua [--strict] [--name NAME] [--textures FILE] [--models FILE]
                      [--slot N | --map-id N] [--stock-dbc DIR | --no-stock] [--no-patch]
                      [--dir DIR] <map.w3x> <build folder>
Builds a WC3 map into WoW 3.3.5a's files in the build folder.
Today the terrain (issue W02a), the placements (W02b), the map's
registration (W02c) and the triggers' first step (W02e): WDT, WDL and ADTs (with the doodads) under
World/Maps/<name>/, the units as creatures in server/world.sql, the map's
own models, its rows in the client's tables (DBFilesClient/; server/dbc.sql
and server/dbc/; patch-W.MPQ), map.lua, world/creatures-<id>.tsv,
placements.lua, conversion-report.lua, and server/triggers/<name>/ (the
script transpiled for the server's shim, its data, the natives report).
W02's later parts (server data, the rest of the triggers) add to this command.
Exit status: 0 built, 1 conversion failed, 2 bad options.
]])
end

-- {{{ arguments
local DIR = (debug.getinfo(1, "S").source:match("^@(.-)src/cli/[^/]*$"))
local opts, paths = {}, {}
local i = 1
local function bad(msg)
    io.stderr:write("wow-convert: " .. msg .. "\n")
    usage(io.stderr)
    os.exit(2)
end
while i <= #arg do
    local a = arg[i]
    if a == "--help" or a == "-h" then usage(io.stdout) os.exit(0)
    elseif a == "--strict" then opts.strict = true
    elseif a == "--no-stock" then opts.stock_dbc = false
    elseif a == "--no-patch" then opts.patch = false
    elseif a == "--name" or a == "--textures" or a == "--models" or a == "--map-id" or a == "--slot"
        or a == "--stock-dbc" or a == "--dir" then
        local v = arg[i + 1]
        if not v or v:sub(1, 2) == "--" then bad(a .. " needs a value") end
        if a == "--name" then opts.name = v
        elseif a == "--textures" then opts.textures = v
        elseif a == "--models" then opts.models = v
        elseif a == "--map-id" then
            opts.map_id = tonumber(v)
            if not opts.map_id or opts.map_id ~= math.floor(opts.map_id) or opts.map_id < 900 or opts.map_id > 999 then
                bad("--map-id: a whole number from 900 to 999 (W02c's map ids)")
            end
        elseif a == "--slot" then
            opts.slot = tonumber(v)
            if not opts.slot or opts.slot ~= math.floor(opts.slot) or opts.slot < 0 or opts.slot > 99 then bad("--slot: a whole number from 0 to 99") end
        elseif a == "--stock-dbc" then opts.stock_dbc = v
        else DIR = v end
        i = i + 1
    elseif a:sub(1, 2) == "--" then bad("unknown option " .. a)
    else paths[#paths + 1] = a end
    i = i + 1
end
if #paths ~= 2 then bad("give the map and the build folder") end
if not DIR or DIR == "" then DIR = "./" end
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
package.path = DIR .. "src/?.lua;" .. DIR .. "src/?/init.lua;" .. package.path
-- }}}

local wowbuild = require("wowbuild")
if opts.name and not wowbuild.valid_name(opts.name) then bad("--name: letters, digits and _ only, 1-48 long") end

opts.dir = DIR   -- the shim's list of natives (W02e) is read from this project's folder
local ok, report = pcall(wowbuild.convert, paths[1], paths[2], opts)
if not ok then
    io.stderr:write("wow-convert: " .. tostring(report) .. "\n")
    os.exit(1)
end
print(wowbuild.summary(report))
print("report: " .. paths[2] .. "/" .. wowbuild.REPORT)
os.exit(0)
