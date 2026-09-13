# 703 — Reaching a peer from a computer

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 702 |
| Blocks | 704, 706 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | F5 |

## Current behavior

Nothing. No bytes leave the machine. The dependency manifest in `input/`
records the socket library LuaJIT already ships with, and `./install-dependencies`
checks that it can be required. `tests/025-other-players.lua` looks for a
`transport-loopback` stem — a transport with no wire, delivering in order — and
asserts the lockstep layer above it never mentions which transport it has.

## Intended behavior

On a computer the wire is **UDP on the local network**, and a batch is one
datagram. The transport is a record with three functions and nothing else:

- `open()` — binds the port named in `input/`, returns the transport
- `send(peer, datagram)` — one batch, or one request, to one peer
- `receive()` — everything that has arrived, in arrival order, as records

Two transports share that shape: the UDP one and a **loopback** one for tests,
which delivers to a table in the same process, in order, with no wire. The
lockstep module picks one by name from a dispatch table read out of `input/`
and never learns which it got. That is the whole reason the shape is three
functions: a transport that offered a fourth would be one the tests could not
stand in for.

**Lost datagrams are the normal case.** A machine that is waiting on a peer's
batch for tick T sends a **want** datagram naming T after a short wait, and
sends it again on a counter until the batch arrives. Every machine keeps every
batch it has sent until every peer has acknowledged the tick; the
acknowledgement rides on every batch as a field — "the highest tick I hold from
you" — so there is no separate acknowledgement message. A batch that arrives
late is as good as one that arrived on time until the delay runs out, which is
why nothing here needs to be reliable in the transport's sense.

The datagram is a flat encoding: a kind, the sender's id, the tick, the
acknowledged tick, a count, and then the commands as the door already stores
them, every field an integer or a length-prefixed string. No text format, no
nesting, and a decoder that refuses a malformed datagram by name.

Nothing is encrypted and nothing is authenticated. Every machine already holds
the whole world, so there is nothing on the wire to protect (F5 is the
question of whether to do it anyway).

## Suggested implementation steps

1. Claim `transport-loopback` first, because the tests use it: `open`, `send`,
   `receive`, a queue per peer in one table.
2. Claim `transport-udp`: the same three functions over the socket library's
   datagram socket, non-blocking, bound to the port in `input/transport`.
3. Write the datagram encoder and decoder as one pair of functions with a
   dispatch table by kind: `batch`, `want`, and the discovery kinds issue 704
   adds. The decoder returns a named refusal for anything it cannot read.
4. Write the sent-batch table and the resend-on-request path: a `want` for T
   answers with the stored batch for T; a stored batch is dropped once every
   peer's acknowledged tick has passed it.
5. Wire the transport choice into `open_match` (issue 701) as a table lookup on
   the name.
6. Test with two lockstep worlds in one process over the loopback, then two
   processes on one machine over UDP on the loopback address.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- `input/dependencies` — where the socket library is recorded
- `tests/025-other-players.lua`

## Still open

- **F5.** Whether to sit above the handheld's encrypted messaging layer for the
  sake of one code path, even though nothing in a match is secret. Answering it
  decides whether the computer transport gains a matching layer.
- The port number, and whether it lives in `input/` or the catalogue.
