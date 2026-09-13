# 308 — A pattern is drawn once

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 204, 307 |
| Blocks | 504, 605, 901 |
| Reads | [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) |
| Open questions | A4 |

## Current behavior

Nothing. Movement (issue 204) walks a unit along a list of points it carries,
and the phase 2 tests hand units their points directly. There is no pattern
record in the world, nothing validates a route, and no factory (issue 307) has
one to give.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that a pattern arrives with the placing command and can never
be changed afterwards by any verb; that a land pattern with a point in the water
is refused, naming the point; that a pattern whose first point is not the
factory's cell is refused; and that every unit the factory emits carries a copy
of the pattern, not a reference to it. The factories document describes the
drawing.

## Intended behavior

When a land or sea factory is placed, the player **draws in the sand** the
route its output will take: a list of points on the field, in order, starting
at the factory. That is the pattern. Every unit the factory ever emits carries a
copy of it and walks it leg by leg, and when it reaches the last point it holds
there and fights — the working ruling in A4.

**The pattern cannot be redesigned after it is laid.** Not edited, not extended,
not re-pointed. There is no verb at the command door that touches a pattern,
and that absence is the mechanism: a rule that exists as a missing verb cannot
be broken by a later feature that forgets it. To send units somewhere else,
build another factory and draw another pattern. The vision is explicit and it
is the design — a player who cannot fiddle with a route has to think about the
route before drawing it.

A pattern is validated when the placement command is applied, and a failure is
a refused placement, named to the point that failed: every point must be on the
field; a land pattern may not cross water and a sea pattern may not leave it,
checked along every leg and not only at the points, because a straight leg
between two dry points can cross a bay; the first point must be the factory's
cell; and a pattern must hold at least two points, since a pattern of one point
is a factory whose output stands on it. Nothing is repaired.

A pattern is stored once, in flat arrays, and a unit's copy is the pattern's
index plus its own leg counter — a copy in the sense that matters, which is
that nothing can change what the unit reads, because nothing can change a
pattern. That is the "copy at the boundary" pattern with the boundary made
permanent.

The route is the whole tactical game: a trough is safe and blind, a ridge is
fast and seen. The player chooses, in advance, with a finger.

## Suggested implementation steps

1. In the `factories` stem, add pattern arrays to the world: a `pattern_start`
   and `pattern_length` per pattern (integers), and one flat pair of arrays
   `point_x`, `point_y` (doubles) that every pattern's points are appended to.
   Allocated once to a catalogue maximum; a placement that would overflow is
   refused by name rather than growing anything.
2. Export `validate_pattern(field, domain, cell, points)` returning either an
   integer zero for valid or the index of the first offending point and a
   named reason. Walk every leg across the heightfield with the same
   line-drawing loop the sightline uses (issue 103), asking the domain rule
   (issue 203) at every cell crossed.
3. Make `place` (issue 307) call it before writing anything, and store the
   points only on success. Make the unit spawn in the emit pass write the
   pattern index and a leg of one into the unit's row (issue 201).
4. Confirm by reading the door's dispatch table (issue 108) that no verb takes a
   pattern index; add a test that walks the table and asserts it, so a future
   verb that edits a pattern fails a test rather than a review.
5. Give the terminal viewer (issue 111) a pattern layer — every friendly
   pattern as a line of characters — so a drawn route can be looked at before
   the window exists.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: arrives with the
   command, no verb changes it, water refused by point, wrong first point
   refused, units carry copies.

## Related documents and tools

- [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) — the drawing and why it is final
- [the dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) — the field every leg is checked against
- [strategems](../strategems/patterns-that-keep-working) — copy at the boundary
- `tests/021-inflows-and-outflows.lua`
- issue 204 — movement, which walks the pattern
- issue 605 — the drawing as input, on a computer

## Still open

- A4: what a land unit does at the end of its pattern — hold and fight is the
  working ruling; a looping patrol would be a flag on the pattern and a change
  to movement, not to this issue's validation.
- Whether a pattern may be drawn through cells the team does not hold. The
  working ruling is yes: the drawing is a plan, and the ground is taken by
  walking it.
