# 804 -- Furnishing asks the ruleset

**Phase:** 8, content generation
**Blocked by:** [803](803-the-graph-becomes-geometry.md)
**Blocks:** [806](806-the-generator-checks-its-own-work.md)
**Documents:** [content is generated](../../docs/013-content-is-generated.md)

## Current behaviour

Geometry exists and is empty. No lights, no doors, no crockery.

## Intended behaviour

Put things in it — and **ask the ruleset what belongs**, because knowing that a
tavern contains tables and a bar is game-specific knowledge.

### The stage that must not know what a tavern is

The layout stage produced a room with a certain shape and a certain connection to
its neighbours. It never learned that meant a tavern.

So furnishing asks: given a room of this kind and this size, what stands in it?
The ruleset answers with kinds and counts, and **swap the ruleset and the same
layout generator furnishes a spaceship instead**.

That is the test of whether the split is real. If furnishing has a list of
taverns in it, the generator has a game inside it.

### Lights and doors are not furniture

A **door** is a wall whose flags a thing controls, and the geometry stage already
emitted the segment. Furnishing adds the leaf and links them.

A **light** is a thing with `THING_EMITS_LIGHT` plus a light record, and the
validator insists those two agree.

Both are structural rather than decorative, so they are placed here and not left
to a ruleset that might not bother.

## Suggested implementation steps

1. Add a `furnish(room_kind, area)` hook to the ruleset interface, returning
   kinds and counts.
2. Place them without overlapping walls, from a named stream.
3. Place doors on corridor segments and link the leaves.
4. Place lights where the description asks for them.
5. A ruleset with no `furnish` hook produces an **empty but valid** world — which
   is a legal outcome, not a failure.
6. Write the companion `.info.md`.
7. Test: two rulesets furnishing the same layout differently; no furniture inside
   a wall; the door leaf and its segment agreeing; the light and its thing
   agreeing.
