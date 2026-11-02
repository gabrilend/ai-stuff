#!/usr/bin/env luajit
-- test_fetch.lua - catalogue, check and store maps and models (issue 603)
--
-- In plain terms: nothing is fetched from any public site, since none has
-- been reviewed yet, and nothing goes over the network without --network;
-- a request carries the tool's name and nothing about the person; a folder
-- of maps and models becomes a catalogue that reads back as plain data
-- (and a catalogue can't run code); a map downloads, is stored by its hash
-- and parses; a model in a .zip (stored and deflated entries) reads, and
-- its textures decode; a file that isn't a map, a damaged texture or a
-- hash that doesn't match the one published is refused and not stored.
--
-- Run: luajit src/tests/test_fetch.lua [DIR]
-- Issue: issues/603-fetch-maps-and-models-from-public-sites.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local fetch = require("fetch")
local catalogue = require("fetch.catalogue")
local zip = require("fetch.zip")
local storage = require("assets.storage")
local dedup = require("assets.dedup")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function errors(f, ...)
    local ok, err = pcall(f, ...)
    return not ok, tostring(err)
end
local function write(path, data)
    os.execute("mkdir -p " .. sh(path:match("^(.*)/")))
    local f = assert(io.open(path, "wb")); f:write(data); f:close()
end
local function read(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local d = f:read("*a"); f:close(); return d
end
local function le(n, bytes)
    local out = {}
    for i = 1, bytes do out[i] = string.char(n % 256); n = math.floor(n / 256) end
    return table.concat(out)
end

-- {{{ a .zip writer for the test: stored entries, or deflated by gzip
local function raw_deflate(data)
    local tmp = os.tmpname()
    write(tmp, data)
    local p = io.popen("gzip -n -c " .. sh(tmp) .. " 2>/dev/null")
    local gz = p:read("*a"); p:close()
    os.remove(tmp)
    if #gz < 18 then return nil end
    return gz:sub(11, -9)   -- past the 10-byte header (no name: -n), before CRC and size
end

local function make_zip(files)
    local body, central, offset = {}, {}, 0
    for _, f in ipairs(files) do
        local method, payload = 0, f.data
        if f.deflate then
            local d = raw_deflate(f.data)
            if d then method, payload = 8, d end
        end
        local crc = zip.crc32(f.data)
        local head = "PK\3\4" .. le(20, 2) .. le(0, 2) .. le(method, 2) .. le(0, 4) .. le(crc, 4)
            .. le(#payload, 4) .. le(#f.data, 4) .. le(#f.name, 2) .. le(0, 2) .. f.name
        body[#body + 1] = head .. payload
        central[#central + 1] = "PK\1\2" .. le(20, 2) .. le(20, 2) .. le(0, 2) .. le(method, 2) .. le(0, 4)
            .. le(crc, 4) .. le(#payload, 4) .. le(#f.data, 4) .. le(#f.name, 2) .. le(0, 2) .. le(0, 2)
            .. le(0, 2) .. le(0, 2) .. le(0, 4) .. le(offset, 4) .. f.name
        offset = offset + #head + #payload
    end
    local cd = table.concat(central)
    return table.concat(body) .. cd .. "PK\5\6" .. le(0, 4) .. le(#files, 2) .. le(#files, 2)
        .. le(#cd, 4) .. le(offset, 4) .. le(0, 2)
end
-- }}}

local SCRATCH = os.tmpname()
os.remove(SCRATCH)
local DATA = SCRATCH .. "/player-data"
local S = storage.open(DATA)

-- {{{ The sources, and the network
print("\n=== Sources and the network ===")
local unreviewed = 0
for _, s in ipairs(fetch.SOURCES) do
    if s.access == "unreviewed" and not fetch.may_fetch(s) then unreviewed = unreviewed + 1 end
end
test("every site in the source list starts unreviewed, and may not be fetched", unreviewed == #fetch.SOURCES
    and #fetch.SOURCES >= 1 and fetch.SOURCES[1].name == "hive-workshop")
local ran = {}
local function runner(cmd) ran[#ran + 1] = cmd; return true end
local hive_entry = { kind = "map", title = "x", download_url = "https://www.hiveworkshop.com/x.w3x" }
local bad, msg = errors(fetch.get, hive_entry, { network = true, site = fetch.source("hive-workshop"), run = runner })
test("an unreviewed site is never fetched, even with --network", bad and #ran == 0
    and msg:find("hasn't been reviewed", 1, true), msg)
local by_hand = { name = "t", title = "Hand Site", base = "https://hand.example", access = "visit by hand" }
bad, msg = errors(fetch.get, { download_url = "https://hand.example/m.w3x" }, { network = true, site = by_hand, run = runner })
test("a \"visit by hand\" site is never fetched", bad and #ran == 0 and msg:find("visit it by hand", 1, true), msg)
local allowed = { name = "ok", title = "Reviewed Site", base = "https://ok.example", access = "allowed" }
bad, msg = errors(fetch.get, { download_url = "https://ok.example/m.w3x" }, { site = allowed, run = runner })
test("without --network nothing goes over the network, even from a reviewed site", bad and #ran == 0
    and msg:find("without --network", 1, true), msg)
bad, msg = errors(fetch.get, { download_url = "https://elsewhere.example/m.w3x" }, { network = true, site = allowed, run = runner })
test("an address off the reviewed site is refused", bad and #ran == 0, msg)
bad = errors(fetch.get, { download_url = "http://ok.example/m.w3x" }, { network = true, site = allowed, run = runner })
test("plain http is refused", bad and #ran == 0)
local path = fetch.get({ download_url = "https://ok.example/m.w3x" }, { network = true, site = allowed, run = runner,
                                                                      folder = SCRATCH })
test("a reviewed site with --network: one request", #ran == 1 and path:find("^" .. SCRATCH:gsub("%p", "%%%0")))
local cmd = ran[1] or ""
test("the request names the tool as its user agent", cmd:find("--user-agent 'world-edit-to-execute fetch'", 1, true) ~= nil, cmd)
test("and sends nothing else about the person: no headers, cookies or referrer",
    not cmd:find("%-H ") and not cmd:find("--header", 1, true) and not cmd:find("cookie", 1, true)
    and not cmd:find("--referer", 1, true) and not cmd:find(" %-e ") and not cmd:find(" %-b ")
    and not cmd:find(os.getenv("USER") or "\0", 1, true), cmd)
test("HTTPS only, redirects included", cmd:find("--proto =https --proto-redir =https", 1, true) ~= nil)
-- }}}

-- {{{ Catalogues
print("\n=== Catalogues ===")
local MAP = DIR .. "/assets/Daow4.4.w3x"
local have_map = io.open(MAP, "rb")
if have_map then have_map:close() end
local FOLDER = SCRATCH .. "/downloads"
if have_map then os.execute("cp " .. sh(MAP) .. " " .. sh(FOLDER .. "/") .. " 2>/dev/null || (mkdir -p " .. sh(FOLDER) .. " && cp " .. sh(MAP) .. " " .. sh(FOLDER .. "/") .. ")") end
write(FOLDER .. "/not-a-map.w3x", "this is a text file")
write(FOLDER .. "/readme.txt", "ignored")
local cat = fetch.scan_folder(FOLDER, "my-downloads")
local titles = {}
for _, e in ipairs(cat.entries) do titles[#titles + 1] = e.kind .. ":" .. e.title end
test("a folder becomes a catalogue of its maps and models (not other files)",
    table.concat(titles, ",") == (have_map and "map:Daow4.4,map:not-a-map" or "map:not-a-map"), table.concat(titles, ","))
test("entries point at the files on disk", cat.entries[1].download_url:find("^file:///"))
fetch.save(S, cat)
local back = fetch.load(S, "my-downloads")
test("the catalogue reads back", back and #back.entries == #cat.entries and back.entries[1].title == cat.entries[1].title)
write(DATA .. "/catalogue/evil.lua", 'os.execute("touch ' .. SCRATCH .. '/pwned"); return { source = "evil", entries = {} }')
local evil, emsg = fetch.load(S, "evil")
test("a catalogue can't run code", evil == nil and read(SCRATCH .. "/pwned") == nil, emsg)
bad, msg = errors(catalogue.write, SCRATCH .. "/x.lua", { source = "x", entries = { { kind = "song", title = "t" } } })
test("an entry of an unknown kind isn't written", bad and msg:find("kind", 1, true), msg)
local odd = { source = "odd", entries = { { kind = "model", title = 'quote " and \\ and\nnewline', size_bytes = 3 } } }
catalogue.write(SCRATCH .. "/odd.lua", odd)
test("awkward text survives the round trip", catalogue.read(SCRATCH .. "/odd.lua").entries[1].title == odd.entries[1].title)
-- }}}

-- {{{ Downloading maps
print("\n=== Downloading maps ===")
local not_map = have_map and 2 or 1
bad, msg = errors(fetch.download, S, cat, not_map)
test("a file that isn't a map is refused, naming the file and the reason", bad
    and msg:find("not-a-map.w3x isn't a map", 1, true) and msg:find("MPQ", 1, true), msg)
test("and nothing is stored", S:info("map", "not-a-map") == nil and #S.store:list() == 0)
if have_map then
    local e = fetch.download(S, cat, 1)
    test("a map downloads, stored by its hash", e.hash == dedup.hash_file(MAP) and S.store:exists(e.hash))
    test("its checks are recorded", e.checked.opens and e.checked.map_info)
    test("it is in the player's maps", e.stored_as == "maps/Daow4.4/Daow4.4.w3x"
        and S:info("map", "Daow4.4").total_bytes == #read(MAP))
    local mpq = require("mpq")
    local a = mpq.open(DATA .. "/" .. e.stored_as)
    test("and opens from there", a ~= nil and a:has("war3map.w3i"))
    if a then a:close() end
    fetch.save(S, cat)
    test("the catalogue keeps the hash", fetch.load(S, "my-downloads").entries[1].hash == e.hash)
    local cat2 = fetch.scan_folder(FOLDER, "again")
    cat2.entries[1].published_hash = "sha256:" .. string.rep("0", 64)
    local before = #S.store:list()
    bad, msg = errors(fetch.download, S, cat2, 1)
    test("a file that doesn't match its published hash is refused and not stored", bad
        and msg:find("doesn't match the hash", 1, true) and #S.store:list() == before
        and S:info("map", "Daow4.4").total_bytes > 0, msg)
else
    print("  [SKIP] the test maps aren't here")
end
-- }}}

-- {{{ Models
print("\n=== Models ===")
local mpq_ok, mpq = pcall(require, "mpq")
local archive = have_map and mpq_ok and mpq.open(MAP)
if archive then
    local mdx_bytes = archive:extract("File00000020.mdx")
    local blp = archive:extract("File00000021.blp")
    archive:close()
    local model = require("parsers.mdx").parse(mdx_bytes)
    local names = {}
    for _, t in ipairs(model.textures) do
        if t.replaceable == 0 and t.path ~= "" then names[t.path:lower()] = t.path end
    end
    local files = { { name = "Hero/Hero.mdx", data = mdx_bytes, deflate = true } }
    local first = true
    for _, p in pairs(names) do
        -- some with their folders, some flattened, one deflated
        local name = first and ("Hero/" .. p:gsub("\\", "/")) or p:match("([^\\]+)$")
        files[#files + 1] = { name = name, data = blp, deflate = first }
        first = false
    end
    local z = make_zip(files)
    local zr = zip.open(z)
    test("the zip reader lists the files", #zr.entries == #files)
    test("and reads a deflated file back", zr:read("Hero/Hero.mdx") == mdx_bytes)
    local checked = fetch.check_model(z, "hero.zip", { install_read = function() return nil end })
    local n = 0 for _ in pairs(names) do n = n + 1 end
    test("a zipped model reads, and every texture it names decodes", #checked.models == 1
        and checked.textures_in_download == n and #checked.stock_unverified == 0, tostring(checked.textures_in_download))

    local partial = make_zip({ files[1], files[2] })
    checked = fetch.check_model(partial, "partial.zip", { install_read = function() return nil end })
    test("textures not in the download, with no install: listed as unverified", checked.textures_in_download == 1
        and #checked.stock_unverified == n - 1)
    checked = fetch.check_model(partial, "partial.zip", { install_read = function() return blp end })
    test("with an install that has them: read from it and decoded", checked.textures_from_install == n - 1)
    local broken = {}
    for k, f in ipairs(files) do broken[k] = f end
    broken[2] = { name = files[2].name, data = "BLP1 cut short" }
    bad, msg = errors(fetch.check_model, make_zip(broken), "broken.zip", { install_read = function() return nil end })
    test("a texture in the download that doesn't decode: refused, naming it", bad and msg:find("doesn't decode", 1, true), msg)
    bad, msg = errors(fetch.check_model, make_zip({ { name = "readme.txt", data = "hi" } }), "empty.zip")
    test("a zip with no model: refused", bad and msg:find("holds no .mdx", 1, true), msg)
    local tampered = z:sub(1, 99) .. string.char((z:byte(100) + 1) % 256) .. z:sub(101)   -- inside the deflated model
    bad, msg = errors(function() local t = zip.open(tampered); for _, e in ipairs(t.entries) do t:read(e) end end)
    test("a damaged zip entry fails its check", bad, msg)

    -- the whole download: a model folder with the zip and a bare .mdx
    write(SCRATCH .. "/models/hero.zip", z)
    write(SCRATCH .. "/models/bare.mdx", mdx_bytes)
    local mcat = fetch.scan_folder(SCRATCH .. "/models", "model-folder")
    local zi = mcat.entries[1].title == "bare" and 2 or 1
    local e = fetch.download(S, mcat, zi, { install_read = function() return nil end })
    test("a model downloads into the source's pack, stored once as it came", e.stored_as
        == "asset-packs/fetched-model-folder/hero/hero.zip" and S.store:exists(e.hash)
        and read(DATA .. "/" .. e.stored_as) == z, tostring(e.stored_as))
    local e2 = fetch.download(S, mcat, 3 - zi, { install_read = function() return nil end })
    test("a bare model's textures are all stock: unverified without an install", #e2.checked.stock_unverified == n)
else
    print("  [SKIP] the test maps aren't here")
end
-- }}}

-- {{{ The command line
print("\n=== The command line ===")
local TOOL = "luajit " .. sh(DIR .. "/src/cli/fetch.lua") .. " --dir " .. sh(DIR) .. " --data " .. sh(DATA)
local out = io.popen(TOOL .. " sources 2>&1"):read("*a")
test("sources lists every site and that it isn't reviewed", out:find("hive%-workshop%s+unreviewed") ~= nil, out)
out = io.popen(TOOL .. " scan " .. sh(FOLDER) .. " --as cli-folder 2>&1"):read("*a")
test("scan writes a catalogue", out:find("cli%-folder: %d+ entries") ~= nil, out)
out = io.popen(TOOL .. " list cli-folder 2>&1"):read("*a")
test("list shows it", out:find("not-a-map", 1, true) ~= nil, out)
out = io.popen(TOOL .. " download cli-folder " .. (have_map and 2 or 1) .. " 2>&1; echo \"exit $?\""):read("*a")
test("download of a bad file says why, and fails", out:find("isn't a map", 1, true) and out:find("exit 1", 1, true), out)
-- }}}

os.execute("rm -rf " .. sh(SCRATCH))
print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
