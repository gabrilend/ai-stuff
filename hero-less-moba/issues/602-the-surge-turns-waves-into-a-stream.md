# 602 — The Surge Turns Waves Into a Stream

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 207, 601 |
| Blocks | 603, 605, 607 |
| Reads | [the siege-surge](../docs/014-the-siege-surge.md) |
| Open questions | B2 — surge length and stream rate |

## Current behavior

A surge is a stream: one body per lane per team on one shared timer, so bodies come
in threes. Towers stop replacing guards and are unkillable for the duration, and the
chest cannot grow — which falls out rather than being enforced, since a stream body
belongs to no wave and "wiped" is a statement about a group.

It is the one thing in the game that walks out in a line.

## Intended behavior

During a siege-surge both bases emit **one body per lane on a very short
interval** — a trickle from each of the three mouths, continuously, instead of a
batch every several seconds. Where normal play sends a handful of soldiers down
each lane every several seconds, a surge sends one down each lane every fraction
of a second.

The spawner reads row 2 of the phase table. Same function, different interval and
count — if a branch is needed, the phase table is the wrong shape and should be
fixed rather than worked around.

### Guards join the stream

While a surge runs, **towers spawn no guards.** That production is redirected to
the base and emerges as ordinary stream bodies.

Mechanically it is a redirect of the existing guard timer, not a new spawner: the
tower's timer still fires, but the body appears at the library node facing
outward with no leash instead of at the tower node with one. The defence walks
out to meet the fight instead of waiting at home for it.

Those bodies are dealt to like every other stream body — a share of everything
the team owns, split across the bodies spawning that instant — rather than
carrying the tower's upgrades the way a guard does in any other phase. Issue 603
owns the deal itself.

**Towers shoot at bare catalogue values for the duration.** No upgrade applies to
a tower while a surge runs, so entering the phase sweeps every standing guard
back to baseline and leaving it sweeps them forward again — the ordinary
clear-then-re-stamp from issue 303, fired by a phase change rather than by a
placement. Combined with towers being invulnerable and producing no replacements,
a surge is the one stretch where a team's stone is inert: it cannot be lost, it
cannot be reinforced, and it is not carrying anything.

### Why the stream

Discrete waves give a lane a rhythm: a push, a lull, a push. Both teams learn the
rhythm and play to it, and by the middle of a match the lanes have settled into a
standing pattern. A continuous stream deletes the lull. There is no between-waves
moment to reposition in, no window where a lane is briefly empty, and nothing to
time anything against, because there is no spawn clock any more.

The frontline stops being a place where two waves meet and becomes a place where
two **rates** meet.

### Wave records still exist, and never complete

The stream creates a wave record per lane per interval as before — it is just a
much smaller, much more frequent batch. That keeps the wipe detection from issue
208 working unchanged with no special case.

But note the consequence and do not treat it as a bug: with one body per record,
a "wave" is wiped the moment that body dies, which would pay an upgrade for every
single kill. **It must not.** A surge earns nothing. The phase table's row 2 says
the chest does not grow, and the draw routine reads it. The cleanest expression
is to give the wave record a `pays` flag set from the phase at creation, so the
wipe detector stays ignorant of phases entirely.

## Suggested implementation steps

1. Fill in row 2 of the phase table with the stream's interval and count.
2. Add the `pays` flag to the wave record, set from the phase at creation, and
   check it in the draw routine rather than in the wipe detector.
3. Redirect the guard timer to the base spawn while the phase is 2.
4. Check the body-count ceiling. A continuous stream in three lanes from both
   bases is the peak load the simulation will ever see, and it decides the
   soldier store's capacity.
5. Write a test that a surge pays no upgrades at all, despite producing hundreds
   of single-body wave records that all "complete."
6. Watch one in the terminal viewer. The stream should look visibly different
   from waves at a glance; if it does not, the rate is wrong.

## Related documents and tools

- [The siege-surge](../docs/014-the-siege-surge.md)
- [Waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md)

## Still open

**B2 — how long does a surge last, and how fast is the stream relative to the
wave rate?** Awaiting evidence rather than undecided: it is found by watching one
run, not by argument. Together those two decide the peak body count, which is the
number the soldier store's fixed capacity is sized against (E3), and which
decides whether the thread pool is worth having at all.
