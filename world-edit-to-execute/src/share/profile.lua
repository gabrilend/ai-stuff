--[[
A Received Shared List, Checked and Kept (Issue 609)

The receiver's side of a shared map-and-model list (share/list.lua), in
the editor: every file is checked against its hash, stored once
(assets/dedup.lua), and kept as one of the player's own asset packs.

    local profile = require("share.profile")
    local problems = profile.verify(l, store, bundle)   -- {} when every file is there and right
    local pack, problems = profile.keep(l, { data = folder, bundle = dir, name = "Ana's models" })
    -- pack: <data>/asset-packs/Ana's models, a pack like any other

    local trust = profile.trust(folder)
    trust:decide("Ana", l)   -- "apply" (always from Ana, or always for this map) or "ask"
    trust:always_from("Ana", true)   trust:always_for_map(l.map.hash, true)

Nothing is kept when any file is missing or doesn't match its hash: the
list is refused whole, and each problem is named.

Using a list for one game (a layer in front of the player's packs, taken
off afterwards) is the W client's, its issue 1110, since the
editor-and-client split of 2026-11-04; it was worked out here first (see
issue 609, "After the editor-and-client split").
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

-- {{{ function profile.keep
-- opts: data (the player data folder), store (default its blobs/), bundle
-- (the folder the sent files arrived in; nil when the store has them
-- all), name (the asset pack to make). Every file is checked first; then
-- each is stored once and linked into <data>/asset-packs/<name>/ under
-- its path. Gives the pack's folder; or nil and the problems (nothing is
-- stored or kept then).
function profile.keep(l, opts)
    list.check(l)
    check_name(opts.name)
    local data = opts.data
    local store = opts.store or dedup.open(data .. "/blobs")
    local problems = profile.verify(l, store, opts.bundle)
    if #problems > 0 then return nil, problems end
    local pack = data .. "/asset-packs/" .. opts.name
    if exists(pack) then error("profile: there is already an asset pack named " .. opts.name, 2) end
    for _, e in ipairs(l.entries) do
        if not store:exists(e.hash) then
            local hash = store:store_file(opts.bundle .. "/" .. e.hash:sub(#list.PREFIX + 1))
            assert(hash == e.hash, "profile: a sent file changed while it was stored")
        end
    end
    local linked = {}
    for _, e in ipairs(l.entries) do
        local path = list.key_of(e.path or e.key)
        if not linked[path] then
            store:link(e.hash, pack .. "/" .. path)
            linked[path] = true
        end
    end
    return pack
end
-- }}}

-- {{{ trust: "always from this player", "always for this map"
-- The remembered answers to the one question asked when a map and its
-- list are given to keep ("check out my map").
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
    write_file(self.path, "-- Shared lists kept without asking (issue 609)\n"
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
-- otherwise (the one question, asked when a map and its list are given
-- to keep: keep SENDER's models for this map?).
function T:decide(sender, l)
    if self.players[sender] or self.maps[l.map.hash] then return "apply" end
    return "ask"
end
-- }}}

return profile
