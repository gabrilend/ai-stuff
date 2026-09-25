--[[
standard_names.lua - the file names a Warcraft III map normally holds

An MPQ archive stores only hashes of its file names; the names themselves
live in an optional "(listfile)" inside it. Protected maps strip or falsify
that listfile, so tools that want to find a map's files by name need their
own list of the usual ones. Used by src/cli/mpq-extract.lua (as an extra
listfile for StormLib) and src/tests/test_stormlib.lua.

Usage:
  local names = require("mpq.standard_names")
  for _, n in ipairs(names.MAP_FILES) do ... end
  local path = names.write_listfile()   -- a temporary listfile; caller removes it
]]

local M = {}

-- {{{ MAP_FILES
M.MAP_FILES = {
    "(listfile)", "(attributes)", "(signature)",
    "war3map.w3i", "war3map.w3e", "war3map.wts", "war3map.j", "scripts\\war3map.j",
    "war3map.lua", "scripts\\war3map.lua",
    "war3map.shd", "war3map.wpm", "war3map.doo", "war3mapUnits.doo",
    "war3map.w3r", "war3map.w3c", "war3map.w3s", "war3map.wtg", "war3map.wct",
    "war3map.w3u", "war3map.w3t", "war3map.w3b", "war3map.w3d", "war3map.w3a",
    "war3map.w3h", "war3map.w3q", "war3map.mmp", "war3mapMap.blp", "war3mapMap.tga",
    "war3mapPreview.tga", "war3mapMisc.txt", "war3mapSkin.txt", "war3mapExtra.txt",
    "war3map.imp",
}
-- }}}

-- {{{ function M.write_listfile
-- Writes the names, one per line, to a temporary file and returns its path.
-- The caller removes it (os.remove) when done.
function M.write_listfile()
    local path = os.tmpname()
    local f = assert(io.open(path, "w"))
    f:write(table.concat(M.MAP_FILES, "\r\n"), "\r\n")
    f:close()
    return path
end
-- }}}

return M
