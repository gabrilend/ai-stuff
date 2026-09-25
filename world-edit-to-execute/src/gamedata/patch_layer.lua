--[[
patch_layer.lua - turn a Warcraft III patch program into a stored "layer"

A patch layer is the set of files one Blizzard patch produces, extracted once
from the patch program without running it, so that any number of game
versions can sit side by side and be chosen per map (issue 112b). Nothing in
the installs is ever changed.

What's inside a patch program (1.21b, read 2026-09-24):
- The .exe carries an MPQ archive. Its "mpqs.lst" names a nested archive
  (Patch_War3x.mpq) holding the patch itself.
- "patch.lst" lists every entry, one per line:
    target;name-in-archive;0x0   a file that goes into the rebuilt War3Patch.mpq
    target;name-in-archive       a loose file in the install folder (maps, Game.dll)
  One name can appear in several folders, so names in the archive carry
  "~00", "~01" suffixes.
- "delete.lst" lists install files the patcher deletes first. It starts with
  War3Patch.mpq: the patcher throws the old one away and builds a new one from
  patch.lst alone. So a layer is complete by itself: layers replace each
  other, they don't stack.
- Each entry is a whole file or a diff against the old file (gamedata/bsd0.lua).
  Archive entries diff against the same path in the game's archives; loose
  entries diff against the file on disk.

Layer on disk:
  <layer>/archive/<target path, "/" separators>   what War3Patch.mpq would hold
  <layer>/install/<target path>                    loose install files
  <layer>/manifest.lua                             what was built, from what, with CRC32s

Usage:
  local patch_layer = require("gamedata.patch_layer")
  local summary = patch_layer.build({
      patch_program = ".../War3TFT_121b_English.exe",
      install = ".../wc3-installs/frozen-throne",
      base_archives = { "war3.mpq", "War3x.mpq", "War3xlocal.mpq" },  -- lowest priority first
      version = "1.21b",
      output = ".../patch-layers/1.21b",
      scratch = "/tmp/...",           -- where the nested archive is unpacked
  })

Issue: issues/112b-game-version-layers-per-map.md
]]

local stormlib = require("mpq.stormlib")
local bsd0 = require("gamedata.bsd0")

local M = {}

-- {{{ local function shell_quote
local function shell_quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function ensure_folder
local function ensure_folder(path)
    local status = os.execute("mkdir -p " .. shell_quote(path))
    if status ~= 0 and status ~= true then
        error("could not create folder " .. path)
    end
end
-- }}}

-- {{{ local function write_file
local function write_file(path, bytes)
    local folder = path:match("^(.*)/[^/]+$")
    if folder then ensure_folder(folder) end
    local f = assert(io.open(path, "wb"))
    f:write(bytes)
    f:close()
end
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local bytes = f:read("*a")
    f:close()
    return bytes
end
-- }}}

-- {{{ local function install_index
-- Maps lower-cased relative paths in the install folder to real paths, since
-- patch.lst's case doesn't always match the files on disk ("maps\" vs "Maps/").
local function install_index(install)
    local index = {}
    local listing = io.popen("find " .. shell_quote(install .. "/") .. " -type f")
    for path in listing:lines() do
        local relative = path:sub(#install + 2)
        index[relative:lower()] = path
    end
    listing:close()
    return index
end
-- }}}

-- {{{ local function parse_list
-- Splits a CRLF text file into lines, dropping blank ones. A line holding only
-- "*" ends the list (patch.lst and delete.lst both finish with one).
local function parse_list(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        if line == "*" then
            break
        end
        if line:match("%S") then
            lines[#lines + 1] = line
        end
    end
    return lines
end
-- }}}

-- {{{ local function serialize
-- Writes a Lua value as source text (tables, strings, numbers, booleans),
-- keys sorted so manifests diff cleanly.
local function serialize(value, indent)
    indent = indent or ""
    local kind = type(value)
    if kind == "string" then
        return string.format("%q", value)
    elseif kind == "number" or kind == "boolean" then
        return tostring(value)
    end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    local inner = indent .. "    "
    local parts = {}
    for _, k in ipairs(keys) do
        local key = type(k) == "number" and "" or (string.format("[%q] = ", k))
        parts[#parts + 1] = inner .. key .. serialize(value[k], inner)
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end
-- }}}

-- {{{ function M.build
-- Builds one layer. Returns a summary table; raises an error on the first
-- entry that can't be built (a missing base, a CRC mismatch), naming it.
function M.build(options)
    local outer = stormlib.open(options.patch_program)
    local program_bytes = read_file(options.patch_program)

    -- The nested archive named in mpqs.lst holds the patch.
    local nested_name = parse_list(outer:read("mpqs.lst"))[1]:match("^%s*(.-)%s*$")
    ensure_folder(options.scratch)
    local nested_path = options.scratch .. "/" .. nested_name
    outer:extract(nested_name, nested_path)
    outer:close()
    local patch = stormlib.open(nested_path)

    -- The game's own archives, highest priority first, for archive-entry bases.
    local archives = {}
    for i = #options.base_archives, 1, -1 do
        archives[#archives + 1] = {
            name = options.base_archives[i],
            archive = stormlib.open(options.install .. "/" .. options.base_archives[i]),
        }
    end
    local on_disk = install_index(options.install)

    local manifest = {
        version = options.version,
        built = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        patch_program = {
            file = options.patch_program:match("[^/]+$"),
            size = #program_bytes,
            crc32 = bsd0.crc32(program_bytes),
        },
        base_archives = options.base_archives,
        deleted = parse_list(patch:read("delete.lst")),
        entries = {},
    }
    local patch_cmd = patch:read("patch.cmd")
    manifest.requires_older_than = patch_cmd:match("FileVersionLessThan%s+\"[^\"]*\"%s+([%d%.]+)")

    local counts = { archive = 0, install = 0, diff = 0, whole = 0 }
    for _, line in ipairs(parse_list(patch:read("patch.lst"))) do
        local target, source, flag = line:match("^(.-);(.-);(.*)$")
        if not target then
            target, source = line:match("^(.-);(.*)$")
        end
        if not target then
            error("patch.lst line not understood: " .. line)
        end
        local place = flag and "archive" or "install"
        local entry = patch:read(source)
        local header = assert(bsd0.read_header(entry))

        local old, base_from = nil, nil
        if header.kind == bsd0.KIND_DIFF then
            if place == "archive" then
                for _, a in ipairs(archives) do
                    if a.archive:has(target) then
                        old = a.archive:read(target)
                        base_from = a.name
                        break
                    end
                end
            else
                local real = on_disk[target:gsub("\\", "/"):lower()]
                if real then
                    old = read_file(real)
                    base_from = "install"
                end
            end
            if not old then
                error(string.format("%s: diff needs %s, which isn't in the %s", source, target,
                    place == "archive" and "game's archives" or "install folder"))
            end
        end

        local new, err = bsd0.apply(entry, old)
        if not new then
            error(string.format("%s -> %s: %s", source, target, err))
        end
        write_file(options.output .. "/" .. place .. "/" .. target:gsub("\\", "/"), new)

        local kind = header.kind == bsd0.KIND_DIFF and "diff" or "whole"
        counts[place] = counts[place] + 1
        counts[kind] = counts[kind] + 1
        manifest.entries[#manifest.entries + 1] = {
            target = target,
            place = place,
            kind = kind,
            base = base_from,
            size = #new,
            crc32 = bsd0.crc32(new),
        }
    end
    patch:close()
    for _, a in ipairs(archives) do a.archive:close() end
    os.remove(nested_path)

    manifest.counts = counts
    write_file(options.output .. "/manifest.lua",
        "-- Patch layer manifest, written by src/gamedata/patch_layer.lua. Do not edit.\n"
        .. "return " .. serialize(manifest) .. "\n")
    return manifest
end
-- }}}

return M
