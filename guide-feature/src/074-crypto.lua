-- 074-crypto.lua - the canvas server's locks: AES-256-GCM, SHA-256, PBKDF2.
--
-- In plain terms: the HTML page (issue 803) is read from outside the house,
-- over plain HTTP, so the server sends the canvas locked. It locks with
-- AES-256-GCM, the same cipher rmail uses, and the page unlocks it with
-- noble-ciphers (libs/noble-ciphers/). A viewer who signs in with a password
-- has a key made from that password by PBKDF2-HMAC-SHA256, many thousands of
-- rounds, so each guess costs time; the page makes it the same way with
-- noble-hashes. `scripts/add-viewer` makes it here once, when the viewer is
-- set up, and the server keeps only the key.
--
-- Written in plain LuaJIT, with no library: the canvas server is the one
-- program reachable from outside, and it stays one file of Lua with nothing
-- to build. Each piece is checked against its standard's published examples
-- (src/075-test-crypto.lua). It is a careful copy of the standards, not a
-- hardened library: its AES looks up tables, which a program on the same
-- machine could time. Nothing else runs on kuvalu's canvas server's side,
-- and the page's side is noble's.
--
--   local crypto = dofile(DIR .. "/src/074-crypto.lua")
--   local sealed = crypto.seal(key, plaintext, aad)   -- nonce .. ciphertext .. tag
--   local text, problem = crypto.open(key, sealed, aad)
--   crypto.gcm_encrypt(key, nonce, plaintext, aad)    -- ciphertext, tag
--   crypto.gcm_decrypt(key, nonce, ciphertext, tag, aad)  -- plaintext or nil
--   crypto.sha256(text), crypto.hmac_sha256(key, text)
--   crypto.pbkdf2_sha256(password, salt, rounds, length)
--   crypto.random_bytes(n), crypto.to_hex(bytes), crypto.from_hex(text)
--
-- Keys, nonces and results are Lua strings of bytes. LuaJIT-compatible.

local bit = require("bit")
local band, bor, bxor, lshift, rshift, tobit = bit.band, bit.bor, bit.bxor, bit.lshift,
    bit.rshift, bit.tobit
local byte, char, concat = string.byte, string.char, table.concat

local M = {}

-- {{{ bytes and words
-- A 32-bit big-endian word from four bytes of `text` at `at`, and back.
local function word_at(text, at)
    local a, b, c, d = byte(text, at, at + 3)
    return tobit(bor(lshift(a, 24), lshift(b, 16), lshift(c, 8), d))
end

local function word_bytes(w)
    return char(band(rshift(w, 24), 255), band(rshift(w, 16), 255),
                band(rshift(w, 8), 255), band(w, 255))
end
-- }}}

-- {{{ function M.to_hex() and M.from_hex()
function M.to_hex(bytes)
    return (string.gsub(bytes, ".", function(c) return string.format("%02x", byte(c)) end))
end

-- Lower or upper case, an even number of digits, nothing else; nil otherwise.
function M.from_hex(text)
    if type(text) ~= "string" or #text % 2 ~= 0 or string.find(text, "[^%x]") then
        return nil
    end
    return (string.gsub(text, "%x%x", function(pair) return char(tonumber(pair, 16)) end))
end
-- }}}

-- {{{ function M.random_bytes()
-- From the system's own source of randomness; never from math.random.
function M.random_bytes(count)
    local handle = assert(io.open("/dev/urandom", "rb"), "crypto: /dev/urandom cannot be read")
    local bytes = handle:read(count)
    handle:close()
    assert(bytes and #bytes == count, "crypto: /dev/urandom gave too few bytes")
    return bytes
end
-- }}}

-- {{{ AES
-- The cipher of FIPS 197, encryption only (GCM never runs it backwards), with
-- the usual four round tables built at load from the S-box, which is itself
-- worked out from its definition (inverse in GF(2^8), then the affine map).

-- {{{ the tables
local SBOX, T0, T1, T2, T3 = {}, {}, {}, {}, {}
do
    -- powers and logs of 3, the generator, for inverses
    local exp, log = {}, {}
    local x = 1
    for i = 0, 254 do
        exp[i], log[x] = x, i
        local double = band(lshift(x, 1), 255)
        if band(x, 128) ~= 0 then double = bxor(double, 0x1b) end
        x = bxor(x, double)    -- times 3
    end
    local function rotl8(v, n) return band(bor(lshift(v, n), rshift(v, 8 - n)), 255) end
    for v = 0, 255 do
        local inverse = v == 0 and 0 or exp[(255 - log[v]) % 255]
        SBOX[v] = bxor(inverse, rotl8(inverse, 1), rotl8(inverse, 2), rotl8(inverse, 3),
            rotl8(inverse, 4), 0x63)
    end
    for v = 0, 255 do
        local s = SBOX[v]
        local s2 = band(lshift(s, 1), 255)
        if band(s, 128) ~= 0 then s2 = bxor(s2, 0x1b) end
        local s3 = bxor(s2, s)
        T0[v] = tobit(bor(lshift(s2, 24), lshift(s, 16), lshift(s, 8), s3))
        T1[v] = tobit(bor(lshift(s3, 24), lshift(s2, 16), lshift(s, 8), s))
        T2[v] = tobit(bor(lshift(s, 24), lshift(s3, 16), lshift(s2, 8), s))
        T3[v] = tobit(bor(lshift(s, 24), lshift(s, 16), lshift(s3, 8), s2))
    end
end
-- }}}

-- {{{ local function expand_key()
-- The 60 round-key words of a 32-byte key.
local function expand_key(key)
    assert(type(key) == "string" and #key == 32, "crypto: an AES-256 key is 32 bytes")
    local w = {}
    for i = 0, 7 do w[i] = word_at(key, i * 4 + 1) end
    local rcon = 1
    for i = 8, 59 do
        local t = w[i - 1]
        if i % 8 == 0 then
            t = bor(lshift(SBOX[band(rshift(t, 16), 255)], 24),
                    lshift(SBOX[band(rshift(t, 8), 255)], 16),
                    lshift(SBOX[band(t, 255)], 8),
                    SBOX[band(rshift(t, 24), 255)])
            t = bxor(t, lshift(rcon, 24))
            rcon = rcon * 2    -- 01 to 40: AES-256 needs seven, so it never wraps
        elseif i % 8 == 4 then
            t = bor(lshift(SBOX[band(rshift(t, 24), 255)], 24),
                    lshift(SBOX[band(rshift(t, 16), 255)], 16),
                    lshift(SBOX[band(rshift(t, 8), 255)], 8),
                    SBOX[band(t, 255)])
        end
        w[i] = tobit(bxor(w[i - 8], t))
    end
    return w
end
-- }}}

-- {{{ local function encrypt_block()
-- One 16-byte block as four words in, four words out.
local function encrypt_block(w, a, b, c, d)
    a, b, c, d = bxor(a, w[0]), bxor(b, w[1]), bxor(c, w[2]), bxor(d, w[3])
    local k = 4
    for _ = 1, 13 do
        a, b, c, d =
            bxor(T0[band(rshift(a, 24), 255)], T1[band(rshift(b, 16), 255)],
                 T2[band(rshift(c, 8), 255)], T3[band(d, 255)], w[k]),
            bxor(T0[band(rshift(b, 24), 255)], T1[band(rshift(c, 16), 255)],
                 T2[band(rshift(d, 8), 255)], T3[band(a, 255)], w[k + 1]),
            bxor(T0[band(rshift(c, 24), 255)], T1[band(rshift(d, 16), 255)],
                 T2[band(rshift(a, 8), 255)], T3[band(b, 255)], w[k + 2]),
            bxor(T0[band(rshift(d, 24), 255)], T1[band(rshift(a, 16), 255)],
                 T2[band(rshift(b, 8), 255)], T3[band(c, 255)], w[k + 3])
        k = k + 4
    end
    local function last(p, q, r, s, key)
        return tobit(bxor(bor(lshift(SBOX[band(rshift(p, 24), 255)], 24),
            lshift(SBOX[band(rshift(q, 16), 255)], 16),
            lshift(SBOX[band(rshift(r, 8), 255)], 8),
            SBOX[band(s, 255)]), key))
    end
    return last(a, b, c, d, w[56]), last(b, c, d, a, w[57]),
           last(c, d, a, b, w[58]), last(d, a, b, c, w[59])
end
-- }}}

-- {{{ function M.aes256_block()
-- One block, for the tests against FIPS 197's own example.
function M.aes256_block(key, block)
    local a, b, c, d = encrypt_block(expand_key(key), word_at(block, 1), word_at(block, 5),
        word_at(block, 9), word_at(block, 13))
    return word_bytes(a) .. word_bytes(b) .. word_bytes(c) .. word_bytes(d)
end
-- }}}
-- }}}

-- {{{ GCM
-- NIST SP 800-38D with a 12-byte nonce and a 16-byte tag, the only shape this
-- project uses (rmail's, and the page's).

-- {{{ local function gf_multiply()
-- X times Y in GCM's field, each four words, bit by bit (Algorithm 1 of the
-- standard). A canvas is a hundred blocks or so; this is quick enough.
local function gf_multiply(x1, x2, x3, x4, y1, y2, y3, y4)
    local z1, z2, z3, z4 = 0, 0, 0, 0
    local xs = { x1, x2, x3, x4 }
    for word = 1, 4 do
        local x = xs[word]
        for bit_index = 31, 0, -1 do
            if band(rshift(x, bit_index), 1) == 1 then
                z1, z2, z3, z4 = bxor(z1, y1), bxor(z2, y2), bxor(z3, y3), bxor(z4, y4)
            end
            local carry = band(y4, 1)
            y4 = bor(rshift(y4, 1), lshift(band(y3, 1), 31))
            y3 = bor(rshift(y3, 1), lshift(band(y2, 1), 31))
            y2 = bor(rshift(y2, 1), lshift(band(y1, 1), 31))
            y1 = rshift(y1, 1)
            if carry == 1 then y1 = bxor(y1, tobit(0xe1000000)) end
        end
    end
    return tobit(z1), tobit(z2), tobit(z3), tobit(z4)
end
-- }}}

-- {{{ local function ghash()
-- GHASH over the additional data, then the ciphertext, each padded to whole
-- blocks, then their lengths in bits.
local function ghash(h1, h2, h3, h4, aad, ciphertext)
    local s1, s2, s3, s4 = 0, 0, 0, 0
    local function absorb(text)
        local padded = text .. string.rep("\0", (16 - #text % 16) % 16)
        for at = 1, #padded, 16 do
            s1, s2, s3, s4 = gf_multiply(bxor(s1, word_at(padded, at)),
                bxor(s2, word_at(padded, at + 4)), bxor(s3, word_at(padded, at + 8)),
                bxor(s4, word_at(padded, at + 12)), h1, h2, h3, h4)
        end
    end
    absorb(aad)
    absorb(ciphertext)
    -- lengths in bits, as two 64-bit numbers; a canvas is far below 2^29 bytes
    local a_bits, c_bits = #aad * 8, #ciphertext * 8
    s1, s2, s3, s4 = gf_multiply(bxor(s1, tobit(math.floor(a_bits / 4294967296))),
        bxor(s2, tobit(a_bits % 4294967296)),
        bxor(s3, tobit(math.floor(c_bits / 4294967296))),
        bxor(s4, tobit(c_bits % 4294967296)), h1, h2, h3, h4)
    return s1, s2, s3, s4
end
-- }}}

-- {{{ local function counter_mode()
-- The text XORed with E(K, J0 + 1), E(K, J0 + 2) ... (GCTR from inc32(J0)).
local function counter_mode(w, n1, n2, n3, text)
    local out = {}
    local counter = 2
    for at = 1, #text, 16 do
        local k1, k2, k3, k4 = encrypt_block(w, n1, n2, n3, tobit(counter))
        local stream = word_bytes(k1) .. word_bytes(k2) .. word_bytes(k3) .. word_bytes(k4)
        local piece = string.sub(text, at, at + 15)
        local bytes = {}
        for i = 1, #piece do
            bytes[i] = char(bxor(byte(piece, i), byte(stream, i)))
        end
        out[#out + 1] = concat(bytes)
        counter = counter + 1
    end
    return concat(out)
end
-- }}}

-- {{{ local function setup()
local function setup(key, nonce)
    assert(type(nonce) == "string" and #nonce == 12, "crypto: a GCM nonce here is 12 bytes")
    local w = expand_key(key)
    local h1, h2, h3, h4 = encrypt_block(w, 0, 0, 0, 0)
    local n1, n2, n3 = word_at(nonce, 1), word_at(nonce, 5), word_at(nonce, 9)
    local e1, e2, e3, e4 = encrypt_block(w, n1, n2, n3, 1)    -- E(K, J0), for the tag
    return w, h1, h2, h3, h4, n1, n2, n3, e1, e2, e3, e4
end

local function tag_of(h1, h2, h3, h4, e1, e2, e3, e4, aad, ciphertext)
    local s1, s2, s3, s4 = ghash(h1, h2, h3, h4, aad, ciphertext)
    return word_bytes(bxor(s1, e1)) .. word_bytes(bxor(s2, e2))
        .. word_bytes(bxor(s3, e3)) .. word_bytes(bxor(s4, e4))
end
-- }}}

-- {{{ function M.gcm_encrypt()
-- The ciphertext (as long as the plaintext) and the 16-byte tag.
function M.gcm_encrypt(key, nonce, plaintext, aad)
    aad = aad or ""
    local w, h1, h2, h3, h4, n1, n2, n3, e1, e2, e3, e4 = setup(key, nonce)
    local ciphertext = counter_mode(w, n1, n2, n3, plaintext)
    return ciphertext, tag_of(h1, h2, h3, h4, e1, e2, e3, e4, aad, ciphertext)
end
-- }}}

-- {{{ function M.gcm_decrypt()
-- The plaintext, or nil when the tag does not match (a wrong key, or text
-- changed on the way). The tags are compared without stopping early.
function M.gcm_decrypt(key, nonce, ciphertext, tag, aad)
    aad = aad or ""
    if type(tag) ~= "string" or #tag ~= 16 then return nil end
    local w, h1, h2, h3, h4, n1, n2, n3, e1, e2, e3, e4 = setup(key, nonce)
    local expected = tag_of(h1, h2, h3, h4, e1, e2, e3, e4, aad, ciphertext)
    local difference = 0
    for i = 1, 16 do
        difference = bor(difference, bxor(byte(expected, i), byte(tag, i)))
    end
    if difference ~= 0 then return nil end
    return counter_mode(w, n1, n2, n3, ciphertext)
end
-- }}}

-- {{{ function M.seal() and M.open()
-- What travels: a fresh random 12-byte nonce, the ciphertext, the tag, in
-- that order (the page reads it the same way). `aad` is text both sides know
-- and bind the lock to, never sent.
function M.seal(key, plaintext, aad)
    local nonce = M.random_bytes(12)
    local ciphertext, tag = M.gcm_encrypt(key, nonce, plaintext, aad)
    return nonce .. ciphertext .. tag
end

function M.open(key, sealed, aad)
    if type(sealed) ~= "string" or #sealed < 28 then
        return nil, "too short to be sealed"
    end
    local text = M.gcm_decrypt(key, string.sub(sealed, 1, 12), string.sub(sealed, 13, -17),
        string.sub(sealed, -16), aad)
    if not text then return nil, "the key is wrong, or it was changed on the way" end
    return text
end
-- }}}
-- }}}

-- {{{ SHA-256, HMAC, PBKDF2
-- FIPS 180-4, RFC 2104, RFC 8018.

-- {{{ local K and compress()
local K = {}
do
    local values = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }
    for i, v in ipairs(values) do K[i - 1] = tobit(v) end
end

local INITIAL = { tobit(0x6a09e667), tobit(0xbb67ae85), tobit(0x3c6ef372), tobit(0xa54ff53a),
                  tobit(0x510e527f), tobit(0x9b05688c), tobit(0x1f83d9ab), tobit(0x5be0cd19) }

local ror = bit.ror
local W = {}

-- The state (eight words) after one 64-byte block, given as 16 words.
local function compress(h, m)
    for i = 0, 15 do W[i] = m[i + 1] end
    for i = 16, 63 do
        local a, b = W[i - 15], W[i - 2]
        local s0 = bxor(ror(a, 7), ror(a, 18), rshift(a, 3))
        local s1 = bxor(ror(b, 17), ror(b, 19), rshift(b, 10))
        W[i] = tobit(W[i - 16] + s0 + W[i - 7] + s1)
    end
    local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
    for i = 0, 63 do
        local S1 = bxor(ror(e, 6), ror(e, 11), ror(e, 25))
        local ch = bxor(band(e, f), band(bit.bnot(e), g))
        local t1 = hh + S1 + ch + K[i] + W[i]
        local S0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
        local maj = bxor(band(a, b), band(a, c), band(b, c))
        hh, g, f, e, d, c, b, a = g, f, e, tobit(d + t1), c, b, a, tobit(t1 + S0 + maj)
    end
    return { tobit(h[1] + a), tobit(h[2] + b), tobit(h[3] + c), tobit(h[4] + d),
             tobit(h[5] + e), tobit(h[6] + f), tobit(h[7] + g), tobit(h[8] + hh) }
end
-- }}}

-- {{{ local function digest_from()
-- SHA-256 of `text`, continuing from `state` after `before` bytes already
-- hashed (HMAC starts from its keyed state). Returns the eight words.
local function digest_from(state, before, text)
    local length = before + #text
    local padded = text .. "\128" .. string.rep("\0", (55 - #text) % 64)
    local bits = length * 8
    padded = padded .. word_bytes(tobit(math.floor(bits / 4294967296)))
        .. word_bytes(tobit(bits % 4294967296))
    local h = state
    for at = 1, #padded, 64 do
        local m = {}
        for i = 0, 15 do m[i + 1] = word_at(padded, at + i * 4) end
        h = compress(h, m)
    end
    return h
end

local function words_bytes(h)
    local out = {}
    for i = 1, #h do out[i] = word_bytes(h[i]) end
    return concat(out)
end
-- }}}

-- {{{ function M.sha256()
function M.sha256(text)
    return words_bytes(digest_from(INITIAL, 0, text))
end
-- }}}

-- {{{ local function hmac_states()
-- The inner and outer states after the key's 64-byte pads: each HMAC then
-- costs two short hashes from these, which PBKDF2 does thousands of times.
local function hmac_states(key)
    if #key > 64 then key = M.sha256(key) end
    key = key .. string.rep("\0", 64 - #key)
    local inner, outer = {}, {}
    for i = 1, 64 do
        local k = byte(key, i)
        inner[i], outer[i] = char(bxor(k, 0x36)), char(bxor(k, 0x5c))
    end
    local function state_after(pad)
        local m = {}
        for i = 0, 15 do m[i + 1] = word_at(pad, i * 4 + 1) end
        return compress(INITIAL, m)
    end
    return state_after(concat(inner)), state_after(concat(outer))
end

local function hmac_with(inner, outer, text)
    return words_bytes(digest_from(outer, 64, words_bytes(digest_from(inner, 64, text))))
end
-- }}}

-- {{{ function M.hmac_sha256()
function M.hmac_sha256(key, text)
    local inner, outer = hmac_states(key)
    return hmac_with(inner, outer, text)
end
-- }}}

-- {{{ function M.pbkdf2_sha256()
-- The key a password makes: `length` bytes after `rounds` rounds.
-- Each round's 32-byte HMAC is one block in and one block out of each state,
-- so the rounds are done on words, not strings.
function M.pbkdf2_sha256(password, salt, rounds, length)
    assert(type(rounds) == "number" and rounds >= 1, "crypto: PBKDF2 needs at least one round")
    local inner, outer = hmac_states(password)
    -- the padding of a 32-byte message hashed after one 64-byte block
    local PAD = { tobit(0x80000000), 0, 0, 0, 0, 0, 0, (64 + 32) * 8 }
    local function round(u)
        local m = {}
        for i = 1, 8 do m[i] = u[i] end
        for i = 1, 8 do m[8 + i] = PAD[i] end
        local first = compress(inner, m)
        for i = 1, 8 do m[i] = first[i] end
        return compress(outer, m)
    end
    local out = {}
    local blocks = math.ceil(length / 32)
    for index = 1, blocks do
        local u = digest_from(outer, 64,
            words_bytes(digest_from(inner, 64, salt .. word_bytes(index))))
        local t = { u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8] }
        for _ = 2, rounds do
            u = round(u)
            for i = 1, 8 do t[i] = bxor(t[i], u[i]) end
        end
        out[#out + 1] = words_bytes(t)
    end
    return string.sub(concat(out), 1, length)
end
-- }}}
-- }}}

return M
