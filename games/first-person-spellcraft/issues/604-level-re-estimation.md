# 604 — Level re-estimation: "they are that potentialed"

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** 602 (the capability estimate + yardstick it updates); Phase 5
(the success/failure signal it consumes). Optionally 601 (may ask the seam to
help judge a near-miss).
**Blocks:** 606 (tuning reads the re-estimated values), 608 (the loop).

## Current Behavior

None of this exists yet. When a party finishes a lair, nothing changes about how
the DM sees them. There is no consumer of Phase 5's success/failure signal, and
the level yardstick from issue 602 never moves — so the DM's "conception of a
level" is frozen and every future lair is tuned to a stale belief.

## Intended Behavior

The stage that closes the loop. It consumes **attempt outcomes** from Phase 5 —
per puzzle: solved or not, which stats were exercised, how close a failure came,
whether a trap fired — and updates **two** things:

- **The capability estimate** (issue 602): a solved puzzle raises the
  demonstrated ceiling and confidence on the stats it exercised; a failure
  lowers or holds them, informed by how close the miss was.
- **The level yardstick** (issue 602): when a party conquers what the yardstick
  called "level N," the **yardstick stretches** so that N now demands more. This
  is the literal vision line — the DM "changes its conception of what a level
  means." The party is not what changes; the ruler is.

Both updates are the strategem
["Remember the demonstrated, re-estimate the meaning"](../strategems/README):
first record what was demonstrated, then re-estimate what the measurement means.
Because 602 kept capability and yardstick separate, this issue can move each with
its own rule and test each alone.

The DM must **not** overreact to a single lair — updates are incremental (a
learning-rate style blend), so one lucky solve does not peg the estimate to
maximum. Prefer erroring on malformed outcomes over silently discarding them.

## Suggested Implementation Steps

1. Define the **attempt-outcome** structure (or confirm the Phase-5 shape): per
   puzzle — solved flag, exercised stats, closeness-of-failure, trap-fired flag.
2. Write **update-capability-from-outcomes**: fold outcomes into the per-stat
   capability estimate, raising demonstrated ceiling/confidence on success,
   adjusting gently on failure by closeness.
3. Write **stretch-the-yardstick**: when demonstrated performance meets or beats
   what the yardstick called this lair's level, widen the yardstick so that level
   number now requires more.
4. Make both updates **incremental** (a tunable blend rate), documented with a
   comment on *why* the rate is what it is (avoid single-lair overreaction).
5. Provide the **re-estimate** entry point that runs both updates for a finished
   lair's outcomes (stage E of the datapath).
6. Companion `*.info.md` describing the entry point and the outcome structure.
7. Tests: a clean sweep raises the ceiling and stretches the yardstick; a near
   failure barely moves the estimate; a bad failure holds/lowers it; repeated
   conquests stretch the yardstick monotonically; a malformed outcome errors.

## Meta

- **This is the heart of the phase's learning claim.** If issue 608's demo shows
  anything, it shows this: the same party facing successively harder lairs
  because the yardstick keeps stretching.
- **Sequel hook:** the same re-estimation later hardens a Phase-8 province
  "relationship" as it is fought over repeatedly.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — stage E and
  the "level yardstick" structure.
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(Phase 5)* —
  where the success/failure signal originates.
- [strategems/README](../strategems/README) — remember, then re-estimate.
