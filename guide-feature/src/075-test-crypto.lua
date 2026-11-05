#!/usr/bin/env luajit
-- 075-test-crypto.lua
--
-- Holds the canvas server's locks (074) to the published examples of each
-- standard: AES-256 (FIPS 197, appendix C.3), AES-256-GCM (the GCM
-- specification's test cases 13 to 16, which NIST publishes with SP
-- 800-38D), SHA-256 (FIPS 180's examples), HMAC-SHA256 (RFC 4231) and
-- PBKDF2-HMAC-SHA256 (RFC 7914, section 11). Then what the server relies on:
-- a changed byte, a wrong key or other additional data never unlocks; two
-- seals of one text differ; hex reads back.
--
-- For a general: the canvas crosses the open internet locked with this. If
-- it agrees with the standards' own answers, a browser's copy of the same
-- standard (noble-ciphers) unlocks it.
--
-- usage:
--   luajit 075-test-crypto.lua [--dir ROOT]

-- {{{ DIR
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local crypto = dofile(DIR .. "/src/074-crypto.lua")
local hex, bytes = crypto.to_hex, crypto.from_hex

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

io.write("\n=== AES-256 and AES-256-GCM, against the published examples ===\n")
-- {{{
local fips = hex(crypto.aes256_block(
    bytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"),
    bytes("00112233445566778899aabbccddeeff")))
check("FIPS 197 C.3: one block", fips == "8ea2b7ca516745bfeafc49904b496089", fips)

local ZERO_KEY, ZERO_NONCE = string.rep("\0", 32), string.rep("\0", 12)
local K = bytes("feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308")
local IV = bytes("cafebabefacedbaddecaf888")
local P = bytes("d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a72"
    .. "1c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255")
local C = "522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa"
    .. "8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662898015ad"
local A = bytes("feedfacedeadbeeffeedfacedeadbeefabaddad2")
local cases = {
    { "13: nothing to lock, all zero", ZERO_KEY, ZERO_NONCE, "", "", "", "530f8afbc74536b9a963b4f1c4cb738b" },
    { "14: one zero block", ZERO_KEY, ZERO_NONCE, string.rep("\0", 16), "",
      "cea7403d4d606b6e074ec5d3baf39d18", "d0d1c8a799996bf0265b98b5d48ab919" },
    { "15: four blocks", K, IV, P, "", C, "b094dac5d93471bdec1a502270e3cc6c" },
    { "16: 60 bytes and additional data", K, IV, string.sub(P, 1, 60), A, string.sub(C, 1, 120),
      "76fc6ece0f4e1768cddf8853bb2d551b" },
}
for _, case in ipairs(cases) do
    local name, key, nonce, plain, aad, want_c, want_t = unpack(case)
    local got_c, got_t = crypto.gcm_encrypt(key, nonce, plain, aad)
    check("GCM test case " .. name .. ": the ciphertext and the tag",
        hex(got_c) == want_c and hex(got_t) == want_t, hex(got_c) .. " " .. hex(got_t))
    check("GCM test case " .. string.match(name, "^%d+") .. " unlocks again",
        crypto.gcm_decrypt(key, nonce, bytes(want_c), bytes(want_t), aad) == plain)
end
-- }}}

io.write("\n=== what never unlocks ===\n")
-- {{{
local function flip(text, at)
    return string.sub(text, 1, at - 1) .. string.char(bit.bxor(string.byte(text, at), 1))
        .. string.sub(text, at + 1)
end
local c16, t16 = bytes(string.sub(C, 1, 120)), bytes("76fc6ece0f4e1768cddf8853bb2d551b")
check("a changed byte of the ciphertext", crypto.gcm_decrypt(K, IV, flip(c16, 30), t16, A) == nil)
check("a changed byte of the tag", crypto.gcm_decrypt(K, IV, c16, flip(t16, 16), A) == nil)
check("other additional data", crypto.gcm_decrypt(K, IV, c16, t16, flip(A, 1)) == nil)
check("no additional data where there was some", crypto.gcm_decrypt(K, IV, c16, t16) == nil)
check("a wrong key", crypto.gcm_decrypt(flip(K, 32), IV, c16, t16, A) == nil)
check("another nonce", crypto.gcm_decrypt(K, flip(IV, 12), c16, t16, A) == nil)
check("a tag cut short", crypto.gcm_decrypt(K, IV, c16, string.sub(t16, 1, 15), A) == nil)
check("a tag with a byte too many", crypto.gcm_decrypt(K, IV, c16, t16 .. "\0", A) == nil)
-- }}}

io.write("\n=== sealed as it travels ===\n")
-- {{{
local canvas_text = "canvas: 3\nsize: 16x3\n\ncafé olé\nmarks:\n" .. string.rep("x", 300)
local one, two = crypto.seal(K, canvas_text, "guide-feature canvas abc"),
    crypto.seal(K, canvas_text, "guide-feature canvas abc")
check("a seal is nonce, ciphertext, tag: 28 bytes more than the text",
    #one == #canvas_text + 28)
check("it opens with the same key and the same words beside it",
    crypto.open(K, one, "guide-feature canvas abc") == canvas_text)
check("two seals of one text differ (a fresh nonce each time)", one ~= two
    and string.sub(one, 1, 12) ~= string.sub(two, 1, 12))
local nothing, why = crypto.open(K, one, "guide-feature canvas abd")
check("in another session's words it does not open, and says why", nothing == nil
    and why == "the key is wrong, or it was changed on the way", why)
local short, short_why = crypto.open(K, string.rep("x", 27))
check("something shorter than a nonce and a tag does not open, and says so",
    short == nil and short_why == "too short to be sealed", short_why)
check("random bytes: as many as asked, not the same twice",
    #crypto.random_bytes(32) == 32 and crypto.random_bytes(16) ~= crypto.random_bytes(16))
check("hex both ways, either case", hex("\0\255\16") == "00ff10"
    and bytes("00FF10") == "\0\255\16")
check("hex that is odd, or not hex, is nothing",
    bytes("abc") == nil and bytes("zz") == nil and bytes(nil) == nil)
-- }}}

io.write("\n=== SHA-256, HMAC-SHA256, PBKDF2-HMAC-SHA256 ===\n")
-- {{{
check("SHA-256 of abc (FIPS 180)", hex(crypto.sha256("abc"))
    == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
check("SHA-256 of nothing", hex(crypto.sha256(""))
    == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
check("SHA-256 of the two-block example", hex(crypto.sha256(
    "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
    == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
check("SHA-256 of a million a's", hex(crypto.sha256(string.rep("a", 1000000)))
    == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
check("HMAC-SHA256, RFC 4231 case 2", hex(crypto.hmac_sha256("Jefe",
    "what do ya want for nothing?"))
    == "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
check("HMAC-SHA256, RFC 4231 case 6: a key longer than a block", hex(crypto.hmac_sha256(
    string.rep("\170", 131), "Test Using Larger Than Block-Size Key - Hash Key First"))
    == "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54")
check("PBKDF2, RFC 7914: passwd, salt, 1 round, 64 bytes",
    hex(crypto.pbkdf2_sha256("passwd", "salt", 1, 64))
    == "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc"
    .. "49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783")
check("PBKDF2, RFC 7914: Password, NaCl, 80000 rounds, 64 bytes",
    hex(crypto.pbkdf2_sha256("Password", "NaCl", 80000, 64))
    == "4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56"
    .. "a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d")
check("PBKDF2: 32 bytes are the first 32 of 64",
    crypto.pbkdf2_sha256("passwd", "salt", 3, 32)
    == string.sub(crypto.pbkdf2_sha256("passwd", "salt", 3, 64), 1, 32))
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
