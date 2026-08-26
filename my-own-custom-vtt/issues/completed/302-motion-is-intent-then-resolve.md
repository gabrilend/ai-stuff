# 302 -- Motion is intent, then resolve

**Phase:** 3, the world ticks
**Blocked by:** [301](301-the-tick-is-a-dispatch-table.md)
**Blocks:** [303](303-bodies-collide-with-walls.md),
[308](308-the-turn-is-a-window.md)
**Documents:** [the world and its tick](../../docs/004-the-world-and-its-tick.md),
[the turn is a transaction](../../docs/019-the-turn-is-a-transaction.md)

## Current behaviour

Nothing moves.

## Intended behaviour

Movement in two passes. The first writes where each body **intends** to be. The
second decides where it actually ends up and commits.

Nothing writes a position during the first pass. The intent array is separate
storage, sized once, one entry per thing.

### Why this is not an optimisation

Three things fall out of it, and the third is the one that matters most:

**Simultaneous outcomes are fair.** Two bodies reaching for the same doorway both
write their intent, and the resolve decides between them. The outcome does not
depend on which one the loop reached first.

**The pass can be sliced across threads with no locks**, because no worker reads
what another worker writes. That is the general rule from
[the thread pool](201-the-thread-pool.md), and motion is where it is most obviously
load-bearing.

**Turns resolve simultaneously because ticks already do.** The turn in
[308](308-the-turn-is-a-window.md) is this same pattern at a larger scale --
declarations accumulate, then settle. Simultaneity did not need to be built for
turns; it was already how every pass worked.

### Two kinds of intent

| Source | Shape | From |
| --- | --- | --- |
| **Driven** | A direction being pushed, cleared when the key lifts. Not "step once" -- "I am pushing this way". | `DRIVE` |
| **Ordered** | A destination, pursued over many ticks until reached or cancelled. | `ORDER_MOVE` |

Both produce the same intent record, which is what stops there being two movement
systems. The difference is only who recomputes the direction each tick: driven
motion takes it from the held command, ordered motion recomputes it toward the
destination.

## Suggested implementation steps

1. Allocate the intent array beside the things array, same length, at load.
2. Write the driven and ordered intent producers. Both write the same record.
3. Write the resolve pass as a separate function called from a separate table row,
   so it is visible in [301](301-the-tick-is-a-dispatch-table.md) that these are
   two passes and not one.
4. Zero the intent array at the start of each beat rather than at the end. A stale
   intent is a body that keeps walking after its order was cancelled, and clearing
   at the start makes that impossible regardless of what happened in between.
5. Write the companion `.info.md`.
6. Test: two bodies intending the same square, run with one thread and with many,
   assert the same one arrives both times. That is the determinism claim, tested at
   the smallest scale where it can fail.
