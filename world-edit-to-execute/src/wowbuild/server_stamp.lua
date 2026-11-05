--[[
The Server's Stamp of a Build Folder (Issue W02f, step 1; issue 913)

AzerothCore reads a converted map's tables and maps only when it starts
(W02f), so the editor's Test Map starts the server again whenever a new
build changes what the server reads, and reuses the running one when it
doesn't. This names exactly the files of a build folder the server reads,
each with its CRC-32 and size, written as <build>/server-stamp after the
converter has written everything else:

  # W02f: the files of this build folder the server reads (src/wowbuild/server_stamp.lua)
  format 1
  1a2b3c4d 1234 patch-W.MPQ
  ...

one line a file, sorted by path, nothing else: no time, no count of
seconds, so the same server files give the same stamp, byte for byte.

What the server reads (server_stamp.READS), whichever of them the folder
holds, for every map converted into it:

  server/world.sql                     the creatures (W02b, W02h)
  server/dbc.sql                       the tables' rows for <table>_dbc (W02c)
  server/dbc/<Table>.dbc               the stock tables with the maps' rows (W02c)
  server/triggers/<dir>/war3map.lua    the script for the shim (W02e)
  server/triggers/<dir>/map-data.lua   what the shim reads of the build (W02e)
  server/ale/wc3shim/<module>.lua      the shim itself, copied into the build
                                       for the install (W02f step 2)
  patch-W.MPQ                          what the extractors read for the
                                       server's maps, vmaps and mmaps (W02c, W02d)

Not the W client's files (map.lua, DBFilesClient/, the loose ground
files, world/, the map's imports), and not the reports (conversion-report.lua,
placements.lua, World/Maps/<dir>/registration.lua,
server/triggers/<dir>/natives-report.lua), and not what the server never
reads (install-plan.lua, which the install reads; the shim's licence).

    local server_stamp = require("wowbuild.server_stamp")
    local text, files = server_stamp.write(build_dir)
    server_stamp.files(build_dir)          -- { "patch-W.MPQ", "server/dbc.sql", ... }
]]

local bsd0 = require("gamedata.bsd0")       -- its crc32: the system zlib's

local server_stamp = {}

server_stamp.FILE = "server-stamp"
server_stamp.FORMAT = 1
server_stamp.HEADER = "# W02f: the files of this build folder the server reads (src/wowbuild/server_stamp.lua)"

-- each: a fixed path, or a folder and the ending its files have (a folder
-- of one level, or of one level of map folders then a name)
server_stamp.READS = {
    { path = "server/world.sql" },
    { path = "server/dbc.sql" },
    { folder = "server/dbc", ending = ".dbc" },
    { folder = "server/triggers", each_map = "war3map.lua" },
    { folder = "server/triggers", each_map = "map-data.lua" },
    -- the shim's own code, since step 2's install plan installs it from
    -- the build (2026-11-05): a changed shim starts the server again
    { folder = "server/ale/wc3shim", ending = ".lua" },
    { path = "patch-W.MPQ" },
}

-- {{{ helpers
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function list_dir(dir)
    local out = {}
    local p = io.popen("ls -1 " .. quote(dir) .. " 2>/dev/null")
    if p then for name in p:lines() do out[#out + 1] = name end p:close() end
    table.sort(out)
    return out
end

local function is_file(path)
    local f = io.open(path, "rb")
    if not f then return false end
    local ok = f:read(0) ~= nil or f:seek("end") == 0   -- a folder opens on Linux but can't be read
    f:close()
    return ok
end
-- }}}

-- {{{ server_stamp.files: the folder's files the server reads, sorted
function server_stamp.files(build_dir)
    local out, seen = {}, {}
    local function add(rel)
        if not seen[rel] and is_file(build_dir .. "/" .. rel) then seen[rel] = true out[#out + 1] = rel end
    end
    for _, r in ipairs(server_stamp.READS) do
        if r.path then add(r.path)
        elseif r.ending then
            for _, name in ipairs(list_dir(build_dir .. "/" .. r.folder)) do
                if name:sub(-#r.ending) == r.ending then add(r.folder .. "/" .. name) end
            end
        elseif r.each_map then
            for _, dir in ipairs(list_dir(build_dir .. "/" .. r.folder)) do
                add(r.folder .. "/" .. dir .. "/" .. r.each_map)
            end
        end
    end
    table.sort(out)
    return out
end
-- }}}

-- {{{ server_stamp.text: the stamp of the folder as it is now
function server_stamp.text(build_dir)
    local files = server_stamp.files(build_dir)
    local lines = { server_stamp.HEADER, "format " .. server_stamp.FORMAT }
    for _, rel in ipairs(files) do
        local f = assert(io.open(build_dir .. "/" .. rel, "rb"))
        local bytes = f:read("*a")
        f:close()
        lines[#lines + 1] = string.format("%08x %d %s", bsd0.crc32(bytes), #bytes, rel)
    end
    return table.concat(lines, "\n") .. "\n", files
end
-- }}}

-- {{{ server_stamp.remove / server_stamp.write
-- remove: before a conversion, so a stamp never outlives the files it names
function server_stamp.remove(build_dir)
    os.remove(build_dir .. "/" .. server_stamp.FILE)
end

-- write: after every other file; whole (another name, then renamed)
function server_stamp.write(build_dir)
    local text, files = server_stamp.text(build_dir)
    local path = build_dir .. "/" .. server_stamp.FILE
    local tmp = path .. ".part"
    local f, err = io.open(tmp, "wb")
    if not f then error("can't write " .. path .. ": " .. tostring(err), 0) end
    f:write(text)
    f:close()
    local ok, e = os.rename(tmp, path)
    if not ok then error("can't write " .. path .. ": " .. tostring(e), 0) end
    return text, files
end
-- }}}

-- {{{ server_stamp.read: a stamp's text, checked, or nil and why
-- (the editor's side: the header comment may change, the format line and
-- the file lines may not)
function server_stamp.read(build_dir)
    local f = io.open(build_dir .. "/" .. server_stamp.FILE, "rb")
    if not f then return nil, "no " .. server_stamp.FILE end
    local text = f:read(1024 * 1024 + 1) or ""
    f:close()
    if #text > 1024 * 1024 then return nil, "its " .. server_stamp.FILE .. " is too big" end
    local format_seen
    for line in text:gmatch("[^\n]*") do
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if not format_seen then
                local n = line:match("^format (%d+)$")
                if tonumber(n) ~= server_stamp.FORMAT then
                    return nil, "its " .. server_stamp.FILE .. " isn't format " .. server_stamp.FORMAT
                end
                format_seen = true
            elseif not line:match("^%x%x%x%x%x%x%x%x %d+ %S.*$") then
                return nil, "its " .. server_stamp.FILE .. " has a line that isn't a checksum, a size and a path"
            end
        end
    end
    if not format_seen then return nil, "its " .. server_stamp.FILE .. " has no format line" end
    return text
end
-- }}}

return server_stamp
