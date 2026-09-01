# 405 — The Meet Pass Pairs Bodies

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 301, 302, 308 |
| Blocks | 406, 501, 702, 707 |
| Reads | [two bodies meeting](../docs/016-two-bodies-meeting.md) |
| Open questions | none |

## Current behavior

Bodies pass through each other without noticing.

## Intended behavior

**Everything that happens between two bodies happens in this one pass.** No
other pass reads one body's state and changes another's.

Pairing is the only thing in the simulation that is not independent per body.
Confining it here is what lets every other pass be split across cores without
anybody thinking about it — and this pass is small precisely because it is the
one that cannot be. See [the tick](../docs/010-the-tick.md).

For each body, look at its own bucket and the eight around it, and consider each
body found whose **id is greater than its own**. That one comparison is what
stops every pair being considered twice, instead of a set of already-seen pairs,
and it keeps the pass a single sweep with bounded work per body.

What a pairing means is a **dispatch table indexed by the two creature kinds**,
not a chain of conditions. The chain grows as the square of the number of
creatures and cannot be printed. Being able to print the complete list of what
any two things do when they meet is the fastest way to notice that nobody wrote
down what happens when a golem meets a ball.

Two walkers wanting the same surface: the lower id gets it, the other re-decides
next tick. Deterministic, cheap, and unfairly in a way nobody can perceive. Two
bodies already overlapping are pushed apart along the line between them; if
neither can move they stay overlapped and it is **counted** — an overlap that
persists is a real problem, one that resolves next tick is not, and counting is
the only way to tell them apart.

## Suggested implementation steps

1. Write the neighbourhood iterator over the nine buckets with the greater-id
   filter.
2. Write the meet table as a two-dimensional table of functions indexed by kind,
   with a default that does nothing, and a printer that dumps the whole table.
3. Write the contested-surface rule and the overlap push.
4. Count meetings by kind pair, overlaps resolved, and overlaps persisting.
5. Test: two bodies placed adjacent are paired exactly once, not twice. Two
   bodies placed in the same cell separate within a tick when there is room and
   are counted when there is not.

## Related documents and tools

- [Two bodies meeting](../docs/016-two-bodies-meeting.md)
- [The tick](../docs/010-the-tick.md)
