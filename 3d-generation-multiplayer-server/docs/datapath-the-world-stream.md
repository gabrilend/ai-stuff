# datapath — the world stream

*session key → an encrypted header stream → a table of things that exist → a
frame's worth of truth*

The second conversation, on a second port, and a much larger one. Where the
login server is six messages and then silence, the world server is a permanent
duplex stream that never stops until the socket closes.

---

## Three layers, stacked

```
   TCP socket
       │
       ▼
   ┌──────────────────────────────────────────────────┐
   │  the cipher   only headers are encrypted;        │  RC4, one stream per
   │               bodies are plain                   │  direction, never reset
   └────────────────────────┬─────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────┐
   │  the frame    size + opcode + body               │  variable header width
   └────────────────────────┬─────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────┐
   │  the dispatch opcode → handler, by index         │  a table, not a switch
   └──────────────────────────────────────────────────┘
```

The layers are worth keeping apart because they fail differently. A cipher bug
desynchronises the stream permanently and every subsequent packet is garbage. A
framing bug shows up as one absurd length. A dispatch bug is a packet politely
ignored. Told apart, each is a ten-minute diagnosis; conflated, they are a week.

---

## Getting in

```
   client                                                    world server
     │                                                       (TCP 8085)
     │◀─── AUTH_CHALLENGE   a random 32-bit seed ────────────│   plaintext
     │                                                        │
     │  digest = SHA1( account ‖ 0u32 ‖ our seed ‖ their seed ‖ K )
     │                                                        │
     │──── AUTH_SESSION  build, account, our seed, digest ───▶│   plaintext
     │                                                        │
     │        ── both sides now switch the cipher on ──       │
     │                                                        │
     │◀─── AUTH_RESPONSE   accepted, expansion level ─────────│   encrypted header
     │──── CHAR_ENUM ────────────────────────────────────────▶│
     │◀─── CHAR_ENUM   the characters on this account ────────│
     │──── PLAYER_LOGIN  the chosen character's id ──────────▶│
     │◀─── LOGIN_VERIFY_WORLD  map, x, y, z, facing ──────────│
     │◀─── UPDATE_OBJECT  everything visible, including us ───│
     │                                                        │
     │◀════════════ the stream, from here on ═══════════════▶│
```

The digest is the point of the whole exchange: it proves we hold `K` without
sending it, and it mixes in **both** seeds so a recording of a previous login
cannot be replayed. Our seed is a fresh random `u32` we choose; theirs arrived
in the challenge.

The first two messages are plaintext. The cipher engages immediately after, and
it does so on **both sides at once** — there is no acknowledgement, no
negotiation, and no way to detect a mismatch except that everything afterward is
noise. Turning the cipher on at the wrong moment is the single most likely bug
in phase 4, and the only defence is a byte-level log of the first four packets
in each direction, which is worth building before it is needed.

---

## The cipher, precisely

Two RC4 keystreams, one per direction, derived from the session key:

```
    fixed 16-byte seed  ──┐
                          ├──▶ HMAC-SHA1 ──▶ 20-byte RC4 key ──▶ RC4 ──▶ discard
    K (40 bytes)  ────────┘                                             1024 bytes
```

Two different fixed seeds — one for each direction — are used as the HMAC key
over `K`. Each resulting twenty-byte digest initialises an RC4 state, and the
first 1024 bytes of each keystream are generated and thrown away. (That discard
is a defence against a known weakness in RC4's early output; without it the
first bytes of the stream leak information about the key.)

Three properties that shape the code:

- **RC4 is a stream cipher with no framing.** Every encrypted byte advances the
  state exactly one step. Encrypt one byte too many or too few, ever, and the
  two ends are permanently out of phase. There is no resynchronisation.
- **Only headers pass through it.** Bodies are plaintext. This is an unusual
  choice and it is enormously convenient: a packet log stays half-readable, and
  a body parser can be tested against captured bytes with no crypto in the loop.
- **The two streams are independent.** Sending never disturbs receiving.

Because the seeds are constants in the server's source, our copy of them is
generated from it rather than transcribed — see the opcode note below, which
applies for the same reason.

---

## The frame

The header widths are asymmetric, which is a real property of the format and a
reliable source of off-by-two:

**Client → server, always 6 bytes**

| Field | Width | Order | Counts |
|---|---|---|---|
| size | 2 | **big**-endian | the opcode field plus the body |
| opcode | 4 | little-endian | |

**Server → client, 4 bytes, or 5 when large**

| Field | Width | Order | Counts |
|---|---|---|---|
| size | 2 | **big**-endian | the opcode field plus the body |
| opcode | 2 | little-endian | |

When a body would push the size past `0x7FFF`, the server sets the top bit of
the first byte and the header becomes five bytes with a three-byte size. So the
reader cannot decrypt a fixed number of bytes up front: it decrypts **one** byte,
inspects the high bit, and only then knows whether three or four more follow.
Getting this wrong is not a parse error — it is a cipher desynchronisation, and
it presents as garbage from that packet onward.

Note the mixed endianness within a single header. Sizes are big-endian; opcodes
and every field in every body are little-endian. This is inherited, not chosen.

---

## The opcodes are generated, never transcribed

There are roughly fifteen hundred of them, and we implement a few dozen. The
authoritative list is an enumeration in the server's own headers — the same tree
we clone on every build.

**So the client's opcode table is generated from that header at build time.**

```
    upstream/azerothcore/src/server/game/Server/Protocol/Opcodes.h
                          │
                          ▼  a small awk/sed extractor
    src/net/opcodes.generated.h     name → number, for every opcode
                          │
                          ▼  hand-written, small
    src/net/dispatch.c              number → handler, for the ones we handle
```

Three things follow from this, and they are why it is worth the extractor:

1. **We cannot mistype an opcode.** A transcription error in a number produces a
   packet that is silently ignored, with no diagnostic anywhere.
2. **Our subset stays honest.** If upstream ever retires a message we still
   handle, the generated header shrinks and that handler fails to compile. The
   client learns about the change at build time rather than by quietly ignoring
   traffic that stopped arriving.
3. **It is the same discipline as the registry.** A derived artifact that is
   recomputed cannot drift; one that is hand-maintained always does.

The dispatch itself is a **table indexed by opcode**, not a chain of comparisons
— a jump through a pointer array rather than a walk down a ladder of branches.
The unhandled case is a single default entry that returns. No log, no counter: a
message we do not implement is dropped, silently, and the receive loop carries
on to the next one.

---

## What arrives: the update block

The largest and strangest message in the protocol, and the one that actually
carries the world. It appears in two forms — plain, and zlib-compressed with the
uncompressed length as a `u32` prefix. Decompress, and the two are identical
from there.

```
    u32  number of blocks
    ├── block: u8 update type
    │           0  VALUES          — fields changed on something we know
    │           1  MOVEMENT        — it moved
    │           2  CREATE_OBJECT   — it now exists to us
    │           3  CREATE_OBJECT2  — it now exists, and it is us
    │           4  OUT_OF_RANGE    — forget these
    │           5  NEAR_OBJECTS    — these are nearby
    │      packed GUID
    │      object type byte        (player, creature, gameobject, item, …)
    │      movement block          (position, facing, speed, flags)
    │      values block            (a bitmask, then one u32 per set bit)
    └── …
```

Two encodings inside it are worth naming, because both are compression schemes
that look like corruption when misread:

**The packed GUID.** An eight-byte identifier is preceded by a mask byte; bit
*n* set means byte *n* of the identifier is present, and absent bytes are zero.
Most identifiers are small, so most of them cross the wire in two or three bytes
instead of eight.

```
    mask 0b00000101  →  two bytes follow  →  guid = 0x00000000_00__b1_00_b0
```

**The values block.** A count of 32-bit mask words, then those words, then one
`u32` for each bit set — in order. Reading it requires knowing what field
*number* means, and that mapping is another enumeration in the server's headers,
generated for the same reasons as the opcodes. Position is in the movement
block; health, level, display, faction, and the equipment slots are here.

The receiving side of this is a **pure function from bytes to a list of world
changes** — no rendering, no sockets. Which means a captured packet log replays
through it offline, and every future rendering bug can be answered by asking
whether the world model was right.

---

## What we send

Very little, which is the point. The client's entire outbound vocabulary after
login:

| Intent | Message |
|---|---|
| I am moving / I stopped / I am still moving | the movement family, each carrying a full position block |
| I clicked that | gameobject use, or set-selection for a creature |
| I want that item's contents | loot |
| I am drinking this | item use |
| I am wearing this | equip |
| I am still here | ping, answered by pong |

The movement messages carry a **movement info** structure: flags, a client
timestamp, x, y, z, facing, fall time, and optional trailing blocks that are
present only when the corresponding flag bit is set. The server relays these to
other players nearly verbatim, which is what makes other whisps move on our
screen — the same structure we send is the one we receive about everyone else.

The heartbeat is not optional. A client that stops sending movement while moving
is corrected by the server; a client that stops answering pings is disconnected.
Both are reasonable behaviours to discover deliberately rather than by accident.

---

## Where this lands in the code

```
src/net/
    rc4         two states, initialised from K, 1024 bytes discarded
    header      the one-byte peek, the variable width, the endianness
    opcodes.generated.h      ◀── extracted from the clone at build time
    dispatch    a table, opcode → handler
    update      packed guids, mask blocks, the movement structure
    session     the login-to-world state machine, and the heartbeat
src/world/
    entities    what exists, where, and with what fields
```

`src/world/` receives a list of changes and knows nothing about how they were
encoded. That boundary is what lets the whole lower half run without a window
for the entirety of phases 2 through 4.

---

## What "done" looks like

A headless program that logs in, enters a world, walks its character in a
square, and prints a running list of everything visible with positions —
against **unmodified** upstream. When that program exists, the protocol work is
finished, and every remaining problem in the project is one we chose.

## Related

- `docs/datapath-the-handshake.md` — where `K` comes from
- `docs/datapath-the-whisp.md` — what the positions eventually become
- `docs/architecture.md` — the one-way arrows between net, world, and draw
- `docs/roadmap.md` — phase 4 is this document, made real
