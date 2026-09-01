# 401 — A Step From Surface To Surface

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 102, 107, 301, 303, 306 |
| Blocks | 402, 403, 404, 601 |
| Reads | [walking the surface graph](../docs/014-walking-the-surface-graph.md) |
| Open questions | none |

## Current behavior

`038-walking.lua`. `from_cell`, `from_layer` and `progress` on the body; the step
completes when progress reaches one and the stance becomes the destination.

Wandering is weighted against reversing, drawn from the `wander_guy` stream.
Measured over a long headless run, walkers travel about ninety cells apiece where
balls travel eighteen — they do not oscillate.

The intent table has two rows so far, `wander` and `idle`, rather than the six
this issue describes. `errand`, `approach`, `flee` and `engage` arrive with the
issues that need them; a body with nowhere at all to go idles rather than
erroring, which the validator counts as a dead-end surface and reports as zero.

## Intended behavior

A walking body holds three things beyond its stance: the surface it left, the
surface it is arriving at, and a `progress` from zero to one. Each tick,
`progress` advances by `speed × dt`; at one, the stance becomes the destination
and the body decides again.

The body is **either at one surface or at another**. It is never between them as
far as anything that matters is concerned, which is what makes both spatial
questions simple: "which cell is this body in" is exactly one cell, and "who is
near it" is one bucket lookup. A continuous position would put a walker in two
cells for half of every step and every question about it would need a
tie-breaking rule.

Deciding is a small table of intents — `wander`, `errand`, `idle`, `approach`,
`flee`, `engage` — each a row rather than a branch.

Wandering is **weighted against reversing**. An unweighted random walk on a graph
spends most of its time going back and forth across the same two cells, which
looks broken rather than aimless. `reverse_weight` makes turning around unlikely
but never impossible — a body in a dead end must be able to.

## Suggested implementation steps

1. Add the `from_cell`, `from_layer` and `progress` fields to the store.
2. Write the `walking` row's `advance` over a chunk: advance progress, and on
   arrival settle the stance and clear the intent.
3. Write the wander chooser: the four answers from issue 107, filtered to
   not-blocked, weighted against the reverse direction, drawn from the `wander`
   stream.
4. Write the intent table with the six rows, four of them raising a named error
   until their issues land.
5. Hand a walker that walks off a ledge to issue 306's falling, and abandon its
   step rather than resuming it — the surface it was heading for is no longer
   adjacent to where it landed.
6. Test: a walker on an open terrace covers ground rather than oscillating —
   measure the distance from its start after a thousand ticks and assert it
   exceeds what an unweighted walk would give. A walker in a dead end escapes.

## Related documents and tools

- [Walking the surface graph](../docs/014-walking-the-surface-graph.md)
- [Standing somewhere and going elsewhere](../docs/004-standing-somewhere-and-going-elsewhere.md)
