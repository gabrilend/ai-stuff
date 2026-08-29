# 1307 -- The third view, and it is not the browser

**Phase:** 13, the world becomes solid
**Blocked by:** [1305](1305-the-unseen-is-a-surface.md)
**Blocks:** [1309](1309-the-phase-13-demo.md)
**Documents:** [the three programs](../docs/002-the-three-programs.md),
[the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

Two views exist and both speak the same protocol with no server changes: the
browser, reached through the bridge, and the terminal renderer from phase 11.
Both draw a plan view of a flat world -- coloured circles for things, lines for
walls, a visibility polygon for light.

Phase 11 proved that a second view costs no server change. This is that claim
being spent a second time.

## Intended behaviour

**A third view, in LuaJIT, drawing the world in three dimensions**, with things
as billboarded sprites choosing one of eight facings.

### Why this is now possible

Not because the renderer got easier. Because the visibility problem was deleted.

Drawing 3D in a 2D framework means writing the matrix arithmetic and the depth
setup by hand, which is a great deal of work to pile on top of a bounding-volume
tree and a sampling budget. Once visibility is [one comparison against a cached
number](1303-visibility-is-one-equation.md), what is left is *drawing meshes you
were told to draw*, and that is ordinary.

### The facing costs nothing

Every thing already stores `facing` as a 16-bit angle where a full turn is 65,536,
and it is already on the wire. The eight-way sprite choice is *(facing minus
camera yaw)* shifted, computed in the view. Rotating the camera sends no bytes.

Sprites themselves already reach the table as numbers rather than as images --
phase 11 closed that, because the paintbrush is a closed set of numeric moves.
Eight facings is either eight generations or one generator taking a facing as an
input, and that is a question for the studio rather than for the view.

### It joins the browser rather than replacing it

Same wire, no server changes. The browser stays, because it is the renderer
everybody already has and nobody has to install anything to sit at the table.

### What was considered and refused

**A native renderer streaming video to a browser window.** It costs the renderer,
then the encoder, then the latency, and the browser ends up decoding a film of a
game it could have drawn. The one real reason to build it is playing on a machine
that cannot run the renderer -- a phone, a tablet -- which is a different feature
from this one.

## Suggested implementation steps

1. The protocol first: confirm nothing new is needed. If something is, that is a
   finding, because phase 11's whole claim was that a view costs no server change.
2. Camera, projection, depth. Fixed point up to the boundary of the view, since
   the view is allowed floating point and the simulation is not.
3. Draw the edge graph: loops as surfaces, materials as their appearance.
4. Billboards, and the facing subtraction.
5. The aperture fill from [1305](1305-the-unseen-is-a-surface.md).
6. Run it beside the browser and the terminal on one session, all three watching
   the same thing, the way phase 11's demo did with two.
