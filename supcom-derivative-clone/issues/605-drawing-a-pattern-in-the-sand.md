# 605 — Drawing a pattern in the sand

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 308, 603 |
| Blocks | 804 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. A pattern is designed in
[factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
as a list of points drawn once when a factory is placed, and issue 308 builds
the placement command that carries it — cell, domain, line, pattern, all at
once — and the validation that refuses a bad one by name. The test program
`tests/024-watching-it-happen.lua` asserts that a drawing becomes exactly one
command, and fails today because nothing draws.

## Intended behavior

Placing a factory is the largest input the player makes, and it is one gesture
that ends in one command.

**The gesture.** The player picks a cell on a field lens and a domain and a line
from a small chooser that appears there. Then the drawing begins: each click on
the lens adds a point, a drag adds points as the cursor moves, and the drawing
is shown as a line in the sand from the factory's cell through every point so
far, in the team's colour. Finishing the drawing — a key, or a double click —
issues **one placement command** through the door carrying the cell, the domain,
the line, and the points. Cancelling discards the drawing and issues nothing.

**The viewer does not validate.** The simulation's placement command is the
authority on whether a pattern is legal — a point in the water, a first point
off the factory, a sea pattern that leaves the sea — and the viewer does not
carry a second copy of those rules to disagree with it. What the viewer may do
is show facts from the snapshot: a point over water is drawn in the sea's
colour while it is being drawn, because the cell's height is a fact the field
holds, not a rule. The player sees the fact and decides.

**Refusals are loud, and they are shown where they happened.** When the door
refuses a placement, the refusal names the point that failed and why, and the
viewer draws that refusal at that point on the drawing — a mark and the words —
and **keeps the drawing on screen** to be corrected and finished again. The
drawing is the player's work, and a refusal that erased it would be a second
insult on top of the first.

**A pattern cannot be redesigned.** Once the command is accepted and the snapshot
shows the factory, the drawing becomes the patterns layer's line for that
factory, and there is no gesture that edits it. To send units somewhere else,
the player draws another.

The same gesture without a drawing — cell, domain, line, finish — places an air
factory, whose output goes to the cloud and follows no pattern. The chooser
does not offer a drawing step for the air domain.

## Suggested implementation steps

1. Write the drawing as a numbered source file with a companion: a small state
   record — the chosen cell, domain, and line; the points so far; the refusal
   being shown, if any — and a dispatch table on input events: click, drag,
   finish, cancel.
2. Convert every screen point to a field point through the lens's `to_field`
   (issue 603) at the moment it is added, so that a lens pushed mid-drawing does
   not move the points already drawn.
3. On finish, build one command in the shape issue 308 expects and hand it to
   the door through issue 601's channel with this drawing's identifier, so the
   refusal comes back here.
4. Draw the drawing as a line through the points on the lens, and the points
   themselves as marks coloured by the ground under them from the snapshot's
   field.
5. Draw a refusal at the point it names, with its words, until the drawing is
   changed or cancelled.
6. Once the snapshot shows the placed factory, drop the drawing state; the
   patterns layer draws the pattern from the snapshot from then on.
7. The test: a sequence of screen points through a known lens yields one command
   whose points are the expected field points; cancel yields nothing; a refusal
   naming a point leaves the drawing state intact with that refusal attached.

## Related documents and tools

- [The views](../docs/010-the-views.md) — drawing in the sand, and loud refusals.
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
  — what a pattern is and why it is drawn once.
- Issue 308 (the placement command and its validation), issue 307 (lines), issue
  603 (the lens transform), issue 601 (the command channel and the refusal
  path), issue 804 (the same gesture with a stylus).
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether a drag should add a point per cell crossed or a point per sample of
  the cursor, which decides how many points a pattern has and therefore how
  much a command weighs on the wire (issue 703). Per cell crossed is the
  working choice.
- Whether the chooser should show the line's cost stream before the drawing
  begins. The cost is a fact from the catalogue and showing it is not a rule;
  the question is only whether it belongs in this gesture or in the strip.
