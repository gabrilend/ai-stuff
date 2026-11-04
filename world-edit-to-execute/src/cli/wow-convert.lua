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
--   --dir DIR       this project's folder (default: found from this file)
--   --help
--
-- Builds today ONLY THE TERRAIN (W02a): the map's WDT, WDL and ADT files,
-- under <build folder>/World/Maps/<name>/, and <build folder>/conversion-report.lua.
-- The later parts of W02 add to this same command as they are built:
-- doodads and units (W02b), map registration and patch-W.MPQ (W02c), server
-- data (W02d), triggers (W02e), the world database (W02h).
--
-- Exit status: 0 built; 1 the map couldn't be converted (the reason on
-- stderr); 2 the options were wrong. A summary goes to stdout.
--
-- Issue: issues/W02a-terrain-to-adt-writer.md

local function usage(out)
    out:write([[
usage: wow-convert.lua [--strict] [--name NAME] [--textures FILE] [--dir DIR] <map.w3x> <build folder>
Builds a WC3 map into WoW 3.3.5a's files in the build folder.
Today only the terrain (issue W02a): WDT, WDL and ADTs under World/Maps/<name>/,
and conversion-report.lua. W02's later parts (doodads and units, map
registration and patch-W.MPQ, server data, triggers) add to this command.
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
    elseif a == "--name" or a == "--textures" or a == "--dir" then
        local v = arg[i + 1]
        if not v or v:sub(1, 2) == "--" then bad(a .. " needs a value") end
        if a == "--name" then opts.name = v elseif a == "--textures" then opts.textures = v else DIR = v end
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

local ok, report = pcall(wowbuild.convert, paths[1], paths[2], opts)
if not ok then
    io.stderr:write("wow-convert: " .. tostring(report) .. "\n")
    os.exit(1)
end
print(wowbuild.summary(report))
print("report: " .. paths[2] .. "/" .. wowbuild.REPORT)
os.exit(0)
