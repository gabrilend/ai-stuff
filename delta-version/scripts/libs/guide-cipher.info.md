# libs/guide-cipher.lua — info

The guide's own cipher, version one (issue 065f). Home-made: keeps out a
casual reader, not an expert; detects a wrong key, not a changed message.

| | |
|---|---|
| `M.make_key()` | 32 random bytes (string) from /dev/urandom |
| `M.encrypt(key, text [, nonce])` | sealed string: version line, 16-byte nonce, then marker + text mixed with the stream. Nonce fresh each call unless given (tests). |
| `M.decrypt(key, sealed)` | the text; errors on unknown version, too short, or wrong key |
| `M.stream_sample(key, nonce, count)` | the first `count` stream bytes (integers 0–255), for measuring |
| `M.to_hex(text)`, `M.from_hex(text)` | bytes ↔ hex text, one sealed message per line |
| `M.version` | `"ialmstla-cipher 1"` |

## How the stream is made

1. Key and nonce fold into the logistic map's settings: r in [3.9, 4.0) (past
   the threshold near 3.57 where it splits into chaos), x in (0.05, 0.95).
2. 1000 steps thrown away, so the start forgets the seed.
3. Each step: x → r·x·(1−x); 32 bits of x cut into 2..65536 and replaced by
   the nearest prime (table built once by sieve); output byte = that prime
   mixed (exclusive-or) with two other slices of x.
4. A step that lands within a hair of 0 or 1 is pushed back into the middle,
   so the stream never freezes.

## How even the stream is

Run `test-guide-cipher.sh` (each byte value within 15% of even over 262 144
bytes; keys one byte apart agree on under 2% of bytes). A chi-square over a
mebibyte can be had from `M.stream_sample` and lands where a fair stream does.

## First upgrade worth making

A keyed checksum, so a message changed on disk is detected, not just a wrong key.
