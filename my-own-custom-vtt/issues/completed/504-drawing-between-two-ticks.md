# 504 -- Drawing between two ticks

**Phase:** 5, the bridge and the browser
**Blocked by:** [503](503-the-view-receives-state.md)
**Blocks:** [506](506-light-from-the-visibility-polygon.md)
**Documents:** [the dynamic picture](../../docs/012-the-dynamic-picture.md)

## Current behaviour

The view holds world state. Drawing it directly would show everything moving in
visible steps.

## Intended behaviour

The world beats about twenty times a second. Browsers draw sixty times a second
or better. Drawing exactly what was last received makes everything jump.

So the view **interpolates**: it holds the two most recent states and draws the
world between them, one beat behind live.

That is the standard trade and it buys smooth motion for about a fiftieth of a
second of latency, which nobody at a tabletop will ever notice.

### The part that is not standard

**A body that appears or disappears must not be interpolated from nowhere.**

Bodies arrive and leave constantly here, because the outbound filter sends only
what is currently visible. A goblin stepping out from behind a pillar is not
moving quickly -- it was absent and is now present, and interpolating it from its
old position would slide it out of the wall.

So: a body present in both states interpolates. A body present in only the newer
one appears where it is. A body present in only the older one is gone.

This is a direct consequence of sight being a security boundary, and it is the
kind of thing that would otherwise be discovered as "why do goblins slide out of
walls".

### And the fan does not interpolate either

The visibility polygon changes shape abruptly when a corner is turned. Blending
two of them produces a shape that is neither, sweeping through walls. Take the
newest and redraw.

## Suggested implementation steps

1. Keep two states with their tick numbers.
2. Interpolate position and facing for bodies in both. Facing must take the short
   way round, or a body turning past due east spins the wrong way all the way
   about.
3. Handle appearance and disappearance explicitly, with a comment saying why.
4. Take the newest fan, unblended.
5. If updates stop arriving, stop extrapolating after a beat or two. A view that
   keeps confidently walking bodies forward during a network hiccup is lying.
6. Write the companion `.info.md`.
