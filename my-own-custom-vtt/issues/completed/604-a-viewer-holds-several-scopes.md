# 604 -- A viewer holds several scopes

**Phase:** 6, control is a dial
**Blocked by:** [602](602-membership-is-a-list-or-a-region.md)
**Blocks:** [605](605-the-tavern-commands-its-crockery.md)
**Documents:** [who controls what](../docs/008-who-controls-what.md),
[sight and what it remembers](../docs/007-sight-and-what-it-remembers.md)
**Open questions:** [2.2](../docs/016-open-questions.md) — union or switch;
[6.5](../docs/016-open-questions.md) — hidden from other GMs;
[6.6](../docs/016-open-questions.md) — a GM seeing the players' fog.

## Current behaviour

A viewer has one body. `struct viewpoint` already carries a `sees_all` flag, and
was shaped for the plural.

## Intended behaviour

Being a player with a character **and** the commander of the forest is two scopes
held by one connection, and neither knows about the other.

A scope is held by **at most one** viewer, which is what makes "who moved that"
answerable. Multiple GMs are therefore not a special case: two connections, each
with a scope over the whole map.

### Sight becomes a union

This finishes [206](206-sight-for-a-viewer-is-a-union.md), which has been open
since phase 2 waiting for scopes to exist.

A viewer's sight is the union of what every body in every scope they hold can see.
A player driving one character sees from one pair of eyes. A commander with six
goblins sees from six.

**Do not merge the fans into one polygon.** The filter asks "inside any of them",
which is a loop with early exit. The fog folds each in turn and unions in the
bitmap for free. Only a renderer might want one outline, and even it may prefer
compositing. Polygon union is difficult, slow, full of degenerate cases, and
nothing here needs it.

### The two shortcuts are flags, not patience

`SEES_ALL` skips the geometry entirely — without it a GM would sweep for every
creature on the map, every beat. `SEES_REGION` sees a whole region rather than
from its bodies' eyes.

`SEES_REGION` is a design question wearing a performance costume: whether the
tavern's commander *should* be blind to the corner their crockery cannot see is
about what it feels like to play a building.

## Suggested implementation steps

1. Extend `struct viewpoint` to carry the viewer rather than one body, and gather
   bodies from their scopes.
2. Sweep once per body with eyes, into a per-viewer list of fans.
3. Implement the two flags as early exits before any sweeping.
4. Fold every fan into the one fog.
5. Write the companion `.info.md`, and close 206.
6. Test: two scopes, bodies in different rooms, both visible; `SEES_ALL` seeing a
   body behind a wall; a scope held by nobody contributing nothing.
