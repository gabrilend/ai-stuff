# 104 — The Terraces Are Piled Rectangles

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 101, 103 |
| Blocks | 105, 106, 108 |
| Reads | [carving the maze](../docs/003-carving-the-maze.md) |
| Open questions | 7 (should the upper terraces be inset) |

## Current behavior

Slabs are piled **nested** — each smaller than the last and roughly on top of it,
its centre wandering by a fraction of its own size — plus a handful of scattered
outcrops for irregularity.

Scattered rectangles were what this issue originally described, and they do not
work. Seventy overlapping rectangles do not make terraces, they make noise: every
edge is a height change, the edges land everywhere, and the result renders as a
field of separate cubes at a hundred different heights. Nesting makes the edges
few and long, so every wall on a terrace is the same height and a corridor reads
as a channel between two walls. See `docs/003-carving-the-maze.md` and the entry
in `docs/balance-updates.md`.

Heights cap one wall-height below the top of the world, so a wall standing on the
tallest possible room still fits.

## Intended behavior

The first generator pass. It produces a **landscape** and knows nothing about
mazes.

Every room — a cell where both x and y are odd — is given a base height in
layers. Start every room at zero. Then `terrace_count` times: draw a rectangle
with a size from `terrace_size` and a position biased toward the middle by
`centre_bias`, and add `terrace_rise` to every room inside it.

This is the literal reading of what was asked for: *"a successive layer of flat
stones, rectangular, piled upon one another."* Each rectangle is one flat stone
layer; piling them produces the stepped mound.

Heights clamp at `layers - 1`. A rectangle that would push a room past the top of
the world does not lift it, which produces flat summits rather than an error, and
a flat summit is a real feature of a pile of slabs rather than a failure.

The centre bias is what makes the result look like the reference picture rather
than like scattered boxes: positions drawn toward the middle mean slabs
accumulate there, so the thing is tallest in the centre and steps down to the
edges.

## Suggested implementation steps

1. Write the room lattice helpers first — is this cell a room, a link, or a
   pillar — since three later passes need them and they are pure arithmetic on x
   and y.
2. Allocate the height array at one entry per cell. Rooms are the only entries
   written in this pass; the rest are filled by pass four.
3. Write the rectangle draw: position from the `terrace` stream with the centre
   bias applied by averaging two draws, which pulls the distribution toward the
   middle without needing a distribution function.
4. Sweep the rectangle raising rooms. Clamp.
5. Report the height histogram from the pass, so that a `centre_bias` that is
   doing nothing is visible as a flat histogram rather than as a maze that looks
   slightly wrong.
6. Write the test: the same seed produces the same height array; every height is
   within range; the mean height near the centre exceeds the mean at the edges by
   a margin that a zero bias does not produce.

## Related documents and tools

- [Carving the maze](../docs/003-carving-the-maze.md)
- `docs/balance-updates.md` — the first values and why they were guessed

## Still open

Open question 7 asks whether slabs should be strictly inset inside one another,
which would produce a true stepped pyramid rather than an approximation of one.
The bias approach is assumed for now because it produces irregular edges, which
look more like a ruin and less like a wedding cake. If the answer comes back the
other way, it is a change to step 3 alone.
