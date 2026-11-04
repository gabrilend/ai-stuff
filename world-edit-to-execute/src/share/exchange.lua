--[[
Shared Lists Between Two Players (Issue 609a)

The conversation that carries a shared map-and-model list (share/list.lua)
from one player to another, and the one consent step before anything is
applied. It speaks through a transport (anything with send(to, message)),
so the mail system that carries it is glue: share/rmail_hook.lua is that
glue for rmail (issue 609b), and a test passes messages by hand.

    sharer                               receiver
    X:offer("ben", l, map)               on_message: read (never run), checked
          -- list, and the map file -->  consent: trusted? else ask the player
                       <-- want --       only the hashes the store lacks
    on_message: only hashes offered
    to ben, copied from the pack -- files -->
                                         the map checked against the list's
                                         hash, every file checked; stored
                                         ready: the map at q.map_file

"Check out my map" (issue 609, "A list travels only with its map"): the
map file goes with its list, in the same message. The receiver takes the
map only on yes, and only when its bytes have the hash the list gives;
a map that doesn't match refuses the whole list.

    local exchange = require("share.exchange")
    local X = exchange.new({ data = folder, me = "ana", transport = t,
                             pack = folder .. "/asset-packs/mine",  -- the sharer's files
                             consent = function(q) return nil end,  -- default: ask later
                             on_ready = function(P, q) end })
    X:offer("ben", l, "maps/castle.w3x") -- the sharer: the list and its map
    X:on_message(msg)                    -- every message the transport delivers
    X:pending()                          -- questions waiting for the player
    X:answer(id, "yes" | "no")           -- the player's answer to one
    X:wants(id, from, hex)               -- waiting for that file from that sender? (glue)
    X:wants_map(id, from)                -- waiting for that list's map? nil: not asked yet (glue)
    exchange.prompt(q)                   -- the prompt's words, with each entry's provenance

Messages are plain tables:

    { kind = "list",  from = "ana", id = "ana-1", text = list.encode(l),
      map = { name = "<64 hex>.w3x", path = "/where/it/is" } }  -- path nil: it comes later
    { kind = "map",   from = "ana", id = "ana-1", map = { name = "<64 hex>.w3x", path = "/where/it/is" } }
    { kind = "want",  from = "ben", id = "ana-1", hashes = { "sha256:...", ... } }
    { kind = "files", from = "ana", id = "ana-1", files = { { name = "<64 hex>", path = "/where/it/is" } } }

Consent defaults to asking: unless the player said "always from this
player" or "always for this map" (profile.trust), nothing is requested,
stored or applied until they answer yes. A sharer only ever sends files
it offered to that same player, and a receiver only takes files it asked
that sender for.
]]

local list = require("share.list")
local profile = require("share.profile")
local dedup = require("assets.dedup")

local exchange = {}

exchange.MAX_ID = 64
exchange.MAX_MAP_NAME = 64   -- the folder a received map is linked into, <data>/maps/<name>/

local X = {}
X.__index = X

-- {{{ local helpers
local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function good_id(id)
    return type(id) == "string" and #id > 0 and #id <= exchange.MAX_ID and id:match("^[%w%-_.]+$") ~= nil
end

local function good_hex(name)
    return type(name) == "string" and #name == 64 and name:match("^%x+$") ~= nil
end

local function hex_of(hash)
    return hash:sub(#list.PREFIX + 1)
end

local function copy(from, to)
    local src = io.open(from, "rb")
    if not src then return false end
    local out = assert(io.open(to, "wb"))
    while true do
        local piece = src:read(65536)
        if not piece then break end
        out:write(piece)
    end
    src:close()
    out:close()
    return true
end

local function hash_of(path)
    local ok, h = pcall(list.hash_file, path)
    return ok and h or nil
end

-- A map file's name as it travels: its hash's hex, then the extension the
-- sharer's file had (so the editor knows a .w3x from a .w3m). Gives the
-- name for HASH, or (given NAME) whether NAME is that.
local function map_name(hash, ext)
    ext = type(ext) == "string" and ext:lower() or nil
    if ext and not (#ext <= 8 and ext:match("^%w+$")) then ext = nil end
    return hex_of(hash) .. (ext and ("." .. ext) or "")
end

local function good_map_name(name, hash)
    if type(name) ~= "string" then return false end
    local hex, ext = name:match("^(%x+)$"), ""
    if not hex then hex, ext = name:match("^(%x+)%.(%w+)$") end
    return hex ~= nil and #hex == 64 and hex:lower() == hex_of(hash) and #ext <= 8
end

-- A map's name as a folder name: letters, digits, spaces and a few marks.
local function folder_of(name, hash)
    local s = (type(name) == "string" and name or ""):gsub("[^%w _%-.,()']", ""):gsub("^[%s.]+", ""):gsub("%s+$", "")
    s = s:sub(1, exchange.MAX_MAP_NAME):gsub("%s+$", "")
    if s == "" then s = "map-" .. hex_of(hash):sub(1, 12) end
    return s
end
-- }}}

-- {{{ function exchange.new
-- opts: data (the player data folder), me (this player's name, for
-- message ids), transport ({ send = function(to, message) }), pack (the
-- folder a sharer's files come from), consent (function(question) giving
-- "yes", "no" or nil for "ask the player later"; default nil), on_ready
-- (function(P, question): a list was applied), on_problem (function(id,
-- what)), name_for (function(question): the profile's name; default the
-- message id), store (default <data>/blobs).
function exchange.new(opts)
    assert(type(opts) == "table" and opts.data, "exchange: needs opts.data")
    assert(opts.transport and type(opts.transport.send) == "function", "exchange: needs a transport with send(to, message)")
    return setmetatable({
        data = opts.data,
        me = opts.me or "me",
        transport = opts.transport,
        pack = opts.pack,
        consent = opts.consent or function() return nil end,
        on_ready = opts.on_ready or function() end,
        on_problem = opts.on_problem or function() end,
        name_for = opts.name_for or function(q) return "share-" .. q.id end,
        store = opts.store or dedup.open(opts.data .. "/blobs"),
        trust = profile.trust(opts.data),
        offered = {},        -- id -> { to, list, hashes = set }
        received = {},       -- id -> { from, list, question, state, wanted = set }
        count = 0,
        refused = 0,
    }, X)
end
-- }}}

-- {{{ The sharer: offer, and answer a want
-- Sends L to player TO, with MAP (the map file L names) when given: "check
-- out my map". The map is copied first, so a map edited afterwards still
-- arrives as the list names it. Gives the message id the answer will carry.
function X:offer(to, l, map)
    list.check(l)
    self.count = self.count + 1
    local id = self.me:gsub("[^%w%-_.]", "") .. "-" .. self.count .. "-" .. os.time()
    id = id:sub(-exchange.MAX_ID)
    local m
    if map ~= nil then
        if hash_of(map) ~= l.map.hash then
            error("exchange: " .. tostring(map) .. " isn't the map the list names (its hash differs)", 2)
        end
        local name = map_name(l.map.hash, map:match("%.([^./]+)$"))
        local dir = self.data .. "/share-outgoing/" .. id .. ".map"
        os.execute("mkdir -p " .. sh(dir))
        m = { name = name, path = dir .. "/" .. name }
        if not copy(map, m.path) or hash_of(m.path) ~= l.map.hash then
            os.execute("rm -rf " .. sh(dir))
            error("exchange: " .. map .. " changed while it was copied", 2)
        end
    end
    local hashes = {}
    for _, e in ipairs(l.entries) do hashes[e.hash] = true end
    self.offered[id] = { to = to, list = l, hashes = hashes, pack = self.pack }
    self.transport.send(to, { kind = "list", from = self.me, id = id, text = list.encode(l), map = m })
    return id
end

function X:want(msg)
    local o = self.offered[msg.id]
    if not o or o.to ~= msg.from then
        return self:problem(msg.id, "a request for files from " .. tostring(msg.from) .. " that wasn't offered them")
    end
    if type(msg.hashes) ~= "table" then return self:problem(msg.id, "a request with no hashes") end
    local wanted, seen = {}, {}
    for _, h in ipairs(msg.hashes) do
        if type(h) ~= "string" or not o.hashes[h] then
            return self:problem(msg.id, "a request for a file that isn't in the list: " .. tostring(h))
        end
        if not seen[h] then seen[h] = true; wanted[#wanted + 1] = h end
    end
    local dir = self.data .. "/share-outgoing/" .. msg.id
    local ok, err = pcall(list.bundle, o.list, o.pack, wanted, dir)
    if not ok then return self:problem(msg.id, tostring(err)) end
    local files = {}
    for _, h in ipairs(wanted) do files[#files + 1] = { name = hex_of(h), path = dir .. "/" .. hex_of(h) } end
    self.transport.send(msg.from, { kind = "files", from = self.me, id = msg.id, files = files })
    return true
end

-- The bundle written for a want, removed once the transport has taken it;
-- with WHAT "map", the copy of the map sent with the list.
function X:sent(id, what)
    if good_id(id) then
        os.execute("rm -rf " .. sh(self.data .. "/share-outgoing/" .. id .. (what == "map" and ".map" or "")))
    end
end
-- }}}

-- {{{ The receiver: a list arrives
function X:problem(id, what)
    self.refused = self.refused + 1
    pcall(self.on_problem, id, what)
    return nil, what
end

function X:list(msg)
    if self.received[msg.id] then return self:problem(msg.id, "a list with an id already seen") end
    local l, err = list.decode(msg.text)
    if not l then return self:problem(msg.id, err) end
    local m
    if msg.map ~= nil then
        if type(msg.map) ~= "table" or not good_map_name(msg.map.name, l.map.hash)
            or (msg.map.path ~= nil and type(msg.map.path) ~= "string") then
            return self:problem(msg.id, "a map sent with the list under a name that isn't the list's map: refused whole")
        end
        m = { name = msg.map.name:lower(), path = msg.map.path }
    end
    local missing = list.missing(l, self.store)
    local q = { id = msg.id, sender = msg.from, list = l, map = l.map, entries = l.entries, missing = #missing,
                map_sent = m ~= nil, map_held = self.store:exists(l.map.hash) }
    local r = { from = msg.from, list = l, question = q, state = "asking", map = m }
    self.received[msg.id] = r
    local answer
    if self.trust:decide(msg.from, l) == "apply" then
        q.trusted = true
        answer = "yes"
    else
        local ok, a = pcall(self.consent, q)
        answer = ok and a or nil
    end
    if answer == "yes" or answer == "no" then return self:answer(msg.id, answer) end
    return "asking"
end

-- Questions waiting for the player, oldest first.
function X:pending()
    local out = {}
    for _, r in pairs(self.received) do
        if r.state == "asking" then out[#out + 1] = r.question end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- The player's answer to question ID: "yes" asks the sender for only the
-- files the store lacks (or applies at once when it has them all), and
-- takes the map sent with the list unless the store holds it already;
-- "no" forgets the list and sends nothing.
function X:answer(id, yes)
    local r = self.received[id]
    if not r or r.state ~= "asking" then return nil, "no question " .. tostring(id) .. " is waiting" end
    if yes ~= "yes" then
        r.state = "declined"
        return "declined"
    end
    local missing = list.missing(r.list, self.store)
    r.need_map = r.map ~= nil and not self.store:exists(r.list.map.hash)
    r.wanted = {}
    for _, h in ipairs(missing) do r.wanted[hex_of(h)] = true end
    r.state = "waiting"
    r.models_in = #missing == 0
    if #missing > 0 then
        self.transport.send(r.from, { kind = "want", from = self.me, id = id, hashes = missing })
    end
    if r.need_map and r.map.path then
        return self:take_map(id, r.map.path)     -- it came with the list (in process)
    end
    if not r.need_map and r.models_in then return self:apply(id, nil) end
    return "waiting"
end
-- }}}

-- {{{ The receiver: the files arrive
-- Whether this side is waiting for files on ID from FROM, and (given HEX,
-- a file's name) whether that file is one it asked for. For glue that has
-- to answer a mail program's consent step before the files message is
-- whole (share/rmail_hook.lua); it changes nothing.
function X:wants(id, from, hex)
    local r = self.received[id]
    if not r or r.state ~= "waiting" or r.from ~= from then return false end
    if hex == nil then return not r.models_in end
    return not r.models_in and good_hex(hex) and r.wanted[hex:lower()] == true
end

-- Whether this side wants the map sent with list ID by FROM: true after
-- yes while it hasn't come, false when it never will (no, refused, already
-- held, already come, or no such list), and nil while the player hasn't
-- answered. For glue that answers a consent step for the map; changes
-- nothing.
function X:wants_map(id, from)
    local r = self.received[id]
    if not r or r.from ~= from or not r.map then return false end
    if r.state == "asking" then return nil end
    return r.state == "waiting" and r.need_map == true
end

-- The map sent with list ID, at PATH: its bytes must have the hash the
-- list gives, or the whole list is refused. Then it is stored, and the
-- list is applied once its files are in too.
function X:take_map(id, path)
    local r = self.received[id]
    local function refuse(why)
        r.state = "failed"
        if r.bundle then os.execute("rm -rf " .. sh(r.bundle)); r.bundle = nil end
        return self:problem(id, why)
    end
    if hash_of(path) ~= r.list.map.hash then
        return refuse("the map sent with the list doesn't match the hash the list gives: refused whole")
    end
    local ok, h = pcall(self.store.store_file, self.store, path)
    if not ok or h ~= r.list.map.hash then return refuse("the map changed while it was stored: refused whole") end
    r.need_map = false
    if r.models_in then
        local bundle = r.bundle
        r.bundle = nil
        local result, P = self:apply(id, bundle)
        if bundle then os.execute("rm -rf " .. sh(bundle)) end
        return result, P
    end
    return "waiting"
end

function X:got_map(msg)
    local r = self.received[msg.id]
    if not r or r.state ~= "waiting" or r.from ~= msg.from or not r.need_map then
        return self:problem(msg.id, "a map from " .. tostring(msg.from) .. " that wasn't asked for")
    end
    if type(msg.map) ~= "table" or type(msg.map.path) ~= "string" or type(msg.map.name) ~= "string"
        or msg.map.name:lower() ~= r.map.name then
        return self:problem(msg.id, "a map that isn't the one sent with the list")
    end
    return self:take_map(msg.id, msg.map.path)
end

function X:files(msg)
    local r = self.received[msg.id]
    if not r or r.state ~= "waiting" or r.from ~= msg.from or r.models_in then
        return self:problem(msg.id, "files from " .. tostring(msg.from) .. " that weren't asked for")
    end
    if type(msg.files) ~= "table" then return self:problem(msg.id, "a files message with no files") end
    local dir = self.data .. "/share-incoming/" .. msg.id
    os.execute("rm -rf " .. sh(dir) .. " && mkdir -p " .. sh(dir))
    for _, f in ipairs(msg.files) do
        -- only a name this side asked for: a hash's hex, never a path
        if type(f) == "table" and good_hex(f.name) and r.wanted[f.name:lower()] and type(f.path) == "string" then
            copy(f.path, dir .. "/" .. f.name:lower())
        end
    end
    r.models_in = true
    if r.need_map then
        r.bundle = dir        -- checked when the map has come too
        return "waiting"
    end
    local result, err = self:apply(msg.id, dir)
    os.execute("rm -rf " .. sh(dir))
    return result, err
end

function X:apply(id, bundle)
    local r = self.received[id]
    local ok, P, problems = pcall(profile.apply, r.list, { data = self.data, store = self.store, bundle = bundle,
                                                          name = self.name_for(r.question) })
    if not ok then r.state = "failed"; return self:problem(id, tostring(P)) end
    if not P then
        r.state = "failed"
        local words = {}
        for _, p in ipairs(problems) do words[#words + 1] = p.key .. " " .. p.problem end
        return self:problem(id, "the list was refused whole: " .. table.concat(words, "; "))
    end
    r.state = "ready"
    r.profile = P
    if r.map then r.question.map_file = self:place_map(r) end
    pcall(self.on_ready, P, r.question)
    return "ready", P
end

-- Where the map of received list R is kept: a link to it already in the player data
-- folder, or a new one at <data>/maps/<map's name>/<map's name>.<ext>
-- (the folder made unique with " 2", " 3" ... rather than replace
-- another map of that name). Gives the path.
function X:place_map(r)
    local l = r.list
    local refs = self.store:references(l.map.hash)
    if #refs > 0 then return refs[1] end
    local ext = r.map.name:match("%.(%w+)$")
    local base = folder_of(l.map.name, l.map.hash)
    local n = 1
    while true do
        local folder = base .. (n > 1 and (" " .. n) or "")
        local dir = self.data .. "/maps/" .. folder
        if os.rename(dir, dir) == nil then
            return self.store:link(l.map.hash, dir .. "/" .. folder .. (ext and ("." .. ext) or ""))
        end
        n = n + 1
    end
end
-- }}}

-- {{{ function X:on_message
-- Every message the transport delivers. Gives what happened ("asking",
-- "waiting", "declined", "ready", true for files sent), or nil and why it
-- was refused. Nothing a message says is run.
function X:on_message(msg)
    if type(msg) ~= "table" or not good_id(msg.id) or type(msg.from) ~= "string" or msg.from == "" then
        return self:problem(type(msg) == "table" and msg.id or nil, "not a share message")
    end
    if msg.kind == "list" then return self:list(msg)
    elseif msg.kind == "want" then return self:want(msg)
    elseif msg.kind == "files" then return self:files(msg)
    elseif msg.kind == "map" then return self:got_map(msg)
    end
    return self:problem(msg.id, "an unknown kind of share message: " .. tostring(msg.kind))
end
-- }}}

-- {{{ function exchange.prompt
-- The one prompt's words for question Q: who, which map, and each entry's
-- provenance (its file, size and where else it can be had). A list of
-- lines; the first is the question.
function exchange.prompt(q)
    local lines = {}
    lines[1] = string.format("Use %s's models for this game?", q.sender)
    lines[2] = string.format("Map: %s (%s)", q.map.name or "unnamed", q.map.hash:sub(1, 19))
    lines[3] = string.format("%d files, %d to fetch from %s:", #q.entries, q.missing, q.sender)
    for _, e in ipairs(q.entries) do
        local what = e.path and (e.key .. " uses " .. e.path) or e.key
        local where = (type(e.sources) == "table" and #e.sources > 0) and ("also at " .. table.concat(e.sources, ", "))
            or ("only from " .. q.sender)
        lines[#lines + 1] = string.format("  %s, %d bytes, %s", what, e.size or 0, where)
    end
    return lines
end
-- }}}

return exchange
