--[[
protocol.lua - the matchmaking messages, as bytes (issue 801a)

What this is: every message a host, a joining player and the matchmaking
server send each other before a game starts (issue 801): registering a
game, listing games, joining and leaving a lobby, lobby chat, the
endpoints for NAT punching, starting, and a keepalive. One way each
becomes bytes and back. The game itself never goes through here: once it
starts, its traffic goes straight to the host (net/messages.lua).

The wire (issue 801a), in network byte order:
  [2 bytes] magic 0x5743, "WC"
  [2 bytes] the message's type (protocol.TYPES)
  [4 bytes] the payload's length, at most protocol.MAX_PAYLOAD
  [payload] a MessagePack map of the message's fields, plus `v`, the
            protocol's version (protocol.VERSION)

Each message's fields are described once, as data (protocol.FIELDS): a
name and a kind -- "uint" (a whole number 0 to 2^32-1), "str" (at most
protocol.MAX_TEXT bytes), "bool", or a list of records described the same
way -- and whether it may be left out. Adding a message is adding a
description; the one encoder and decoder walk them all.

Versions: the version rides in every message, so a peer can say which it
speaks. A message of another version is refused naming both. Within a
version, a field the reader doesn't know is dropped on decoding, so a
later version may add optional fields without breaking an older reader;
encoding refuses a field the description lacks, so a misspelt field is
caught where it is written.

Refusals, never guesses: encode and decode raise an error naming the
message and field: a missing field, the wrong kind, a number out of range
or not whole, text too long, an unknown message, a wrong magic, a length
past the limit, bytes cut short or left over.
]]

local msgpack = require("matchmaking.msgpack")

local protocol = {}

protocol.MAGIC = 0x5743
protocol.VERSION = 1
protocol.HEADER = 8
protocol.MAX_PAYLOAD = 1048576          -- a thousand lobbies' list fits many times over
protocol.MAX_TEXT = 1024                -- bytes in any one text field
protocol.MAX_LIST = 4096                -- records in any one list

-- {{{ protocol.TYPES
protocol.TYPES = {
    REGISTER_GAME   = 0x01,   -- host -> server: open a lobby
    UNREGISTER_GAME = 0x02,   -- host -> server: close it
    UPDATE_GAME     = 0x03,   -- host -> server: its lobby's state
    LIST_GAMES      = 0x04,   -- client -> server: which games, filtered
    GAME_LIST       = 0x05,   -- server -> client: the games
    JOIN_GAME       = 0x06,   -- client -> server: join a lobby
    JOIN_ACK        = 0x07,   -- server -> client: joined, and who is there
    JOIN_REJECT     = 0x08,   -- server -> client: not joined, and why
    LEAVE_GAME      = 0x09,   -- client -> server: leave a lobby
    LOBBY_UPDATE    = 0x0A,   -- server -> all in a lobby: who joined, left, is ready
    START_GAME      = 0x0B,   -- host -> server: begin
    GAME_START      = 0x0C,   -- server -> all in a lobby: beginning, and where the host is
    NAT_PUNCH       = 0x0D,   -- server <-> all: a player's outside endpoint
    CHAT_MSG        = 0x0E,   -- client <-> all in a lobby: a line of chat
    PING            = 0x0F,   -- client <-> server: are you there
    PONG            = 0x10,   -- server <-> client: yes
    ASSET_PACKS_AVAILABLE = 0x11, -- server -> a member: the lobby's packs its mirror holds (801f)
}
protocol.NAMES = {}
for name, id in pairs(protocol.TYPES) do protocol.NAMES[id] = name end
-- }}}

-- {{{ protocol.FIELDS
-- A field: { name, kind, optional }. A list's kind is { list = fields }.
local pack = { { "id", "str" }, { "hash", "str" } }
local player = { { "player_id", "uint" }, { "name", "str" }, { "ready", "bool" } }
local game = {
    { "game_id", "uint" }, { "map_name", "str" }, { "map_hash", "str" },
    { "asset_packs", { list = pack } }, { "game_mode", "str" }, { "region", "str" },
    { "players", "uint" }, { "max_players", "uint" },
}

protocol.FIELDS = {
    REGISTER_GAME = {
        { "map_name", "str" }, { "map_hash", "str" }, { "asset_packs", { list = pack } },
        { "max_players", "uint" }, { "game_mode", "str" }, { "region", "str" },
        { "host_port", "uint" },                                   -- where the game itself will listen
        { "host_name", "str", true },                              -- the host's name in its lobby (801b)
    },
    UNREGISTER_GAME = { { "game_id", "uint" } },
    UPDATE_GAME = { { "game_id", "uint" }, { "players", "uint" }, { "max_players", "uint" } },
    LIST_GAMES = {
        { "map_name", "str", true }, { "game_mode", "str", true }, { "region", "str", true },
        { "max_latency_ms", "uint", true }, { "free_slots", "uint", true },
    },
    GAME_LIST = { { "games", { list = game } } },
    JOIN_GAME = { { "game_id", "uint" }, { "player_name", "str" } },
    JOIN_ACK = { { "game_id", "uint" }, { "player_id", "uint" }, { "players", { list = player } } },
    JOIN_REJECT = { { "game_id", "uint" }, { "reason", "str" } },
    LEAVE_GAME = { { "game_id", "uint" }, { "player_id", "uint", true } },   -- from the host, with a player: a kick (801e)
    LOBBY_UPDATE = {
        { "game_id", "uint" }, { "event", "str" },                -- "join", "leave", "ready", "unready",
        { "player_id", "uint" }, { "players", { list = player } },  -- and (801e) "kick", "countdown", "cancel"
        { "seconds", "uint", true },                               -- with "countdown": how long until the start
    },
    START_GAME = { { "game_id", "uint" } },
    GAME_START = { { "game_id", "uint" }, { "host_ip", "str" }, { "host_port", "uint" } },
    NAT_PUNCH = { { "game_id", "uint" }, { "player_id", "uint" }, { "ip", "str" }, { "port", "uint" } },
    CHAT_MSG = { { "game_id", "uint" }, { "player_id", "uint" }, { "text", "str" } },
    PING = { { "nonce", "uint" } },
    PONG = { { "nonce", "uint" } },
    ASSET_PACKS_AVAILABLE = {
        { "game_id", "uint" },
        { "contact", "str" },                                      -- the mirror's rmail contact
        { "packs", { list = { { "id", "str" }, { "hash", "str" }, { "size", "uint" } } } },
    },
}
-- }}}

-- {{{ checking a value against its description
local function check_value(where, kind, v, encoding)
    if type(kind) == "table" then
        if type(v) ~= "table" then error(where .. ": should be a list, is a " .. type(v), 0) end
        local n = #v
        for k in pairs(v) do
            if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
                error(where .. ": should be a list, has the key " .. tostring(k), 0)
            end
        end
        if n > protocol.MAX_LIST then error(where .. ": " .. n .. " records, over " .. protocol.MAX_LIST, 0) end
        local out = {}
        for i = 1, n do
            if type(v[i]) ~= "table" then error(where .. "[" .. i .. "]: should be a record, is a " .. type(v[i]), 0) end
            out[i] = protocol.check_record(where .. "[" .. i .. "]", kind.list, v[i], encoding)
        end
        return out
    elseif kind == "uint" then
        if type(v) ~= "number" then error(where .. ": should be a whole number, is a " .. type(v), 0) end
        if v ~= math.floor(v) or v < 0 or v > 0xffffffff then
            error(where .. ": " .. tostring(v) .. " is not a whole number from 0 to 4294967295", 0)
        end
    elseif kind == "str" then
        if type(v) ~= "string" then error(where .. ": should be text, is a " .. type(v), 0) end
        if #v > protocol.MAX_TEXT then error(where .. ": " .. #v .. " bytes of text, over " .. protocol.MAX_TEXT, 0) end
    elseif kind == "bool" then
        if type(v) ~= "boolean" then error(where .. ": should be true or false, is a " .. type(v), 0) end
    end
    return v
end

-- {{{ protocol.check_record
-- A copy of `record` holding the described fields; raises naming `where`
-- and the field. Encoding refuses fields the description lacks; decoding
-- drops them.
function protocol.check_record(where, fields, record, encoding)
    local out, known = {}, {}
    for _, f in ipairs(fields) do
        local name, kind, optional = f[1], f[2], f[3]
        known[name] = true
        local v = record[name]
        if v == nil then
            if not optional then error(where .. "." .. name .. ": missing", 0) end
        else
            out[name] = check_value(where .. "." .. name, kind, v, encoding)
        end
    end
    if encoding then
        for k in pairs(record) do
            if not known[k] then error(where .. ": " .. tostring(k) .. " is not one of its fields", 0) end
        end
    end
    return out
end
-- }}}
-- }}}

-- {{{ the header
local function u16(n) return string.char(math.floor(n / 256), n % 256) end
local function u32(n) return string.char(math.floor(n / 16777216), math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
local function read_u16(s, at) return s:byte(at) * 256 + s:byte(at + 1) end
local function read_u32(s, at) return ((s:byte(at) * 256 + s:byte(at + 1)) * 256 + s:byte(at + 2)) * 256 + s:byte(at + 3) end
-- }}}

-- {{{ protocol.encode
-- The bytes of one message: header and payload.
function protocol.encode(name, message)
    local fields = protocol.FIELDS[name]
    if not fields then error("matchmaking: " .. tostring(name) .. " is not a message", 0) end
    if type(message) ~= "table" then error(name .. ": the message should be a table, is a " .. type(message), 0) end
    local m = {}
    for k, v in pairs(message) do m[k] = v end
    if m.v ~= nil and m.v ~= protocol.VERSION then
        error(name .. ".v: version " .. tostring(m.v) .. ", this is version " .. protocol.VERSION, 0)
    end
    m.v = nil
    local payload = protocol.check_record(name, fields, m, true)
    payload.v = protocol.VERSION
    local body = msgpack.encode(payload)
    if #body > protocol.MAX_PAYLOAD then
        error(name .. ": " .. #body .. " bytes of payload, over " .. protocol.MAX_PAYLOAD, 0)
    end
    return u16(protocol.MAGIC) .. u16(protocol.TYPES[name]) .. u32(#body) .. body
end
-- }}}

-- {{{ protocol.frame_length
-- How many bytes the message starting `bytes` takes, once its header is
-- there: nil while fewer than 8 bytes have come. Raises on a wrong magic,
-- an unknown type or a length past the limit, so a stream that has gone
-- wrong is dropped at its header, before its payload is waited for.
function protocol.frame_length(bytes)
    if #bytes < protocol.HEADER then return nil end
    local magic = read_u16(bytes, 1)
    if magic ~= protocol.MAGIC then
        error(string.format("matchmaking: the magic is 0x%04x, not 0x%04x (\"WC\")", magic, protocol.MAGIC), 0)
    end
    local id = read_u16(bytes, 3)
    if not protocol.NAMES[id] then error(string.format("matchmaking: 0x%02x is not a message type", id), 0) end
    local len = read_u32(bytes, 5)
    if len > protocol.MAX_PAYLOAD then
        error(protocol.NAMES[id] .. ": " .. len .. " bytes of payload, over " .. protocol.MAX_PAYLOAD, 0)
    end
    return protocol.HEADER + len
end
-- }}}

-- {{{ protocol.decode
-- One whole message from `bytes`: its name and fields (`v` among them).
-- Bytes past its length are refused; read_frame takes one message off a stream.
function protocol.decode(bytes)
    local total = protocol.frame_length(bytes)
    if not total then error("matchmaking: " .. #bytes .. " bytes, shorter than a header", 0) end
    local name = protocol.NAMES[read_u16(bytes, 3)]
    if #bytes < total then error(name .. ": cut short, " .. (total - #bytes) .. " bytes missing", 0) end
    if #bytes > total then error(name .. ": " .. (#bytes - total) .. " bytes left over", 0) end
    local ok, payload = pcall(msgpack.decode, bytes:sub(protocol.HEADER + 1))
    if not ok then error(name .. ": " .. payload, 0) end
    if type(payload) ~= "table" then error(name .. ": the payload should be a map, is a " .. type(payload), 0) end
    if payload.v ~= protocol.VERSION then
        error(name .. ".v: version " .. tostring(payload.v) .. ", this is version " .. protocol.VERSION, 0)
    end
    local message = protocol.check_record(name, protocol.FIELDS[name], payload, false)
    message.v = payload.v
    return name, message
end
-- }}}

-- {{{ protocol.read_frame
-- The first message off a stream's bytes: name, message and the bytes
-- after it, or nil, nil and the bytes as they were while it hasn't all come.
function protocol.read_frame(buffer)
    local total = protocol.frame_length(buffer)
    if not total or #buffer < total then return nil, nil, buffer end
    local name, message = protocol.decode(buffer:sub(1, total))
    return name, message, buffer:sub(total + 1)
end
-- }}}

return protocol
