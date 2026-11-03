--[[
Shared List Applied for One Game (Issue 609)

The receiver's side of a shared map-and-model list (share/list.lua): the
files are checked against their hashes, stored once (assets/dedup.lua),
and linked into a profile folder that the loader puts above every pack for
that game (L:push_layer). After the game it is taken off again, unless the
player keeps it as an asset pack of their own.

    local profile = require("share.profile")
    local P, problems = profile.apply(l, { data = folder, bundle = dir, name = "game-1" })
    P:attach(L)              -- the loader serves the list's files first
    P.types                  -- { hfoo = "units/knight/knight.mdx" }: a unit type's model
    P:revert(L)              -- after the game: as it was
    P:keep("Ana's models", L) -- or: an asset pack of the player's own
    profile.leftovers(folder)    -- profiles still applied (a game that ended without saying so)
    profile.open(folder, name)   -- one of them, to revert or keep

    local trust = profile.trust(folder)
    trust:decide("Ana", l)   -- "apply" (always from Ana, or always for this map) or "ask"
    trust:always_from("Ana", true)   trust:always_for_map(l.map.hash, true)

Nothing is applied when any file is missing or doesn't match its hash:
the list is refused whole, and each problem is named.
]]

local dedup = require("assets.dedup")
local list = require("share.list")

local profile = {}

-- {{{ local helpers
local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function check_name(name)
    if type(name) ~= "string" or name == "" or name:find("[/%z\n\r\t]") or name == "." or name == ".." then
        error("profile: not a usable name: " .. string.format("%q", tostring(name)), 3)
    end
end

local function exists(path)
    return os.rename(path, path) ~= nil
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a")
    f:close()
    return t
end

local function write_file(path, text)
    local part = path .. ".part"
    local f = assert(io.open(part, "wb"))
    f:write(text)
    f:close()
    assert(os.rename(part, path))
end
-- }}}

local P = {}
P.__index = P

-- {{{ function profile.verify
-- Every file L needs, checked: in the store already, or in BUNDLE named by
-- its hash's hex and holding exactly those bytes. Gives the list of
-- problems ({hash, key, problem}), empty when all is well.
function profile.verify(l, store, bundle)
    local problems, seen = {}, {}
    for _, e in ipairs(l.entries) do
        if not seen[e.hash] then
            seen[e.hash] = true
            if not store:exists(e.hash) then
                local file = bundle and (bundle .. "/" .. e.hash:sub(#list.PREFIX + 1))
                if not file or not exists(file) then
                    problems[#problems + 1] = { hash = e.hash, key = e.key, problem = "not sent" }
                elseif list.hash_file(file) ~= e.hash then
                    problems[#problems + 1] = { hash = e.hash, key = e.key, problem = "doesn't match its hash" }
                end
            end
        end
    end
    return problems
end
-- }}}

-- {{{ function profile.apply
-- opts: data (the player data folder), store (default its blobs/), bundle
-- (the folder the sent files arrived in), name (this game's profile).
-- Gives the profile; or nil and the problems (nothing is applied then).
function profile.apply(l, opts)
    list.check(l)
    check_name(opts.name)
    local data = opts.data
    local store = opts.store or dedup.open(data .. "/blobs")
    local problems = profile.verify(l, store, opts.bundle)
    if #problems > 0 then return nil, problems end
    local dir = data .. "/profiles/" .. opts.name
    if exists(dir) then error("profile: " .. opts.name .. " is already applied", 2) end
    for _, e in ipairs(l.entries) do
        if not store:exists(e.hash) then
            local hash = store:store_file(opts.bundle .. "/" .. e.hash:sub(#list.PREFIX + 1))
            assert(hash == e.hash, "profile: a sent file changed while it was stored")
        end
    end
    local self = setmetatable({ name = opts.name, dir = dir, data = data, store = store, list = l,
                                types = {}, files = {} }, P)
    for _, e in ipairs(l.entries) do
        local path = list.key_of(e.path or e.key)
        if e.path then self.types[e.key] = path end
        if not self.files[path] then
            store:link(e.hash, dir .. "/" .. path)
            self.files[path] = e.hash
        end
    end
    write_file(data .. "/profiles/" .. opts.name .. ".list.lua", list.encode(l))
    return self
end
-- }}}

-- {{{ function profile.open / profile.leftovers
-- A profile applied earlier and not yet taken off (a game that ended
-- without saying so: the window closed, the program stopped), read back
-- from its saved list so it can be reverted or kept. Gives nil and why
-- when there's no such profile.
function profile.open(data, name, store)
    check_name(name)
    local text = read_file(data .. "/profiles/" .. name .. ".list.lua")
    if not text then return nil, "no profile named " .. name end
    local l, err = list.decode(text)
    if not l then return nil, err end
    local self = setmetatable({ name = name, dir = data .. "/profiles/" .. name, data = data,
                                store = store or dedup.open(data .. "/blobs"), list = l,
                                types = {}, files = {} }, P)
    for _, e in ipairs(l.entries) do
        local path = list.key_of(e.path or e.key)
        if e.path then self.types[e.key] = path end
        self.files[path] = self.files[path] or e.hash
    end
    return self
end

-- The names of the profiles applied and not taken off, sorted.
function profile.leftovers(data)
    local out = {}
    local p = io.popen("ls -1 " .. sh(data .. "/profiles") .. " 2>/dev/null")
    if p then
        for f in p:lines() do
            local name = f:match("^(.+)%.list%.lua$")
            if name then out[#out + 1] = name end
        end
        p:close()
    end
    table.sort(out)
    return out
end
-- }}}

-- {{{ function P:attach / P:revert / P:keep
function P:attach(L)
    return L:push_layer("share:" .. self.name, self.dir)
end

local function remove(self, L)
    if L then L:pop_layer("share:" .. self.name) end
    for path in pairs(self.files) do self.store:release(self.dir .. "/" .. path) end
    -- the folder holds only the links released above, and their folders
    assert(self.dir:find("/profiles/", 1, true))
    os.execute("rm -rf " .. sh(self.dir))
    os.remove(self.data .. "/profiles/" .. self.name .. ".list.lua")
    self.files = {}
end

-- Takes the list off (L: the loader it was attached to) and removes the
-- profile; the stored files go at the next gc unless something else uses
-- them.
function P:revert(L)
    remove(self, L)
end

-- Makes the list an asset pack of the player's own, named NAME, and takes
-- the profile off. Gives the pack's folder.
function P:keep(name, L)
    check_name(name)
    local pack = self.data .. "/asset-packs/" .. name
    if exists(pack) then error("profile: there is already an asset pack named " .. name, 2) end
    for path, hash in pairs(self.files) do self.store:link(hash, pack .. "/" .. path) end
    remove(self, L)
    return pack
end
-- }}}

-- {{{ trust: "always from this player", "always for this map"
local T = {}
T.__index = T

function profile.trust(data)
    local path = data .. "/share-trust.lua"
    local t = { players = {}, maps = {} }
    local text = read_file(path)
    if text then
        local v = list.parse(text)
        if type(v) == "table" then
            if type(v.players) == "table" then t.players = v.players end
            if type(v.maps) == "table" then t.maps = v.maps end
        end
    end
    return setmetatable({ path = path, players = t.players, maps = t.maps }, T)
end

function T:save()
    os.execute("mkdir -p " .. sh(self.path:match("^(.*)/[^/]*$")))
    write_file(self.path, "-- Shared lists applied without asking (issue 609)\n"
        .. list.serialize({ players = self.players, maps = self.maps }))
end

function T:always_from(player, on)
    self.players[player] = on and true or nil
    self:save()
end

function T:always_for_map(hash, on)
    self.maps[hash] = on and true or nil
    self:save()
end

-- "apply" when the player said always for this sender or this map; "ask"
-- otherwise (the one prompt: use SENDER's models for this game?).
function T:decide(sender, l)
    if self.players[sender] or self.maps[l.map.hash] then return "apply" end
    return "ask"
end
-- }}}

return profile
