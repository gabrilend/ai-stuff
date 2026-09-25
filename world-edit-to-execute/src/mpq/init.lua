--[[
MPQ Archive Library - opens Warcraft III maps (.w3x/.w3m) and reads the files inside

Every map parser, the map loader and the tools open maps here. The reading
itself is StormLib's (src/mpq/stormlib.lua): a coverage check over the 16
test maps found it lists and reads every stored file (2,786), including 2,416
with no known name and an encrypted duplicate hidden by a protected map,
which the project's own Lua reader couldn't. The owner (2026-09-24): "If
we're using Stormlib, then let's use that. If we want to replace it, we'll
rewrite the functionality that we're using it for." A replacement is written
against this interface; docs/formats/mpq-archive.md describes the format
(issue 114).

Usage:
  local mpq = require("mpq")
  local archive, err = mpq.open("path/to/map.w3x")
  if archive:has("war3map.w3i") then
      local data = archive:extract("war3map.w3i")
  end
  for _, name in ipairs(archive:list()) do ... end   -- every stored file
  local info = archive:info()   -- filepath, file_size, file_count, map_name, max_players, map_flags
  archive:close()

Errors: open, extract and extract_to_file return nil and a message; nothing
here raises for a missing file, because callers ask for optional map files
(war3map.w3u and friends) and branch on the answer.
]]

local stormlib = require("mpq.stormlib")
local standard_names = require("mpq.standard_names")
local map_wrapper = require("mpq.map_wrapper")

local mpq = {}

-- {{{ Archive class
local Archive = {}
Archive.__index = Archive
-- }}}

-- {{{ local function check_closed
local function check_closed(self)
    if self._closed then
        error("archive is closed: " .. self.filepath)
    end
end
-- }}}

-- {{{ local function entries
-- StormLib's entries for every stored file, found with the map's own
-- listfile plus the standard map file names; read once per archive.
local function entries(self)
    if not self._entries then
        local listfile = standard_names.write_listfile()
        local ok, list = pcall(self._storm.list, self._storm, "*", listfile)
        os.remove(listfile)
        if not ok then
            error(list)
        end
        self._entries = list
    end
    return self._entries
end
-- }}}

-- {{{ Archive:close
function Archive:close()
    if not self._closed then
        self._storm:close()
        self._closed = true
    end
end
-- }}}

-- {{{ Archive:has
function Archive:has(filename)
    check_closed(self)
    return self._storm:has(filename)
end
-- }}}

-- {{{ Archive:extract
-- The file's bytes, or nil and a message when it's missing or unreadable.
function Archive:extract(filename)
    check_closed(self)
    if not self._storm:has(filename) then
        return nil, "file not found: " .. filename
    end
    local ok, data = pcall(self._storm.read, self._storm, filename)
    if not ok then
        return nil, data
    end
    return data
end
-- }}}

-- {{{ Archive:extract_to_file
-- Writes the file to output_path; true, or nil and a message.
function Archive:extract_to_file(filename, output_path)
    check_closed(self)
    local data, err = self:extract(filename)
    if not data then
        return nil, err
    end
    local f = io.open(output_path, "wb")
    if not f then
        return nil, "cannot write " .. output_path
    end
    f:write(data)
    f:close()
    return true
end
-- }}}

-- {{{ Archive:list
-- Every stored file's name (list of strings), each readable with extract.
-- Files with no known name are listed as StormLib names them
-- ("File00000041.blp"). A name stored more than once (protected maps plant
-- duplicates; the game reads one) is listed once by name, and every copy is
-- also listed by its position ("File00000131.w3d"), so no copy is out of reach.
function Archive:list()
    check_closed(self)
    if self._names then
        return self._names
    end
    local by_name = {}
    for _, e in ipairs(entries(self)) do
        by_name[e.name] = (by_name[e.name] or 0) + 1
    end
    local names, listed = {}, {}
    for _, e in ipairs(entries(self)) do
        if not listed[e.name] then
            names[#names + 1] = e.name
            listed[e.name] = true
        end
        if by_name[e.name] > 1 then
            local extension = e.name:match("%.([^.\\]+)$") or "xxx"
            names[#names + 1] = string.format("File%08d.%s", e.block_index, extension)
        end
    end
    self._names = names
    return names
end
-- }}}

-- {{{ Archive:file_count
-- How many files the archive stores (distinct storage positions).
function Archive:file_count()
    check_closed(self)
    local blocks, count = {}, 0
    for _, e in ipairs(entries(self)) do
        if not blocks[e.block_index] then
            blocks[e.block_index] = true
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ Archive:info
-- filepath, file_size (bytes), file_count, and from the map's 512-byte
-- wrapper map_name, max_players, map_flags (absent for a bare archive).
function Archive:info()
    check_closed(self)
    local f = assert(io.open(self.filepath, "rb"))
    local file_size = f:seek("end")
    f:close()
    local info = { filepath = self.filepath, file_size = file_size, file_count = self:file_count() }
    local wrapper = map_wrapper.read(self.filepath)
    if wrapper then
        info.map_name = wrapper.map_name
        info.max_players = wrapper.max_players
        info.map_flags = wrapper.map_flags
    end
    return info
end
-- }}}

-- {{{ mpq.open
-- Opens a map (or any MPQ archive). Returns an Archive, or nil and a message.
function mpq.open(filepath)
    local ok, storm = pcall(stormlib.open, filepath)
    if not ok then
        return nil, storm
    end
    return setmetatable({ filepath = filepath, _storm = storm, _closed = false }, Archive)
end
-- }}}

-- {{{ mpq.VERSION
mpq.VERSION = "2.0.0"
-- }}}

return mpq
