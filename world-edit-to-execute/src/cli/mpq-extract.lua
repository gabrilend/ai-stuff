#!/usr/bin/env luajit
-- mpq-extract.lua - list or extract the files inside any Blizzard MPQ archive
--
-- In plain terms: MPQ archives are the containers Warcraft III and World of
-- Warcraft keep their files in (maps, game data, patches). This tool opens
-- one, including an archive hidden inside a patch program (.exe), and either
-- lists what's inside or copies files out. It uses StormLib, built by
-- scripts/build-dependencies.sh.
--
-- Usage:
--   luajit src/cli/mpq-extract.lua [--dir DIR] [--listfile FILE] list    <archive> [mask]
--   luajit src/cli/mpq-extract.lua [--dir DIR] extract <archive> <name> <dest-file>
--   luajit src/cli/mpq-extract.lua [--dir DIR] [--listfile FILE] all     <archive> <dest-folder> [mask]
--   luajit src/cli/mpq-extract.lua --help
--
-- mask is a wildcard such as "*" (default) or "Units\*.slk".
-- In "all", archive paths use backslashes; they become folders under dest-folder.
-- Names come from the archive's own (listfile) plus an extra list: FILE if
-- given, otherwise the standard Warcraft III map file names. Files neither
-- list names appear as StormLib's placeholders, e.g. File00000021.blp.
--
-- Issue: issues/completed/112a-stormlib-build-and-update-script.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local LISTFILE = nil
while arg[1] == "--dir" or arg[1] == "--listfile" do
    if arg[1] == "--dir" then DIR = arg[2] else LISTFILE = arg[2] end
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local stormlib = require("mpq.stormlib")
local standard_names = require("mpq.standard_names")

-- {{{ local function with_listfile
-- Runs fn(listfile_path) with the user's listfile, or with a temporary one
-- holding the standard map file names, removed afterwards.
local function with_listfile(fn)
    if LISTFILE then
        return fn(LISTFILE)
    end
    local temporary = standard_names.write_listfile()
    local ok, err = pcall(fn, temporary)
    os.remove(temporary)
    if not ok then error(err, 0) end
end
-- }}}

-- {{{ local function usage
local function usage()
    local f = io.open(arg[0], "r")
    for line in f:lines() do
        if line:match("^%-%- Usage:") then
            print("Usage:")
        elseif line:match("^%-%-   ") then
            print(line:sub(4))
        elseif line:match("^%-%- mask") or line:match("^%-%- In \"all\"") then
            print(line:sub(4))
        end
    end
    f:close()
end
-- }}}

-- {{{ local function ensure_folder
-- Creates a folder and its parents. Paths come from archive entries, so they
-- are passed to mkdir as a single quoted argument, never through a shell word
-- split.
local function ensure_folder(path)
    local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
    local status = os.execute("mkdir -p " .. quoted)
    -- LuaJIT returns the exit status as a number; Lua 5.2+ returns true/nil.
    if status ~= 0 and status ~= true then
        error("could not create folder " .. path)
    end
end
-- }}}

-- {{{ local function cmd_list
local function cmd_list(archive_path, mask)
    with_listfile(function(listfile)
        local archive = stormlib.open(archive_path)
        local entries = archive:list(mask or "*", listfile)
        for _, e in ipairs(entries) do
            print(string.format("%10d  %10d  0x%08x  locale %-5d %s",
                e.size, e.compressed_size, e.flags, e.locale, e.name))
        end
        print(string.format("%d file(s)", #entries))
        archive:close()
    end)
end
-- }}}

-- {{{ local function cmd_extract
local function cmd_extract(archive_path, name, dest)
    local archive = stormlib.open(archive_path)
    archive:extract(name, dest)
    archive:close()
    print("extracted " .. name .. " -> " .. dest)
end
-- }}}

-- {{{ local function cmd_all
-- Extracts every file matching mask, turning backslash paths into folders.
-- A name that tries to climb out of dest-folder ("..") is refused.
local function cmd_all(archive_path, dest_folder, mask)
    with_listfile(function(listfile)
        local archive = stormlib.open(archive_path)
        local count = 0
        ensure_folder(dest_folder)
        for _, e in ipairs(archive:list(mask or "*", listfile)) do
            local relative = e.name:gsub("\\", "/")
            if relative:match("%.%.") then
                error("refusing entry that leaves the destination folder: " .. e.name)
            end
            local dest = dest_folder .. "/" .. relative
            local folder = dest:match("^(.*)/[^/]+$")
            if folder then ensure_folder(folder) end
            archive:extract(e.name, dest)
            count = count + 1
        end
        archive:close()
        print(string.format("extracted %d file(s) into %s", count, dest_folder))
    end)
end
-- }}}

-- {{{ main
local commands = {
    list = function() cmd_list(arg[2], arg[3]) end,
    extract = function() cmd_extract(arg[2], arg[3], arg[4]) end,
    all = function() cmd_all(arg[2], arg[3], arg[4]) end,
}

local command = commands[arg[1] or ""]
if arg[1] == "--help" or arg[1] == "-h" or not command then
    usage()
    os.exit(command and 0 or (arg[1] and 1 or 0))
end
if not arg[2] then
    usage()
    os.exit(1)
end
command()
-- }}}
