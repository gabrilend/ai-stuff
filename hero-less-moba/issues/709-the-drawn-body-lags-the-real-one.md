# 709 — The Drawn Body Lags the Real One

| | |
| --- | --- |
| Phase | 7 — The Window |
| Blocked by | 701, 702, 215 |
| Blocks | — |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) |
| Open questions | R2, R3, R4 |

## Current behavior

A drawn body is at **exactly** where the simulation says it is, blended between the two
most recent snapshots by however far through the tick the frame happens to be. Straight
linear interpolation between two known positions, and nothing else.

That is honest and it is why the picture is trustworthy, and it has one consequence: a
body that changes direction changes direction instantly on screen, because the thing
being drawn has no state of its own to carry.

## Intended behavior

Three separate things were asked for together and they are separable. Only the third is
an architecture change; the first two are visible immediately without it.

### A movement target is pushed off an occupied place — **built, and it left this file**

This is now a rule of the simulation rather than of the drawing, and it lives in
[214](214-going-round-what-is-in-the-way.md). Bodies cannot occupy the same ground at
all, so a destination inside somebody is not a picture problem to be smoothed over —
it is a place the body may not be, and the simulation says so.

Two things about it came out differently from the sketch that was here:

**It is asked about the step, not the destination.** A marching body's place in its
formation can be ninety paces away, and whether somebody is standing on it is a
question about the future. Asked about the place instead of about the next pace,
bodies were shoved off their slots for obstacles they were nowhere near.

**The direction is toward the body's own centre, and that is what "up" meant.** The
paragraph here reasoned its way to the near point of the circle — the point nearest
where the body has just been — and that reasoning was right and is what got built. A
body displaced backwards along its own path has been slowed rather than deflected: it
keeps its file, keeps its heading, and arrives later.

What remains in this file is the drawing.

### The drawn body travels toward the simulated one, with inertia

The picture stops being a blend of two known positions and becomes **a thing with its
own momentum chasing a moving destination.** Explicitly *not* a lerp: a body that has
been going one way keeps some of that when the destination moves, so it leans into a
turn, overshoots a stop, and settles.

Described as a combined-waveform transformation, and that is the useful part of the
description: the drawn position is the sum of the real one and an oscillation that is
decaying, rather than a fraction of the way between two points. What a person watching
gets is bodies that look like they have weight.

**The simulation is untouched.** Where a body *is* stays exactly where it was; this is
a second, softer number that only the screen ever reads, and every measurement, every
test and every replay keeps reading the first one. That separation is the thing to
protect: the moment a drawn position feeds back into a decision, the game is being
played by the renderer.

### The simulation writes into shared memory that every thread reads

Rather than the viewer holding a snapshot handed to it, the world lives in memory every
thread can see — including the drawing thread — so that all of them are reasoning about
the same state at the same time.

This is the largest of the three and the only one that changes the shape of the program.
It should be its own issue before it is started, and it needs an answer to R4 first,
because "everyone reads the same memory" and "the picture is never half of one tick and
half of the next" are in tension, and the current snapshot pair exists precisely to
resolve that tension.

## Suggested implementation steps

1. Put the snap into wherever a movement target is chosen, and watch it in
   [the proving ground](111-the-proving-ground.md) — a scene of bodies being sent onto
   ground somebody is already standing on is a picture that either looks right or does
   not.
2. Give the renderer a per-body drawn position with a velocity, chasing the simulated
   one. Keep the existing straight interpolation behind a switch, because the two want
   comparing and the honest one is the one to fall back to.
3. Leave the shared-memory question alone until the first two are settled and liked.

## Open questions

*R1 is answered and folded into the body above: "up" is back the way the body came —
the point on the circle nearest to where it has just been. A body pushed backwards along
its own path has been slowed rather than deflected, which keeps its file and its place
in the line intact.*

**R2. What are the numbers on the inertia?** How much momentum a drawn body carries and
how fast the oscillation decays, together, decide whether this reads as weight or as
wobble. Found by looking.

**R3. What happens when a body is put somewhere it did not walk?** A spawn, a snap, a
teleport. A drawn body chasing with inertia will visibly fly across the screen unless
told not to, and "told not to" needs a rule.

**R4. What does shared memory actually buy?** The snapshot pair is not an accident: it
is what stops the screen showing half of one tick and half of the next. Reading live
state from a drawing thread reintroduces exactly that, so the answer has to say what is
gained in exchange, and by whom.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- [A body has a size](215-a-body-has-a-size.md) — where the two radii come from
- [Going round what is in the way](214-going-round-what-is-in-the-way.md)
