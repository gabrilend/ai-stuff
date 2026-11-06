-- test_matchmaking_protocol.lua - the matchmaking messages survive the trip to bytes and back (issue 801a)
--
-- In plain terms: a host, a joining player and the matchmaking server only
-- ever exchange bytes. This checks MessagePack against bytes other
-- programs write, that every kind of message comes back from its bytes as
-- it was and gives the same bytes again, that a stream cut anywhere is
-- put back together, and that damaged, misspelt or other-version messages
-- are refused with a reason instead of guessed at.
--
-- Run with: luajit src/tests/test_matchmaking_protocol.lua [DIR]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local msgpack = require("matchmaking.msgpack")
local protocol = require("matchmaking.protocol")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

-- {{{ local function same(a, b)
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
-- }}}

local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
local function unhex(h) return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end)) end

-- {{{ local function refused(f, want)
-- f raises an error whose text holds `want`.
local function refused(f, want)
    local ok, err = pcall(f)
    return not ok and tostring(err):find(want, 1, true) ~= nil, tostring(err)
end
-- }}}
-- }}}

-- {{{ MessagePack against bytes other programs write
print("MessagePack")
local vectors = {
    { "nil", nil, "c0" }, { "false", false, "c2" }, { "true", true, "c3" },
    { "0", 0, "00" }, { "127", 127, "7f" }, { "128", 128, "cc80" }, { "300", 300, "cd012c" },
    { "65536", 65536, "ce00010000" }, { "2^32", 2 ^ 32, "cf0000000100000000" },
    { "-1", -1, "ff" }, { "-32", -32, "e0" }, { "-33", -33, "d0df" }, { "-129", -129, "d1ff7f" },
    { "-40000", -40000, "d2ffff63c0" }, { "-2^40", -2 ^ 40, "d3ffffff0000000000" },
    { "1.5", 1.5, "cb3ff8000000000000" }, { "\"\"", "", "a0" }, { "\"a\"", "a", "a161" },
    { "a 32-byte string", string.rep("x", 32), "d920" .. string.rep("78", 32) },
    { "a 256-byte string", string.rep("y", 256), "da0100" .. string.rep("79", 256) },
    { "[]", {}, "90" }, { "[1,2,3]", { 1, 2, 3 }, "93010203" },
    { "{\"a\":1}", { a = 1 }, "81a16101" },
    { "keys sorted", { b = 2, a = 1, c = { true } }, "83a16101a16202a16391c3" },
}
for _, v in ipairs(vectors) do
    local bytes = msgpack.encode(v[2])
    test("writes " .. v[1] .. " as " .. v[3], hex(bytes) == v[3], hex(bytes))
    test("reads " .. v[3] .. " back", same(msgpack.decode(unhex(v[3])), v[2]))
end
local sixteen = {}
for i = 1, 16 do sixteen[i] = i end
test("a list of 16 is an array16", hex(msgpack.encode(sixteen)):sub(1, 6) == "dc0010" and same(msgpack.decode(msgpack.encode(sixteen)), sixteen))
local map16 = {}
for i = 1, 16 do map16["k" .. i] = i end
test("a map of 16 is a map16", hex(msgpack.encode(map16)):sub(1, 6) == "de0010" and same(msgpack.decode(msgpack.encode(map16)), map16))
test("2^53 is written as a whole number", hex(msgpack.encode(2 ^ 53)) == "cf0020000000000000" and
    hex(msgpack.encode(-2 ^ 53)) == "d3ffe0000000000000")
test("2^53 is kept exactly", msgpack.decode(msgpack.encode(2 ^ 53)) == 2 ^ 53 and msgpack.decode(msgpack.encode(-2 ^ 53)) == -2 ^ 53)
test("past 2^53 is a float", hex(msgpack.encode(2 ^ 60)):sub(1, 2) == "cb" and msgpack.decode(msgpack.encode(2 ^ 60)) == 2 ^ 60)
test("a 32-bit float is read", msgpack.decode(unhex("ca3fc00000")) == 1.5)
test("bin is read as a string", msgpack.decode(unhex("c403616263")) == "abc")
test("str32 and array32 are read", msgpack.decode(unhex("db00000002" .. "6869")) == "hi" and
    same(msgpack.decode(unhex("dd00000002c3c2")), { true, false }))
test("map32 is read", same(msgpack.decode(unhex("df00000001a17801")), { x = 1 }))
test("a 64-bit whole past 2^53 is refused", refused(function() msgpack.decode(unhex("cf0040000000000001")) end, "past 2^53"))
test("a signed 64-bit whole past -2^53 is refused", refused(function() msgpack.decode(unhex("d3ffc0000000000000")) end, "past 2^53"))
test("bytes cut short are refused", refused(function() msgpack.decode(unhex("cd01")) end, "cut short"))
test("bytes left over are refused", refused(function() msgpack.decode(unhex("0101")) end, "left over"))
test("an extension type is refused", refused(function() msgpack.decode(unhex("d40100")) end, "doesn't take"))
local deep = {}
local at = deep
for _ = 1, 40 do at[1] = {}; at = at[1] end
test("nesting deeper than 32 is refused, writing", refused(function() msgpack.encode(deep) end, "deeper"))
test("and reading", refused(function() msgpack.decode(string.rep("\145", 40) .. "\192") end, "deeper"))
local loop = {}
loop.self = loop
test("a table holding itself is refused", refused(function() msgpack.encode(loop) end, "holds itself"))
test("a function is refused", refused(function() msgpack.encode(print) end, "function"))
test("infinity is refused", refused(function() msgpack.encode(math.huge) end, "not a number"))
test("a map key that is not a string or a number is refused, read", refused(function() msgpack.decode(unhex("81c301")) end, "map key"))
test("a table key is refused", refused(function() msgpack.encode({ [{}] = 1 }) end, "map key"))
-- }}}

-- {{{ every message, there and back
print("Every message")
local samples = {
    REGISTER_GAME = { map_name = "Castle Defense v1.3", map_hash = "sha256:abc123",
        asset_packs = { { id = "medieval-pack-v1", hash = "sha256:def456" } },
        max_players = 4, game_mode = "co-op", region = "us-west", host_port = 6112 },
    UNREGISTER_GAME = { game_id = 7 },
    UPDATE_GAME = { game_id = 7, players = 3, max_players = 4 },
    LIST_GAMES = { region = "us-west", max_latency_ms = 100 },
    GAME_LIST = { games = {
        { game_id = 7, map_name = "Castle Defense v1.3", map_hash = "sha256:abc123", asset_packs = {},
          game_mode = "co-op", region = "us-west", players = 3, max_players = 4 },
        { game_id = 9, map_name = "(2)Echo Isles", map_hash = "sha256:0e", game_mode = "melee",
          asset_packs = { { id = "a", hash = "b" }, { id = "c", hash = "d" } },
          region = "eu", players = 1, max_players = 2 },
    } },
    JOIN_GAME = { game_id = 7, player_name = "Ritz" },
    JOIN_ACK = { game_id = 7, player_id = 2, players = {
        { player_id = 1, name = "host", ready = true }, { player_id = 2, name = "Ritz", ready = false } } },
    JOIN_REJECT = { game_id = 7, reason = "full" },
    LEAVE_GAME = { game_id = 7 },
    LOBBY_UPDATE = { game_id = 7, event = "ready", player_id = 2, players = {
        { player_id = 1, name = "host", ready = true }, { player_id = 2, name = "Ritz", ready = true } } },
    START_GAME = { game_id = 7 },
    GAME_START = { game_id = 7, host_ip = "203.0.113.5", host_port = 6112 },
    NAT_PUNCH = { game_id = 7, player_id = 2, ip = "198.51.100.9", port = 50123 },
    CHAT_MSG = { game_id = 7, player_id = 2, text = "gl hf — ready when you are" },
    PING = { nonce = 4294967295 },
    PONG = { nonce = 0 },
}
local count = 0
for name, id in pairs(protocol.TYPES) do
    count = count + 1
    local m = samples[name]
    test(name .. " has a sample", m ~= nil)
    if m then
        local bytes = protocol.encode(name, m)
        local got_name, got = protocol.decode(bytes)
        local want = {}
        for k, v in pairs(m) do want[k] = v end
        want.v = protocol.VERSION
        test(name .. " comes back as it was", got_name == name and same(got, want))
        test(name .. " gives the same bytes again", protocol.encode(name, got) == bytes)
        test(name .. "'s header: \"WC\", type " .. id .. ", its payload's length",
            bytes:sub(1, 2) == "WC" and bytes:byte(3) == 0 and bytes:byte(4) == id and
            ((bytes:byte(5) * 256 + bytes:byte(6)) * 256 + bytes:byte(7)) * 256 + bytes:byte(8) == #bytes - 8)
        test(name .. "'s payload is a MessagePack map holding the version",
            msgpack.decode(bytes:sub(9)).v == protocol.VERSION)
    end
end
test("sixteen message types, numbered 1 to 16", count == 16 and protocol.NAMES[1] == "REGISTER_GAME" and protocol.NAMES[16] == "PONG")
test("LIST_GAMES with no filters at all", same(select(2, protocol.decode(protocol.encode("LIST_GAMES", {}))), { v = 1 }))
test("a message naming its own version is fine", protocol.decode(protocol.encode("PING", { nonce = 1, v = 1 })) == "PING")
-- }}}

-- {{{ a stream, cut anywhere
print("A stream")
local stream = protocol.encode("JOIN_GAME", samples.JOIN_GAME) .. protocol.encode("CHAT_MSG", samples.CHAT_MSG) ..
    protocol.encode("PING", samples.PING)
local all_cuts = true
for cut = 0, #stream do
    local buffer, got = stream:sub(1, cut), {}
    local name, m
    repeat
        name, m, buffer = protocol.read_frame(buffer)
        if name then got[#got + 1] = name end
    until not name
    buffer = buffer .. stream:sub(cut + 1)
    repeat
        name, m, buffer = protocol.read_frame(buffer)
        if name then got[#got + 1] = name end
    until not name
    if not (#got == 3 and got[1] == "JOIN_GAME" and got[2] == "CHAT_MSG" and got[3] == "PING" and buffer == "") then
        all_cuts = false
    end
end
test("three messages, the stream cut at every byte, come out whole and in order", all_cuts)
local n1, m1, rest = protocol.read_frame(stream:sub(1, 7))
test("fewer than a header's bytes wait", n1 == nil and m1 == nil and rest == stream:sub(1, 7))
test("a wrong magic is refused at once", refused(function() protocol.read_frame("XX\0\1\0\0\0\0") end, "magic"))
-- }}}

-- {{{ refusals
print("Refusals")
local ping = protocol.encode("PING", { nonce = 5 })
test("an unknown message name", refused(function() protocol.encode("HELLO", {}) end, "not a message"))
test("a missing field", refused(function() protocol.encode("JOIN_GAME", { game_id = 1 }) end, "JOIN_GAME.player_name: missing"))
test("a misspelt field", refused(function() protocol.encode("PING", { nonce = 1, nonse = 2 }) end, "nonse is not one of its fields"))
test("text for a number", refused(function() protocol.encode("PING", { nonce = "1" }) end, "PING.nonce: should be a whole number"))
test("a fraction", refused(function() protocol.encode("PING", { nonce = 1.5 }) end, "not a whole number"))
test("a negative number", refused(function() protocol.encode("PING", { nonce = -1 }) end, "not a whole number"))
test("a number past 32 bits", refused(function() protocol.encode("PING", { nonce = 2 ^ 32 }) end, "not a whole number"))
test("a number for text", refused(function() protocol.encode("JOIN_REJECT", { game_id = 1, reason = 3 }) end, "should be text"))
test("text too long", refused(function()
    protocol.encode("CHAT_MSG", { game_id = 1, player_id = 1, text = string.rep("a", protocol.MAX_TEXT + 1) }) end, "over 1024"))
test("text just long enough", protocol.decode(protocol.encode("CHAT_MSG",
    { game_id = 1, player_id = 1, text = string.rep("a", protocol.MAX_TEXT) })) == "CHAT_MSG")
test("a word for true or false", refused(function()
    protocol.encode("JOIN_ACK", { game_id = 1, player_id = 1, players = { { player_id = 1, name = "a", ready = "yes" } } }) end,
    "JOIN_ACK.players[1].ready: should be true or false"))
test("a record for a list", refused(function() protocol.encode("GAME_LIST", { games = { x = 1 } }) end, "should be a list"))
test("a number in a list of records", refused(function() protocol.encode("GAME_LIST", { games = { 5 } }) end, "should be a record"))
test("a list too long", refused(function()
    local packs = {}
    for i = 1, protocol.MAX_LIST + 1 do packs[i] = { id = "p", hash = "h" } end
    protocol.encode("REGISTER_GAME", { map_name = "m", map_hash = "h", asset_packs = packs, max_players = 2,
        game_mode = "melee", region = "eu", host_port = 1 }) end, "records, over"))
test("another version, written", refused(function() protocol.encode("PING", { nonce = 1, v = 2 }) end, "version 2, this is version 1"))
test("another version, read", refused(function()
    local body = msgpack.encode({ nonce = 1, v = 2 })
    protocol.decode("WC\0\15\0\0\0" .. string.char(#body) .. body) end, "PING.v: version 2"))
test("no version, read", refused(function()
    local body = msgpack.encode({ nonce = 1 })
    protocol.decode("WC\0\15\0\0\0" .. string.char(#body) .. body) end, "PING.v: version nil"))
test("a field the reader doesn't know is dropped", (function()
    local body = msgpack.encode({ nonce = 1, v = 1, colour = "blue" })
    local _, m = protocol.decode("WC\0\15\0\0\0" .. string.char(#body) .. body)
    return m.colour == nil and m.nonce == 1
end)())
test("a missing field, read", refused(function()
    local body = msgpack.encode({ v = 1 })
    protocol.decode("WC\0\15\0\0\0" .. string.char(#body) .. body) end, "PING.nonce: missing"))
test("a payload that is not a map", refused(function() protocol.decode("WC\0\15\0\0\0\1\5") end, "should be a map"))
test("a payload that is not MessagePack", refused(function() protocol.decode("WC\0\15\0\0\0\1\193") end, "PING: msgpack"))
test("a wrong magic", refused(function() protocol.decode("WD" .. ping:sub(3)) end, "magic is 0x5744"))
test("an unknown type", refused(function() protocol.decode("WC\0\17" .. ping:sub(5)) end, "0x11 is not a message type"))
test("type 0", refused(function() protocol.decode("WC\0\0" .. ping:sub(5)) end, "0x00 is not a message type"))
test("a payload past the limit", refused(function() protocol.decode("WC\0\15\0\16\0\1") end, "over 1048576"))
test("a message whose payload would pass the limit is refused, written", refused(function()
    local games, name = {}, string.rep("m", 1000)
    for i = 1, 1100 do
        games[i] = { game_id = i, map_name = name, map_hash = "h", asset_packs = {}, game_mode = "melee",
            region = "eu", players = 1, max_players = 2 }
    end
    protocol.encode("GAME_LIST", { games = games }) end, "bytes of payload, over 1048576"))
test("a payload just at the limit is waited for", protocol.frame_length("WC\0\15\0\16\0\0") == 8 + 1048576)
test("cut short", refused(function() protocol.decode(ping:sub(1, #ping - 1)) end, "PING: cut short, 1 bytes missing"))
test("bytes left over", refused(function() protocol.decode(ping .. "x") end, "PING: 1 bytes left over"))
test("shorter than a header", refused(function() protocol.decode("WC\0") end, "shorter than a header"))
-- }}}

print(string.format("\nmatchmaking protocol: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
