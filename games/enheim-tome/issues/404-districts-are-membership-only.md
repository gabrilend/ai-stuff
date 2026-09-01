# 404 — Districts Are Membership Only

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 401, 403, 308 |
| Blocks | 405 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | **12** — how many districts, and which blocks go in which |

## Current behavior

Quadrants exist. Nothing sits between them and blocks.

## Intended behavior

A district is **a set of blocks and nothing more**. A name, a quadrant it belongs
to or none, and the blocks that name it.

It has no shape of its own. Its outline is the outer edges of its members,
computed rather than stored — see
[405](405-boundaries-derived-from-members.md).

### What that saves

The alternative, tracing district boundaries by hand, would mean drawing lines
that must coincide exactly with block boundaries already drawn. Every one of those
is a chance for the two to disagree by a pixel, after which a block is inside a
district visually and outside it structurally, or the reverse, and nothing
announces it.

Deriving makes disagreement **unrepresentable**. A block is in a district because
it says so, and the outline follows.

This is the same reasoning that made blocks faces of a network rather than
independent polygons — see [201](201-vertices-edges-and-places.md) — applied a
level up. Where a property matters, pick the representation in which breaking it
cannot be expressed.

### Districts must be contiguous, and that is checkable

A district whose blocks are not all connected to each other through shared edges
is almost certainly a mistake — somebody assigned a block across the river.

Using the neighbour graph from [203](203-adjacency-is-a-shared-edge.md), a walk
from any member should reach every other member without leaving the district.
When it does not, say which blocks are stranded.

**Almost certainly, not certainly.** A district split by a river its own bridges
cross might be legitimate. So this is a report, not a refusal.

### How many there are is unknown

The flat reference view letters about twenty for the whole city — Northside,
Duskside, Crosswater, Fineisle, Old City, Sunshore, Old Harbour, War Port,
Mudside, Newtown, Ritterside and others. Whether that is the right granularity
against roughly two thousand blocks, or whether districts should be finer, is
open question 12.

At twenty districts a district holds a hundred blocks, which feels large for
something a person is supposed to think of as one place.

## Suggested implementation steps

1. A district table: name, and a quadrant or none.
2. Blocks name their district.
3. A derived membership index, rebuilt when assignments change.
4. A contiguity check reported by [309](309-the-coverage-report.md), naming
   stranded members.
5. Test that reassigning a block updates both districts' derived outlines and
   contiguity.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [Open questions](../docs/013-open-questions.md) — question 12
