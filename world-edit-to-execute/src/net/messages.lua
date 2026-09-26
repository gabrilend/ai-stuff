--[[
messages.lua - the gameplay messages between the server and its clients, as bytes (issue 803)

What this is: every message the server and a client send each other during
play, and the one way each becomes bytes and back. The server holds the
only true simulation; clients send orders and "heard" beats, and receive
unit states, events, order answers, and the waiting dialog's news.

Messages are encoded to bytes even when the server runs inside the client,
exactly as they would cross a network, so the two sides never share a Lua
table and a real network later only changes how the bytes travel.

How: each message is described once, as data -- an ordered list of fields,
each a name and a kind (u8, u16, u32, f32, or a list of records described
the same way). One encoder and one decoder walk any description. Adding a
message is adding a description; nothing else changes.

The wire layout of one message:
  u8   type (the message's number, below)
  ...  its fields in order, little-endian; a list is a u16 count, then
       that many records
Time is always a tick number (u32, at 62.5 ticks a second), except where
the game is paused and ticks don't advance: the waiting dialog's times are
milliseconds.

Refusals, never guesses: encoding a value that doesn't fit its field (a
fraction in an integer, a number out of range, a missing field) and
decoding bytes that are short, too long or of an unknown type all raise an
error naming the message and field.

Speed: bytes go into one reused FFI byte buffer, and the name of the field
being worked on is only spelled out when something is refused. The first
version (a table of one-character strings, and a field name built for
every field) took 9.6 ms to encode 2,048 units, over half a tick; this
one takes about 1 ms. Decoding 2,048 units into Lua tables takes about
1.7 ms, most of it making the tables; the renderer's receiver is meant to
decode straight into its mailbox instead.
]]

local ffi = require("ffi")
local bit = require("bit")

local messages = {}

-- {{{ The kinds of field
-- f32 goes through a union so its bits are exactly the float's.
local float_bits = ffi.new("union { float f; uint32_t u; }")

local integer_limits = { u8 = 0xff, u16 = 0xffff, u32 = 0xffffffff }
local integer_bytes = { u8 = 1, u16 = 2, u32 = 4 }
-- }}}

-- {{{ Order kinds, event kinds, refusal reasons
-- Named numbers, so a message carries one byte and code reads a word.
messages.order_kind = { move = 1, attack = 2, attack_move = 3, stop = 4, hold = 5 }
messages.event_kind = { death = 1, spawn = 2, attack_hit = 3, spell_start = 4, spell_land = 5, buff_end = 6 }
messages.refusal = { none = 0, not_yours = 1, unknown_unit = 2, unreachable = 3, paused = 4 }
-- }}}

-- {{{ The message descriptions
-- Each: a number (the type byte), a name, and its fields in order.
local unit_record = {
    { "id", "u32" },
    { "x", "f32" }, { "y", "f32" }, { "z", "f32" },
    { "vx", "f32" }, { "vy", "f32" }, { "vz", "f32" },   -- units a second
    { "facing", "f32" },                                 -- radians
    { "anim", "u16" },                                   -- which animation
    { "anim_phase", "f32" },                             -- seconds into it
}

local descriptions = {
    -- client -> server: a player's order. The client chose the id, so it can
    -- match the answer to the local response it already showed.
    { 1, "order", {
        { "order_id", "u32" },
        { "given_tick", "u32" },          -- the newest tick the client had drawn
        { "kind", "u8" },                 -- messages.order_kind
        { "target_x", "f32" }, { "target_y", "f32" },
        { "target_unit", "u32" },         -- 0: a point, not a unit
        { "units", "list", { { "id", "u32" } } },
    } },
    -- client -> server: every tick at least this; it's how the server knows
    -- a player is still there.
    { 2, "heard", {
        { "tick", "u32" },                -- the newest tick this client received
    } },
    -- server -> client: an order kept or refused, and when it takes effect.
    { 3, "order_answer", {
        { "order_id", "u32" },
        { "accepted", "u8" },             -- 1 kept, 0 refused
        { "effect_tick", "u32" },
        { "refusal", "u8" },              -- messages.refusal
    } },
    -- server -> client: every unit this player can see, true at one tick.
    { 4, "unit_states", {
        { "tick", "u32" },
        { "units", "list", unit_record },
    } },
    -- server -> client: things that happened, each at its own tick.
    { 5, "events", {
        { "tick", "u32" },                -- when the server sent them
        { "events", "list", {
            { "kind", "u8" },             -- messages.event_kind
            { "tick", "u32" },
            { "unit", "u32" },
            { "other", "u32" },           -- the other unit involved, or 0
        } },
    } },
    -- server -> client: the waiting dialog's news. Times in milliseconds,
    -- since ticks stand still while the game is paused.
    { 6, "waiting", {
        { "tick", "u32" },                -- the tick the game paused on
        { "paused", "u8" },               -- 1 paused, 0 resumed
        { "silent", "list", {
            { "player", "u8" },
            { "silent_ms", "u32" },
            { "countdown_ms", "u32" },    -- until a drop vote opens; 0 once open
        } },
    } },
    -- client -> server: this player's slider.
    { 7, "tolerance", {
        { "ms", "u32" },
    } },
    -- server -> client: every player's slider, and the one in force.
    { 8, "tolerances", {
        { "in_force_ms", "u32" },         -- the lowest
        { "players", "list", { { "player", "u8" }, { "ms", "u32" } } },
    } },
    -- client -> server: a vote to drop a silent player.
    { 9, "drop_vote", {
        { "player", "u8" },
    } },
    -- server -> client: the votes cast, and how many a drop needs.
    { 10, "votes", {
        { "needed", "u8" },
        { "silent", "list", { { "player", "u8" }, { "votes", "u8" } } },
    } },
    -- server -> client, for drawing only: the paths units re-planned this
    -- tick, as one flat list of points (a unit's points in order; a unit
    -- with no points has stopped). Flat, so a C reader needs no nesting.
    { 11, "paths", {
        { "tick", "u32" },
        { "stopped", "list", { { "id", "u32" } } },
        { "points", "list", { { "id", "u32" }, { "x", "f32" }, { "y", "f32" } } },
    } },
}

-- Two ways in: by number (decoding) and by name (encoding).
local by_number, by_name = {}, {}
for _, d in ipairs(descriptions) do
    local entry = { number = d[1], name = d[2], fields = d[3] }
    by_number[entry.number] = entry
    by_name[entry.name] = entry
end
messages.names = {}
for _, d in ipairs(descriptions) do messages.names[#messages.names + 1] = d[2] end
-- The descriptions themselves, read-only by agreement: the C unpacker is
-- generated from them (net/messages-c.lua), so the two can't drift apart.
messages.descriptions = descriptions
-- }}}

-- {{{ Where the walk is, for refusals
-- The path to the field being read or written ("order", "units", 3, "id"),
-- kept as a stack and joined only when something is refused: building a
-- name for every field of every unit would cost more than the bytes.
local path, depth = {}, 0

-- {{{ local function refuse(what)
local function refuse(what)
    local parts = {}
    for i = 1, depth do
        local p = path[i]
        if type(p) == "number" then parts[#parts] = parts[#parts] .. "[" .. p .. "]"
        else parts[#parts + 1] = p end
    end
    error(table.concat(parts, ".") .. what, 0)
end
-- }}}
-- }}}

-- {{{ The byte buffer
-- One buffer, reused by every encode in this Lua state and grown when a
-- message needs more (each thread has its own Lua state, so its own
-- buffer). Bytes are stored one at a time, low byte first, so the layout
-- doesn't depend on the machine.
local buffer_size = 4096
local buffer = ffi.new("uint8_t[?]", buffer_size)
local used = 0

-- {{{ local function room_for(n)
local function room_for(n)
    if used + n <= buffer_size then return end
    local size = buffer_size
    while used + n > size do size = size * 2 end
    local grown = ffi.new("uint8_t[?]", size)
    ffi.copy(grown, buffer, used)
    buffer, buffer_size = grown, size
end
-- }}}
-- }}}

-- {{{ local function put_integer(value, kind)
local function put_integer(value, kind)
    if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value > integer_limits[kind] then
        refuse(": " .. tostring(value) .. " does not fit a " .. kind)
    end
    local n = integer_bytes[kind]
    room_for(n)
    -- LuaJIT's bit operations work on 32 bits, which every field fits
    for i = 0, n - 1 do
        buffer[used + i] = bit.band(value, 0xff)
        value = bit.rshift(value, 8)
    end
    used = used + n
end
-- }}}

-- {{{ local function put_fields(fields, record)
-- Walks a description, appending each field's bytes. The kinds form a
-- dispatch: integers, a float, or a list of records.
local function put_fields(fields, record)
    depth = depth + 1
    for _, field in ipairs(fields) do
        local name, kind = field[1], field[2]
        local value = record[name]
        path[depth] = name
        if value == nil then refuse(" is missing") end
        if integer_limits[kind] then
            put_integer(value, kind)
        elseif kind == "f32" then
            if type(value) ~= "number" then refuse(": " .. tostring(value) .. " is not a number") end
            float_bits.f = value
            put_integer(tonumber(float_bits.u), "u32")
        else -- a list
            if type(value) ~= "table" then refuse(" is not a list") end
            put_integer(#value, "u16")
            depth = depth + 1
            for i, each in ipairs(value) do
                path[depth] = i
                put_fields(field[3], each)
            end
            depth = depth - 1
        end
    end
    depth = depth - 1
end
-- }}}

-- {{{ function messages.encode(name, message)
-- The message's bytes, as a string.
function messages.encode(name, message)
    local entry = by_name[name]
    if not entry then error("no message is called " .. tostring(name), 0) end
    used, depth = 0, 1
    path[1] = name
    put_integer(entry.number, "u8")
    put_fields(entry.fields, message)
    return ffi.string(buffer, used)
end
-- }}}

-- The bytes being decoded, as a pointer, and their length.
local reading, reading_length = nil, 0

-- {{{ local function take_integer(pos, kind)
local function take_integer(pos, kind)
    local n = integer_bytes[kind]
    if pos + n > reading_length then refuse(": the message ends early") end
    local value = 0
    for i = n - 1, 0, -1 do value = value * 256 + reading[pos + i] end
    return value, pos + n
end
-- }}}

-- {{{ local function take_fields(pos, fields)
local function take_fields(pos, fields)
    local record = {}
    depth = depth + 1
    for _, field in ipairs(fields) do
        local name, kind = field[1], field[2]
        path[depth] = name
        if integer_limits[kind] then
            record[name], pos = take_integer(pos, kind)
        elseif kind == "f32" then
            local u
            u, pos = take_integer(pos, "u32")
            float_bits.u = u
            record[name] = tonumber(float_bits.f)
        else -- a list
            local count
            count, pos = take_integer(pos, "u16")
            local list = {}
            depth = depth + 1
            for i = 1, count do
                path[depth] = i
                list[i], pos = take_fields(pos, field[3])
            end
            depth = depth - 1
            record[name] = list
        end
    end
    depth = depth - 1
    return record, pos
end
-- }}}

-- {{{ function messages.decode(bytes)
-- The message's name, and its fields as a table.
function messages.decode(bytes)
    if #bytes < 1 then error("an empty message", 0) end
    local entry = by_number[bytes:byte(1)]
    if not entry then error("no message has type " .. bytes:byte(1), 0) end
    reading, reading_length = ffi.cast("const uint8_t *", bytes), #bytes
    depth = 1
    path[1] = entry.name
    local record, pos = take_fields(1, entry.fields)
    reading = nil   -- the string may be collected; the pointer must not outlive it
    if pos ~= #bytes then
        error(entry.name .. ": " .. (#bytes - pos) .. " bytes left over after the last field", 0)
    end
    return entry.name, record
end
-- }}}

-- {{{ function messages.f32(value)
-- A number as it comes back through an f32 field: what a test compares with.
function messages.f32(value)
    float_bits.f = value
    return tonumber(float_bits.f)
end
-- }}}

return messages
