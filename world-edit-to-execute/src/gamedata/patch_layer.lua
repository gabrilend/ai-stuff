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
  patch.lst alone. So a layer's archive files are complete by themselves.
  Loose install files are not: a file the patch doesn't list stays as the
  version below left it.
- Each entry is a whole file or a diff against the old file (gamedata/bsd0.lua).
  The diff names the old file's size and CRC32. Archive entries diff against
  the same path in the previous War3Patch.mpq or the game's archives; loose
  entries against the file on disk.

Stacking. Versions are built in order, each on the layers below it
(options.lower_layers, highest first). For each diff the builder looks for
the old file whose size and CRC32 match: in each lower layer, highest first,
then in the disc install. A full patch (applies over any earlier version)
may diff against the disc even when built on a lower layer; an incremental
one against the layer just below. Either way the base found is recorded per
entry, and the manifest names the layers the build was offered.

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
      lower_layers = { { name = "1.21a", folder = ".../patch-layers/1.21a" } },  -- highest first; may be empty
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

-- {{{ local function open_patch
-- Opens a patch program's nested archive (named in its mpqs.lst), unpacked
-- into scratch. Returns the open archive and the unpacked file's path.
local function open_patch(patch_program, scratch)
    local outer = stormlib.open(patch_program)
    local nested_name = parse_list(outer:read("mpqs.lst"))[1]:match("^%s*(.-)%s*$")
    ensure_folder(scratch)
    local nested_path = scratch .. "/" .. nested_name
    outer:extract(nested_name, nested_path)
    outer:close()
    return stormlib.open(nested_path), nested_path
end
-- }}}

-- {{{ local function file_version
-- The file version stamped in a Windows program (its VS_FIXEDFILEINFO block,
-- found by the 0xFEEF04BD signature): four integers, or nil when absent.
local function file_version(bytes)
    local at = bytes:find("\189\4\239\254", 1, true)
    if not at then
        return nil
    end
    local function u16(o) return bytes:byte(o) + bytes:byte(o + 1) * 256 end
    -- dwFileVersionMS at +8, dwFileVersionLS at +12; each is two 16-bit halves, high first.
    return { u16(at + 10), u16(at + 8), u16(at + 14), u16(at + 12) }
end
-- }}}

-- {{{ function M.target_version
-- The game version a patch program produces: the version stamped in the
-- War3.exe it writes (whole, or rebuilt from its diff against the install's
-- copy). Returns the version string and a list of four integers for
-- ordering.
--
-- Why not the script's own check (FileVersionLessThan "War3.exe" 1.24.4.6387):
-- from 1.25b on it says 1.99.99.9999, a placeholder, and ordering by it put
-- 1.27b before 1.25b. A stated version that isn't the placeholder must agree
-- with the stamped one, or this raises; a diff whose base isn't the
-- install's War3.exe raises too (an incremental patch needs the layer below,
-- which ordering can't assume).
function M.target_version(patch_program, scratch, install)
    local patch, nested_path = open_patch(patch_program, scratch)
    local script = patch:read("patch.cmd")
    local checked_file, stated = script:match("FileVersionLessThan%s+\"[^\"]-\\?([^\\\"]+)\"%s+([%d%.]+)")
    if not checked_file then
        patch:close()
        os.remove(nested_path)
        error(patch_program .. ": patch.cmd has no FileVersionLessThan check naming the game's program")
    end
    local entry
    for _, line in ipairs(parse_list(patch:read("patch.lst"))) do
        local target, source = line:match("^(.-);([^;]*)")
        if target and target:lower() == checked_file:lower() then
            entry = patch:read(source)
        end
    end
    patch:close()
    os.remove(nested_path)
    if not entry then
        error(patch_program .. ": patch.lst doesn't write " .. checked_file .. ", so its version can't be read")
    end
    local header = assert(bsd0.read_header(entry))
    local old = nil
    if header.kind == bsd0.KIND_DIFF then
        old = read_file(install_index(install)[checked_file:lower()] or "")
    end
    local new, err = bsd0.apply(entry, old)
    if not new then
        error(patch_program .. ": can't rebuild " .. checked_file .. " to read its version: " .. err)
    end
    local parts = file_version(new)
    if not parts then
        error(patch_program .. ": the " .. checked_file .. " it writes has no version stamp")
    end
    local version = table.concat(parts, ".")
    -- 1.99.99.9999 (and anything from 1.99 up) is Blizzard's "any version" placeholder.
    local stated_major, stated_minor = stated:match("^(%d+)%.(%d+)")
    local placeholder = tonumber(stated_major) == 1 and tonumber(stated_minor) >= 99
    if not placeholder and stated ~= version then
        error(string.format("%s: patch.cmd says %s but the %s it writes is %s", patch_program, stated,
            checked_file, version))
    end
    return version, parts
end
-- }}}

-- {{{ function M.build
-- Builds one layer. Returns a summary table; raises an error on the first
-- entry that can't be built (a missing base, a CRC mismatch), naming it.
function M.build(options)
    local program_bytes = read_file(options.patch_program)

    -- The nested archive named in mpqs.lst holds the patch.
    local patch, nested_path = open_patch(options.patch_program, options.scratch)

    -- The game's own archives, highest priority first, for archive-entry bases.
    local archives = {}
    for i = #options.base_archives, 1, -1 do
        archives[#archives + 1] = {
            name = options.base_archives[i],
            archive = stormlib.open(options.install .. "/" .. options.base_archives[i]),
        }
    end
    local on_disk = install_index(options.install)

    -- Lower layers, highest first: each one's files, indexed like the install.
    local lower = {}
    for _, layer in ipairs(options.lower_layers or {}) do
        lower[#lower + 1] = {
            name = layer.name,
            archive = install_index(layer.folder .. "/archive"),
            install = install_index(layer.folder .. "/install"),
        }
    end

    -- {{{ local function find_base
    -- The old file a diff names (by size and CRC32): each lower layer's copy,
    -- highest first, then the disc install. Returns the bytes and where they
    -- came from, or nil and the list of places tried. A copy with the wrong
    -- size or CRC32 is passed over, not an error: a full patch built on a
    -- lower layer still diffs against the disc.
    local function find_base(header, place, target)
        local key = target:gsub("\\", "/"):lower()
        local tried = {}
        local function matches(bytes)
            return bytes and #bytes == header.old_size and bsd0.crc32(bytes) == header.old_crc
        end
        for _, layer in ipairs(lower) do
            local real = layer[place][key]
            if real then
                local bytes = read_file(real)
                if matches(bytes) then
                    return bytes, "layer " .. layer.name
                end
                tried[#tried + 1] = "layer " .. layer.name .. " (differs)"
            end
        end
        if place == "archive" then
            for _, a in ipairs(archives) do
                if a.archive:has(target) then
                    local bytes = a.archive:read(target)
                    if matches(bytes) then
                        return bytes, a.name
                    end
                    tried[#tried + 1] = a.name .. " (differs)"
                end
            end
        else
            local real = on_disk[key]
            if real then
                local bytes = read_file(real)
                if matches(bytes) then
                    return bytes, "install"
                end
                tried[#tried + 1] = "install (differs)"
            end
        end
        return nil, #tried > 0 and table.concat(tried, ", ") or "nowhere has it"
    end
    -- }}}

    local manifest = {
        version = options.version,
        built = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        patch_program = {
            file = options.patch_program:match("[^/]+$"),
            size = #program_bytes,
            crc32 = bsd0.crc32(program_bytes),
        },
        base_archives = options.base_archives,
        lower_layers = {},
        deleted = parse_list(patch:read("delete.lst")),
        entries = {},
    }
    for _, layer in ipairs(lower) do
        manifest.lower_layers[#manifest.lower_layers + 1] = layer.name
    end
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
            old, base_from = find_base(header, place, target)
            if not old then
                error(string.format("%s: diff needs %s at %d bytes with CRC32 %08x; tried %s", source, target,
                    header.old_size, header.old_crc, base_from))
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

-- {{{ function M.program_version
-- The file version stamped in a Windows program file (path), as a string
-- ("1.29.2.9231"), or raises.
function M.program_version(path)
    local parts = file_version(assert(read_file(path), "cannot read " .. path))
    if not parts then
        error(path .. " has no version stamp")
    end
    return table.concat(parts, ".")
end
-- }}}

-- {{{ function M.build_install
-- Builds an install layer: a version with no patch program (1.28 on), whose
-- own rebuilt data archives replace the disc's in the chain (issue 112b).
-- options:
--   version        layer name ("1.29.2")
--   source_folder  where the fetch script kept this version's files
--   archive_order  archive names, highest priority first
--   game_program, editor_program   file names in source_folder
--   checksums      file name -> sha256 (from the fetch record)
--   output         the layer folder
-- The archives are hard-linked into output/archives (same disk as the
-- fetched copies; a failed link is an error). Returns the manifest.
function M.build_install(options)
    ensure_folder(options.output .. "/archives")
    local manifest = {
        kind = "install",
        version = options.version,
        built = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        archive_order = options.archive_order,
        archives = {},
        game_version = M.program_version(options.source_folder .. "/" .. options.game_program),
        editor_program = options.editor_program,
    }
    for _, name in ipairs(options.archive_order) do
        local from = options.source_folder .. "/" .. name
        local to = options.output .. "/archives/" .. name
        os.remove(to)
        local status = os.execute("ln " .. shell_quote(from) .. " " .. shell_quote(to))
        if status ~= 0 and status ~= true then
            error("could not link " .. from .. " into the layer")
        end
        local f = assert(io.open(to, "rb"))
        local size = f:seek("end")
        f:close()
        local sha = options.checksums[name]
        if not sha then
            error(name .. " has no checksum in the fetch record")
        end
        manifest.archives[#manifest.archives + 1] = { name = name, size = size, sha256 = sha }
    end
    -- Candidate editor builds: 4-byte constants 6031-6099 present in the
    -- editor. Noisy for a large program (1.29.2's matches 37 by chance), so
    -- evidence is a contrast between versions, recorded in editor_versions.lua.
    local editor = assert(read_file(options.source_folder .. "/" .. options.editor_program))
    manifest.editor_builds = {}
    for build = 6031, 6099 do
        if editor:find(string.char(build % 256, math.floor(build / 256), 0, 0), 1, true) then
            manifest.editor_builds[#manifest.editor_builds + 1] = build
        end
    end
    write_file(options.output .. "/manifest.lua",
        "-- Install layer manifest, written by src/gamedata/patch_layer.lua. Do not edit.\n"
        .. "return " .. serialize(manifest) .. "\n")
    return manifest
end
-- }}}

return M
