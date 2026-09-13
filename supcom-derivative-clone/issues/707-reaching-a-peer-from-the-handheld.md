# 707 — Reaching a peer from the handheld

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 702, 805 |
| Blocks | 806 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | F3, F4, F5 |

## Current behavior

Nothing, and **design pending details on soren-ds wifi capabilities.**

The handheld's operating system, the sibling project Soren DS, has designed but
not built its networking phase. What is written down there: the radio runs in
ad-hoc mode on one fixed network name and channel; addresses are link-local
and self-assigned; peers announce themselves every few seconds and age out of a
peer table; an application sends UDP datagrams to a named port on a named peer
and receives from any transport into one box; a USB-C cable is a second
transport, preferred over the radio when both reach a peer. None of it has run
on hardware.

What is not written down, and what this issue cannot be finished without:

1. Whether the radio chip supports ad-hoc mode at all. The sibling project
   names it the single largest hardware risk of its networking phase.
2. The measured bandwidth, latency and loss rate between two handhelds in a
   room, which decide the input delay and the resend interval.
3. The largest datagram the link carries, which decides whether a batch or a
   log slice ever needs splitting.
4. How many peers one radio can hear, which bounds the match size.
5. What sustained sending costs in battery.

`tests/025-other-players.lua` exercises the lockstep layer over the loopback
transport only; nothing yet exercises a transport on the handheld.

## Intended behavior

The **same lockstep code** as on a computer, with the transport swapped. The
handheld transport is the three-function shape from issue 703 — `open`, `send`,
`receive` — implemented over the sibling system's transport abstraction: `send`
becomes a call to its peer-named send with this game's port, and `receive`
drains its receive box for that port. A peer is addressed by the name the
system's peer table already holds, which is a better address than a number and
is why the lockstep peer record carries a name from the start.

Discovery (issue 704) is half done for us: the system's peer table already knows
who is in the room. The lobby announcement — seed, tick rate, delay, team —
still goes out, as a datagram on this game's port, to every peer the table
holds, rather than as a broadcast.

On the handheld the transport is a **box**, not a Lua module: a C function in
the box directory that takes a datagram and returns nothing, and one that
takes nothing and returns a datagram, wired into the map by issue 801. The
lockstep layer above it is a box too by then. The shape is the same; the
language is the handheld's.

The five unknowns become catalogue numbers when they are measured: the delay
(F3), the resend interval, the slice size, the peer limit. None of them changes
the model.

## Suggested implementation steps

1. Wait for the sibling project's radio phase to reach association and its
   transport abstraction, and record the five measurements above in the
   catalogue as they arrive.
2. Write the handheld transport as two box sources in `src/boxes/`: a sender
   over the system's peer-named send, a receiver over its receive box, both
   with no memory between calls.
3. Add a `handheld` row to the transport dispatch table from issue 703, chosen
   by the name in `input/transport`.
4. Replace the broadcast in `discovery` with a send to each peer in the system's
   table, behind the same `announce` export.
5. Run the phase 7 loopback tests on the desktop engine against the ported
   lockstep boxes before anything is flashed.
6. Two handhelds in one room: lobby, open, hold hashes for a long match. That
   run is issue 806.

## Related documents and tools

- [Other players](../docs/011-other-players.md) — the handheld transport section
- [The handheld](../docs/012-the-handheld.md)
- `tests/025-other-players.lua`

## Still open

- **F3.** The handheld's input delay in ticks, pending measured latency.
- **F4.** The five radio unknowns listed above, pending the sibling project.
- **F5.** Whether to sit above the system's encrypted messaging layer even
  though nothing in a match is secret.
- Whether the USB-C cable, as a second transport, is worth supporting for a
  handheld playing against a laptop it is plugged into. The system would route
  it for free; the game would need nothing new.
