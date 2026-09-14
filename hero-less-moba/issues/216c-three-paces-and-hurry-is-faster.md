# 216c — Three Paces, and Hurry Is Faster Than Marching

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 216b |
| Blocks | 212 |
| Reads | [standing off and falling back](../docs/022-standing-off-and-falling-back.md) |
| Open questions | M5 |

## Current behavior

**Two gears, and a rule that nothing may ever exceed the upper one.**

A body that has got ahead of its place walks at seven tenths of its pace. A body at its
place or behind it marches at full pace. A dead band of a couple of paces stops a body a
hair out of place switching between the two forever.

The rule is stated flatly in the formation design and it is argued for: *a formation
dresses itself by the inside of a turn slowing rather than the outside sprinting, which is
what a body of troops actually does. Asking the outer rank to run is how a line becomes a
crowd.* What replaced hurrying was the front waiting — when the formation has fallen more
than half a rank behind its own anchor, the anchor stops advancing until the line dresses.

An earlier version was a continuous multiplier with the extra taken from whoever was
ahead. It read as breathing rather than marching, and it could not be measured: *how fast
is that soldier going* had a different answer per body per tick.

## Intended behavior

**Three paces, carried on the goal, and hurry is faster than marching.**

| Pace | Multiplier | Who takes it |
| --- | --- | --- |
| relax | 0.70 | ahead of its place; a guard on patrol; a body with a reach giving ground |
| normal | 1.00 | marching in line; walking a lane alone; crossing |
| hurry | 1.35 | charging; leashing home; withdrawing off the map |

**This reverses the rule quoted above, deliberately.** A charging body sprints. The
reasoning that a line dresses by slowing rather than sprinting is about *a line*, and a
body that has left the line to charge something is no longer dressing anything — it has
left the formation's business, which the cohesion budget already recognises by excluding
it.

So the old rule survives where it was actually about formations: **a body still marching
in a line never takes hurry.** The line still dresses by the inside slowing, and the front
still waits. What changes is that leaving the line is now visibly a change of gait, which
is the thing a player should be able to see happen.

### The clamp, and why it is needed

A pace is a multiplier on a body's own speed, not a budget handed to it, so nothing can be
handed an unbounded amount and teleport. That was the failure of the conserved-multiplier
version and it does not come back here.

What does need watching is a body that takes hurry *while a long way from its goal* and
holds it. That is correct for a charge and wrong for a straggler, and the difference is
which pattern placed the goal — which is exactly why the pace is decided by the pattern
rather than by the distance.

### It is a gear, not a dial

Three values, chosen by a row in a table, so *how fast is that soldier going* has one
answer that a person can read off the screen. The dead band stays: a body a hair out of
place must not change gear every tick.

## Suggested implementation steps

1. Put the three multipliers in the unit catalogue rather than in the code, so they are
   turned by looking rather than by editing, and record every turn of them in
   [the balance ledger](../docs/balance-updates.md).
2. Have each pattern name its pace. Marching is the only one that chooses between two,
   and it chooses on the same dead band it uses today.
3. Rewrite the paragraph in the formation design that says nothing exceeds marching pace,
   because it will no longer be true and it is currently load-bearing prose.
4. Measure the match arc across several seeds. A charge that is a third faster changes when
   contact happens, which changes the phase clock, which is the thing that says whether the
   game still runs its arc.
5. Watch it: a scene where one formation charges another, which is a picture that either
   reads as a charge or does not.

## Open questions

**M5. What are the numbers actually?**
0.70, 1.00 and 1.35 are the two that exist plus one that was chosen to be visibly faster
without being a different animal. The right way to settle the third is to watch a charge
and to run several thousand matches and look at what moved in the phase clock, not to
argue about it here.

## Related documents and tools

- [211d — marching speed is not running speed](211d-marching-speed-is-not-running-speed.md),
  which this finishes and partly reverses
- [212 — a beaten body gets one roll](212-a-beaten-body-gets-one-roll.md), which is what
  running away will need
