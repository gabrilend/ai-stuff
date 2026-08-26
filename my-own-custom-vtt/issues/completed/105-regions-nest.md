# 105 -- Regions nest

**Phase:** 1, the world holds still
**Blocked by:** [101](101-the-arithmetic-is-integers.md),
[102](102-the-world-is-flat-arrays.md),
[104](104-walls-are-segments.md)
**Blocks:** [602](602-membership-is-a-list-or-a-region.md), which is how the
tavern's commander exists at all.
**Documents:** [the map is geometry](../../docs/006-the-map-is-geometry-not-a-picture.md),
[who controls what](../../docs/008-who-controls-what.md)

## Current behaviour

Nothing exists.

## Intended behaviour

A region is a named area with a closed polygon boundary and a parent. The tavern.
The forest. The cellar under the tavern. The clearing in the forest.

Regions are what make an abstract control scope addressable. When somebody is
handed command of "the tavern", what they are handed is a region index, and their
scope covers every thing whose `region` field resolves to it.

### The parent chain

Regions nest, and nesting is a single `parent` index rather than a list of
children. A scope over the forest covers the clearing inside it without listing
the clearing, by walking a thing's region up through its parents looking for the
scope's region.

That walk is short -- nesting depth at a tabletop is two or three -- and it happens
on every permission check, so it should be a loop over indices with no
allocation, and it should have a depth limit that the validator enforces rather
than the loop guarding against.

### Which region is a thing in

The `region` field on a thing is maintained rather than computed. Phase 3's motion
pass updates it when a body crosses a boundary, and only for bodies that actually
moved. Phase 1 sets it when a thing is placed, using point-in-polygon against
every region, which is slow and correct and only ever runs at load.

Point-in-polygon on nested regions returns the **deepest** region containing the
point, since a thing in the cellar is in the cellar and not in the tavern.

## Suggested implementation steps

1. Define the region record and the shared vertex pool. Boundaries are closed --
   the last vertex joins the first, and there is no repeated final vertex,
   because a repeated final vertex is a thing half the code remembers.
2. Write point-in-polygon in fixed point. The crossing-number method is the usual
   choice; the care is entirely in what happens when the test ray passes exactly
   through a vertex, and that case needs a comment saying which way it was
   resolved and why.
3. Write the deepest-containing-region query on top of it.
4. Write the parent-chain walk as its own small function, since permission checks
   and the furnishing stage in phase 8 will both want it.
5. Write the companion `.info.md`.
6. Test: nested regions three deep, a point in each level, a point in none, a
   point exactly on a boundary, and a region whose polygon is wound the other way
   round.

## Open question this touches

[6.1](../../docs/016-open-questions.md) -- when a patrol walks out of the forest and
into the tavern, whose is it? Mechanically this file gives the answer "the
tavern's, immediately", because that is what maintaining the `region` field
means. Whether that is the wanted answer is not settled, and if it is not, the
change lands in [602](602-membership-is-a-list-or-a-region.md) rather than here.
