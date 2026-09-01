# 301 — The Tracing Mode

| | |
| --- | --- |
| Phase | 3 — The Tracing Mode |
| Blocked by | 101, 102, 201 |
| Blocks | 302, 306, 307, 308, 309, 311, 312 |
| Reads | [the tracing mode](../docs/005-the-tracing-mode.md) |
| Open questions | — |

## Current behavior

One program exists, and it only reads.

## Intended behavior

**A mode inside the game**, deliberately entered, in which the city can be cut up.

### Why in the game rather than a separate tool

So that **a map is a thing players can make**. If the editor were a developer
tool, nobody but the author could ever produce a city; inside the game, a map is
a mod, and other people's readings of other places become possible.

That reverses an earlier decision, and the reversal costs something worth naming
rather than glossing: the game can no longer be **physically incapable** of
corrupting a network, because it now contains code that writes one. That was a
real guarantee and it is gone.

What replaces it is a discipline: **the editing code lives in its own files, and
nothing that draws the world may touch them.** Generating and viewing stay
separate as an arrangement of the source rather than as a fact about two
executables. It is weaker, and it is the price of maps being mods.

### It is a mode, and that is deliberate

Playing and editing are separate states you switch between on purpose.

They have to be, because the same button means different things in each: in play
the right button acts on the world, in the tracing mode it places a node. Keeping
them apart is what stops a mis-click reshaping the city.

The cost is a mode, and a mode is a thing you can be in without noticing. So it
must be **unmistakable** — the clearest signal being that the cage shows **every
level at once** rather than only the selectable one, which is exactly what
editing needs anyway and exactly what play never does.

### What it shares with play

The texture, the view and its two conversions, the identity buffer, the cage
drawing. Panning and zooming behave identically, because they are the same code.

**The shared code must never ask which mode is running it.** The moment a drawing
file wants to know *am I editing?*, the discipline above has been lost and the two
halves have begun to bleed.

### The tome while editing

The tome's three regions stay, and the mode fills them with its own contents: the
selected thing's fields, the menu opened by tab, the validator's complaints. The
button pane is where the editing actions live.

## Suggested implementation steps

1. Separate the canvas code into files with no play logic and no editing logic in
   them, and check that by reading rather than by intention.
2. Add the mode as a state of the one program, with an unmistakable entry and
   exit.
3. Show every level of the cage while in it.
4. Route the editing gestures — [302](302-cutting-and-severing.md) — only while in
   the mode.
5. Confirm the game still runs and reads identically with the mode never entered,
   since a viewer with no logic in it is what you reach for when you cannot tell
   whether a fault is in the drawing or the thinking.

## Related documents and tools

- [The tracing mode](../docs/005-the-tracing-mode.md)
- [The shape of the code](../docs/010-the-shape-of-the-code.md)
