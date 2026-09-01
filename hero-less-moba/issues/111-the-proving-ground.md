# 111 — The Proving Ground

| | |
| --- | --- |
| Phase | 1 — The World and the Tick |
| Blocked by | 103, 104, 108 |
| Blocks | 206, 214, 602 |
| Reads | [the shape of the code](../docs/018-the-shape-of-the-code.md), [the proving ground](../docs/024-the-proving-ground.md) |
| Open questions | P1, P2 |

## Current behavior

There are three ways to look at this game and none of them can show one rule.

The **headless runner** plays a whole match and prints totals. The **scenario gate**
loads a described world and holds it, but the world it describes is the whole game:
three lanes across a field of thirteen hundred paces, eighteen towers, two libraries,
a chest, five commanders, a phase clock. The **window** draws all of that.

So a question about one mechanic is asked by playing the entire game and squinting.
When a rank piles up behind a body standing in its way, the answer involves the wave
spawner, the phase table, the upgrade economy and the bot, none of which have anything
to do with it. Worse, it involves waiting: the thing to look at happens three minutes
in, in whichever lane the game chose.

And the two existing measuring instruments have both been wrong within the last week
in the same way — a number read off a whole match, attributed to the wrong cause,
because everything was moving at once.

## Intended behavior

**A small square of ground, a handful of bodies, and only the machinery the question
needs.** Three pieces, and the third is the one that makes it worth building.

### The arena

One straight lane running **left to right**, a few hundred paces long, of a stated
width. No towers, no libraries, no bases, no junctions, no bends. A left side and a
right side, and enough room between them to watch something cross.

Straight on purpose: a lane's curve is a real part of how formations work and is the
subject of its own instrument, [the formation sandbox](../tests/060-the-formation-sandbox.info.md).
A test about stepping round an obstacle should not also be a test about cornering,
because when it fails you want one candidate, not two.

### The world, assembled from a named subset

A test declares what it needs — walking and formations, say — and gets a world with
exactly that hung on it. **Anything it did not ask for is absent rather than idle**,
so reaching for it is an error at the moment of reaching rather than a behaviour that
quietly happens in the background of a measurement.

This is the half that makes the instrument trustworthy. A test that runs the whole
cast and merely does not look at most of it is still being influenced by the parts it
is not looking at: waves spawn, phases turn over, bots place upgrades. A test that
cannot spawn a wave because the wave spawner is not there proves something.

### The viewer, showing only what is there

The window opens on the arena and draws the ground, the bodies, and the caption the
scene came with. No chest panel, no hero roster, no sign-posts, no push-depth bands,
no upgrade badges — those describe a match, and there is no match.

**A scene is a file**, the way a scenario is: it names the bodies, where they stand,
and what they are trying to do. A scene that reproduces a bug is a bug report anybody
can open and watch.

## Suggested implementation steps

1. Write the arena's map: one straight lane, left to right, of a stated length and
   width, with the node and lane records the rest of the simulation already expects,
   so that nothing downstream knows it is in a test.
2. Write the subset assembly: given a list of module names, hang those on a world and
   leave the rest unset.
3. Write the scene format and a first scene — a formation on the left walking right,
   past one stationary allied body in the middle.
4. Write the viewer: ground, bodies, caption, and the camera framing the arena.
5. Write the runner script, taking a scene by name.
6. Write down the strategy, so that the next test is written this way without
   anybody having to notice that it should be.

## Open questions

**P1. What does a subset assembly do about the fields a world always has?** The world
record allocates every flat array whether or not the module that reads it is present.
Cheap and harmless, or is a world that has a `target` array but no targeting module a
world that lies about itself?

**P2. Should a scene be able to run without the window at all?** The value of the
arena is mostly in looking, but a scene that can also be asserted about would make
these into tests that fail rather than pictures somebody has to interpret.

## Related documents and tools

- [The proving ground](../docs/024-the-proving-ground.md) — the strategy this serves
- [The scenario gate](110-a-scenario-you-can-hold-at-the-gate.md) — the same idea at
  whole-match scale, and the reason this one is separate
- [The formation sandbox](../tests/060-the-formation-sandbox.info.md)
