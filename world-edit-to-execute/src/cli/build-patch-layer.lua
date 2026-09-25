#!/usr/bin/env luajit
-- build-patch-layer.lua - turn a Warcraft III patch program into a stored layer
--
-- In plain terms: Blizzard's patch programs change the game's files in place,
-- and 1.21b's won't even run under wine. This tool reads the patch program
-- instead of running it, applies each of its changes to a copy, and stores
-- the result as a "layer" for that game version, beside the installs. Maps
-- then choose which layer they load with (issue 112b). The installs are
-- never touched.
--
-- Usage:
--   luajit src/cli/build-patch-layer.lua [--dir DIR] <patch-program.exe> <version>
--   luajit src/cli/build-patch-layer.lua [--dir DIR] --stack [--up-to VERSION]
--   luajit src/cli/build-patch-layer.lua [--dir DIR] --install-layer VERSION
--
-- The third form is for versions with no patch program (1.28 on): it takes
-- that version's own data archives, kept from a game copy by the fetch
-- script, into an install layer that replaces the disc's archives.
--
-- The first form builds one layer on the disc install alone. The second
-- builds the whole stack: every Frozen Throne patch program recorded in
-- wc3-installs/patch-programs/sources.tsv (gathered by
-- scripts/fetch-patch-programs.sh), in the order of the versions they
-- produce, each on all the layers
-- below it. (The version is the one stamped in the War3.exe each program
-- writes; the programs' own version checks turned into a placeholder from
-- 1.25b on.) A layer whose manifest already names the same program and the
-- same layers beneath is left as it is, so running it twice changes nothing.
-- A layer built on a lower layer that has since changed is rebuilt.
--
-- Example:
--   luajit src/cli/build-patch-layer.lua \
--       /mnt/mtwo/games/warcraft-iii/torrent-version/Patch/War3TFT_121b_English.exe 1.21b
--   luajit src/cli/build-patch-layer.lua --stack
--
-- Reads the Frozen Throne install through wc3-installs/frozen-throne and
-- writes each layer to wc3-installs/patch-layers/<version>/ (a link to a
-- folder beside the installs; the layer holds Blizzard's files, so it is
-- never inside the repository).
--
-- Issue: issues/112b-game-version-layers-per-map.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local patch_layer = require("gamedata.patch_layer")

-- {{{ local function read_manifest
local function read_manifest(folder)
    local chunk = loadfile(folder .. "/manifest.lua")
    return chunk and chunk() or nil
end
-- }}}

-- {{{ local function recorded_programs
-- The Frozen Throne rows of the patch-programs record: saved-as, version.
-- The last row for a file wins (the record is append-only).
local function recorded_programs(programs)
    local f = io.open(programs .. "/sources.tsv", "r")
    if not f then
        error("no " .. programs .. "/sources.tsv: run scripts/fetch-patch-programs.sh first")
    end
    local by_file = {}
    for line in f:lines() do
        local saved, version, game = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t")
        -- Rows saved into a version's folder (1.29.2/War3.mpq) are an install
        -- layer's data, not patch programs: --install-layer uses those.
        if saved and game == "tft" and not saved:find("/", 1, true) then
            by_file[saved] = { file = programs .. "/" .. saved, version = version }
        end
    end
    f:close()
    local list = {}
    for _, row in pairs(by_file) do list[#list + 1] = row end
    return list
end
-- }}}

-- {{{ local function build_one
local function build_one(program, version, lower_layers, install, layers)
    local scratch = os.tmpname()
    os.remove(scratch)
    local started = os.clock()
    local manifest = patch_layer.build({
        patch_program = program,
        install = install,
        base_archives = { "war3.mpq", "War3x.mpq", "War3xlocal.mpq" },
        version = version,
        output = layers .. "/" .. version,
        lower_layers = lower_layers,
        scratch = scratch,
    })
    os.execute("rm -rf '" .. scratch:gsub("'", "'\\''") .. "'")
    local c = manifest.counts
    print(string.format("layer %s: %d archive files, %d install files (%d diffs, %d whole) in %.1f s",
        version, c.archive, c.install, c.diff, c.whole, os.clock() - started))
    local bases = {}
    for _, e in ipairs(manifest.entries) do
        if e.base then bases[e.base] = (bases[e.base] or 0) + 1 end
    end
    for base, n in pairs(bases) do
        print(string.format("    %d diffs based on %s", n, base))
    end
    return manifest
end
-- }}}

-- {{{ main
local install = DIR .. "/wc3-installs/frozen-throne"
local layers = DIR .. "/wc3-installs/patch-layers"
local programs = DIR .. "/wc3-installs/patch-programs"
local probe = io.open(layers .. "/.", "r")
if not probe then
    error("no " .. layers .. " folder: create it as a link to a folder beside the installs"
        .. " (see wc3-installs/README.md)")
end
probe:close()

-- {{{ install layers
-- Versions with no patch program (1.28 on): the data archives kept from a
-- game copy, listed in the fetch record under "<version>/".
local INSTALL_LAYERS = {
    ["1.29.2"] = {
        archive_order = { "War3xLocal.mpq", "War3x.mpq", "War3Local.mpq", "War3.mpq" },   -- highest priority first
        game_program = "Warcraft III.exe",
        editor_program = "World Editor.exe",
    },
}
-- }}}

if arg[1] == "--install-layer" then
    local version = arg[2]
    local spec = INSTALL_LAYERS[version]
    if not spec then
        error("no install layer described for " .. tostring(version) .. " (see INSTALL_LAYERS in this file)")
    end
    local checksums = {}
    local f = assert(io.open(programs .. "/sources.tsv", "r"))
    for line in f:lines() do
        local saved, _, _, sha = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t")
        if saved and saved:sub(1, #version + 1) == version .. "/" then
            checksums[saved:sub(#version + 2)] = sha
        end
    end
    f:close()
    local folder = layers .. "/" .. version
    local existing = read_manifest(folder)
    local same = existing and existing.kind == "install" and #existing.archives == #spec.archive_order
    if same then
        for _, a in ipairs(existing.archives) do
            if checksums[a.name] ~= a.sha256 then same = false end
        end
    end
    if same then
        print(version .. ": present; its archives are unchanged")
        os.exit(0)
    end
    local m = patch_layer.build_install({
        version = version, source_folder = programs .. "/" .. version,
        archive_order = spec.archive_order, game_program = spec.game_program,
        editor_program = spec.editor_program, checksums = checksums, output = folder,
    })
    print(string.format("install layer %s: game %s, %d archives, editor builds found: %s",
        version, m.game_version, #m.archives, table.concat(m.editor_builds, " ")))
    os.exit(0)
end

if arg[1] == "--stack" then
    local up_to = arg[2] == "--up-to" and arg[3] or nil
    -- Order by the version each program produces, never by file name.
    local list = recorded_programs(programs)
    local scratch = os.tmpname()
    os.remove(scratch)
    for _, row in ipairs(list) do
        row.target, row.order = patch_layer.target_version(row.file, scratch, install)
    end
    os.execute("rm -rf '" .. scratch:gsub("'", "'\\''") .. "'")
    table.sort(list, function(a, b)
        for i = 1, 4 do
            if (a.order[i] or 0) ~= (b.order[i] or 0) then
                return (a.order[i] or 0) < (b.order[i] or 0)
            end
        end
        return false
    end)

    local below = {}       -- layers built so far, highest first
    local rebuilt_below = false
    for _, row in ipairs(list) do
        print(string.format("%s  (produces %s)  %s", row.version, row.target, row.file:match("[^/]+$")))
        local folder = layers .. "/" .. row.version
        local existing = read_manifest(folder)
        local same_below = existing and table.concat(existing.lower_layers or {}, ",") ==
            table.concat((function()
                local names = {}
                for _, l in ipairs(below) do names[#names + 1] = l.name end
                return names
            end)(), ",")
        local program_crc = nil
        if existing then
            local f = assert(io.open(row.file, "rb"))
            program_crc = require("gamedata.bsd0").crc32(f:read("*a"))
            f:close()
        end
        if existing and same_below and not rebuilt_below
            and existing.patch_program and existing.patch_program.crc32 == program_crc then
            print("    present; its program and the layers beneath are unchanged")
        else
            if existing then
                os.execute("rm -rf '" .. folder:gsub("'", "'\\''") .. "'")
            end
            build_one(row.file, row.version, below, install, layers)
            rebuilt_below = true   -- everything above a rebuilt layer is rebuilt too
        end
        table.insert(below, 1, { name = row.version, folder = folder })
        if up_to and row.version == up_to then
            break
        end
    end
    os.exit(0)
end

local program, version = arg[1], arg[2]
if not program or not version or program == "--help" then
    print("Usage: luajit src/cli/build-patch-layer.lua [--dir DIR] <patch-program.exe> <version>")
    print("       luajit src/cli/build-patch-layer.lua [--dir DIR] --stack [--up-to VERSION]")
    os.exit(program == "--help" and 0 or 1)
end
local manifest = build_one(program, version, {}, install, layers)
print("patch requires the game to be older than " .. tostring(manifest.requires_older_than))
print("written to " .. layers .. "/" .. version)
-- }}}
