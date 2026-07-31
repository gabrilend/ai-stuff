# datapath — the handshake

*account name → a proof that never carries the password → a 40-byte session key*

The login server is a small, self-contained conversation on its own TCP port,
and it is the right first thing to build: six messages, no encryption on the
socket itself, and a well-defined success condition. When it finishes, we hold
a shared secret the world server will demand.

---

## The shape of it

```
   client                                                     auth server
     │                                                        (TCP 3724)
     │──── LOGON_CHALLENGE  account name, build, locale ──────▶│
     │                                                         │ looks up the
     │                                                         │ account's salt
     │                                                         │ and verifier
     │◀─── B, g, N, salt, 16 random bytes, security flags ─────│
     │                                                         │
     │ derives the session key from the password it was        │
     │ typed, and a proof M1 that it did so                    │
     │                                                         │
     │──── LOGON_PROOF  A, M1 ────────────────────────────────▶│
     │                                                         │ derives the same
     │                                                         │ key independently
     │                                                         │ and checks M1
     │◀─── M2, account flags ─────────────────────────────────│
     │                                                         │
     │──── REALM_LIST ────────────────────────────────────────▶│
     │◀─── [ name, host:port, population, characters ] × n ───│
     │                                                         │
     └──▶ carry the 40-byte session key K to the world server
```

Both sides end up holding **K**, forty bytes, and neither side ever put the
password on the wire. The server never even stores the password — only a salt
and a verifier derived from it, which is enough to check a proof and not enough
to reproduce the secret.

---

## The arithmetic

This is SRP-6a, with the parameters the game fixed long ago:

| Symbol | What it is | Size |
|---|---|---|
| `N` | a fixed safe prime, the modulus everything happens in | 32 bytes |
| `g` | the generator; the value is 7 | 1 byte |
| `k` | a multiplier constant; the value is 3 | — |
| `s` | the account's salt, chosen when the account was made | 32 bytes |
| `I` | the account name, uppercased | variable |
| `P` | the password, uppercased | variable |
| `a` / `A` | the client's secret and its public form | 19 / 32 bytes |
| `b` / `B` | the server's secret and its public form | 19 / 32 bytes |
| `v` | the verifier the server stores instead of a password | 32 bytes |
| `K` | the session key both sides arrive at | **40 bytes** |

All large numbers cross the wire **little-endian**, which is worth writing on
the wall: the arithmetic library will want them big-endian, and every byte-order
mistake in this subsystem produces the same symptom — a proof that does not
match, with no further information.

```
    x  =  SHA1( s ‖ SHA1( I : P ) )            the password, salted and folded
    v  =  g^x mod N                             what the server stored
    A  =  g^a mod N                             our public value
    u  =  SHA1( A ‖ B )                         a scrambling parameter
    S  =  (B − k·g^x) ^ (a + u·x)  mod N        the shared secret, 32 bytes
    K  =  interleave(S)                         40 bytes
    M1 =  SHA1( (SHA1(N) ⊕ SHA1(g)) ‖ SHA1(I) ‖ s ‖ A ‖ B ‖ K )
    M2 =  SHA1( A ‖ M1 ‖ K )
```

The server computes `S = (A · v^u) ^ b mod N` from its side and reaches the same
value by a different road. That is the whole trick of the protocol: two parties,
two different formulas, one number.

### The interleave, which is the step everyone gets wrong

`K` is not a hash of `S`. It is **two** hashes, woven together:

```
    S (32 bytes)   s0 s1 s2 s3 s4 s5 … s30 s31
                    │  │  │  │
        even bytes ─┴──┼──┴──┼─────────▶ SHA1 ─▶ 20 bytes ─▶ K[0], K[2], K[4] …
        odd  bytes ────┴─────┴─────────▶ SHA1 ─▶ 20 bytes ─▶ K[1], K[3], K[5] …
```

Take every even-indexed byte of `S` into one 16-byte buffer and every
odd-indexed byte into another, hash each, then interleave the two twenty-byte
digests to make forty bytes. The result is `K`, and it is the input to
everything the world server does with encryption.

Two hazards live here, both silent:

- **Leading zeros.** `S` is a modular result and may have high-order zero bytes.
  Whether those are stripped before splitting changes the answer entirely. The
  convention is to operate on `S` as a fixed 32-byte little-endian buffer.
- **The order of the weave.** Even bytes produce the even-indexed half of `K`.
  Swapping them yields a perfectly plausible forty bytes that fails one message
  later, at the world server, far from the mistake.

Both deserve a test with a known-good vector before anything else is built on
top. The server we are cloning contains a working implementation, which makes
generating those vectors a matter of running it rather than deriving them.

---

## The messages, byte for byte

Everything is packed with no alignment padding. Strings are length-prefixed or
null-terminated depending on the message, which is a genuine inconsistency in
the format and not a transcription error.

**Challenge, client → server**

| Field | Type | Note |
|---|---|---|
| opcode | `u8` | `0x00` |
| error | `u8` | unused in the request |
| size | `u16` | bytes following this field |
| game name | `char[4]` | `"WoW\0"` |
| version | `u8 × 3` | e.g. 3, 3, 5 |
| build | `u16` | 12340 for this protocol |
| platform, os, country | `char[4] × 3` | **reversed** four-character codes |
| timezone bias | `u32` | minutes |
| ip | `u32` | the client's own, as it believes it |
| account length | `u8` | |
| account | `char[n]` | uppercased, not null-terminated |

**Challenge reply, server → client**

Opcode, an unused byte, an error byte, then `B` (32), the length of `g` and `g`,
the length of `N` and `N`, the salt (32), sixteen random bytes, and a security
flags byte. The flags byte can request a second factor; for our own server it
will be zero, and the client is entitled to refuse anything else loudly rather
than guessing.

**Proof, client → server**

Opcode `0x01`, then `A` (32), `M1` (20), a CRC hash (20), a key count byte, and
a security flags byte. The CRC field is where the original client attested to
its own file integrity. Ours has no such files. It sends zeros, and the server
does not check — a small, early, concrete instance of the client being
*liberated* rather than *imitating*.

**Proof reply, server → client**

Opcode, an error byte, `M2` (20), account flags (`u32`), a survey id (`u32`),
and an unknown `u16`. If the error byte is non-zero, the reason is in it, and
the client should say which reason rather than reporting a generic failure.

**Realm list**

Opcode `0x10` and a `u32`. The reply carries a count and then, per realm: a type
byte, a lock byte, a flags byte, a null-terminated name, a null-terminated
`"host:port"`, a population float, a character count, a timezone, and one more
byte. The `host:port` string is the entire point of the message — it is how the
client learns where the world server is, rather than being told at compile time.

---

## Where this lands in the code

```
src/net/
    bignum      modular exponentiation over 32-byte values;
                little-endian in, little-endian out
    sha1        the one hash the entire login uses
    srp6        x, A, u, S, K, M1, M2 — pure functions, no socket
    packet      a cursor over a byte buffer: read_u8, read_u32,
                read_cstring, read_bytes — bounds-checked, one place
    auth        the six-message conversation, as a state machine
```

`srp6` takes bytes and returns bytes and never touches a socket, which is what
makes the known-answer tests possible. `auth` owns the conversation and holds no
arithmetic. The split is not decoration: every bug in this subsystem presents
identically — *the proof did not match* — so the only way to debug it is to be
able to test the mathematics without a server and the conversation without a
password.

### A note on the big-number arithmetic

Modular exponentiation with a 32-byte modulus is the one piece of real
mathematics in the client. Two honest options: link the same crypto library the
server already depends on, or write a small fixed-width modular exponentiation
by hand — a few hundred lines of C for a 256-bit modulus with no need for
constant-time discipline, since the values here are not long-lived secrets on a
machine an attacker shares.

Writing it by hand is more in keeping with the project, and it is one of the
places where the question *"can you write this part in assembly?"* has an
obviously interesting answer. Linking the library is faster to a working login.
This is an open question in the roadmap rather than a decision made in passing.

---

## What "done" looks like

A headless program that reads `input/account`, connects, completes all six
messages, prints the realm list, and prints the forty bytes of `K` — against
**unmodified** upstream, with no patches applied at all. That is the first proof
that the client is real, and it needs no window, no geometry, and no art.

## Related

- `docs/datapath-the-world-stream.md` — what `K` is used for
- `docs/architecture.md` — why the client speaks the original protocol first
- `docs/roadmap.md` — phase 2 is this document, made real
