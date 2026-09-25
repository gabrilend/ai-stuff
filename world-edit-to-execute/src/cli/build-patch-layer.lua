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
--
-- Example:
--   luajit src/cli/build-patch-layer.lua \
--       /mnt/mtwo/games/warcraft-iii/torrent-version/Patch/War3TFT_121b_English.exe 1.21b
--
-- Reads the Frozen Throne install through wc3-installs/frozen-throne and
-- writes the layer to wc3-installs/patch-layers/<version>/ (a link to a
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

-- {{{ main
local program, version = arg[1], arg[2]
if not program or not version or program == "--help" then
    print("Usage: luajit src/cli/build-patch-layer.lua [--dir DIR] <patch-program.exe> <version>")
    os.exit(program == "--help" and 0 or 1)
end

local install = DIR .. "/wc3-installs/frozen-throne"
local layers = DIR .. "/wc3-installs/patch-layers"
local probe = io.open(layers .. "/.", "r")
if not probe then
    error("no " .. layers .. " folder: create it as a link to a folder beside the installs"
        .. " (see wc3-installs/README.md)")
end
probe:close()

local scratch = os.tmpname()
os.remove(scratch)

local started = os.clock()
local manifest = patch_layer.build({
    patch_program = program,
    install = install,
    base_archives = { "war3.mpq", "War3x.mpq", "War3xlocal.mpq" },
    version = version,
    output = layers .. "/" .. version,
    scratch = scratch,
})
os.execute("rm -rf '" .. scratch:gsub("'", "'\\''") .. "'")

local c = manifest.counts
print(string.format("layer %s: %d archive files, %d install files (%d diffs, %d whole) in %.1f s",
    version, c.archive, c.install, c.diff, c.whole, os.clock() - started))
print("patch requires the game to be older than " .. tostring(manifest.requires_older_than))
print("written to " .. layers .. "/" .. version)
-- }}}
