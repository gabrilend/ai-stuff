# 709 — The Drawn Body Lags the Real One

| | |
| --- | --- |
| Phase | 7 — The Window |
| Blocked by | 701, 702, 215 |
| Blocks | — |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) |
| Open questions | R2 provisionally, until looked at; R3 settled; R4 answered by Claude, open for Ritz |

## Current behavior

A drawn body is at **exactly** where the simulation says it is, blended between the two
most recent snapshots by however far through the tick the frame happens to be. Straight
linear interpolation between two known positions, and nothing else.

That is honest and it is why the picture is trustworthy, and it has one consequence: a
body that changes direction changes direction instantly on screen, because the thing
being drawn has no state of its own to carry.

**Step 2 is built, behind a key, and nobody has seen it.** [074](../src/074-the-drawn-body.info.md)
gives every body a drawn place and velocity, pulled toward the honest position by a
spring that swings a little before it settles. The viewer keeps both pictures every
frame and the renderer draws whichever it is handed; `i` swaps them, and the honest one
is the default. The numbers on the spring were chosen by arithmetic, and this machine
has no LÖVE, so how it actually looks is still R2's question.

**Step 3 is begun: the memory and the rule for reading it.** [079](../src/079-the-shared-frame.info.md)
holds the bodies of the viewer's frame in a ring of four blocks, in memory another
thread can be handed, and a reader takes a block only if it was whole before and after
it copied it — so nothing that reads it ever takes half of one tick and half of the
next. [The test](../tests/080-the-shared-frame.lua) proves that with two real
processes: one plays a match and writes every tick, the other reads while it does,
and every frame it kept is exactly a frame the match had. **The game does not use it
yet.** The simulation still runs on the drawing's thread, because putting it on its own
needs LÖVE's threads, and LÖVE is not on this machine to try them; that is the next
step, below.

What it promises, and what `tests/051-the-invariants` checks without a window:

- a walking body is trailed and never led, a stop is overrun, and the body settles;
- the swing is the same at thirty frames a second and at a hundred and fifty, because
  each frame is solved exactly rather than stepped;
- the drawn body is never further than half a personal space from the real one;
- a body that was born, put somewhere, or fast-forwarded is drawn where it is.

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
It needed an answer to R4 first, because "everyone reads the same memory" and "the
picture is never half of one tick and half of the next" are in tension, and the
current snapshot pair exists precisely to resolve that tension. R4 is answered below,
and the answer is what was built: **what is shared is finished frames, not the live
world.**

It stays in this issue rather than becoming one of its own, so the roadmap's rows do
not move. *Chosen by Claude, open for Ritz.*

What is left of it, in order:

1. **A thread for the simulation**, in LÖVE: it assembles the world, keeps the clock the
   accumulator keeps now, applies the commands sent to it on a channel, stamps, and
   writes each tick into the ring in a ByteData both threads hold. The viewer stops
   ticking and reads.
2. **The rest of the frame** — the chest, slots, wallets, phase, sign-posts, events —
   crosses on a channel once a tick. It is small, and it is not drawn between ticks, so
   it needs no ring.
3. **What the viewer reads from the world directly**: the map and the parameters, which
   never change and can be built on both sides from the same seed; and a few live reads
   in input and the renderer (the wave, the structures, the sign-posts), which have to
   move onto the frame first.
4. Looked at, at walking pace and fast-forwarded, beside the one-thread loop it
   replaces, which stays behind a switch until then.

## Suggested implementation steps

1. Put the snap into wherever a movement target is chosen, and watch it in
   [the proving ground](111-the-proving-ground.md) — a scene of bodies being sent onto
   ground somebody is already standing on is a picture that either looks right or does
   not.
2. Give the renderer a per-body drawn position with a velocity, chasing the simulated
   one. Keep the existing straight interpolation behind a switch, because the two want
   comparing and the honest one is the one to fall back to.
3. Shared memory: the frame's bodies in a ring of whole frames (built, not yet used),
   then the simulation on its own thread (listed above, not built).

## Open questions

*R1 is answered and folded into the body above: "up" is back the way the body came —
the point on the circle nearest to where it has just been. A body pushed backwards along
its own path has been slowed rather than deflected, which keeps its file and its place
in the line intact.*

**R2. What are the numbers on the inertia?** How much momentum a drawn body carries and
how fast the oscillation decays, together, decide whether this reads as weight or as
wobble. Found by looking.

*Provisionally: three swings a second, damped to half of what would stop it dead.* That
trails a hurrying body by about two paces, runs past a stop by under one, and settles
within two-thirds of a second. Chosen so the weight is visible at the closer zooms and
invisible at the rest framing. Still to be looked at, which is why the weighted picture
is off by default.

**R3. What happens when a body is put somewhere it did not walk?** A spawn, a snap, a
teleport. A drawn body chasing with inertia will visibly fly across the screen unless
told not to, and "told not to" needs a rule.

*Settled: it snaps, by three tests and one bound.* A body is drawn exactly where it is,
with no velocity, when it was not alive or not followed in the previous frame; when it
moved further than one personal space between two consecutive ticks, which nothing
walking can do (the fastest gait covers under two paces a tick); or when the clock runs
faster than walking pace. Behind those, whatever else goes wrong is caught by a bound:
a drawn body is never more than half a personal space from the honest position, so it
can never be drawn on the far side of a neighbour it did not pass.

**R4. What does shared memory actually buy?** The snapshot pair is not an accident: it
is what stops the screen showing half of one tick and half of the next. Reading live
state from a drawing thread reintroduces exactly that, so the answer has to say what is
gained in exchange, and by whom.

*Answered by Claude, open for Ritz: separate clocks, for the person watching, and
memory to share, for the thread pool. The price is not paid, because what is shared is
finished frames.* Today the simulation and the drawing take turns on one thread: a slow
frame delays ticks, and a fast-forwarded match spends each frame on up to forty ticks
before drawing anything. On its own thread the simulation keeps time whatever the
drawing does, and the drawing draws whatever was most recently finished — the person
watching gets the frame rate back at high speed, and [209](209-the-thread-pool-slices-the-tick.md)'s
workers get memory allocated up front that every thread can see. The tension with the
snapshot pair is resolved by keeping the pair: each tick's frame is written whole into
one block of a ring, under a sequence number that is odd while it is being written, and
a reader keeps a copy only if the number was even and unchanged across the copy. The
writer never waits for a reader. Nothing reads the live world from another thread.

The numbers: **four blocks** — two for the pair a reader blends between, one for the
writer, one spare so a slow reader still finds its pair whole. When the tick before the
newest has gone, the previous frame is the newest again: no blend, the honest picture.
And **x86 only**: the rule needs loads and stores kept in order, which x86 does by
itself and other processors need fences for that LuaJIT does not offer, so the ring
refuses to be made anywhere else rather than run unsoundly.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- [A body has a size](215-a-body-has-a-size.md) — where the two radii come from
- [Going round what is in the way](214-going-round-what-is-in-the-way.md)
