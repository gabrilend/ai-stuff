--[[
Tests for W02f step 1: the server's stamp of a build folder
(src/wowbuild/server_stamp.lua). It names exactly the files the server
reads, each with its CRC-32 and size, and nothing that changes from one
conversion of the same map to the next; the editor's Test Map reuses the
running server while it is the same (issue 913).

    luajit src/tests/test_wow_server_stamp.lua [project folder]

The real conversions need StormLib (STORMLIB_PATH, or the project's deps/);
without it their part is skipped.
]]

-- {{{ Setup paths
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
package.path = DIR .. "src/?.lua;" .. DIR .. "src/?/init.lua;" .. package.path

local server_stamp = require("wowbuild.server_stamp")
local bsd0 = require("gamedata.bsd0")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count, skip_count = 0, 0, 0
local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end
local function skip(name, why)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. ": " .. why)
end
local function section(name) print("\n=== " .. name .. " ===") end
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function write(path, text)
    local dir = path:match("^(.*)/[^/]*$")
    if dir then os.execute("mkdir -p " .. quote(dir)) end
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))
-- }}}

-- {{{ Which files, and the stamp's text
section("The files the server reads")
do
    local b = TMP .. "/made"
    -- what the server reads
    write(b .. "/server/world.sql", "-- creatures\n")
    write(b .. "/server/dbc.sql", "-- rows\n")
    write(b .. "/server/dbc/Map.dbc", "WDBC map")
    write(b .. "/server/dbc/AreaTable.dbc", "WDBC area")
    write(b .. "/server/triggers/WC3_A/war3map.lua", "-- a")
    write(b .. "/server/triggers/WC3_A/map-data.lua", "return {}")
    write(b .. "/server/triggers/WC3_B/war3map.lua", "-- b")
    write(b .. "/server/triggers/WC3_B/map-data.lua", "return { b = 1 }")
    write(b .. "/patch-W.MPQ", "MPQ\26 bytes")
    -- what it doesn't
    write(b .. "/server/triggers/WC3_A/natives-report.lua", "return { seconds = 1 }")
    write(b .. "/server/dbc/notes.txt", "not a table")
    os.execute("mkdir -p " .. quote(b .. "/server/dbc/folder.dbc"))
    write(b .. "/conversion-report.lua", "return { written = 'now' }")
    write(b .. "/placements.lua", "return {}")
    write(b .. "/map.lua", "return { format = 1 }")
    write(b .. "/DBFilesClient/Map.dbc", "WDBC client")
    write(b .. "/World/Maps/WC3_A/WC3_A_31_31.adt", "REVM")
    write(b .. "/World/Maps/WC3_A/registration.lua", "return { written = 'now' }")
    write(b .. "/world/creatures-900.tsv", "# guid")
    -- the map's own files beside map.lua, the W client's (2026-11-05: the
    -- pathing map joined the ground and info files, #252)
    write(b .. "/war3map.w3e", "W3E!")
    write(b .. "/war3map.w3i", "W3I!")
    write(b .. "/war3map.wpm", "MP3W")
    local files = server_stamp.files(b)
    local want = { "patch-W.MPQ", "server/dbc.sql", "server/dbc/AreaTable.dbc", "server/dbc/Map.dbc",
                   "server/triggers/WC3_A/map-data.lua", "server/triggers/WC3_A/war3map.lua",
                   "server/triggers/WC3_B/map-data.lua", "server/triggers/WC3_B/war3map.lua", "server/world.sql" }
    test("exactly the server's files, every map's, sorted", table.concat(files, ",") == table.concat(want, ","),
        table.concat(files, ","))

    local text = server_stamp.text(b)
    local lines = {}
    for l in text:gmatch("[^\n]+") do lines[#lines + 1] = l end
    test("a header comment, the format, then a line a file", lines[1]:sub(1, 1) == "#" and lines[2] == "format 1"
        and #lines == 2 + #want, text)
    test("each line: its CRC-32, its size, its path", lines[3] == string.format("%08x %d patch-W.MPQ",
        bsd0.crc32("MPQ\26 bytes"), #"MPQ\26 bytes"), lines[3])
    test("the CRC-32 is zlib's (\"123456789\" is cbf43926)", string.format("%08x", bsd0.crc32("123456789")) == "cbf43926")

    -- the same server files, the same stamp; a report written anew changes nothing
    write(b .. "/conversion-report.lua", "return { written = 'later', seconds = 2 }")
    write(b .. "/server/triggers/WC3_A/natives-report.lua", "return { seconds = 3 }")
    write(b .. "/World/Maps/WC3_A/registration.lua", "return { written = 'later' }")
    write(b .. "/map.lua", "return { format = 1, start = { x = 1 } }")
    write(b .. "/war3map.wpm", "MP3W another map's pathing")
    test("reports and the W client's files written anew (its pathing map too): the same stamp", server_stamp.text(b) == text)
    write(b .. "/server/world.sql", "-- creatures, one more\n")
    test("a file the server reads changed: another stamp", server_stamp.text(b) ~= text)
    write(b .. "/server/world.sql", "-- creatures\n")
    test("changed back: the stamp as it was", server_stamp.text(b) == text)
    os.remove(b .. "/patch-W.MPQ")
    test("a file the server reads gone: another stamp", server_stamp.text(b) ~= text)
    test("an empty folder: the header and format alone", server_stamp.text(TMP .. "/none") == server_stamp.HEADER .. "\nformat 1\n")
end
-- }}}

-- {{{ Written and read back
section("Written whole, read back, refused when it isn't one")
do
    local b = TMP .. "/rw"
    write(b .. "/server/world.sql", "x")
    local text, files = server_stamp.write(b)
    test("written to <build>/server-stamp, whole (no .part left)", read(b .. "/server-stamp") == text
        and read(b .. "/server-stamp.part") == nil and #files == 1)
    test("read back as it was written", server_stamp.read(b) == text)
    server_stamp.remove(b)
    local r, why = server_stamp.read(b)
    test("removed: none to read, said", r == nil and why:find("no server-stamp", 1, true) ~= nil, why)
    local function refused(name, body, words)
        write(b .. "/server-stamp", body)
        local t, w = server_stamp.read(b)
        test(name, t == nil and (w or ""):find(words, 1, true) ~= nil, w)
    end
    refused("no format line: refused", "# only a comment\n", "no format line")
    refused("format 2: refused", "format 2\n", "isn't format 1")
    refused("a line that isn't a checksum, a size and a path: refused", "format 1\nhello\n", "isn't a checksum")
    write(b .. "/server-stamp", "# another header\nformat 1\n0000abcd 12 server/world.sql\n")
    test("another header comment: still read", server_stamp.read(b) ~= nil)
end
-- }}}

-- {{{ W02's converter writes it
section("W02's converter writes it, last")
do
    local wowbuild = require("wowbuild")
    local maps = { DIR .. "assets/Daow4.4.w3x" }
    local ok, err = pcall(function() require("mpq").open(maps[1]):close() end)
    if not ok then
        skip("the converter's stamp on Daow 4.4", tostring(err):sub(1, 80))
    else
        local b = TMP .. "/daow"
        local report = wowbuild.convert(maps[1], b, {})
        local text = read(b .. "/server-stamp")
        test("the build holds server-stamp, the report names its files", text ~= nil and report.server_stamp
            and #report.server_stamp.files > 0 and server_stamp.read(b) == text)
        local listed = {}
        for l in (text or ""):gmatch("%x+ %d+ ([^\n]+)") do listed[#listed + 1] = l end
        local reports = 0
        for _, p in ipairs(listed) do
            if p:find("report", 1, true) or p:find("registration", 1, true) or p == "map.lua" then reports = reports + 1 end
        end
        test("it names the server's files and no report", #listed == #report.server_stamp.files and reports == 0
            and table.concat(listed, ","):find("server/world.sql", 1, true) ~= nil, table.concat(listed, ","))
        test("its lines are the files as they are now", server_stamp.text(b) == text)
        local in_files = false
        for _, f in ipairs(report.files) do in_files = in_files or f.path == "server-stamp" end
        test("the report's file list has it", in_files)
        -- converted again: the reports change (when, how long), the stamp doesn't
        local report1 = read(b .. "/conversion-report.lua")
        wowbuild.convert(maps[1], b, {})
        test("converted again: the same stamp, byte for byte", read(b .. "/server-stamp") == text)
        test("(while its report was written anew)", read(b .. "/conversion-report.lua") ~= report1)
        -- a conversion refused before it touches the folder leaves it as it was
        local bad = pcall(wowbuild.convert, maps[1], b, { name = "not a name!" })
        local bad2 = pcall(wowbuild.convert, maps[1], b, { map_id = 1 })
        test("a conversion refused before it began: the folder, and its stamp, as they were",
            not bad and not bad2 and read(b .. "/server-stamp") == text)
    end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))

-- {{{ Summary
print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)
-- }}}
