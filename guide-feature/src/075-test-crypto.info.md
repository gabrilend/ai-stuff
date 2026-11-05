# 075-test-crypto — info

Tests the canvas server's locks (074) against the standards' own examples.

    luajit src/075-test-crypto.lua --dir ROOT

- AES-256: FIPS 197 appendix C.3.
- AES-256-GCM: the GCM specification's test cases 13 to 16 (published with
  NIST SP 800-38D), each locked and unlocked.
- Never unlocks: a changed ciphertext byte or tag byte, other or no
  additional data, a wrong key, another nonce, a tag cut short or too long.
- Sealed as it travels: 28 bytes over the text, opens with the same words,
  a fresh nonce each time, too short says so, random bytes, hex.
- SHA-256 (four FIPS 180 examples, a million a's among them), HMAC-SHA256
  (RFC 4231 cases 2 and 6), PBKDF2-HMAC-SHA256 (RFC 7914's two).
