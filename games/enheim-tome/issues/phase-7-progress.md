# Phase 7 — The Day

Time, and the small horizontal object that lets you sweep through it.

**Eight issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [701 — the hour is global](701-the-hour-is-global.md) | not started |
| [702 — the world advances on a move](702-the-world-advances-on-a-move.md) | not started |
| [703 — whereabouts is a function](703-whereabouts-is-a-function.md) | not started |
| [704 — the time-curve](704-the-time-curve.md) | not started |
| [705 — sweeping drives the hour](705-sweeping-drives-the-hour.md) | not started |
| [706 — hovering is not dragging](706-hovering-is-not-dragging.md) | not started |
| [707 — curves you are allowed to read](707-curves-you-are-allowed-to-read.md) | not started |
| [708 — pinned, and on demand](708-pinned-and-on-demand.md) | not started |

## The mistake this phase corrects, recorded because it will recur

The hour began as the shade filter's parameter, which was entirely reasonable —
nothing else needed an hour. Then whereabouts turned out to be a function of it
too, and **a value two unrelated systems consult belongs to neither.**

The tell: the moment a second, unrelated consumer appears for a value, its home is
wrong. It was not wrong when written; it became wrong.

Had it stayed a filter's parameter, the shadows would move and the people would
not, and the city would be visibly incoherent in a way nothing could fix without
this change.

## The problem that was dissolved rather than solved

A clock that both ran and could be scrubbed would mean the screen could show a
moment that is not now — and then every reading on it is a hypothetical that must
be loudly marked or the map becomes quietly untrustworthy.

**The time is only ever now.** Sweeping consults your model rather than
travelling. The state does not exist, so nothing needs marking, and a whole class
of interface problems never arrives.

The guarantee that must be tested: sweeping the hour across a whole day and back
leaves every stored value identical, byte for byte.

## The mark that was not needed

*Where you are* looked like it would require a fifth thing on a map argued down to
four. It did not: the whereabouts function returns a **place**, and the glow
already means *this one*. Before adding a mark, ask whether an existing one
already answers the question.

## What makes the curve worth building

At 225 by 30 pixels it is a shape, not a measurement — two humps and a trough, not
a number. Its value is that it is a scrubber and a readout at once, and that with
several pinned, **one drag shows the whole group's morning**. One curve alone
would be a readout; several make it an instrument for noticing.
