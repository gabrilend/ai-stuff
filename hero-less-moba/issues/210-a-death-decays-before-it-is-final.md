# 210 — A Death Decays Before It Is Final

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 205, 208, 107 |
| Blocks | 801 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md), [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

This issue is the answer to H2 in
[open questions](../docs/020-open-questions.md) — a machine that killed a body the
authority did not could never be told otherwise, because the slot was already gone.

## Current behavior

A body that reaches zero health leaves the field immediately and then **decays for
two seconds**, holding its slot and every one of its numbers, before its death is
made final. Nobody is paid, no wave counter moves, no guard is replaced and no
challenge ends until the decay runs out; then all of it happens at once and the slot
is released.

`alive` goes to zero the instant a body falls, which is what everything in the
simulation already tests — so a decaying body stops fighting, stops being a target,
stops holding a place in the queue and stops counting toward push depth with no
change to any of those passes.

`revive` puts one back, intact, and has no caller yet: the network it exists for is
issue 801. It is tested anyway, because the whole point of holding the slot is that
it is reachable.

The renderer draws them fading and shrinking, under the living so a corpse never
obscures a body somebody has to make a decision about. About a dozen are on the field
at once at the busiest, which is why they are drawn one at a time rather than batched
— each needs its own alpha and a sprite batch has one colour for the whole batch.

## Previously

A body that reached zero health died inside the reap pass, all at once: its
consequences were paid out — the kill, the wave counter, the guard replacement, the
phase transition if it was a monster — and then its slot went back to the free list,
its generation counter was bumped, and it was gone.

There was nothing left of it. Nothing could refer to it, and nothing could undo it.

## Intended behavior

**A death is a two-second process, not an instant.** A body that reaches zero health
stops being alive immediately — it stops fighting, stops being a target, stops
holding a place in the frontline queue, stops counting toward push depth, and leaves
the spatial grid — and then it **decays** for a fixed span, holding its slot and
every one of its numbers, before anything is made final.

While it decays, two things are true that are not true today:

- **Its slot is not free.** Nothing else can be allocated into it, and its
  generation counter has not moved, so every reference to it is still a valid
  reference to it.
- **Its consequences have not happened.** Nobody has been paid, no wave counter has
  moved, no guard has been replaced, no monster has ended a challenge.

When the span runs out, all of it happens at once, exactly as it does today, and
the slot is released.

### Why: a death is the one thing a correction cannot reach

Machines reconcile continuous state on a cycle, and a body that died on this machine
and did not die on the authority's cannot be repaired — the slot is gone, the
generation counter has moved, and there is nothing to write the corrected numbers
onto. Deaths are the hinge everything downstream hangs from: health makes deaths,
deaths make wave wipes, wipes make draws, draws make the chest. One soldier's
difference puts a machine permanently out of step, and no amount of position
correction closes it. That is measured, and the measurement is unpleasant — see
[open questions](../docs/020-open-questions.md), H2.

**A decaying body can be brought back.** Everything about it is still there; the
death is undone by clearing one number. And because reconciliation happens about
once a second, a body only has to survive **two of those cycles** for every machine
to have had its say. Two seconds is enough, and after two seconds a death is a fact.

### And it is not only for the network

A body that fades rather than vanishing is the better thing to look at. A soldier
blinking out of existence the instant its health hits zero is the single most
artificial-looking moment in the game, and every renderer ends up inventing a
death animation with no data behind it. Here the data is real: the body is
genuinely still there, and what is drawn is what is true.

### The cost, stated plainly

**Every consequence of a death lands two seconds late.** A kill pays two seconds
after the blow; a wave wipe draws two seconds after the last body falls; a challenge
monster ends its challenge two seconds after it dies. Uniformly, for everything, so
it is a delay and not a distortion.

The alternative — paying immediately and undoing it if the death is reverted — was
rejected. A payment can be unmade only if it has not been spent, and a chest draw
that has already been placed cannot be unmade at all. **A consequence that has been
acted on is not revertible**, so the only honest place to put the boundary is before
the consequence rather than after it.

## Suggested implementation steps

1. Add `decaying` to the soldier arrays: ticks remaining, 0 for everything else.
   Zero is the sentinel, as everywhere.
2. In the reap pass, a body at zero health sets `alive` to 0 and `decaying` to the
   span, and **stops there**. Every existing test of `alive == 1` then excludes it
   with no change — targeting, the frontline queue, push depth, the grid, the brain.
   That is why the flag goes where it goes.
3. Add a second sweep, in the same pass, over decaying bodies: count the span down,
   and when it reaches zero, run everything the reap pass runs today and release the
   slot.
4. Put the decaying bodies into the snapshot with their remaining span, so the
   renderer can fade them. Do not put them in the live list — a viewer counting
   bodies must not count corpses.
5. Write `revive`, which clears the decay and restores health from a number the
   corrector supplies. It has no caller until issue 801 exists; write it anyway,
   with the test, because the whole point is that the slot is reachable.
6. Test that a decaying body is not targeted, not counted, not walked, and not
   allocated over — and that reviving one puts it back on the field intact.

## Related documents and tools

- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)
- [Damage is buffered then applied](205-damage-is-buffered-then-applied.md) — the
  same shape of idea one step earlier: a two-stage split so that simultaneous
  outcomes resolve the same way every run
- [A wave knows when it is gone](208-a-wave-knows-when-it-is-gone.md) — the counter
  this delays
- [Reconciling across machines](801-reconciling-across-machines.md) — the reason
- The replay log's divergence measurement, which is how the size of the problem was
  established and is how any improvement will be shown

## Still open

**Whether two seconds is right** is a question about the reconciliation cycle, which
is not built. It is two cycles at the current cadence. If the cadence changes, this
follows it, and the two numbers should be defined in terms of each other rather than
written down separately.

**A body that dies twice.** If a machine revives a body and it immediately dies
again from damage still in flight, its consequences are paid once, on the second
death. That is correct, and it is worth a test rather than an assumption.
