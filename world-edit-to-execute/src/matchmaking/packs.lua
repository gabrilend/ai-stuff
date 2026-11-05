--[[
packs.lua - which asset packs a mirror holds, and which a player lacks (issue 801f)

In plain terms: a lobby names the asset packs its map needs (an id and a
hash each, in REGISTER_GAME). A matchmaking server can keep common packs
to hand out, so players needn't fetch them from the host. This module
keeps the list of packs in a folder (the mirror's, or a player's own) and
works out, for a lobby, which packs a player is missing and where to
fetch each: the mirror when it holds that very pack, otherwise the host.

The fetching itself is not here. Every asset transfer goes over rmail
(owner, 2026-09-23; issue 609): the mirror is an rmail contact that
answers requests for packs, and the player accepts each transfer through
rmail's consent step. The matchmaking server only tells a player which
of the lobby's packs the mirror holds and the mirror's rmail contact
(the ASSET_PACKS_AVAILABLE message).

A pack here is one file, `<id>.pack`, in a folder; its hash is
"sha256:" and the file's SHA-256 in hex (as `sha256sum` prints it), the
form lobbies already use for map hashes.

- **`packs.registry(dir)`**: the packs in `dir` (every `*.pack` file).
  `:list()` (sorted by id: { id, hash, size, file }), `:get(id)`,
  `:has(id, hash)`, `:add(id, from)` (copies a file in), `:remove(id)`,
  `:reload()` (looks at the folder again).
- **`packs.hash_file(path)`**: "sha256:..." and the size, or nil and why.
- **`packs.available(registry, required)`**: those of a lobby's required
  packs ({ id, hash }) the registry holds, as the server advertises them.
- **`packs.plan(required, have, mirror)`**: for each required pack the
  player lacks (`have`: { [id] = hash }, or a registry), where to fetch it:
  { id, hash, from = "mirror" | "host", size? }. A pack the player holds
  under another hash counts as missing (another version).
]]

local packs = {}

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- {{{ hashing
function packs.hash_file(path)
    local f = io.open(path, "rb")
    if not f then return nil, "no such file: " .. tostring(path) end
    local size = f:seek("end")
    f:close()
    local p = io.popen("sha256sum -b -- " .. quote(path) .. " 2>/dev/null")
    local out = p and p:read("*l") or ""
    if p then p:close() end
    local hex = out:match("^(%x+)")
    if not hex then return nil, "sha256sum could not read " .. path end
    return "sha256:" .. hex:lower(), size
end
-- }}}

-- {{{ the registry
local Registry = {}
Registry.__index = Registry

local function good_id(id)
    return type(id) == "string" and id:match("^[%w][%w%._%-]*$") ~= nil and #id <= 64
end
packs.good_id = good_id

function packs.registry(dir)
    if type(dir) ~= "string" or dir == "" then error("packs: a registry needs a folder", 0) end
    local self = setmetatable({ dir = dir:gsub("/+$", ""), packs = {}, skipped = {} }, Registry)
    self:reload()
    return self
end

-- Looks at the folder again: every `*.pack` file with a good id.
function Registry:reload()
    self.packs, self.skipped = {}, {}
    local p = io.popen("find " .. quote(self.dir) .. " -maxdepth 1 -type f -name '*.pack' 2>/dev/null")
    local names = {}
    for line in p:lines() do names[#names + 1] = line end
    p:close()
    table.sort(names)
    for _, file in ipairs(names) do
        local id = file:match("([^/]+)%.pack$")
        if good_id(id) then
            local hash, size = packs.hash_file(file)
            if hash then self.packs[id] = { id = id, hash = hash, size = size, file = file }
            else self.skipped[#self.skipped + 1] = file .. ": " .. size end
        else
            self.skipped[#self.skipped + 1] = file .. ": not a pack id"
        end
    end
    return self
end

function Registry:list()
    local out = {}
    for _, p in pairs(self.packs) do out[#out + 1] = p end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Registry:get(id) return self.packs[id] end

function Registry:has(id, hash)
    local p = self.packs[id]
    return p ~= nil and (hash == nil or p.hash == hash)
end

-- Copies the file `from` in as pack `id`; returns the pack, or nil and why.
function Registry:add(id, from)
    if not good_id(id) then return nil, "a pack id is letters, digits, '.', '_' and '-', up to 64" end
    local src = io.open(from, "rb")
    if not src then return nil, "no such file: " .. tostring(from) end
    local file = self.dir .. "/" .. id .. ".pack"
    local tmp = file .. ".part"
    local dst = io.open(tmp, "wb")
    if not dst then src:close() return nil, "can't write in " .. self.dir end
    while true do
        local chunk = src:read(1048576)
        if not chunk then break end
        dst:write(chunk)
    end
    src:close()
    dst:close()
    local ok, err = os.rename(tmp, file)
    if not ok then os.remove(tmp) return nil, err end
    local hash, size = packs.hash_file(file)
    if not hash then return nil, size end
    self.packs[id] = { id = id, hash = hash, size = size, file = file }
    return self.packs[id]
end

-- Takes pack `id` off the mirror (its file is deleted); true, or nil and why.
function Registry:remove(id)
    local p = self.packs[id]
    if not p then return nil, "no pack " .. tostring(id) end
    local ok, err = os.remove(p.file)
    if not ok then return nil, err end
    self.packs[id] = nil
    return true
end
-- }}}

-- {{{ for a lobby
local function holds(have, id, hash)
    if type(have) == "table" and have.has then return have:has(id, hash) end
    return have ~= nil and have[id] == hash
end

-- The lobby's packs the registry holds, as { id, hash, size }.
function packs.available(registry, required)
    local out = {}
    for _, r in ipairs(required or {}) do
        local p = registry and registry:get(r.id)
        if p and p.hash == r.hash then out[#out + 1] = { id = p.id, hash = p.hash, size = p.size } end
    end
    return out
end

-- What the player must fetch, and from where. `mirror` is the list the
-- server advertised ({ id, hash, size }), or nil when there is none.
function packs.plan(required, have, mirror)
    local on_mirror = {}
    for _, m in ipairs(mirror or {}) do on_mirror[m.id .. "\0" .. m.hash] = m end
    local out = {}
    for _, r in ipairs(required or {}) do
        if not holds(have, r.id, r.hash) then
            local m = on_mirror[r.id .. "\0" .. r.hash]
            out[#out + 1] = { id = r.id, hash = r.hash, from = m and "mirror" or "host", size = m and m.size }
        end
    end
    return out
end
-- }}}

return packs
