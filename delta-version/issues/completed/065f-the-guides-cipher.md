# Issue 065f: The Guide's Cipher

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065e
**Blocks**: 065g

## Current Behavior
`scripts/libs/guide-cipher.lua` encrypts and decrypts; `scripts/libs/guide-trail.lua`
writes a walk's notes into a guide's room only encrypted. Tests:
`scripts/test-guide-cipher.sh`.

## Intended Behavior
The cipher she described: "a step that bifurcates into unpredictable answers
past a threshold" — the logistic map, run with r between 3.9 and 4.0, past the
point near 3.57 where it splits into chaos — mixed with "pick a random number,
take the nearest prime". Key and a fresh 16-byte nonce choose the map's
settings; each step's number is cut to a range, swapped for its nearest
prime, and folded into one output byte; the message is mixed with that
stream by exclusive-or, which undoes itself. A known marker encrypted ahead of
every message catches a wrong key. Every message carries a version line so an
upgraded cipher can sit beside this one: "the robot can upgrade it later,
let's just make sure it works."

The trail: one encrypted note per line in `trail-<walk>.trail`, listed as kept
when begun and dated as an extension with each note. The key lives in the
room as `guide.key`, made owner-only before the key is written into it.

## Suggested Implementation Steps
1. Nearest-prime table by sieve; seed from key and nonce; keystream; mix.
2. Version line, nonce, marker; hex for one message per line.
3. Trail writer and reader over the room's ledgers.
4. Tests: round trips, wrong key, fresh nonce, no plain text on disk, even
   byte counts, one-byte key change, ledger check after writing.

## Decided against
- Reusing one stream for every message: two messages mixed with the same
  stream give away their difference, so every message gets its own nonce.
- Claiming it is strong: it is home-made, and chaos-based ciphers are a
  known-weak family. It does not detect a message altered on disk; a keyed
  checksum is the first upgrade.
