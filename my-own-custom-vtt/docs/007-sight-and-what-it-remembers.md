# Sight and what it remembers

Two different questions, computed by two different passes, stored in two
different places, and confused with each other in almost every virtual tabletop:

- **What can this person see right now?** Recomputed from scratch every tick.
  Never stored between ticks.
- **What has this person ever seen?** Accumulated forever, never recomputed.

The first is *sight*. The second is *memory*. A corridor you walked down an hour
ago is in your memory and not in your sight, and the difference is exactly the
difference between a floor plan you remember and a goblin who is standing there
now.

## Sight

Visibility is computed **per viewer**, as the union of what every body that
viewer commands can see. A player driving one character sees from one pair of
eyes. A commander with six goblins sees from six, unioned -- which is the correct
answer and also the reason a commander with many bodies is expensive.

### From one pair of eyes

The body has a position, a `facing`, a `sight_arc`, and a `sight_range` -- see
[a thing in the world](005-a-thing-in-the-world.md). Those four define a wedge.
The question is which parts of that wedge the walls leave intact.

The method is an **angular sweep**, and the shape of it is:

1. Take every wall segment whose bounding box intersects the sight circle. The
   broad-phase index that makes this cheap is a build concern, not a design one.
2. For each such segment, compute the angle from the eye to each endpoint. Clip
   to the wedge; discard segments entirely outside it.
3. Sort the endpoints by angle. This is the `n log n` and it is the whole cost.
4. Sweep through them in order, keeping a set of segments currently crossing the
   sweep ray. At each step the nearest of that set is what is visible at that
   angle. Where the nearest changes, a visibility boundary is emitted.

The output is a **visibility polygon**: a fan of wedges out from the eye, each
reaching to whatever stops it. Not a bitmap, not a list of lit cells -- a polygon,
because it is exact and because it is small enough to send to the view, which
needs it to draw the light and dark edges without stair-stepping.

`ONE_WAY` segments are checked against which side the eye is on, once, when they
enter the sweep set.

### Why this is the parallel pass

Each viewer's sight depends on the walls and the bodies, and on **no other
viewer**. There is no shared mutable state in the whole computation. Twelve
viewers is twelve independent problems handed to the thread pool with a `for`
loop and no locks.

It is also the most expensive pass in the tick, which is the pleasant case: the
slow thing is the parallel thing.

## Memory

Each viewer has one fog record, and it grows.

Memory is stored as **a bitmap over a coarse cell grid** -- one bit per cell, set
the first time any part of that cell falls inside the viewer's visibility polygon,
never cleared. Cell size is configuration; the natural choice is one world foot,
which for a four-hundred-foot map is 160,000 bits, twenty kilobytes per viewer.
Twelve people at the table is a quarter of a megabyte, once.

This is the one place a grid appears inside the server, and it is worth being
precise about why it is not a contradiction of
[the map is geometry](006-the-map-is-geometry-not-a-picture.md):

- The rules grid, if a ruleset has one, decides *where things may stand*. That is
  a constraint on the world and it is deliberately kept out.
- The memory grid decides *how finely we record having-been-somewhere*. Memory is
  approximate by nature. Nobody needs hundredth-of-an-inch precision on the
  question "have I been down this corridor". Quantising it turns an unbounded
  polygon-union problem into setting bits, and setting bits is free.

The two grids need not be the same size and neither knows about the other.

### Terrain is remembered; bodies are not

When the outbound pass builds a viewer's update, walls are sent for every cell in
their memory, and **things are sent only for what is in their sight right now**.

Walk into a room, see a goblin, walk out. The room stays on your screen. The
goblin does not. That is correct: you remember the shape of the room and you have
no idea whether the goblin is still standing there.

Whether a *stale ghost* is drawn instead -- a faded goblin where you last saw one --
is a ruleset decision, not a server one, because it is a statement about how the
game handles uncertainty. If a ruleset wants it, it asks for it, and the server
sends last-seen positions for bodies the viewer has seen before. If it does not
ask, nothing is sent, and a tampered client cannot show what it was never given.

## The part that is not about drawing

Everything above is also the security model. The visibility polygon is not
computed so the browser can draw a nice edge -- it is computed so the outbound
pass knows which records it is permitted to put on the socket.

That argument is made properly in
[what a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md), and
it is the reason sight lives in the C server on the host's machine rather than in
the client, where it would be a great deal more convenient and completely
worthless.

## Read next

- [Who controls what](008-who-controls-what.md) -- which bodies a viewer sees
  from in the first place.
- [What a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md).
