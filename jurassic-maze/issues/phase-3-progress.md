# Phase 3 — The Rolling

**All eight issues complete**, and the vision's first sentence works: balls roll
down the maze, none of them get inside a wall, and the headless report proves
both.

| Issue | |
| --- | --- |
| [301](completed/301-a-body-is-an-index-into-flat-arrays.md) | a body is an index into flat arrays |
| [302](completed/302-the-tick-is-a-table-of-passes.md) | the tick is a table of passes |
| [303](completed/303-locomotion-is-a-dispatch-table.md) | locomotion is a dispatch table |
| [304](completed/304-the-floor-is-an-interpolated-height-field.md) | the floor is an interpolated height field |
| [305](completed/305-a-ball-collides-with-faces-and-corners.md) | a ball collides with faces and corners |
| [306](completed/306-falling-is-shared-by-everybody.md) | falling is shared by everybody |
| [307](completed/307-the-aquarium-tops-itself-up.md) | the aquarium tops itself up |
| [308](completed/308-bodies-are-bucketed-by-cell.md) | bodies are bucketed by cell |

`./run-phase-demo 3` shows it. `./run-maze --scene both` runs it live.

Phase four is under way ahead of schedule: the walking row and its smoothing —
[401](completed/401-a-step-from-surface-to-surface.md) and
[402](completed/402-smoothing-belongs-to-the-renderer.md) — were built alongside
rolling, because a dispatch table with one row in it does not demonstrate that it
is a dispatch table.

## The journey, and what it taught

### Eight times too slow, in two places, for the same reason

The first working move pass cost fourteen microseconds a body. It now costs under
two, and neither fix was a clever algorithm — both were a loop where a constant
would do.

`highest_surface_at_or_below` walked down from a layer testing one bit at a time.
A ball near the summit made it test twenty-eight bits to find the floor under
itself, twice a tick, for every ball. Binary search over a thirty-two bit word
does it in five comparisons regardless.

The slope was sampled by interpolating the floor at four points around the ball —
five interpolations and twenty bounds-checked array reads per ball per tick. Four
corner heights make the patch *exactly* bilinear, so the derivative is one
subtraction per axis, and it is not merely faster but more correct: the sampled
version averages across patch boundaries, which are genuine discontinuities.

**What it taught:** the second one had been written down in the design document as
the right way to do it, with a reason attached, and the reason was wrong. A
justification in a document is not evidence.

### The tuning sweep that reported the same number twelve times

A parameter sweep over friction and restitution printed identical results for
every setting. The world loads its own copy of every module, so mutating the
creature table an outer script had loaded changed nothing — the world was reading
a different table.

**What it taught:** worth knowing before writing anything that tunes a number,
and it is now written in issue 302's current behaviour where somebody will find
it. The isolation is correct; the surprise was mine.

### The most important test does not assert what it was going to

`tests/053-bodies-stay-outside-stone.lua` was written to assert that no ball is
ever at a position whose column has stone at its height. It failed immediately,
on seven thousand bodies, on the fourth tick.

They were not in walls. A ball rolls on an **interpolated** floor, so halfway
across a step the blended floor is between the two cells' heights while the ball
is still over one of them — the ball is, strictly, a fraction of a layer inside
the step it is crossing. That is the lie the interpolation exists to tell, and it
is what turns a flight of one-layer steps into a ramp a ball can accelerate down.

The clamp bounds it: a cell more than one layer from the ball's own never
contributes, so the dip can never exceed one layer. The test asserts *that
bound*. A ball that has tunnelled into a wall is several layers under.

**What it taught:** the invariant somebody writes down first is often a
simplification of the one that is actually true, and the difference between them
is usually a design decision they had already made and forgotten.

### The physics numbers are not about physics

Stone against stone has a restitution somewhere near a third. At a third, the
average ball travels two cells and thirty-six of two hundred and sixty are
motionless — because a maze is made entirely of walls, and a ball meets one
within a cell or two of being dropped.

At 0.85 the average ball travels seventeen cells and one is motionless. Over a
minute it descends seven layers and the deepest gets down twenty.

**What it taught:** the sweep that found this took ten minutes to write and
answered a question that would have taken an afternoon of adjusting numbers and
squinting. Every number in the ball's row of the creature table now has a
measurement behind it rather than a guess, and the measurements are in
`docs/balance-updates.md`.

## What is worth carrying into phase 4

- Sweep the parameter, do not adjust it. Twelve settings measured beats one
  setting argued about.
- The thread pool is still not wired up, and the passes still declare whether
  they are safe to split. At a few hundred bodies there is nothing to gain. The
  flag being *stated* now is what makes adding it later a change to the tick
  rather than an audit of every pass.
