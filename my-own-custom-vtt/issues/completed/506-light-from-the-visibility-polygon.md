# 506 -- Light from the visibility polygon

**Phase:** 5, the bridge and the browser
**Blocked by:** [504](504-drawing-between-two-ticks.md)
**Blocks:** [508](508-the-phase-five-demo.md)
**Documents:** [the dynamic picture](../../docs/012-the-dynamic-picture.md),
[sight and what it remembers](../../docs/007-sight-and-what-it-remembers.md)

## Current behaviour

The view receives a fan of angles and distances and does nothing with it.

## Intended behaviour

Draw the world with a clean edge between what is lit and what is not, using the
polygon the server already computed.

### The convergence worth noticing

That polygon exists because the outbound filter needed to know which records it
was permitted to send. It is **also** exactly what a renderer needs to draw light
and shadow without stair-stepping.

The alternatives -- a grid of lit and unlit cells, or a blurred overlay -- are
worse at both jobs at once. **The geometry that made the fog secure is the
geometry that makes it look good**, and when a decision made for correctness turns
out to be the pretty one too, that is usually a sign it was right for a reason
nobody has written down yet.

### Three layers, painted in order of certainty

| Layer | What it is | How it looks |
| --- | --- | --- |
| Never seen | Not in memory | Nothing. Not black -- **absent**. |
| Remembered | In memory, not in sight | The floor plan, desaturated and still. |
| Visible | Inside the polygon | Lit, and the only layer where bodies appear. |

The middle layer is the one that carries the idea. A person should be able to
look at their screen and know, without being told, that they are looking at
something they remember rather than something they can see.

Lights from the world contribute their own polygons, composited: bright, dim,
dark. What bright and dim *mean* is a ruleset's business; the view only draws
them differently.

## Suggested implementation steps

1. Build a path from the fan -- the origin, then each boundary at its angle and
   distance -- and use it to clip.
2. Draw remembered terrain, then clip to the polygon and draw the lit layer over
   it.
3. Draw bodies only inside the clip. A body outside it was not sent, so this is
   belt and braces rather than a filter -- and worth a comment saying so, or
   somebody will later "optimise" it away and be right for the wrong reason.
4. Soften the edge slightly. A hard line reads as a rendering artefact; a
   fractionally soft one reads as light.
5. Write the companion `.info.md`.

## What this does not do

No shadows cast by bodies, and no light bouncing. A body does not block sight
unless it is flagged to, and the server is what would have to say so.
