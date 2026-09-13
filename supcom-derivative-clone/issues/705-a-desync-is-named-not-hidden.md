# 705 — A desync is named, not hidden

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 109, 701 |
| Blocks | 708 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | F2 |

## Current behavior

Nothing. The snapshot system (issue 109) fingerprints the world every tick and
the reproducibility test compares two runs on one machine. No hash has ever
crossed a wire. `tests/025-other-players.lua` looks for `check_hash` on the
`lockstep` stem and asserts that a disagreeing hash names its tick.

## Intended behavior

Every so many ticks — the hash-exchange interval from the catalogue — a
machine's batch carries the fingerprint of its world at that tick. A machine
that receives a fingerprint for a tick and finds it differs from its own does
exactly three things, in order:

1. **Halts the match** at that tick, on every machine, because the halt is
   itself carried as a datagram kind and a machine that hears it halts too.
2. **Says which tick**, on screen and in the log, with both fingerprints and
   both peer names.
3. **Writes its snapshot** of that tick and of the tick before it to the RAM
   tier, under `tmp/shared-memory/desync/`, beside the command log, so that the
   two machines' snapshots can be diffed and the replay run up to the tick
   before on either.

It does not resynchronise. It does not pick the machine with the lower id and
copy its world. It does not carry on and hope the difference stays small. A
desync is a bug in the simulation — a global random draw, a hash-table walk, a
floating-point operation that differs between two processors — and the only
correct response to a bug is to catch it with its evidence intact. A match that
quietly resynchronised would be a match in which that bug was never found.

The interval trades diagnosis against bytes: a fingerprint every tick names the
exact tick of divergence but costs a hash per batch; one every hundred ticks
costs almost nothing and names a window. The catalogue holds it, and the
snapshot of the tick before the named one narrows the window either way.

## Suggested implementation steps

1. Add `check_hash(tick, theirs, ours)` to the `lockstep` stem: equal returns
   true; unequal returns false and a record naming the tick, both hashes, and
   both peers.
2. Add the fingerprint field to the batch record from issue 701, filled only on
   interval ticks, zero otherwise — zero is not a hash the fingerprint can
   produce, or the fingerprint is made so that it cannot.
3. Add the `halt` datagram kind to the encoder from issue 703, carrying the
   tick and the two hashes.
4. Write the halt path: stop advancing, print, write both snapshots with the
   snapshot module's `record` from issue 109, write the command log beside
   them, and tell the viewer so it can show the tick.
5. Test: two loopback worlds, one of which is given a different seed after
   opening, and the assertion that the halt names the first interval tick after
   the divergence.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the
  snapshot and the determinism rules
- `tests/025-other-players.lua`

## Still open

- **F2.** Whether double-precision arithmetic agrees across a desktop processor
  and the handheld's cores. This issue is the instrument that answers it: the
  first cross-target match either holds its hashes or halts on the first
  interval, and the halt names the tick to start reading from.
