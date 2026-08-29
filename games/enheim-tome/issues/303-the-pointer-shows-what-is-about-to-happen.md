# 303 — The Pointer Shows What Is About to Happen

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 302 |
| Blocks | — |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | — |

## Current behavior

A click does one of three things. You find out which by clicking.

## Intended behavior

Before any click commits, the map says which of the three is about to happen:

- a **vertex** about to be adopted **lights up**
- an **edge** about to be adopted **lights up along its whole length**, so you can
  see exactly how much you are taking
- **empty ground** shows the new vertex as a ghost where it would land

### Why this is not polish

Silent mis-snapping is the failure mode that costs a day of retracing to find,
**because it produces a network that looks completely correct on screen**. Two
hairlines a pixel apart down one lane look like one hairline. The blocks either
side are not neighbours, nothing propagates between them, and there is no visible
symptom until something much later behaves wrongly for no apparent reason.

Feedback before the press is the only cheap defence. The validator in
[208](208-the-network-validator.md) is the expensive one, and it catches the
mistake after it is made rather than preventing it.

### Edge adoption especially

Adopting an edge takes a whole run of street, and how far that run goes is not
obvious from the painting — an edge might be the short stretch you expected or
the entire lane. Lighting its full length is what makes that visible **before**
you own it, rather than after.

### It must be legible over the painting

Over brown roofs, blue water, grey stone and green gardens. So the highlight is
**additive light and shape** rather than a colour that means something — a
thickened, brightened line and a clear dot — following the same reasoning as the
glow in the game. See [507](507-the-glow.md).

## Suggested implementation steps

1. Run the same hit-test the click will run, every frame, on the current pointer.
2. Draw the highlight for whichever kind came back, in the same pass that draws
   the cage so it composites the same way.
3. Draw the ghost vertex for empty ground at exactly the position the click would
   place, not at the raw pointer — if snapping would move it, the ghost must show
   the moved position.
4. Keep the in-progress trace drawn as it grows, so the loop being built is always
   visible.
5. Check by eye at three zooms that you can tell adopt-vertex from adopt-edge
   from new-vertex without clicking.

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [302 — the click does three things](302-the-click-does-three-things.md)
