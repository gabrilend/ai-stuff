--[[
Fetch: Maps and Models Into the Player's Storage (Issue 603)

Finds maps and models, writes them into a catalogue (fetch/catalogue.lua,
read by the catalogue viewer, 1001), and downloads one when the player
asks: the file is fetched, checked, refused when it fails, and otherwise
stored once by its hash (assets/dedup.lua, 604) in the player's storage
(assets/storage.lua, 605), with the hash and the checks written back to
its entry.

Local files only, unless asked. A source on disk (a folder of maps and
models the player already has) is read freely. Nothing is fetched over
the network unless BOTH hold: the site's entry in fetch/sources.lua is
"allowed" (every site starts "unreviewed": the owner reviews its terms
first), and the player passes network = true (--network on the command
line). A request then carries the tool's name as its user agent and
nothing about the person (CLAUDE.md, Privacy).

    local fetch = require("fetch")
    local cat = fetch.scan_folder("/path/to/downloads", "my-downloads")  -- a catalogue of what's there
    fetch.save(S, cat)                                   -- <player data>/catalogue/my-downloads.lua
    local entry = fetch.download(S, cat, 3)              -- fetch, check, store; raises when refused
    fetch.save(S, cat)                                   -- with the entry's hash and checks

The checks before an item counts as downloaded:
  map     it opens as an MPQ archive and its war3map.w3i parses
  model   every .mdx in it parses, and every texture it names decodes:
          those in the download must; stock ones (not in it) are read from
          the player's install when there is one, and listed as unverified
          when there isn't
  both    when the entry has a published_hash, the file matches it
]]

local catalogue = require("fetch.catalogue")
local dedup = require("assets.dedup")

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."

local fetch = {}

fetch.ROOT = HERE .. "/../.."
fetch.USER_AGENT = "world-edit-to-execute fetch"
fetch.MAX_BYTES = 512 * 1024 * 1024
fetch.SOURCES = dofile(HERE .. "/sources.lua")

local function sh(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- {{{ fetch.source / fetch.may_fetch
function fetch.source(name, sources)
    for _, s in ipairs(sources or fetch.SOURCES) do
        if s.name == name then return s end
    end
    return nil
end

-- Whether a site may be fetched from at all, and why not.
function fetch.may_fetch(site)
    if not site then return false, "it isn't in the source list" end
    if site.access == "allowed" then return true end
    if site.access == "visit by hand" then
        return false, site.title .. "'s terms don't allow automated access: visit it by hand"
    end
    return false, (site.title or site.name) .. " hasn't been reviewed yet (its terms and robots.txt), so nothing is fetched from it"
end
-- }}}

-- {{{ local function kind_of / safe_name
local KIND_BY_EXT = { w3x = "map", w3m = "map", mdx = "model", zip = "model" }

local function kind_of(name)
    local ext = name:lower():match("%.([%w]+)$")
    return ext and KIND_BY_EXT[ext]
end
fetch.kind_of = kind_of

-- A title as one folder name: no slashes or control characters, not . or ..
local function safe_name(s)
    s = tostring(s):gsub("[%c/\\]", "-"):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "." or s == ".." then s = "_" .. s end
    return s
end
fetch.safe_name = safe_name
-- }}}

-- {{{ fetch.scan_folder
-- A catalogue of the maps (.w3x, .w3m) and models (.mdx, .zip) in FOLDER
-- and its subfolders, as source NAME (default: the folder's name).
function fetch.scan_folder(folder, name)
    local real = io.popen("realpath -e " .. sh(folder) .. " 2>/dev/null"):read("*l")
    if not real or real == "" then
        error("fetch: no folder " .. tostring(folder), 2)
    end
    name = name or real:match("([^/]+)$")
    local entries = {}
    local p = io.popen("find -L " .. sh(real) .. " -type f -printf '%s\\t%P\\n' 2>/dev/null")
    local found = {}
    for line in p:lines() do
        local size, rel = line:match("^(%d+)\t(.+)$")
        if rel and kind_of(rel) then found[#found + 1] = { rel = rel, size = tonumber(size) } end
    end
    p:close()
    table.sort(found, function(a, b) return a.rel < b.rel end)
    for _, f in ipairs(found) do
        entries[#entries + 1] = {
            kind = kind_of(f.rel),
            title = f.rel:match("([^/]+)$"):gsub("%.[%w]+$", ""),
            download_url = "file://" .. real .. "/" .. f.rel,
            size_bytes = f.size,
            terms = "the player's own files",
        }
    end
    return { source = name, local_folder = real, entries = entries }
end
-- }}}

-- {{{ fetch.catalogue_path / fetch.save / fetch.load
function fetch.catalogue_path(S, source)
    return S.folder .. "/catalogue/" .. safe_name(source) .. ".lua"
end

function fetch.save(S, cat)
    catalogue.write(fetch.catalogue_path(S, cat.source), cat)
end

function fetch.load(S, source)
    return catalogue.read(fetch.catalogue_path(S, source))
end
-- }}}

-- {{{ fetch.http_command
-- The command that fetches URL into OUT: curl, HTTPS only (redirects too),
-- the tool's name as the user agent, and nothing else about the caller (no
-- cookies, no referrer, no extra headers).
function fetch.http_command(url, out)
    return table.concat({
        "curl", "--fail", "--silent", "--show-error", "--location",
        "--proto", "=https", "--proto-redir", "=https",
        "--max-filesize", tostring(fetch.MAX_BYTES), "--max-time", "600",
        "--user-agent", sh(fetch.USER_AGENT),
        "--output", sh(out), sh(url),
    }, " ")
end
-- }}}

-- {{{ fetch.get
-- The fetched file's path on disk, and whether it is a temporary copy.
-- opts: network (true to allow a network fetch), site (its source list
-- entry), run (runs a shell command; for tests), folder (for temporary
-- files).
function fetch.get(entry, opts)
    opts = opts or {}
    local url = entry.download_url
    if type(url) ~= "string" then error("fetch: the entry has no download_url", 2) end
    local path = url:match("^file://(/.+)$")
    if path then
        local f = io.open(path, "rb")
        if not f then error("fetch: " .. path .. " isn't there any more", 2) end
        f:close()
        return path, false
    end
    if not url:match("^https://") then
        error("fetch: only file:// and https:// addresses are fetched, not " .. url, 2)
    end
    if not opts.network then
        error("fetch: " .. url .. " is on the network; nothing is fetched over the network without --network", 2)
    end
    local ok, why = fetch.may_fetch(opts.site)
    if not ok then error("fetch: " .. why, 2) end
    if not url:find("^" .. opts.site.base:gsub("%p", "%%%0") .. "/") then
        error("fetch: " .. url .. " isn't on " .. opts.site.base, 2)
    end
    local out = (opts.folder or "/tmp") .. "/fetch-" .. string.format("%08x", math.random(0, 0x7fffffff)) .. ".part"
    local run = opts.run or function(cmd) local r = os.execute(cmd); return r == true or r == 0 end
    if not run(fetch.http_command(url, out)) then
        os.remove(out)
        error("fetch: the download of " .. url .. " failed", 2)
    end
    return out, true
end
-- }}}

-- {{{ fetch.check_map
function fetch.check_map(path, name)
    local mpq = require("mpq")
    local archive, err = mpq.open(path)
    if not archive then
        error("fetch: " .. name .. " isn't a map: it doesn't open as an MPQ archive (" .. tostring(err) .. ")", 2)
    end
    local info = archive:has("war3map.w3i") and archive:extract("war3map.w3i")
    archive:close()
    if not info then
        error("fetch: " .. name .. " isn't a map: the archive has no war3map.w3i", 2)
    end
    local ok, w3i = pcall(require("parsers.w3i").parse, info)
    if not ok or not w3i then
        error("fetch: " .. name .. " isn't a map: its war3map.w3i doesn't parse (" .. tostring(w3i) .. ")", 2)
    end
    return { opens = true, map_info = true, map_name = w3i.name, players = w3i.players and #w3i.players or nil }
end
-- }}}

-- {{{ fetch.check_model
-- BYTES is a .mdx, or a .zip holding one or more with their textures.
-- opts.install_read(path): a stock file's bytes from the player's install,
-- or nil (default: through assets.open, when there is an install).
local function decode_texture(path, data)
    if data:sub(1, 4) == "BLP1" then return require("parsers.blp").decode(data) end
    if path:lower():match("%.tga$") then return require("parsers.tga").decode(data) end
    error("not a BLP1 or TGA texture")
end

local function default_install_read(root)
    local A
    return function(path)
        if A == nil then
            A = require("assets").open(nil, { root = root })
            if not A.chain then A = false end
        end
        return A and A:read(path) or nil
    end
end

function fetch.check_model(bytes, name, opts)
    opts = opts or {}
    local install_read = opts.install_read or default_install_read(opts.root or fetch.ROOT)
    local mdx = require("parsers.mdx")
    local models, z = {}, nil
    if bytes:sub(1, 4) == "MDLX" then
        models[1] = { name = name, data = bytes }
    elseif bytes:sub(1, 2) == "PK" then
        local ok, res = pcall(require("fetch.zip").open, bytes)
        if not ok then error("fetch: " .. name .. ": " .. tostring(res), 2) end
        z = res
        for _, e in ipairs(z.entries) do
            if e.name:lower():match("%.mdx$") then
                local rok, data = pcall(z.read, z, e)
                if not rok then error("fetch: " .. name .. ": " .. tostring(data), 2) end
                models[#models + 1] = { name = e.name, data = data }
            end
        end
        if #models == 0 then error("fetch: " .. name .. " holds no .mdx model", 2) end
    else
        error("fetch: " .. name .. " is neither a model (.mdx) nor a .zip", 2)
    end
    -- the zip's files by name alone too, for packers that flatten folders
    local by_base = {}
    if z then
        for _, e in ipairs(z.entries) do
            local base = e.name:lower():match("([^/\\]+)$")
            by_base[base] = by_base[base] == nil and e or false
        end
    end
    local checked = { models = {}, textures_in_download = 0, textures_from_install = 0, stock_unverified = {} }
    local seen = {}
    for _, m in ipairs(models) do
        local ok, parsed = pcall(mdx.parse, m.data)
        if not ok then error("fetch: " .. name .. ": " .. m.name .. " doesn't read as a model: " .. tostring(parsed), 2) end
        checked.models[#checked.models + 1] = m.name
        for _, t in ipairs(parsed.textures or {}) do
            local path = t.path
            if t.replaceable == 0 and path and path ~= "" and not seen[path:lower()] then
                seen[path:lower()] = true
                local e = z and (z:find(path) or by_base[path:lower():match("([^/\\]+)$")] or nil)
                if e then
                    local rok, data = pcall(z.read, z, e)
                    local dok, err = false, data
                    if rok then dok, err = pcall(decode_texture, path, data) end
                    if not (rok and dok) then
                        error("fetch: " .. name .. ": the texture " .. path .. " doesn't decode: " .. tostring(err), 2)
                    end
                    checked.textures_in_download = checked.textures_in_download + 1
                else
                    local data = install_read(path)
                    if data then
                        local dok, err = pcall(decode_texture, path, data)
                        if not dok then
                            error("fetch: " .. name .. ": the stock texture " .. path .. " doesn't decode: " .. tostring(err), 2)
                        end
                        checked.textures_from_install = checked.textures_from_install + 1
                    else
                        checked.stock_unverified[#checked.stock_unverified + 1] = path
                    end
                end
            end
        end
    end
    table.sort(checked.stock_unverified)
    return checked
end
-- }}}

-- {{{ fetch.download
-- Fetches entry I of CAT, checks it, and stores it in the storage S
-- (assets/storage.lua): a map as maps/<title>/<file>, a model as
-- asset-packs/fetched-<source>/<title>/<file>. Writes hash, checked and
-- stored_as into the entry and returns it; raises (storing nothing) when
-- the fetch or a check fails. opts as fetch.get's; opts.site defaults to
-- the source list's entry for the catalogue's source.
function fetch.download(S, cat, i, opts)
    opts = opts or {}
    local entry = cat.entries[i]
    if not entry then error("fetch: " .. cat.source .. " has no entry " .. tostring(i), 2) end
    local get_opts = { network = opts.network, site = opts.site or fetch.source(cat.source, opts.sources),
                       run = opts.run, folder = S.folder }
    local path, temporary = fetch.get(entry, get_opts)
    local file = (entry.download_url:match("([^/?#]+)[?#]?[^/]*$") or "download")
    local ok, result = pcall(function()
        local hash = dedup.hash_file(path)
        if entry.published_hash and entry.published_hash ~= hash then
            error("fetch: " .. file .. " doesn't match the hash its source publishes (" .. entry.published_hash
                .. "); got " .. hash .. ". Not stored.", 0)
        end
        local checked
        if entry.kind == "map" then
            checked = fetch.check_map(path, file)
        else
            local f = assert(io.open(path, "rb"))
            local bytes = f:read("*a")
            f:close()
            checked = fetch.check_model(bytes, file, opts)
        end
        local stored
        if entry.kind == "map" then
            S:put_file("map", safe_name(entry.title), file, path)
            stored = "maps/" .. safe_name(entry.title) .. "/" .. file
        else
            local pack = "fetched-" .. safe_name(cat.source)
            S:put_file("pack", pack, safe_name(entry.title) .. "/" .. file, path)
            stored = "asset-packs/" .. pack .. "/" .. safe_name(entry.title) .. "/" .. file
        end
        return { hash = hash, checked = checked, stored = stored }
    end)
    if temporary then os.remove(path) end
    if not ok then
        -- the checks' messages, without the file-and-line prefixes error() adds
        local msg = tostring(result)
        repeat local before = msg; msg = msg:gsub("^[^%s:]+:%d+: ", "") until msg == before
        error(msg, 0)
    end
    entry.hash = result.hash
    entry.checked = result.checked
    entry.stored_as = result.stored
    entry.downloaded = os.date("!%Y-%m-%d")
    return entry
end
-- }}}

return fetch
