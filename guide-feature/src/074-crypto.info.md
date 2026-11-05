# 074-crypto — info

The canvas server's locks (issue 803), in plain LuaJIT with no library: the
canvas server stays one Lua program with nothing to build.

| Name | Meaning |
|---|---|
| `seal(key, plaintext, aad)` | a fresh 12-byte nonce, the ciphertext, the 16-byte tag (what travels) |
| `open(key, sealed, aad)` | the plaintext, or nil and why ("too short to be sealed"; "the key is wrong, or it was changed on the way") |
| `gcm_encrypt(key, nonce, plaintext, aad)` | AES-256-GCM: ciphertext, tag |
| `gcm_decrypt(key, nonce, ciphertext, tag, aad)` | the plaintext, or nil; the tags are compared without stopping early |
| `aes256_block(key, block)` | one AES-256 block (FIPS 197) |
| `sha256(text)`, `hmac_sha256(key, text)` | FIPS 180-4, RFC 2104 |
| `pbkdf2_sha256(password, salt, rounds, length)` | RFC 8018; about 180,000 rounds a second |
| `random_bytes(n)` | from `/dev/urandom` |
| `to_hex(bytes)`, `from_hex(text)` | nil for odd or non-hex text |

Its AES looks up tables, as most software AES does. A program on the same
machine could time it. It is checked against each standard's published
examples (`075-test-crypto.lua`). The browser's side is noble-ciphers.
