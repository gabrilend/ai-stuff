# 308 — Bodies Are Bucketed By Cell

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 301, 302 |
| Blocks | 307, 405, 601 |
| Reads | [a body and what it carries](../../docs/011-a-body-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

A counting sort into preallocated count, offset and id arrays. Nothing allocated
per tick. `largest_bucket` goes into the report.

The footprint hook and the carried-body skip are both written and neither has
anything to exercise it yet — nothing is wider than a cell until phase six and
nothing is carried until phase seven. They are here because writing the
placement to take a footprint costs nothing now and is a rewrite later.

The renderer reads these same buckets to group bodies into draw bands, which is
the second reason they are rebuilt every tick rather than maintained
incrementally.

## Intended behavior

A **bucket per cell**, rebuilt every tick by the `index` pass in two sweeps: one
counting how many bodies are in each cell, one placing them.

Two preallocated arrays — a count and an offset — and one array of ids. No lists,
no tables, nothing allocated per tick. A counting sort, which is what this is,
costs two linear passes and gives constant-time lookup of a cell's occupants.

This is what keeps [the meet pass](../405-the-meet-pass-pairs-bodies.md)
proportional to the number of bodies instead of to its square. That property
depends on bodies being **spread out**: a hundred bodies in one cell puts them
all in one bucket and the pass is quadratic again, on the tick where things are
already going badly.

So the largest bucket size goes in the report. A number that climbs is the
warning; a stall is what happens if nobody looks.

Two details that are easy to get wrong:

- A **body wider than one cell** goes in every bucket its footprint covers, or
  anything standing beside its tail cannot see it. Phase six needs this; writing
  the placement to take a footprint now costs nothing.
- A **carried body is in no bucket at all.** It is not in a cell of its own, it
  is in its mount's, and skipping it is also what stops the meet pass pairing a
  rider with whatever its mount walks past.

The renderer uses these same buckets to draw bodies in the right order, which is
the second reason they are rebuilt every tick rather than maintained
incrementally — an incrementally maintained index is one that can be subtly wrong
for a while.

## Suggested implementation steps

1. Allocate the count and offset arrays at one entry per cell, once.
2. Write the count sweep, the prefix sum, and the placement sweep.
3. Write `bodies_in(cell)` returning a range into the id array, and
   `for_each_near(cell, fn)` covering the nine-cell neighbourhood.
4. Write the footprint placement for wide bodies, and the skip for carried ones.
5. Record the largest bucket into the report.
6. Test: against a slow reference that builds a table of lists, over random body
   placements, the buckets agree exactly. A wide body appears in every cell of
   its footprint and no others.

## Related documents and tools

- [A body and what it carries](../../docs/011-a-body-and-what-it-carries.md)
- [Two bodies meeting](../../docs/016-two-bodies-meeting.md)
