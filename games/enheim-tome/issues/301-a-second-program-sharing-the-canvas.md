# 301 — A Second Program, Sharing the Canvas

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 101, 102, 201 |
| Blocks | 302, 306, 307, 308, 309, 311 |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | — |

## Current behavior

One program exists, and it only reads.

## Intended behavior

A **second executable** that writes the fence network. The game only ever reads
one. They share the canvas code — the texture, the view, the conversions — and
nothing else.

### Why two programs rather than one with a mode

Defining the city is data generation; playing it is data viewing. Keeping them
apart buys two things:

- The tracing tool can have whatever **dense, ugly, keyboard-heavy** interface
  makes it fastest, because no player will ever see it. It is an instrument, not
  a product.
- **The game physically cannot corrupt a network**, because it contains no code
  that writes one. Not "does not"; cannot.

The trade is that noticing a bad trace mid-game means leaving the game to fix it.
A pin the game could drop for the tool to pick up as a worklist would soften that
and is not currently planned.

### What is shared, and how

The shared parts live in files both programs read: loading the painting, the view
record and its two conversions, the identity buffer, the cage drawing. Neither
program owns them.

**The shared code must not know which program is running it.** No flag, no mode
enquiry. The moment a shared file asks "am I the editor?", the split has been
lost and the two halves have begun to bleed.

### Its own front door

A run script at the project root, runnable from any directory, that opens the
tool on a named network — or on a new empty one. It creates the RAM tiers before
anything tries to write there.

## Suggested implementation steps

1. Separate the canvas code into files with no game logic and no editor logic in
   them, and check that by reading, not by intention.
2. Give the tool its own entry point that sets up the same window split — the map
   pane behaves identically; the tome pane becomes the tool's own controls.
3. Load a network if named, otherwise start an empty one.
4. Write the run script, with a hard-coded project directory at the top,
   overridable by argument.
5. Have the script create `tmp/` and `tmp/shared-memory/` before launching.
6. Confirm the game still runs unchanged after the separation — the viewer with
   no logic in it is what you reach for when you cannot tell whether a fault is
   in the drawing or the thinking, so it must stay runnable.

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [The shape of the code](../docs/010-the-shape-of-the-code.md)
