--[[
Storage: What the Player's Maps and Asset Packs Take Up (Issue 605)

The player data folder (assets/player_data.lua) holds the store of blobs
(assets/dedup.lua, issue 604) and, beside it, one folder for each map and
each asset pack the player has, filled with links into the store:

    <player data>/blobs/                  each file once, by its hash
    <player data>/maps/<name>/            a map's files (links into blobs/)
    <player data>/asset-packs/<name>/     an asset pack's files
    <player data>/last-used               when each map or pack was last used

This module says how much each one takes, how much of that is its own
(freed if it is deleted) and how much it shares, deletes one, and collects
what nothing uses any more.

    local storage = require("assets.storage")
    local S = storage.open()                          -- or storage.open(folder)
    S:put("map", "Castle Fight", "war3map.w3e", bytes)  -- store once, link into the map's folder
    S:put_file("pack", "medieval", "units/footman.mdx", path)
    S:touch("map", "Castle Fight")                    -- used now
    S:info("map", "Castle Fight")                     -- sizes: total, unique, shared; files; last used
    S:list("map")  S:list("pack")                     -- the infos of every map / pack, by name
    S:overview()                                      -- the totals, and every map and pack
    S:delete("map", "Castle Fight")                   -- removes its folder; returns the bytes freed (blobs at gc)
    S:gc()                                            -- removes blobs nothing uses: count, bytes
    S:orphans()                                       -- the hashes gc() would remove
    S:edit("pack", "medieval", "units/footman.mdx")   -- its link becomes a private copy to edit
    S:edit("pack", "medieval")                        -- every link in the pack, the same
    S:protect()                                       -- stored files still writable made read-only

Stored files are read-only, since one may be shared by many maps and
packs. edit() is copy-on-write: the file in that one map or pack becomes
its own copy (and counts as its unique bytes from then on); every other
map and pack keeps the stored file.

"Unique" bytes are those of blobs no other map, pack or link uses (and
that aren't pinned): deleting the source and collecting frees exactly
them. "Shared" bytes stay after a delete. A plain file in a source's
folder (not a link) is its own, and counts as unique.

The January design's "servers" are gone (issue 601's note, 2026-09-26:
nothing is server-provided); asset packs take their place, and "last
connected" is "last used".
]]

local dedup = require("assets.dedup")

local storage = {}

storage.KINDS = { map = "maps", pack = "asset-packs" }

-- {{{ local helpers
local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function check_kind(kind)
    if not storage.KINDS[kind] then
        error("storage: a kind is \"map\" or \"pack\", got " .. tostring(kind), 3)
    end
end

-- A name is one folder: not empty, no "/", not "." or "..".
local function check_name(name)
    if type(name) ~= "string" or name == "" or name:find("/", 1, true) or name == "." or name == ".."
        or name:find("\0", 1, true) or name:find("\n", 1, true) or name:find("\t", 1, true) then
        error("storage: not a usable name for a map or pack: " .. string.format("%q", tostring(name)), 3)
    end
end

-- A path inside a source: relative, no "..", no empty parts.
local function check_inner(path)
    if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" then
        error("storage: a file's path inside a map or pack is relative, got " .. tostring(path), 3)
    end
    for part in path:gmatch("[^/]*") do
        if part == ".." then
            error("storage: a file's path can't leave its map or pack: " .. path, 3)
        end
    end
end
-- }}}

local Storage = {}
Storage.__index = Storage

-- {{{ function storage.open
-- The player data FOLDER, by default the one assets/player_data.lua names.
function storage.open(folder)
    if not folder then
        folder = dofile(dedup.ROOT .. "/src/assets/player_data.lua").folder(dedup.ROOT)
    end
    local store = dedup.open(folder .. "/blobs")
    local self = setmetatable({
        folder = store.dir:gsub("/blobs$", ""),
        store = store,
        used = {},
    }, Storage)
    local f = io.open(self.folder .. "/last-used", "rb")
    if f then
        for line in f:read("*a"):gmatch("[^\n]+") do
            local kind, name, when = line:match("^(%a+)\t(.-)\t(%d+)$")
            if kind then self.used[kind .. "\t" .. name] = tonumber(when) end
        end
        f:close()
    end
    return self
end
-- }}}

-- {{{ function Storage:dir
function Storage:dir(kind, name)
    check_kind(kind)
    check_name(name)
    return self.folder .. "/" .. storage.KINDS[kind] .. "/" .. name
end
-- }}}

-- {{{ function Storage:touch
local function save_used(self)
    local keys = {}
    for key in pairs(self.used) do keys[#keys + 1] = key end
    table.sort(keys)
    local lines = {}
    for i, key in ipairs(keys) do lines[i] = key .. "\t" .. self.used[key] .. "\n" end
    local part = self.folder .. "/last-used.part"
    local f = assert(io.open(part, "wb"))
    f:write(table.concat(lines))
    f:close()
    assert(os.rename(part, self.folder .. "/last-used"))
end

-- Records that KIND NAME was used at WHEN (now by default).
function Storage:touch(kind, name, when)
    check_kind(kind)
    check_name(name)
    self.used[kind .. "\t" .. name] = when or os.time()
    save_used(self)
end
-- }}}

-- {{{ function Storage:put / Storage:put_file
-- Stores the bytes once and links them in as PATH inside KIND NAME's folder.
-- Returns the hash. Marks the source used.
function Storage:put(kind, name, path, bytes)
    check_inner(path)
    local dir = self:dir(kind, name)
    local hash = self.store:store(bytes)
    self.store:link(hash, dir .. "/" .. path)
    self:touch(kind, name)
    return hash
end

function Storage:put_file(kind, name, path, file)
    check_inner(path)
    local dir = self:dir(kind, name)
    local hash = self.store:store_file(file)
    self.store:link(hash, dir .. "/" .. path)
    self:touch(kind, name)
    return hash
end
-- }}}

-- {{{ local function walk
-- Every file in DIR: { path (inside DIR), hex (when it is a link to a
-- stored blob) or size (a plain file) }. A link to anything else, or to a
-- blob no longer stored, is listed with neither.
local function walk(self, dir)
    local files = {}
    local p = io.popen("find -P " .. sh(dir) .. " -mindepth 1 \\( -type l -o -type f \\) -printf '%y\\t%s\\t%P\\t%l\\n' 2>/dev/null")
    for line in p:lines() do
        local kind, size, path, target = line:match("^(%a)\t(%d+)\t(.-)\t(.*)$")
        if kind == "f" then
            files[#files + 1] = { path = path, size = tonumber(size) }
        elseif kind == "l" then
            local hex = target:match("(%x+)$")
            if hex and #hex == 64 and self.store.sizes[hex] and self.store:exists("sha256:" .. hex) then
                files[#files + 1] = { path = path, hex = hex }
            else
                files[#files + 1] = { path = path }
            end
        end
    end
    p:close()
    table.sort(files, function(a, b) return a.path < b.path end)
    return files
end
-- }}}

-- {{{ local function measure
-- The sizes of one source, against every blob's live link count (COUNTS).
local function measure(self, kind, name, counts)
    local dir = self:dir(kind, name)
    local files = walk(self, dir)
    local own_links, plain = {}, 0
    for _, f in ipairs(files) do
        if f.hex then
            own_links[f.hex] = (own_links[f.hex] or 0) + 1
        elseif f.size then
            plain = plain + f.size
        end
    end
    local info = {
        kind = kind,
        name = name,
        dir = dir,
        file_count = #files,
        blob_count = 0,
        total_bytes = plain,
        unique_bytes = plain,
        shared_bytes = 0,
        plain_bytes = plain,
        broken_links = 0,
        last_used = self.used[kind .. "\t" .. name],
        blobs = {},
    }
    for _, f in ipairs(files) do
        if not f.hex and not f.size then info.broken_links = info.broken_links + 1 end
    end
    for hex, mine in pairs(own_links) do
        local size = self.store.sizes[hex]
        info.blob_count = info.blob_count + 1
        info.total_bytes = info.total_bytes + size
        info.blobs[hex] = true
        if (counts[hex] or 0) <= mine and not self.store.pins[hex] then
            info.unique_bytes = info.unique_bytes + size
        else
            info.shared_bytes = info.shared_bytes + size
        end
    end
    return info
end
-- }}}

-- {{{ function Storage:names
-- The names of every source of KIND, sorted.
function Storage:names(kind)
    check_kind(kind)
    local out = {}
    local base = self.folder .. "/" .. storage.KINDS[kind]
    local p = io.popen("find -P " .. sh(base) .. " -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' 2>/dev/null")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    table.sort(out)
    return out
end
-- }}}

-- {{{ function Storage:info / Storage:list
-- One source's sizes: { kind, name, dir, file_count, blob_count, total_bytes,
-- unique_bytes, shared_bytes, plain_bytes, broken_links, last_used }, or nil
-- when it has no folder.
function Storage:info(kind, name)
    local dir = self:dir(kind, name)
    if not os.rename(dir, dir) then return nil end   -- no such folder
    return measure(self, kind, name, self.store:refcounts())
end

function Storage:list(kind)
    local counts = self.store:refcounts()
    local out = {}
    for _, name in ipairs(self:names(kind)) do
        out[#out + 1] = measure(self, kind, name, counts)
    end
    return out
end
-- }}}

-- {{{ function Storage:overview
-- The whole folder: { total_bytes (blobs once, plus plain files),
-- naive_bytes (every link as its own copy, plus plain files), savings_bytes,
-- savings_percent, shared_bytes (blobs two or more sources use),
-- orphan_count, orphan_bytes, blob_count, maps, packs }.
function Storage:overview()
    local counts = self.store:refcounts()
    local maps, packs = {}, {}
    for _, name in ipairs(self:names("map")) do maps[#maps + 1] = measure(self, "map", name, counts) end
    for _, name in ipairs(self:names("pack")) do packs[#packs + 1] = measure(self, "pack", name, counts) end
    local st = self.store:stats()
    local plain = 0
    local users = {}
    for _, list in ipairs({ maps, packs }) do
        for _, info in ipairs(list) do
            plain = plain + info.plain_bytes
            for hex in pairs(info.blobs) do users[hex] = (users[hex] or 0) + 1 end
        end
    end
    local shared = 0
    for hex, n in pairs(users) do
        if n > 1 then shared = shared + self.store.sizes[hex] end
    end
    local orphan_bytes, orphans = 0, self.store:orphans()
    for _, hash in ipairs(orphans) do orphan_bytes = orphan_bytes + self.store.sizes[hash:sub(8)] end
    local total, naive = st.storage_bytes + plain, st.naive_bytes + plain
    return {
        total_bytes = total,
        naive_bytes = naive,
        savings_bytes = naive - total,
        savings_percent = naive > 0 and math.floor((naive - total) * 100 / naive + 0.5) or 0,
        shared_bytes = shared,
        blob_count = st.unique_blobs,
        orphan_count = #orphans,
        orphan_bytes = orphan_bytes,
        maps = maps,
        packs = packs,
    }
end
-- }}}

-- {{{ function Storage:delete
-- Removes KIND NAME's folder and its last-used line. Returns the bytes this
-- frees (its unique bytes: its plain files at once, its own blobs at the
-- next gc(), which removes blobs and runs only when called) and its info
-- from before; or nil and a message when there is no such map or pack.
function Storage:delete(kind, name)
    local info = self:info(kind, name)
    if not info then
        return nil, "no " .. kind .. " named " .. name
    end
    local dir = info.dir
    -- dir is <player data>/<maps|asset-packs>/<one checked name>; never
    -- anything above it.
    assert(dir:sub(1, #self.folder + 1) == self.folder .. "/" and not dir:find("/%.%.?/") and not dir:find("/%.%.?$"))
    os.execute("rm -rf " .. sh(dir))
    if self.used[kind .. "\t" .. name] then
        self.used[kind .. "\t" .. name] = nil
        save_used(self)
    end
    return info.unique_bytes, info
end
-- }}}

-- {{{ function Storage:edit
-- Makes files in KIND NAME's folder editable: each link into the store
-- becomes a private copy (dedup's unshare). PATH names one file inside
-- the folder; without it, every link in the folder. Returns the list of
-- files made private (paths inside the folder); or nil and a message.
function Storage:edit(kind, name, path)
    local dir = self:dir(kind, name)
    if not os.rename(dir, dir) then
        return nil, "no " .. kind .. " named " .. name
    end
    local paths = {}
    if path then
        check_inner(path)
        paths[1] = path
    else
        for _, f in ipairs(walk(self, dir)) do
            if f.hex then paths[#paths + 1] = f.path end
        end
    end
    local done = {}
    for _, p in ipairs(paths) do
        local abs, changed = self.store:unshare(dir .. "/" .. p)
        if not abs then
            return nil, changed
        end
        if changed then done[#done + 1] = p end
    end
    return done
end
-- }}}

-- {{{ function Storage:gc / Storage:orphans / Storage:protect
function Storage:gc()
    return self.store:gc()
end

function Storage:orphans()
    return self.store:orphans()
end

function Storage:protect()
    return self.store:protect()
end
-- }}}

-- {{{ function storage.size
-- A byte count as people read it: "512 B", "1.5 KB", "450 MB", "2.3 GB".
function storage.size(n)
    local units = { "B", "KB", "MB", "GB", "TB" }
    local i = 1
    while n >= 1024 and i < #units do
        n = n / 1024
        i = i + 1
    end
    if i == 1 then return string.format("%d B", n) end
    if n >= 100 then return string.format("%d %s", math.floor(n + 0.5), units[i]) end
    return string.format("%.1f %s", n, units[i])
end
-- }}}

return storage
