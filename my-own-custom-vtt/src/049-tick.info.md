# 049-tick

The heartbeat, as a table you can read the ordering off.

Each beat runs a dispatch table of passes, in order. Not a sequence of calls in a
function body: **the order of the simulation is a piece of readable data**, and
every "does X happen before Y?" question is answered by looking at one array.

## The passes

| # | Pass | What it does |
| --- | --- | --- |
| 1 | intake | drain sockets, decode, refuse or accept |
| 2 | intent | turn standing orders into intended motion |
| 3 | motion | advance what moves, resolve against walls |
| 4 | region | re-test what moved, and collect the crossings |
| 5 | rules | the ruleset's slice of the beat |
| 6 | sight | recompute what each viewer can see |
| 7 | memory | fold sight into each viewer's fog |
| 8 | outbound | build and send each viewer's filtered update |

Five of those do no work yet — no sockets, no ruleset, no viewers. **An empty row
is better than an absent one**: it is where the later work goes, and the table
stays the whole truth about ordering rather than most of it.

`sim_passes()` returns the table, so a demo can print it and the ordering is
readable from outside the source.

## Intent, then resolve

Two passes, not one. The first writes down where every body would like to be; the
second decides where it ends up.

Three things fall out, and the third matters most: simultaneous outcomes are
fair; the pass slices across threads with no locks; and **turns resolve
simultaneously because ticks already do** — the turn in `053-session` is this
same pattern at a larger scale, so simultaneity never had to be built for it.

Intent is cleared at the **start** of a beat rather than the end. A stale intent
is a body that keeps walking after its order was cancelled, and clearing here
makes that impossible regardless of what ran last.

## Two kinds of order, one intent

`ORDER_DRIVE` is a direction being pushed — what a held key becomes, persisting
until replaced or stopped, *not* a step that gets consumed. `ORDER_MOVE` is a
destination pursued over many beats, clamped so a body one centimetre away steps
one centimetre rather than overshooting and oscillating.

Both produce the same `struct intent`, which is what stops there being two
movement systems.

## Sliding, twice, then stopping

A body pushed into a wall at an angle projects its movement along the wall and
tries again. **Twice, then stop.** Two attempts handles a corner literally —
project against the first wall, then the second, then stop. Iterating until
nothing blocks is how a body jitters in a corner forever or squeezes through it,
and both are worse than not moving.

Bodies do **not** collide with each other, and that is deliberate: how much room a
creature claims is a rule, and this program has no rules. A ruleset that wants
exclusion refuses the command.

## The region pass runs on one thread

After the barrier, and only for bodies that actually moved — which is what makes
it affordable, since most things are standing still. Crossings are collected and
delivered in index order, because a ruleset called from three threads at once
could not be deterministic.

That incremental maintenance is also what lets the region field drift if motion
is ever wrong, which is why the validator recomputes every one from scratch.

## A measurement that went the other way

The motion passes go to the pool and it makes them **slower** — twenty-four
bodies is a few microseconds of arithmetic and a barrier costs more than that.
Results are identical at every thread count, which was the claim that mattered.
Open question 13.1 is about what to do with the finding.
