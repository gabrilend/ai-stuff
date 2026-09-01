# 404 — An Idle Is A Row With A Clock

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 103, 401 |
| Blocks | 406 |
| Reads | [idling and being idle together](../../docs/015-idling-and-being-idle-together.md) |
| Open questions | none |

## Current behavior

Six rows in the creature table — breathe, look around, stretch, crouch, scratch,
sit — each with a duration range, a bob, a rate, and optionally a squat or a
turn. Weights per creature kind.

The simulation's whole involvement is which row and how much of its clock is
left. `Walking.idle_offset` turns that into a drawn height offset: a sine for the
bob, a constant for the squat, eased in and out over the idle so a squat does not
snap on and off. Two numbers and a sine, in the renderer, read from a table.

`breathe` is the default and is the one that matters. A genuinely motionless body
reads as a bug — the eye assumes something crashed.

## Intended behavior

There is no animation system and there is not going to be one. An idle is a row
in a table: a name, a duration range, and a small amount of motion the renderer
applies. The rows are listed in
[the document](../../docs/015-idling-and-being-idle-together.md).

The simulation's whole involvement is **which row, and how much of its clock is
left**. Everything visible is arithmetic in the renderer driven by the fraction
elapsed. An idling body costs one timer decrement per tick, which is what lets
there be a great many of them.

`breathe` is the default and it is the one that matters. A genuinely motionless
body reads as a bug — the eye assumes something crashed. A body whose drawn
height moves by a twentieth of a layer on a slow cycle reads as alive, and nobody
notices why.

Weights are per creature kind and live in the creature table, so a nervous little
guy scratches and a sunning dinosaur sits.

## Suggested implementation steps

1. Write the idle table with the six rows and their duration ranges.
2. Add `idle_row` and reuse the existing `timer` field on the body.
3. Write the chooser, drawing from the `idle` stream against the creature's
   weights.
4. Write the renderer's per-row motion as a table of functions from elapsed
   fraction to a drawn offset, so adding an idle is a row in two tables and
   nothing else.
5. Make any non-idle intent cancel the idle immediately.
6. Test: over a long run the distribution of chosen idles matches the weights to
   within sampling error; no body is ever in an idle whose clock has expired.

## Related documents and tools

- [Idling and being idle together](../../docs/015-idling-and-being-idle-together.md)
