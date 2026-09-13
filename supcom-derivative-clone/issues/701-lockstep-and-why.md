# 701 — Lockstep, and why

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 108, 109 |
| Blocks | 702, 705 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | none |

## Current behavior

Nothing. The command door (issue 108) accepts a command with a tick stamp and
applies it at that tick; the snapshot system (issue 109) fingerprints the world
at the end of every tick. Neither knows that a second machine exists.

The direction is set: [other players](../docs/011-other-players.md) chooses
lockstep over an authority that reconciles, and the open questions page records
the choice as made. The test program `tests/025-other-players.lua` names this
issue and looks for a source file with the stem `lockstep`, which does not exist.

## Intended behavior

A `lockstep` module that sits between the command door and whatever carries
bytes, and that turns one simulation into one match held by several machines.
Every machine runs the whole simulation. Only intent crosses the wire, as
**batches**: one per peer per tick, holding that peer's commands stamped for
that tick — usually none.

The one rule the module enforces: **a machine advances tick T only when it holds
every peer's batch for T, including the empty ones.** An empty batch is not the
absence of a message; it is a message saying "nothing from me for T", and a
missing one stalls the tick. `ready(world, tick)` asks that question and is the
only thing the runner consults before calling the tick's advance.

Why this model, restated from the document so the issue stands alone: commands
are rare and small because units are not driven; every command already takes
effect at a later tick because everything is queued, so the delay costs the
player nothing new; and the handheld's wire is a radio whose capacity is not yet
measured, which a model sending a few bytes a second fits and a model
reconciling state does not.

The **match record** the module owns:

- the list of peers, each with a name, an integer id, and the highest tick it
  has acknowledged
- the delay, in ticks, from the catalogue
- a table of batches keyed by tick and then by peer id
- the hash-exchange interval and the stall threshold, both in ticks
- the transport in use, chosen by name from a dispatch table so the module
  never mentions a socket

A single machine playing alone is a match with one peer — itself — and a delay
of one tick. There is one runner loop, not two, and it is the lockstep loop.

## Suggested implementation steps

1. Claim the `lockstep` stem with `./new-source-file`. Exports: `schedule`
   (issue 702), `ready`, `check_hash` (issue 705), and `open_match(peers, delay,
   transport)`.
2. Write the batch record: sender id, tick, command count, the commands as the
   door already stores them, and an acknowledged-tick field for the sender's
   view of the receiver. Every field an integer or a string; nothing absent.
3. Write the match record above, allocated once, with the batch table keyed by
   tick then peer.
4. Write `ready`: true only when every peer, including the local one, has a
   batch for the tick. Array order over the peer list, so two machines ask the
   same question the same way.
5. Write the runner loop in the headless runner (issue 110): receive whatever the
   transport holds, file each batch, call `ready`, and only then advance. On a
   stall past the threshold, print which peer and which tick, and keep waiting.
6. Write the self-only case as the first test: one peer, delay one, and the
   reproducibility test still passes through the lockstep loop.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the
  determinism rules lockstep depends on
- `tests/025-other-players.lua` — the test that specifies this module

## Still open

Nothing beyond the questions in the table. The stall threshold and the
hash-exchange interval are catalogue numbers, not decisions here.
