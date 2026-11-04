--[[
Shared Lists Between Two Players (Issue 609a)

The conversation that carries a shared map-and-model list (share/list.lua)
from one player to another, and the one consent step before anything is
kept ("check out my map": a map and its list given to keep). It speaks
through a transport (anything with send(to, message)),
so the mail system that carries it is glue: share/rmail_hook.lua is that
glue for rmail (issue 609b), and a test passes messages by hand.

    sharer                               receiver
    X:offer("ben", l, map)               on_message: read (never run), checked
      -- one message: the list,          consent: trusted? else ask the player
         every file it names, the map -->
                                         on yes: only the files the store
                                         lacks, and the map if not held
                                         the map checked against the list's
                                         hash, every file checked; kept as
                                         one of the player's packs; ready: the
                                         pack's folder, the map at q.map_file

"Check out my map" (issue 609, "A list travels only with its map"): the
map file and every file the list names go with the list, in one message,
and nothing comes back. The receiver takes only what it lacks (over
rmail, by answering each file's consent form), only on yes, and the map
only when its bytes have the hash the list gives; a map or file that
doesn't match refuses the whole list.

    local exchange = require("share.exchange")
    local X = exchange.new({ data = folder, me = "ana", transport = t,
                             pack = folder .. "/asset-packs/mine",  -- the sharer's files
                             consent = function(q) return nil end,  -- default: ask later
                             on_ready = function(pack, q) end })  -- pack: the kept pack's folder
    X:offer("ben", l, "maps/castle.w3x") -- the sharer: the list, its files and its map
    X:on_message(msg)                    -- every message the transport delivers
    X:pending()                          -- questions waiting for the player
    X:answer(id, "yes" | "no")           -- the player's answer to one
    X:wants(id, from, hex)               -- take that file? nil: not answered yet (glue)
    X:wants_map(id, from)                -- take that list's map? nil: not answered yet (glue)
    X:awaiting(id, from)                 -- the names still to come; nil: not answered yet (glue)
    exchange.prompt(q)                   -- the prompt's words, with each entry's provenance

Messages are plain tables:

    { kind = "list",  from = "ana", id = "ana-1", text = list.encode(l),
      map = { name = "<64 hex>.w3x", path = "/where/it/is" },          -- path nil: it comes later
      files = { { name = "<64 hex>", path = "/where/it/is" }, ... } }  -- likewise
    { kind = "files", from = "ana", id = "ana-1", files = { ... }, map = { ... } }  -- the glue: what came

Consent defaults to asking: unless the player said "always from this
player" or "always for this map" (profile.trust), nothing is requested,
stored or kept until they answer yes. A receiver only takes files the
list names, that its store lacks, from the sender of that list.
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
-- (function(pack, question): a list was kept, as the asset pack in folder
-- PACK), on_problem (function(id, what)), name_for (function(question):
-- the kept pack's name; default "share-" and the message id), store
-- (default <data>/blobs).
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
        received = {},       -- id -> { from, list, question, state, map, files, wanted = set }
        count = 0,
        refused = 0,
    }, X)
end
-- }}}

-- {{{ The sharer: offer
-- Sends L to player TO in one message: the list, every file it names
-- (copied from the pack, each named by its hash's hex) and, when given,
-- MAP (the map file L names): "check out my map". Everything is copied
-- first, so a file edited afterwards still arrives as the list names it.
-- The receiver takes only the files it lacks, so nothing comes back.
-- Gives the message's id.
function X:offer(to, l, map)
    list.check(l)
    self.count = self.count + 1
    local id = self.me:gsub("[^%w%-_.]", "") .. "-" .. self.count .. "-" .. os.time()
    id = id:sub(-exchange.MAX_ID)
    local dir = self.data .. "/share-outgoing/" .. id
    local m
    if map ~= nil then
        if hash_of(map) ~= l.map.hash then
            error("exchange: " .. tostring(map) .. " isn't the map the list names (its hash differs)", 2)
        end
        local name = map_name(l.map.hash, map:match("%.([^./]+)$"))
        os.execute("mkdir -p " .. sh(dir))
        m = { name = name, path = dir .. "/" .. name }
        if not copy(map, m.path) or hash_of(m.path) ~= l.map.hash then
            os.execute("rm -rf " .. sh(dir))
            error("exchange: " .. map .. " changed while it was copied", 2)
        end
    end
    local hashes, seen = {}, {}
    for _, e in ipairs(l.entries) do
        if not seen[e.hash] then seen[e.hash] = true; hashes[#hashes + 1] = e.hash end
    end
    local ok, err = pcall(list.bundle, l, self.pack, hashes, dir)
    if not ok then
        os.execute("rm -rf " .. sh(dir))
        error("exchange: " .. tostring(err), 2)
    end
    local files = {}
    for _, h in ipairs(hashes) do files[#files + 1] = { name = hex_of(h), path = dir .. "/" .. hex_of(h) } end
    self.transport.send(to, { kind = "list", from = self.me, id = id, text = list.encode(l), map = m, files = files })
    return id
end

-- The copies written for offer ID, removed once the transport has taken
-- them.
function X:sent(id)
    if good_id(id) then os.execute("rm -rf " .. sh(self.data .. "/share-outgoing/" .. id)) end
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
    -- the files that came with it: the list's own hashes only, never a path
    -- as a name; given without paths, they come later (over rmail)
    local named = {}
    for _, e in ipairs(l.entries) do named[hex_of(e.hash)] = true end
    local files = {}
    for _, f in ipairs(type(msg.files) == "table" and msg.files or {}) do
        if type(f) == "table" and good_hex(f.name) and named[f.name:lower()] and type(f.path) == "string" then
            files[f.name:lower()] = f.path
        end
    end
    local missing = list.missing(l, self.store)
    local q = { id = msg.id, sender = msg.from, list = l, map = l.map, entries = l.entries, missing = #missing,
                map_sent = m ~= nil, map_held = self.store:exists(l.map.hash) }
    local r = { from = msg.from, list = l, question = q, state = "asking", map = m, named = named, files = files }
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

-- The player's answer to question ID: "yes" takes, of the files sent with
-- the list, only those the store lacks, and the map unless the store holds
-- it already, and keeps the list once they are in (at once when nothing
-- is lacking); "no" forgets the list and takes nothing. Nothing is sent
-- back to the sharer either way.
function X:answer(id, yes)
    local r = self.received[id]
    if not r or r.state ~= "asking" then return nil, "no question " .. tostring(id) .. " is waiting" end
    if yes ~= "yes" then
        r.state = "declined"
        return "declined"
    end
    r.wanted = {}
    for _, h in ipairs(list.missing(r.list, self.store)) do r.wanted[hex_of(h)] = true end
    r.need_map = r.map ~= nil and not self.store:exists(r.list.map.hash)
    r.state = "waiting"
    -- in process the files came with the list: take them now
    local all = not r.need_map or r.map.path ~= nil
    for hex in pairs(r.wanted) do if not r.files[hex] then all = false end end
    if not all then return "waiting" end
    local files = {}
    for hex in pairs(r.wanted) do files[#files + 1] = { name = hex, path = r.files[hex] } end
    return self:files({ kind = "files", from = r.from, id = id, files = files, map = r.need_map and r.map or nil })
end
-- }}}

-- {{{ The receiver: the files arrive
-- Whether this side wants HEX, a file sent with list ID by FROM: true
-- after yes for a file the store lacked, false when it never will (not
-- one of the list's files, already held, no, refused, or no such list),
-- and nil while the player hasn't answered. For glue that answers a mail
-- program's consent step for each file; it changes nothing.
function X:wants(id, from, hex)
    local r = self.received[id]
    if not r or r.from ~= from or not good_hex(hex) or not r.named[hex:lower()] then return false end
    if r.state == "asking" then return nil end
    return r.state == "waiting" and r.wanted[hex:lower()] == true
end

-- The same for the map sent with list ID.
function X:wants_map(id, from)
    local r = self.received[id]
    if not r or r.from ~= from or not r.map then return false end
    if r.state == "asking" then return nil end
    return r.state == "waiting" and r.need_map == true
end

-- What this side still waits for on list ID from FROM: the names (each
-- file's hex, and the map's name) it will take, all at once in one files
-- message; an empty list when it takes nothing more (no, refused, kept,
-- or no such list), and nil while the player hasn't answered. For glue
-- that gathers the files as they come; it changes nothing.
function X:awaiting(id, from)
    local r = self.received[id]
    if not r or r.from ~= from then return {} end
    if r.state == "asking" then return nil end
    if r.state ~= "waiting" then return {} end
    local out = {}
    for hex in pairs(r.wanted) do out[#out + 1] = hex end
    table.sort(out)
    if r.need_map then out[#out + 1] = r.map.name end
    return out
end

-- What list ID's files and map came as, once those this side wants are
-- in: msg.files ({ { name = <64 hex>, path } }) and msg.map ({ name, path
-- }). The map is checked first: its bytes must have the hash the list
-- gives. Then every file is checked and the list kept; anything wrong
-- refuses it whole, and nothing is kept.
function X:files(msg)
    local r = self.received[msg.id]
    if not r or r.state ~= "waiting" or r.from ~= msg.from then
        return self:problem(msg.id, "files from " .. tostring(msg.from) .. " that weren't asked for")
    end
    if type(msg.files) ~= "table" then return self:problem(msg.id, "a files message with no files") end
    if r.need_map then
        local m = msg.map
        if type(m) ~= "table" or type(m.path) ~= "string" or type(m.name) ~= "string" or m.name:lower() ~= r.map.name then
            r.state = "failed"
            return self:problem(msg.id, "the map sent with the list didn't come: refused whole")
        end
        if hash_of(m.path) ~= r.list.map.hash then
            r.state = "failed"
            return self:problem(msg.id, "the map sent with the list doesn't match the hash the list gives: refused whole")
        end
        local ok, h = pcall(self.store.store_file, self.store, m.path)
        if not ok or h ~= r.list.map.hash then
            r.state = "failed"
            return self:problem(msg.id, "the map changed while it was stored: refused whole")
        end
        r.need_map = false
    end
    local dir = self.data .. "/share-incoming/" .. msg.id
    os.execute("rm -rf " .. sh(dir) .. " && mkdir -p " .. sh(dir))
    for _, f in ipairs(msg.files) do
        -- only a name this side asked for: a hash's hex, never a path
        if type(f) == "table" and good_hex(f.name) and r.wanted[f.name:lower()] and type(f.path) == "string" then
            copy(f.path, dir .. "/" .. f.name:lower())
        end
    end
    local result, err = self:keep(msg.id, dir)
    os.execute("rm -rf " .. sh(dir))
    return result, err
end

-- Every file checked, then the list kept as one of the player's asset
-- packs (profile.keep); one bad file refuses it whole.
function X:keep(id, bundle)
    local r = self.received[id]
    local ok, pack, problems = pcall(profile.keep, r.list, { data = self.data, store = self.store, bundle = bundle,
                                                            name = self.name_for(r.question) })
    if not ok then r.state = "failed"; return self:problem(id, tostring(pack)) end
    if not pack then
        r.state = "failed"
        local words = {}
        for _, p in ipairs(problems) do words[#words + 1] = p.key .. " " .. p.problem end
        return self:problem(id, "the list was refused whole: " .. table.concat(words, "; "))
    end
    r.state = "ready"
    r.pack = pack
    if r.map then r.question.map_file = self:place_map(r) end
    pcall(self.on_ready, pack, r.question)
    return "ready", pack
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
-- Every message the transport delivers, and the files the glue gathered
-- for a list. Gives what happened ("asking", "waiting", "declined",
-- "ready" (kept)), or nil and why it was refused. Nothing a message says
-- is run.
function X:on_message(msg)
    if type(msg) ~= "table" or not good_id(msg.id) or type(msg.from) ~= "string" or msg.from == "" then
        return self:problem(type(msg) == "table" and msg.id or nil, "not a share message")
    end
    if msg.kind == "list" then return self:list(msg)
    elseif msg.kind == "files" then return self:files(msg)
    end
    return self:problem(msg.id, "an unknown kind of share message: " .. tostring(msg.kind))
end
-- }}}

-- {{{ function exchange.prompt
-- The one prompt's words for question Q (asked when a map and its list
-- are given to keep; the lobby's prompt, for a hosted map, is the W
-- client's, its issue 1110): who, which map, and each entry's
-- provenance (its file, size and where else it can be had). A list of
-- lines; the first is the question.
function exchange.prompt(q)
    local lines = {}
    lines[1] = string.format("Keep %s's models for this map?", q.sender)
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
