--[[
Dedup: Each File Stored Once, by Its Hash (Issue 604)

A content-addressed store. A file's name is the SHA-256 of its bytes, so
the same texture fetched for ten maps is kept once, and "do we have it
already?" is one look at one path. Maps and asset folders get symbolic
links into the store, and each link is a reference: a blob nobody links to
any more is removed by gc(), and only when gc() is called.

    <store>/ab/ab3def...      a blob: the file's bytes, named by their hash
    <store>/index             one line per blob: hash, size (makes list() and stats() cheap)
    <store>/references        one line per link made: hash, the link's path from the store
    <store>/pins              hashes gc() must keep, whatever links to them
    <store>/incoming/         half-written blobs; a finished one is renamed into place

The store's folder is <player data>/blobs by default (assets/player_data.lua:
<root>/player-data/blobs, unless <root>/config/player-data.lua moves it).

    local dedup = require("assets.dedup")
    local store = dedup.open(folder)                  -- or dedup.init(folder), then dedup.store(...)
    local hash, new = store:store(bytes)              -- "sha256:ab3def...", true the first time
    store:store_file(path)                            -- the same, read from a file in pieces
    store:exists(hash)  store:path(hash)
    store:link(hash, "maps/x/assets/grass.blp")       -- a relative symbolic link to the blob
    store:release("maps/x/assets/grass.blp")          -- removes that link, and the reference
    store:references(hash)  store:refcount(hash)      -- the links that point at it now
    store:list()  store:stats()  store:gc()  store:verify()
    store:pin(hash)  store:unpin(hash)

A reference counts while its link is in place and still leads to the blob.
Deleting a map's folder therefore drops its references with no call here:
the next stats() or gc() sees the links are gone. Links and the reference
lines both give paths relative to the store, so moving the whole player
data folder (the store and the maps beside it) keeps every reference.

Linux (and other POSIX systems) only: links are made with symlink(2)
through the FFI. One program at a time writes a store; two that store the
same bytes at once are safe (each writes its own incoming file and the
rename is atomic), but their index lines may repeat, which load() folds.
]]

local ffi = require("ffi")

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local SHA_256 = HERE .. "/../../../burner-of-down-things/src/015-sha-256.lua"

for _, decl in ipairs({
    "int mkdir(const char *path, unsigned int mode);",
    "int rmdir(const char *path);",
    "int symlink(const char *target, const char *linkpath);",
    "int unlink(const char *path);",
    "long readlink(const char *path, char *buf, size_t size);",
    "char *realpath(const char *path, char *resolved);",
}) do
    pcall(ffi.cdef, decl)
end
local C = ffi.C

local EEXIST = 17
local PATH_MAX = 4096

local dedup = {}

dedup.PREFIX = "sha256:"
dedup.ROOT = HERE .. "/../.."

-- {{{ local function sha
-- The monorepo's own SHA-256 (burner-of-down-things), loaded on first use,
-- as parsers/png.lua loads the kanji project's inflate.
local sha_256
local function sha()
    if not sha_256 then
        local ok, m = pcall(dofile, SHA_256)
        if not ok then
            error("dedup: the monorepo's SHA-256 isn't at " .. SHA_256 .. " (" .. tostring(m) .. ")")
        end
        sha_256 = m
    end
    return sha_256
end
-- }}}

-- {{{ local function hex_of
-- The 64 hex digits of a "sha256:..." hash; an error (pointing at the
-- caller's caller) for anything else.
local function hex_of(hash)
    if type(hash) ~= "string" then
        error("dedup: a hash is a string like \"sha256:\" and 64 hex digits, got " .. type(hash), 3)
    end
    local hex = hash:match("^sha256:(%x+)$")
    if not hex or #hex ~= 64 or hex:find("%u") then
        error("dedup: not a hash: \"" .. hash .. "\" (wants \"sha256:\" and 64 lower-case hex digits)", 3)
    end
    return hex
end
-- }}}

-- {{{ file system helpers
local function realpath(path)
    local buf = ffi.new("char[?]", PATH_MAX)
    if C.realpath(path, buf) == nil then
        return nil
    end
    return ffi.string(buf)
end

local function readlink(path)
    local buf = ffi.new("char[?]", PATH_MAX)
    local n = C.readlink(path, buf, PATH_MAX)
    if n < 0 then
        return nil, ffi.errno()
    end
    return ffi.string(buf, n)
end

local function mkdir_p(path)
    local built = path:sub(1, 1) == "/" and "" or "."
    for part in path:gmatch("[^/]+") do
        built = built .. "/" .. part
        if C.mkdir(built, 493) ~= 0 and ffi.errno() ~= EEXIST then   -- 493 = 0755
            error("dedup: can't make the folder " .. built .. " (errno " .. ffi.errno() .. ")", 3)
        end
    end
end

local function is_file(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function split(path)
    local dir, name = path:match("^(.*)/([^/]+)$")
    if not dir then
        return ".", path
    end
    return (dir == "" and "/" or dir), name
end

local function expand(path)
    if path:sub(1, 2) == "~/" then
        return (os.getenv("HOME") or "~") .. path:sub(2)
    end
    return path
end

-- The path from the folder FROM to the file TO, both absolute and resolved.
local function relative(from, to)
    local a, b = {}, {}
    for part in from:gmatch("[^/]+") do a[#a + 1] = part end
    for part in to:gmatch("[^/]+") do b[#b + 1] = part end
    local same = 0
    while same < #a and same < #b and a[same + 1] == b[same + 1] do
        same = same + 1
    end
    local out = {}
    for _ = same + 1, #a do out[#out + 1] = ".." end
    for i = same + 1, #b do out[#out + 1] = b[i] end
    return table.concat(out, "/")
end

-- An absolute path with its "." and ".." parts worked out, by text alone
-- (the path need not exist).
local function normalize(path)
    local out = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            out[#out] = nil
        elseif part ~= "." then
            out[#out + 1] = part
        end
    end
    return "/" .. table.concat(out, "/")
end

-- Writes TEXT to PATH by way of a file beside it, so a reader never sees
-- half of it.
local function write_whole(path, text)
    local part = path .. ".part"
    local f = assert(io.open(part, "wb"))
    assert(f:write(text))
    assert(f:close())
    assert(os.rename(part, path))
end

local function append(path, line)
    local f = assert(io.open(path, "ab"))
    assert(f:write(line, "\n"))
    assert(f:close())
end

local function lines_of(path)
    local f = io.open(path, "rb")
    if not f then
        return function() return nil end
    end
    local text = f:read("*a")
    f:close()
    return text:gmatch("([^\n]*)\n")
end
-- }}}

local Store = {}
Store.__index = Store

local seeded = false

-- {{{ function dedup.open
-- Opens the store in FOLDER, making the folder if need be, and reads its
-- index, references and pins.
function dedup.open(folder)
    if type(folder) ~= "string" or folder == "" then
        error("dedup.open: wants the store's folder", 2)
    end
    folder = expand(folder)
    mkdir_p(folder .. "/incoming")
    local s = setmetatable({
        dir = realpath(folder),
        sizes = {},      -- hex -> bytes
        order = {},      -- hexes, oldest first
        refs = {},       -- absolute link path -> hex
        pins = {},       -- hex -> true
    }, Store)
    s:load()
    if not seeded then
        math.randomseed(os.time() + math.floor(os.clock() * 1e6))
        seeded = true
    end
    return s
end
-- }}}

-- {{{ function Store:load
function Store:load()
    self.sizes, self.order, self.refs, self.pins = {}, {}, {}, {}
    for line in lines_of(self.dir .. "/index") do
        local hex, size = line:match("^(%x+)\t(%d+)$")
        if hex and not self.sizes[hex] then
            self.sizes[hex] = tonumber(size)
            self.order[#self.order + 1] = hex
        end
    end
    for line in lines_of(self.dir .. "/references") do
        local hex, dest = line:match("^(%x*)\t(.+)$")
        if dest then
            dest = normalize(self.dir .. "/" .. dest)
            self.refs[dest] = hex ~= "" and hex or nil   -- an empty hash: released
        end
    end
    for line in lines_of(self.dir .. "/pins") do
        if line:match("^%x+$") then
            self.pins[line] = true
        end
    end
end
-- }}}

-- {{{ function Store:path
function Store:path(hash)
    local hex = hex_of(hash)
    return self.dir .. "/" .. hex:sub(1, 2) .. "/" .. hex
end
-- }}}

-- {{{ function Store:exists
-- One open of one path: no list is searched.
function Store:exists(hash)
    return is_file(self:path(hash))
end
-- }}}

-- {{{ local function settle
-- Moves a finished incoming file into place as blob HEX and indexes it.
local function note(self, hex, abs)
    append(self.dir .. "/references", hex .. "\t" .. relative(self.dir, abs))
end

local function settle(self, part, hex, size)
    local shard = self.dir .. "/" .. hex:sub(1, 2)
    mkdir_p(shard)
    local ok, err = os.rename(part, shard .. "/" .. hex)
    if not ok then
        os.remove(part)
        error("dedup: can't move the new blob into place: " .. tostring(err), 3)
    end
    if not self.sizes[hex] then
        self.sizes[hex] = size
        self.order[#self.order + 1] = hex
    end
    append(self.dir .. "/index", hex .. "\t" .. size)
end

local function incoming(self, hex)
    return string.format("%s/incoming/%s.%08x", self.dir, hex, math.random(0, 0x7fffffff))
end
-- }}}

-- {{{ function Store:store
-- Stores BYTES; returns its hash, and true when it wasn't stored before.
function Store:store(bytes)
    if type(bytes) ~= "string" then
        error("dedup: store wants the file's bytes as a string, got " .. type(bytes), 2)
    end
    local hex = sha().of_string(bytes)
    local hash = dedup.PREFIX .. hex
    if self.sizes[hex] and self:exists(hash) then
        return hash, false
    end
    local part = incoming(self, hex)
    local f = assert(io.open(part, "wb"))
    local ok, err = f:write(bytes)
    f:close()
    if not ok then
        os.remove(part)
        error("dedup: can't write the new blob: " .. tostring(err), 2)
    end
    settle(self, part, hex, #bytes)
    return hash, true
end
-- }}}

-- {{{ function Store:store_file
-- Stores the file at PATH, read in pieces (a map can be large). The copy is
-- hashed again before it is kept, so a file changed while it was read is
-- refused rather than filed under the wrong hash.
function Store:store_file(path)
    local src = io.open(path, "rb")
    if not src then
        error("dedup: can't open " .. tostring(path), 2)
    end
    src:close()
    local hex = sha().of_file(path)
    local hash = dedup.PREFIX .. hex
    if self.sizes[hex] and self:exists(hash) then
        return hash, false
    end
    local part = incoming(self, hex)
    src = assert(io.open(path, "rb"))
    local out = assert(io.open(part, "wb"))
    local size = 0
    while true do
        local piece = src:read(65536)
        if not piece then break end
        size = size + #piece
        assert(out:write(piece))
    end
    src:close()
    out:close()
    if sha().of_file(part) ~= hex then
        os.remove(part)
        error("dedup: " .. path .. " changed while it was being stored", 2)
    end
    settle(self, part, hex, size)
    return hash, true
end
-- }}}

-- {{{ local function live
-- True when the link at DEST is in place and leads to blob HEX.
local function live(self, dest, hex)
    if not self.sizes[hex] then
        return false
    end
    local target = realpath(dest)
    return target ~= nil and target == realpath(self.dir .. "/" .. hex:sub(1, 2) .. "/" .. hex)
end
-- }}}

-- {{{ function Store:link
-- Makes DEST a relative symbolic link to the blob, making DEST's folders
-- as needed, and records the reference. A link already there is replaced
-- (or kept, if it already leads to this blob); a real file is never
-- replaced. Returns DEST's absolute path.
function Store:link(hash, dest)
    local hex = hex_of(hash)
    if not self:exists(hash) then
        error("dedup: no blob " .. hash .. " to link to", 2)
    end
    if type(dest) ~= "string" or dest == "" or dest:sub(-1) == "/" then
        error("dedup: link wants the path of the link to make, got " .. tostring(dest), 2)
    end
    local dir, name = split(expand(dest))
    mkdir_p(dir)
    local abs = realpath(dir) .. "/" .. name
    local blob = realpath(self:path(hash))
    local old, errno = readlink(abs)
    if old then
        if realpath(abs) == blob then
            if self.refs[abs] ~= hex then
                self.refs[abs] = hex
                note(self, hex, abs)
            end
            return abs
        end
        C.unlink(abs)
    elseif errno ~= 2 then   -- ENOENT: nothing there, as wanted
        error("dedup: " .. abs .. " is already there and isn't a link; not replacing it", 2)
    end
    if C.symlink(relative(realpath(dir), blob), abs) ~= 0 then
        error("dedup: can't make the link " .. abs .. " (errno " .. ffi.errno() .. ")", 2)
    end
    self.refs[abs] = hex
    note(self, hex, abs)
    return abs
end
-- }}}

-- {{{ function Store:release
-- Removes the link at DEST if it leads into this store, and its reference.
-- True when there was one.
function Store:release(dest)
    local dir, name = split(expand(dest))
    local real = realpath(dir)
    if not real then
        return false
    end
    local abs = real .. "/" .. name
    local hex = self.refs[abs]
    if hex and live(self, abs, hex) then
        C.unlink(abs)
    end
    if hex then
        self.refs[abs] = nil
        note(self, "", abs)
        return true
    end
    return false
end
-- }}}

-- {{{ function Store:references
-- The links that lead to HASH now, sorted.
function Store:references(hash)
    local hex = hex_of(hash)
    local out = {}
    for dest, h in pairs(self.refs) do
        if h == hex and live(self, dest, hex) then
            out[#out + 1] = dest
        end
    end
    table.sort(out)
    return out
end

function Store:refcount(hash)
    return #self:references(hash)
end
-- }}}

-- {{{ local function counts
-- Live references per blob, in one pass over the references.
local function counts(self)
    local n = {}
    for dest, hex in pairs(self.refs) do
        if live(self, dest, hex) then
            n[hex] = (n[hex] or 0) + 1
        end
    end
    return n
end
-- }}}

-- {{{ function Store:list
-- Every stored hash, oldest first, from the index (no folder is walked).
function Store:list()
    local out = {}
    for i, hex in ipairs(self.order) do
        out[i] = dedup.PREFIX .. hex
    end
    return out
end
-- }}}

-- {{{ function Store:stats
-- naive_bytes is what the same links would take as copies: each blob once
-- per link, and once if nothing links to it (it is still on disk).
function Store:stats()
    local n = counts(self)
    local s = { unique_blobs = #self.order, total_references = 0, storage_bytes = 0,
                naive_bytes = 0, savings_percent = 0, pinned = 0 }
    for _, hex in ipairs(self.order) do
        local size, refs = self.sizes[hex], n[hex] or 0
        s.storage_bytes = s.storage_bytes + size
        s.naive_bytes = s.naive_bytes + size * math.max(refs, 1)
        s.total_references = s.total_references + refs
        if self.pins[hex] then s.pinned = s.pinned + 1 end
    end
    if s.naive_bytes > 0 then
        s.savings_percent = math.floor((s.naive_bytes - s.storage_bytes) * 100 / s.naive_bytes + 0.5)
    end
    return s
end
-- }}}

-- {{{ function Store:pin / Store:unpin
local function save_pins(self)
    local hexes = {}
    for hex in pairs(self.pins) do hexes[#hexes + 1] = hex end
    table.sort(hexes)
    write_whole(self.dir .. "/pins", #hexes > 0 and table.concat(hexes, "\n") .. "\n" or "")
end

function Store:pin(hash)
    self.pins[hex_of(hash)] = true
    save_pins(self)
end

function Store:unpin(hash)
    self.pins[hex_of(hash)] = nil
    save_pins(self)
end

function Store:pinned(hash)
    return self.pins[hex_of(hash)] == true
end
-- }}}

-- {{{ function Store:gc
-- Removes every blob that no link leads to and that isn't pinned, forgets
-- references whose links are gone, and rewrites the index and references.
-- Returns how many blobs were removed and the bytes freed.
function Store:gc()
    local n = counts(self)
    local removed, freed, kept = 0, 0, {}
    for _, hex in ipairs(self.order) do
        if (n[hex] or 0) > 0 or self.pins[hex] then
            kept[#kept + 1] = hex
        else
            local shard = self.dir .. "/" .. hex:sub(1, 2)
            os.remove(shard .. "/" .. hex)
            C.rmdir(shard)   -- only succeeds once the shard is empty
            removed, freed = removed + 1, freed + self.sizes[hex]
            self.sizes[hex] = nil
        end
    end
    self.order = kept
    local index, refs = {}, {}
    for _, hex in ipairs(kept) do
        index[#index + 1] = hex .. "\t" .. self.sizes[hex] .. "\n"
    end
    local dests = {}
    for dest, hex in pairs(self.refs) do
        if live(self, dest, hex) then
            dests[#dests + 1] = dest
        else
            self.refs[dest] = nil
        end
    end
    table.sort(dests)
    for _, dest in ipairs(dests) do
        refs[#refs + 1] = self.refs[dest] .. "\t" .. relative(self.dir, dest) .. "\n"
    end
    write_whole(self.dir .. "/index", table.concat(index))
    write_whole(self.dir .. "/references", table.concat(refs))
    return removed, freed
end
-- }}}

-- {{{ function Store:verify
-- Hashes every blob again. Returns a list of problems ({hash, problem});
-- empty when every blob is present and holds the bytes its name says.
function Store:verify()
    local problems = {}
    for _, hex in ipairs(self.order) do
        local hash = dedup.PREFIX .. hex
        local path = self:path(hash)
        if not is_file(path) then
            problems[#problems + 1] = { hash = hash, problem = "missing" }
        elseif sha().of_file(path) ~= hex then
            problems[#problems + 1] = { hash = hash, problem = "its bytes no longer match its hash" }
        end
    end
    return problems
end
-- }}}

-- {{{ the module-level store
-- dedup.init(folder) opens one store that dedup.store(...), dedup.exists(...)
-- and the rest then use, as issue 604 sketches the API. With no folder it
-- opens the player data's (assets/player_data.lua).
function dedup.init(folder)
    if not folder then
        folder = dofile(HERE .. "/player_data.lua").blobs(dedup.ROOT)
    end
    dedup.default = dedup.open(folder)
    return dedup.default
end

for _, name in ipairs({ "store", "store_file", "exists", "path", "link", "release", "references",
                        "refcount", "list", "stats", "pin", "unpin", "pinned", "gc", "verify" }) do
    dedup[name] = function(...)
        if not dedup.default then
            error("dedup." .. name .. ": call dedup.init(folder) first, or use dedup.open(folder)", 2)
        end
        return dedup.default[name](dedup.default, ...)
    end
end
-- }}}

return dedup
