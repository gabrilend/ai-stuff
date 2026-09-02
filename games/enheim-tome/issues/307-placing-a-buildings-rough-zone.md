# 307 — Placing a Building's Rough Zone

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 301, 302 |
| Blocks | 204, 406 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | — |

## Current behavior

Blocks exist. Nothing inside them can be pointed at.

## Intended behavior

Each building gets a **rough shape over its roof** — enough to click, not a traced
outline.

### Why rough is the right answer

There are five to seven buildings in a block and they sit well apart, so a crude
blob distinguishes them perfectly. Tracing ten thousand accurate footprints would
take an order of magnitude longer and, in the packed quarter south-west of the
bridge, would mostly be **inventing** rather than observing — one roof genuinely
does not visibly end where the next begins there.

So: a few points each, seconds of work, and the difference between a blob and a
footprint is invisible the moment the thing is being used to aim rather than to
draw. The cage's finest level is a little loose, and that is honest about how
much the painting actually tells us.

### It is a separate act from tracing

Blocks are traced first; zones are placed on a return visit, possibly years
later. The tool must not require a block to be fully populated before you move on.

A block with no building zones is a block whose buildings nobody has placed yet.
It still works: hit-testing falls through to the block, because the identity
buffer holds the **finest place that exists** rather than assuming buildings are
always there.

### Zones may not leave their block

A zone belongs to exactly one block and must lie inside it. A zone straddling a
street is a mistake — it would make a building hit-testable from a block it does
not belong to, and the containment chain would then disagree with the geometry.

Overlap between two zones in the same block is also a mistake, since the identity
buffer can only hold one identity per pixel and whichever draws last would
silently win.

## Suggested implementation steps

1. A mode in which clicks build a small polygon rather than a fence, committed on
   close or after a few points.
2. Assign it to the block under it automatically; refuse if it is not wholly
   within one block, saying which street it crosses.
3. Check for overlap with existing zones in the same block and refuse.
4. Give it a name and a purpose at placement, both optional and editable later.
5. Fill zones into the identity buffer after blocks, so buildings win where they
   exist — see [204](204-the-identity-buffer.md).
6. Report, per block, how many zones have been placed, so the coverage report can
   tell traced-but-unpopulated from finished.
7. Test that a click inside a zone reports the building and a click in the same
   block outside every zone reports the block.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [The tracing mode](../docs/005-the-tracing-mode.md)
