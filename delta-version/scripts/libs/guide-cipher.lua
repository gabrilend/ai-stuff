-- guide-cipher.lua - The reading-walk guide's own cipher, version one.
--
-- In plain terms: the guide writes its words encrypted. This turns a secret
-- key and a fresh random number (the nonce, different for every message) into
-- a stream of unpredictable bytes, and mixes the message with that stream;
-- running the same stream over the result gives the message back. The stream
-- comes from two things she named (issue 065):
--
--   1. a step that splits into unpredictable answers past a threshold -- the
--      logistic map, x -> r * x * (1 - x). Below r of about 3.57 it settles
--      into a repeating cycle; above it, chaos: two starting points that
--      differ in the twelfth decimal place disagree completely within a few
--      dozen steps. The key chooses r (between 3.9 and 4.0, deep in the chaos)
--      and the starting point;
--   2. "pick a random number, take the nearest prime": each step's number is
--      cut down to a range, replaced by the prime nearest to it, and that
--      prime is folded into the output byte.
--
-- WHAT THIS IS NOT. It is home-made, and home-made ciphers are usually broken
-- by people who study ciphers; chaos-based ones especially. It keeps a casual
-- reader out, not an expert. Version one is "made to work first"; the guide
-- upgrades it later (the version number in every message lets old and new
-- coexist). It detects a wrong key (a known marker is encrypted first), but it
-- does not detect a message changed on disk -- that would need a keyed
-- checksum, and is the first upgrade worth making.
--
-- Floating point: LuaJIT's numbers are 64-bit IEEE doubles and x86-64 rounds
-- them the same way every time, so the same key and nonce give the same stream
-- on any x86-64 machine. A machine that rounded differently would not decrypt
-- what this one wrote.

local bit = require("bit")
local M = {}

-- {{{ M.version
M.version = "ialmstla-cipher 1"
-- }}}

-- {{{ local MARKER
-- Encrypted ahead of every message; finding it again on the way out is how a
-- wrong key is told from a right one.
local MARKER = "IALMSTLA"
-- }}}

-- {{{ local PRIME_RANGE
-- Numbers are cut into 2..PRIME_RANGE before the nearest prime is taken; the
-- table of nearest primes is built once, by sieve, the first time it is asked.
local PRIME_RANGE = 65536
local nearest_prime_table = nil
-- }}}

-- {{{ local function build_nearest_primes()
-- For every n in 2..PRIME_RANGE, the prime closest to it (the lower one on a
-- tie). One sieve, then two sweeps: the last prime at or below each n, and the
-- next prime at or above it.
local function build_nearest_primes()
    local limit = PRIME_RANGE + 200
    local composite = {}
    for n = 2, math.floor(math.sqrt(limit)) do
        if not composite[n] then
            for multiple = n * n, limit, n do composite[multiple] = true end
        end
    end
    local below, above = {}, {}
    local last = 2
    for n = 2, limit do
        if not composite[n] then last = n end
        below[n] = last
    end
    local following = limit
    for n = limit, 2, -1 do
        if not composite[n] then following = n end
        above[n] = following
    end
    local nearest = {}
    for n = 2, PRIME_RANGE do
        nearest[n] = (n - below[n] <= above[n] - n) and below[n] or above[n]
    end
    return nearest
end
-- }}}

-- {{{ local function seed_from()
-- The key and nonce, folded into the map's two settings. Each byte nudges an
-- accumulator through the map itself, so every byte of both changes where the
-- stream starts. r lands in [3.9, 4.0); x in (0.05, 0.95).
local function seed_from(key, nonce)
    local material = key .. nonce
    local a, b = 0.3141592653589793, 0.2718281828459045
    for index = 1, #material do
        local byte = material:byte(index)
        a = (a + byte / 257 + index * 1e-6) % 1
        b = (b * 3.99 * (1 - b) + byte / 263) % 1
        a = 3.97 * a * (1 - a)
    end
    return 3.9 + (a % 1) * 0.0999, 0.05 + (b % 1) * 0.9
end
-- }}}

-- {{{ local function keystream()
-- A function giving the next unpredictable byte each call.
--
-- The map can fall onto a point it never leaves (exactly 0, or a value whose
-- next step is 0); if x comes within a hair of either end it is pushed back
-- into the middle by the golden ratio and a step counter, so the stream never
-- freezes. The first 1000 steps are thrown away: the start still remembers
-- the seed; after a thousand it has forgotten.
local function keystream(key, nonce)
    if not nearest_prime_table then nearest_prime_table = build_nearest_primes() end
    local r, x = seed_from(key, nonce)
    local step = 0
    local function advance()
        step = step + 1
        x = r * x * (1 - x)
        if x < 1e-9 or x > 1 - 1e-9 then x = (x + 0.6180339887498949 + step * 1e-7) % 1 end
    end
    for _ = 1, 1000 do advance() end
    return function()
        advance()
        local whole = math.floor(x * 4294967296)          -- 32 bits of x
        local cut = whole % (PRIME_RANGE - 1) + 2           -- into 2..PRIME_RANGE
        local prime = nearest_prime_table[cut]
        local low = math.floor(x * 1099511627776) % 256     -- bits 33..40 of x
        return bit.band(bit.bxor(prime, low, bit.rshift(whole, 13)), 255)
    end
end
-- }}}

-- {{{ local function mix()
-- The message mixed with the stream, byte by byte (exclusive-or, which undoes
-- itself: mixing twice with the same stream gives the message back).
local function mix(text, next_byte)
    local out = {}
    for index = 1, #text do
        out[index] = string.char(bit.bxor(text:byte(index), next_byte()))
    end
    return table.concat(out)
end
-- }}}

-- {{{ M.make_key()
-- 32 random bytes from the operating system. A key read from anywhere less
-- random would make every message easier to guess.
function M.make_key()
    local handle = io.open("/dev/urandom", "rb")
    if not handle then error("guide-cipher: cannot read /dev/urandom", 0) end
    local key = handle:read(32)
    handle:close()
    return key
end
-- }}}

-- {{{ M.encrypt(key, text, nonce)
-- A message, encrypted: the version line, 16 bytes of nonce, then the marker
-- and the message mixed with the stream. The nonce is fresh from the operating
-- system unless given (tests give one to get a repeatable result). A nonce must
-- never be used twice with one key: two messages mixed with the same stream
-- give away their difference.
function M.encrypt(key, text, nonce)
    if #key < 16 then error("guide-cipher: a key needs at least 16 bytes", 0) end
    if not nonce then
        local handle = io.open("/dev/urandom", "rb")
        nonce = handle:read(16)
        handle:close()
    end
    return M.version .. "\n" .. nonce .. mix(MARKER .. text, keystream(key, nonce))
end
-- }}}

-- {{{ M.decrypt(key, sealed)
-- The message back, or an error: an unknown version, a message too short to
-- hold a nonce and marker, or a marker that does not come back (the wrong key).
function M.decrypt(key, sealed)
    local version, rest = sealed:match("^([^\n]*)\n(.*)$")
    if version ~= M.version then error("guide-cipher: not a " .. M.version .. " message", 0) end
    if #rest < 16 + #MARKER then error("guide-cipher: message too short", 0) end
    local nonce, body = rest:sub(1, 16), rest:sub(17)
    local opened = mix(body, keystream(key, nonce))
    if opened:sub(1, #MARKER) ~= MARKER then error("guide-cipher: wrong key", 0) end
    return opened:sub(#MARKER + 1)
end
-- }}}

-- {{{ M.stream_sample(key, nonce, count)
-- The first count bytes of the stream, for measuring it (the test counts how
-- evenly the 256 byte values come up).
function M.stream_sample(key, nonce, count)
    local next_byte = keystream(key, nonce)
    local out = {}
    for index = 1, count do out[index] = next_byte() end
    return out
end
-- }}}

-- {{{ M.to_hex(text) / M.from_hex(text)
-- Encrypted bytes as a line of text (two characters per byte), so a trail can
-- hold one encrypted entry per line.
function M.to_hex(text)
    return (text:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end
function M.from_hex(text)
    if not text:match("^%x*$") or #text % 2 == 1 then error("guide-cipher: not hex", 0) end
    return (text:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end
-- }}}

return M
