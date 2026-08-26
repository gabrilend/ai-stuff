# 304 -- Crossing a boundary changes region

**Phase:** 3, the world ticks
**Blocked by:** [303](303-bodies-collide-with-walls.md),
[105](105-regions-nest.md)
**Blocks:** [602](602-membership-is-a-list-or-a-region.md) -- the tavern's
commander depends entirely on this being right.
**Documents:** [the map is geometry](../../docs/006-the-map-is-geometry-not-a-picture.md),
[who controls what](../../docs/008-who-controls-what.md)

## Current behaviour

A thing's `region` is set once, at load, by testing it against every region.

## Intended behaviour

Maintain it as bodies move, and tell the ruleset when it changes.

After the motion resolve, any body that actually moved is re-tested for which
region it is in. A body that did not move is not tested, which is what makes this
affordable -- most things in a world are standing still.

The test returns the **deepest** containing region: a body in the cellar is in the
cellar, not in the tavern above it.

### The crossing is the hook

When the region changes, the ruleset is told: this thing left that region and
entered this one. **That single event is what everything of the form "when they
enter the tavern" is built on** -- ambushes, doors that lock behind you, a
barkeeper who looks up.

It costs a point-in-polygon test only for bodies that moved, which is the whole
reason the field is maintained rather than computed on demand by everything that
wants it.

### This is where control changes hands

A goblin patrol walking out of the forest and into the tavern changes its `region`
field here, and region-membership scopes are evaluated from that field. So the
moment this pass runs, the patrol belongs to the tavern's commander instead of the
forest's.

**That is mechanically what happens and it is not settled that it is what anybody
wants** -- the forest's commander may have been walking that patrol for ten
minutes with an intention. See [6.1](../../docs/016-open-questions.md).

If the answer changes, it changes in
[602](602-membership-is-a-list-or-a-region.md) rather than here: this file's job is
to keep the field truthful, and whose the goblin *is* is a separate question asked
of a truthful field.

## Suggested implementation steps

1. Track which things moved during the resolve -- a flag written by
   [303](303-bodies-collide-with-walls.md), not a comparison of before and after,
   because a body that moved and slid back has still crossed things.
2. Re-test only those. Use the deepest-containing query from
   [105](105-regions-nest.md).
3. Buffer the crossing events rather than calling the ruleset from inside a
   parallel pass. Collect them, then deliver in index order after the barrier -- a
   ruleset called from three threads at once is a ruleset that cannot be
   deterministic.
4. Write the companion `.info.md`.
5. Test: walk a body across a boundary and assert one event. Walk it back and
   forth across the same boundary in one tick -- fast enough to skip the region
   entirely -- and decide, deliberately, whether that is one crossing, two, or
   none. Comment the answer.
6. Test nested entry: walking into the cellar from outside should report the
   deepest region, and the parent chain should still say the body is in the tavern.
