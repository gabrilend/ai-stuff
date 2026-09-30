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

-- {{{ Archive:files
-- Every stored file as { name, size, block }: names as list gives them,
-- or, with more names (known from elsewhere: what the map's data refers
-- to), those names for the files they find (issue 908)
function Archive:files(more_names)
    check_closed(self)
    local list = entries(self)
    if more_names and #more_names > 0 then
        local path = os.tmpname()
        local f = assert(io.open(path, "w"))
        f:write(table.concat(standard_names.MAP_FILES, "\r\n"), "\r\n", table.concat(more_names, "\r\n"), "\r\n")
        f:close()
        local ok, l = pcall(self._storm.list, self._storm, "*", path)
        os.remove(path)
        if ok then list = l end
    end
    local out, seen = {}, {}
    for _, e in ipairs(list) do
        if not seen[e.block_index] then
            seen[e.block_index] = true
            out[#out + 1] = { name = e.name, size = e.size, block = e.block_index }
        end
    end
    return out
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

-- {{{ mpq.save_copy (issue 911a)
-- Writes a copy of the map at src to dst with the given files put in
-- ({ ["war3map.w3e"] = bytes, ... }; replacing those of the same name;
-- a name given false is taken out: issue 908).
-- The copy is a new archive: every file of the map whose name is known
-- (its listfile, the usual map files, the imports war3map.imp lists) is
-- carried over, then the given ones; the map's 512-byte header (HM3W:
-- name, flags, players) goes in front as it was. Protected maps (tables
-- StormLib opens only to read) save this way too. The map read is never
-- written. true and a report { copied, skipped = { names } }, or nil and
-- a message.
local names_mod = require("mpq.standard_names")

-- the imports war3map.imp lists, with and without war3mapImported\
local function imported(bytes)
    local out = {}
    if not bytes or #bytes < 8 then return out end
    local compat = require("compat")
    local count = compat.unpack_int32(bytes, 5)
    local pos = 9
    for _ = 1, count do
        if pos > #bytes then break end
        pos = pos + 1
        local z = bytes:find("\0", pos, true)
        if not z then break end
        local name = bytes:sub(pos, z - 1)
        out[#out + 1] = name
        out[#out + 1] = "war3mapImported\\" .. name
        pos = z + 1
    end
    return out
end

-- The copy is the map's own archive with the files changed in place
-- (mpq/patch.lua): nothing else in it moves, unnamed files included.
-- When that can't be done, a new archive is built instead
-- (mpq.rebuild_copy), carrying over the files whose names are known.
function mpq.save_copy(src, dst, files)
    if src == dst then return nil, "won't write over the map it read" end
    local f = io.open(src, "rb")
    if not f then return nil, "can't read " .. src end
    local bytes = f:read("*a")
    f:close()
    -- the listfile names every file given (tools list by it)
    local given_listfile = files["(listfile)"] ~= nil
    local okl, arch = pcall(stormlib.open, src)
    if okl then
        local listed = arch:has("(listfile)") and select(2, pcall(arch.read, arch, "(listfile)")) or ""
        arch:close()
        if type(listed) ~= "string" then listed = "" end
        local have = {}
        for line in listed:gmatch("[^\r\n]+") do have[line:lower()] = true end
        local extra, gone = {}, {}
        for name, b in pairs(files) do
            if b == false then gone[name:lower()] = true
            elseif not have[name:lower()] and name ~= "(listfile)" then extra[#extra + 1] = name end
        end
        table.sort(extra)
        if (#extra > 0 or next(gone)) and not files["(listfile)"] then
            local copy = {}
            for k, v in pairs(files) do copy[k] = v end
            local kept = {}
            for line in listed:gmatch("[^\r\n]+") do
                if not gone[line:lower()] then kept[#kept + 1] = line end
            end
            for _, n in ipairs(extra) do kept[#kept + 1] = n end
            copy["(listfile)"] = table.concat(kept, "\r\n") .. "\r\n"
            files = copy
        end
    end
    local out, report = require("mpq.patch").apply(bytes, files)
    if out then
        local o = io.open(dst, "wb")
        if not o then return nil, "can't write " .. dst end
        o:write(out)
        o:close()
        -- read back through StormLib: every file given must be there, as given
        local okr, check = pcall(stormlib.open, dst)
        local good = okr
        if okr then
            for name, b in pairs(files) do
                if b == false then
                    if check:has(name) then good = false end
                else
                    local okf, got = pcall(check.read, check, name)
                    if not okf or got ~= b then good = false end
                end
            end
            check:close()
        end
        if good then
            report.how = "patched"
            -- counted over the files given (not the listfile kept up)
            if report.names["(listfile)"] and not given_listfile then
                if report.names["(listfile)"] == "replaced" then report.replaced = report.replaced - 1
                else report.added = report.added - 1 end
            end
            return true, report
        end
    end
    return mpq.rebuild_copy(src, dst, files)
end

function mpq.rebuild_copy(src, dst, files)
    if src == dst then return nil, "won't write over the map it read" end
    local ok, from = pcall(stormlib.open, src)
    if not ok then return nil, from end
    -- the names this map's files go by
    local names, seen, skipped = {}, {}, {}
    local function add(n)
        local key = n:lower()
        if not seen[key] and n ~= "(listfile)" and n ~= "(attributes)" and n ~= "(signature)" then
            seen[key] = true
            if from:has(n) then names[#names + 1] = n end
        end
    end
    local listed = from:list("*")
    for _, e in ipairs(listed) do
        if e.name:match("^File%d+%.") then skipped[#skipped + 1] = e.name else add(e.name) end
    end
    for _, n in ipairs(names_mod.MAP_FILES) do add(n) end
    if from:has("war3map.imp") then
        local okr, imp = pcall(from.read, from, "war3map.imp")
        for _, n in ipairs(okr and imported(imp) or {}) do add(n) end
    end
    -- unnamed entries whose file turned out to be known by another name
    local keep = {}
    for _, n in ipairs(skipped) do keep[#keep + 1] = n end
    local tmp = dst .. ".building"
    os.remove(tmp)
    local count = #names
    for n in pairs(files) do count = count + 1 end
    local okc, to = pcall(stormlib.create, tmp, math.max(64, count * 2 + 16))
    if not okc then from:close() return nil, to end
    local copied = 0
    local done = {}
    local function put(name, bytes)
        local okw, err = pcall(to.write, to, name, bytes)
        if not okw then error(err) end
        done[name:lower()] = true
        copied = copied + 1
    end
    local okall, err = pcall(function()
        for _, n in ipairs(names) do
            local bytes = files[n]
            if bytes == nil then bytes = from:read(n) end
            if bytes ~= false then put(n, bytes) else done[n:lower()] = true end
        end
        local extra = {}
        for n, b in pairs(files) do if not done[n:lower()] and b ~= false then extra[#extra + 1] = n end end
        table.sort(extra)
        for _, n in ipairs(extra) do put(n, files[n]) end
    end)
    to:flush()
    to:close()
    from:close()
    if not okall then os.remove(tmp) return nil, err end
    -- the header in front, then the archive
    local f = io.open(src, "rb")
    local head = f:read(512)
    f:close()
    if not head or head:sub(1, 4) ~= "HM3W" then head = "" end
    local t = io.open(tmp, "rb")
    local body = t:read("*a")
    t:close()
    os.remove(tmp)
    local o = io.open(dst, "wb")
    if not o then return nil, "can't write " .. dst end
    o:write(head, body)
    o:close()
    return true, { copied = copied, skipped = keep, how = "rebuilt" }
end
-- }}}

-- {{{ mpq.VERSION
mpq.VERSION = "2.0.0"
-- }}}

return mpq
