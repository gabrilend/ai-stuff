# Phase 4 — People connect

**Goal:** the geometry from phase 2 starts deciding which bytes are allowed onto
a socket.

**Status: complete.** All eight issues done. `./run-phase-demo 4` puts three
participants on real sockets and searches their raw outbound bytes.

## The issues

| Issue | What it established |
| --- | --- |
| [401 the door hands out a port](completed/401-the-door-hands-out-a-port.md) | One always-open port, a range behind it, and a refusal that names what to change. |
| [402 a session is a socket](completed/402-a-session-is-a-socket.md) | The port number is the identity, resolved by the kernel before our code runs. |
| [403 the wire format](completed/403-the-wire-format.md) | An opcode and a chain of positional flag words. Nobody sends a length. |
| [404 one function writes to a socket](completed/404-one-function-writes-to-a-socket.md) | The whole security model, in one static function with one caller. |
| [405 refusals are sentences](completed/405-refusals-are-sentences.md) | Because nobody reads a rules screen. |
| [406 commands run a gauntlet](completed/406-commands-run-a-gauntlet.md) | The gates, in order, with the later ones stubbed in place. |
| [407 the leak test](completed/407-the-leak-test.md) | Searching bytes, and every case run inverted. |
| [408 the phase four demo](completed/408-the-phase-four-demo.md) | The capstone. |

## What is built

| Source | What it is |
| --- | --- |
| `056-protocol` | The flag chain, the slot table, the register file. |
| `058-viewer` | One participant, their memory, and their two buffers. |
| `059-outbound` | Four gates and one door out. |
| `061-door` | The only file that knows what a socket is. |
| `063-demo-phase-4` | Three people, real sockets, a leak sweep. |

## The decisions that shaped it

**The leak test searches raw bytes, not the filter.** Asking the filter whether it
would have sent something is asking the accused — a test that shares an
implementation with the thing it tests agrees with it about the bug too.

**And every case runs inverted.** A leak test that passes because it searched for
the wrong bytes is worse than no test, because it retires the suspicion. So each
case also moves the body into view and asserts the search now *does* find it.

**The stubbed gates return "admits nothing".** Scopes arrive in phase 6, so gate 1
is not yet real — and it is stubbed in the direction that cannot leak. A stub
returning "yes" would have quietly disabled everything below it.

**Sockets are quarantined in one file.** Everything above works on buffers, which
is what lets the leak test run exhaustively on every build without a network.

## What the numbers came out as

Reported by the demo rather than fixed here. As of the phase's close: about 150
microseconds to build one viewer's update, roughly a kilobyte of it — about 19
kilobytes a second per person at twenty beats. Most of it is walls, which come
from memory and stop growing once somebody has explored the map.

## What building it taught

**The validator caught the demo.** An early version set every body's `region` to
1, and the world was refused before a single socket opened — the east room is
region 3. That check exists for the motion pass drifting, and it caught a
demo author instead, which is the same bug wearing different clothes.

**A guessed number failed a leak test.** An assertion that "more than twelve
walls" would be remembered was wrong, because a wall is remembered by its
midpoint and the fixture's geometry does not oblige. Replaced with the property
that actually matters — memory only grows — rather than a number tuned until it
passed.

## Blocking open questions

- **4.2** — what is in the `secret` field? Nothing authenticates yet, and building
  a check before deciding what a secret is would mean building the wrong one.
- **4.3** — how large can a table get? Sets the range, the pool size, and whether
  `SEES_REGION` is an optimisation or a necessity.
- **4.4** — what happens when somebody drops? The fog currently survives, which is
  the reversible choice and is not the same as the decided one.
- **13.3** — commands declared past the point a retcon replays to. Phase 3 said
  this would surface here; it has not yet, because nothing declares ahead.

## What phase 5 inherits

A server that fills a buffer with exactly what one person is allowed to know, and
a wire format that a browser can be taught. What is missing is the bridge and
anything that draws.
