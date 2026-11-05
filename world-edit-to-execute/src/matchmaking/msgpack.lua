--[[
msgpack.lua - MessagePack, the part the matchmaking protocol uses (issue 801a)

What this is: a small encoder and decoder for MessagePack, the compact
binary form of nested lists and tables that the matchmaking messages carry
(the issue chose it so any language can read them). Written here rather
than fetched, because it is short and the project installs nothing.

What it carries: nil, true and false, whole numbers (exactly, up to 2^53
either way, the most a Lua number holds exactly), other numbers as 64-bit
floats, strings (as MessagePack's "str"; "bin" is read as a string too),
lists and tables with string or number keys.

How Lua's values map: a table whose keys are exactly 1..n (and an empty
table) is a list; any other table is a map, its keys written sorted so
the same table always gives the same bytes. A float that MessagePack calls
32-bit is read as the float it is.

Refusals, never guesses: encoding a function, a table inside itself, a
non-finite number, or a map key that is not a string or a number, and
decoding bytes cut short, bytes left over, an extension type, a whole
number past 2^53, or nesting deeper than 32 all raise an error saying what
and where.
]]

local ffi = require("ffi")

local msgpack = {}

msgpack.MAX_DEPTH = 32
local EXACT = 2 ^ 53

-- {{{ bytes
local double_bits = ffi.new("union { double d; uint8_t b[8]; }")
local float_bits = ffi.new("union { float f; uint8_t b[4]; }")
local little = ffi.abi("le")

local function be(n, count)
    -- n's low `count` bytes, most significant first; n is a whole number >= 0
    local out = {}
    for i = count, 1, -1 do
        out[i] = string.char(n % 256)
        n = math.floor(n / 256)
    end
    return table.concat(out)
end

local function double_be(x)
    double_bits.d = x
    local out = {}
    for i = 0, 7 do out[#out + 1] = string.char(double_bits.b[little and 7 - i or i]) end
    return table.concat(out)
end
-- }}}

-- {{{ encode
local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do
        local kt = type(k)
        if kt ~= "string" and kt ~= "number" then
            error("msgpack: a map key must be a string or a number, not a " .. kt, 0)
        end
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta == "number" end
        return a < b
    end)
    return keys
end

local function is_list(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do
        if t[i] == nil then return false, n end
    end
    return true, n
end

local function encode_number(x, out)
    if x ~= x or x == math.huge or x == -math.huge then
        error("msgpack: " .. tostring(x) .. " is not a number MessagePack can carry", 0)
    end
    if x == math.floor(x) and x >= -EXACT and x <= EXACT then
        if x >= 0 then
            if x < 128 then out[#out + 1] = string.char(x)
            elseif x < 2 ^ 8 then out[#out + 1] = "\204" .. be(x, 1)
            elseif x < 2 ^ 16 then out[#out + 1] = "\205" .. be(x, 2)
            elseif x < 2 ^ 32 then out[#out + 1] = "\206" .. be(x, 4)
            else out[#out + 1] = "\207" .. be(x, 8) end
        else
            if x >= -32 then out[#out + 1] = string.char(256 + x)
            elseif x >= -2 ^ 7 then out[#out + 1] = "\208" .. be(2 ^ 8 + x, 1)
            elseif x >= -2 ^ 15 then out[#out + 1] = "\209" .. be(2 ^ 16 + x, 2)
            elseif x >= -2 ^ 31 then out[#out + 1] = "\210" .. be(2 ^ 32 + x, 4)
            else
                -- two's complement over 64 bits: the high half, then the low
                local hi = math.floor(x / 2 ^ 32)
                out[#out + 1] = "\211" .. be(2 ^ 32 + hi, 4) .. be(x - hi * 2 ^ 32, 4)
            end
        end
    else
        out[#out + 1] = "\203" .. double_be(x)
    end
end

local function encode_value(v, out, seen, depth)
    local t = type(v)
    if v == nil then out[#out + 1] = "\192"
    elseif v == false then out[#out + 1] = "\194"
    elseif v == true then out[#out + 1] = "\195"
    elseif t == "number" then encode_number(v, out)
    elseif t == "string" then
        local n = #v
        if n < 32 then out[#out + 1] = string.char(0xa0 + n)
        elseif n < 2 ^ 8 then out[#out + 1] = "\217" .. be(n, 1)
        elseif n < 2 ^ 16 then out[#out + 1] = "\218" .. be(n, 2)
        else out[#out + 1] = "\219" .. be(n, 4) end
        out[#out + 1] = v
    elseif t == "table" then
        if seen[v] then error("msgpack: a table that holds itself can't be written", 0) end
        if depth >= msgpack.MAX_DEPTH then error("msgpack: nested deeper than " .. msgpack.MAX_DEPTH, 0) end
        seen[v] = true
        local list, n = is_list(v)
        if list then
            if n < 16 then out[#out + 1] = string.char(0x90 + n)
            elseif n < 2 ^ 16 then out[#out + 1] = "\220" .. be(n, 2)
            else out[#out + 1] = "\221" .. be(n, 4) end
            for i = 1, n do encode_value(v[i], out, seen, depth + 1) end
        else
            local keys = sorted_keys(v)
            if n < 16 then out[#out + 1] = string.char(0x80 + n)
            elseif n < 2 ^ 16 then out[#out + 1] = "\222" .. be(n, 2)
            else out[#out + 1] = "\223" .. be(n, 4) end
            for _, k in ipairs(keys) do
                encode_value(k, out, seen, depth + 1)
                encode_value(v[k], out, seen, depth + 1)
            end
        end
        seen[v] = nil
    else
        error("msgpack: a " .. t .. " can't be written", 0)
    end
end

-- {{{ msgpack.encode
function msgpack.encode(v)
    local out = {}
    encode_value(v, out, {}, 0)
    return table.concat(out)
end
-- }}}
-- }}}

-- {{{ decode
local function need(s, at, n)
    if at + n - 1 > #s then
        error(string.format("msgpack: cut short at byte %d (needs %d more)", at, at + n - 1 - #s), 0)
    end
end

local function uint(s, at, n)
    need(s, at, n)
    local x = 0
    for i = at, at + n - 1 do x = x * 256 + s:byte(i) end
    return x
end

local decode_value

local function decode_str(s, at, n)
    need(s, at, n)
    return s:sub(at, at + n - 1), at + n
end

local function decode_list(s, at, n, depth)
    local t = {}
    for i = 1, n do t[i], at = decode_value(s, at, depth + 1) end
    return t, at
end

local function decode_map(s, at, n, depth)
    local t = {}
    for _ = 1, n do
        local k, v
        k, at = decode_value(s, at, depth + 1)
        if type(k) ~= "string" and type(k) ~= "number" then
            error("msgpack: a map key at byte " .. at .. " is not a string or a number", 0)
        end
        v, at = decode_value(s, at, depth + 1)
        t[k] = v
    end
    return t, at
end

local function whole(x, at)
    if x > EXACT then error("msgpack: the whole number at byte " .. at .. " is past 2^53", 0) end
    return x
end

function decode_value(s, at, depth)
    if depth > msgpack.MAX_DEPTH then error("msgpack: nested deeper than " .. msgpack.MAX_DEPTH, 0) end
    need(s, at, 1)
    local b = s:byte(at)
    at = at + 1
    if b < 0x80 then return b, at
    elseif b >= 0xe0 then return b - 256, at
    elseif b < 0x90 then return decode_map(s, at, b - 0x80, depth)
    elseif b < 0xa0 then return decode_list(s, at, b - 0x90, depth)
    elseif b < 0xc0 then return decode_str(s, at, b - 0xa0)
    elseif b == 0xc0 then return nil, at
    elseif b == 0xc2 then return false, at
    elseif b == 0xc3 then return true, at
    elseif b == 0xc4 or b == 0xd9 then return decode_str(s, at + 1, uint(s, at, 1))
    elseif b == 0xc5 or b == 0xda then return decode_str(s, at + 2, uint(s, at, 2))
    elseif b == 0xc6 or b == 0xdb then return decode_str(s, at + 4, uint(s, at, 4))
    elseif b == 0xca then
        need(s, at, 4)
        for i = 0, 3 do float_bits.b[little and 3 - i or i] = s:byte(at + i) end
        return tonumber(float_bits.f), at + 4
    elseif b == 0xcb then
        need(s, at, 8)
        for i = 0, 7 do double_bits.b[little and 7 - i or i] = s:byte(at + i) end
        return tonumber(double_bits.d), at + 8
    elseif b == 0xcc then return uint(s, at, 1), at + 1
    elseif b == 0xcd then return uint(s, at, 2), at + 2
    elseif b == 0xce then return uint(s, at, 4), at + 4
    elseif b == 0xcf then return whole(uint(s, at, 8), at), at + 8
    elseif b == 0xd0 then local x = uint(s, at, 1); return x >= 2 ^ 7 and x - 2 ^ 8 or x, at + 1
    elseif b == 0xd1 then local x = uint(s, at, 2); return x >= 2 ^ 15 and x - 2 ^ 16 or x, at + 2
    elseif b == 0xd2 then local x = uint(s, at, 4); return x >= 2 ^ 31 and x - 2 ^ 32 or x, at + 4
    elseif b == 0xd3 then
        local hi, lo = uint(s, at, 4), uint(s, at + 4, 4)
        if hi >= 2 ^ 31 then hi = hi - 2 ^ 32 end
        local x = hi * 2 ^ 32 + lo
        if x < -EXACT or x > EXACT then error("msgpack: the whole number at byte " .. at .. " is past 2^53", 0) end
        return x, at + 8
    elseif b == 0xdc then return decode_list(s, at + 2, uint(s, at, 2), depth)
    elseif b == 0xdd then return decode_list(s, at + 4, uint(s, at, 4), depth)
    elseif b == 0xde then return decode_map(s, at + 2, uint(s, at, 2), depth)
    elseif b == 0xdf then return decode_map(s, at + 4, uint(s, at, 4), depth)
    end
    error(string.format("msgpack: byte %d is 0x%02x, a type this reader doesn't take", at - 1, b), 0)
end

-- {{{ msgpack.decode
-- One value from all of `s`: bytes left over are refused.
function msgpack.decode(s)
    local v, at = decode_value(s, 1, 0)
    if at <= #s then error("msgpack: " .. (#s - at + 1) .. " bytes left over after the value", 0) end
    return v
end
-- }}}
-- }}}

return msgpack
