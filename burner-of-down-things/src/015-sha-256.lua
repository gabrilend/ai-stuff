-- 015-sha-256.lua
--
-- SHA-256 (FIPS 180-4) in LuaJIT, with no outside program. The ledger chains
-- its lines with it and the snapshot compares files with it; both need a
-- checksum nobody can steer, and both run it often enough that starting a
-- `sha256sum` process per call would dominate the time.
--
-- LuaJIT's bit operations work on signed 32-bit integers. Every addition is
-- therefore folded back with bit.tobit, and results are printed with
-- bit.tohex, which reads the 32 bits as unsigned.

local bit = require("bit")
local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
local rshift, lshift, ror = bit.rshift, bit.lshift, bit.ror
local tobit, tohex = bit.tobit, bit.tohex
local byte, char, rep, format = string.byte, string.char, string.rep, string.format

local sha_256 = {}

-- The first 32 bits of the fractional parts of the cube roots of the first 64
-- primes: the round constants.
local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
for i = 1, 64 do
    K[i] = tobit(K[i])
end

-- The first 32 bits of the fractional parts of the square roots of the first
-- 8 primes: the starting state.
local INITIAL = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

-- One message schedule, reused by every block, to keep the garbage collector
-- out of the inner loop.
local W = {}

-- {{{ local function compress
-- Mixes one 64-byte block (starting at `offset` in `block_text`) into `state`.
local function compress(state, block_text, offset)
    for i = 0, 15 do
        local b1, b2, b3, b4 = byte(block_text, offset + i * 4, offset + i * 4 + 3)
        W[i] = bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4)
    end
    for i = 16, 63 do
        local w15, w2 = W[i - 15], W[i - 2]
        local s0 = bxor(ror(w15, 7), ror(w15, 18), rshift(w15, 3))
        local s1 = bxor(ror(w2, 17), ror(w2, 19), rshift(w2, 10))
        W[i] = tobit(W[i - 16] + s0 + W[i - 7] + s1)
    end
    local a, b, c, d, e, f, g, h =
        state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8]
    for i = 0, 63 do
        local S1 = bxor(ror(e, 6), ror(e, 11), ror(e, 25))
        local ch = bxor(band(e, f), band(bnot(e), g))
        local t1 = tobit(h + S1 + ch + K[i + 1] + W[i])
        local S0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
        local maj = bxor(band(a, b), band(a, c), band(b, c))
        local t2 = tobit(S0 + maj)
        h, g, f, e, d, c, b, a = g, f, e, tobit(d + t1), c, b, a, tobit(t1 + t2)
    end
    state[1] = tobit(state[1] + a); state[2] = tobit(state[2] + b)
    state[3] = tobit(state[3] + c); state[4] = tobit(state[4] + d)
    state[5] = tobit(state[5] + e); state[6] = tobit(state[6] + f)
    state[7] = tobit(state[7] + g); state[8] = tobit(state[8] + h)
end
-- }}}

-- {{{ local function new_state
local function new_state()
    local state = {}
    for i = 1, 8 do
        state[i] = tobit(INITIAL[i])
    end
    return state
end
-- }}}

-- {{{ local function length_bytes
-- The message length in bits as 8 big-endian bytes. Lengths beyond 2^53 bits
-- cannot occur for anything this machine hashes.
local function length_bytes(byte_count)
    local bits = byte_count * 8
    local out = {}
    for i = 8, 1, -1 do
        out[i] = char(bits % 256)
        bits = math.floor(bits / 256)
    end
    return table.concat(out)
end
-- }}}

-- {{{ local function finish
-- Pads the tail (fewer than 64 bytes not yet compressed), compresses it, and
-- returns the digest as 64 hex characters.
local function finish(state, tail, total_bytes)
    local zeros = (55 - #tail) % 64
    local padded = tail .. "\128" .. rep("\0", zeros) .. length_bytes(total_bytes)
    for offset = 1, #padded, 64 do
        compress(state, padded, offset)
    end
    local hex = {}
    for i = 1, 8 do
        hex[i] = tohex(state[i], 8)
    end
    return table.concat(hex)
end
-- }}}

-- {{{ function sha_256.of_string
function sha_256.of_string(text)
    -- tostring() of a non-string would silently hash something else.
    if type(text) ~= "string" then
        error("sha_256.of_string: input must be a string, got " .. type(text))
    end
    local state = new_state()
    local whole = #text - #text % 64
    for offset = 1, whole, 64 do
        compress(state, text, offset)
    end
    return finish(state, text:sub(whole + 1), #text)
end
-- }}}

-- {{{ function sha_256.of_file
-- Reads the file in 64 KiB pieces (a multiple of the block size), so a large
-- file is never held whole.
function sha_256.of_file(path)
    local file = io.open(path, "rb")
    if not file then
        error("sha_256.of_file: cannot open " .. path)
    end
    local state = new_state()
    local total = 0
    local tail = ""
    while true do
        local piece = file:read(65536)
        if not piece then
            break
        end
        total = total + #piece
        piece = tail .. piece
        local whole = #piece - #piece % 64
        for offset = 1, whole, 64 do
            compress(state, piece, offset)
        end
        tail = piece:sub(whole + 1)
    end
    file:close()
    return finish(state, tail, total)
end
-- }}}

return sha_256
