# 203 — Three Tones And A Mottle

| | |
| --- | --- |
| Phase | 2 — The Eye |
| Blocked by | 202 |
| Blocks | nothing |
| Reads | [drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md) |
| Open questions | 10 (what colour is it) |

## Current behavior

Faces are drawn and they are all the same colour, so the maze reads as a flat
noisy texture rather than as geometry.

## Intended behavior

Three tones, one per face orientation: top at full brightness, left at about
three quarters, right at about half. Light from the upper left, as in the
reference picture.

**No normal vectors and no lighting model.** Every face in this world has one of
exactly three orientations, known when the projection was chosen, so the shading
is a lookup with three entries. A lighting calculation here would be arithmetic
performed to rediscover a constant.

The base colour varies per cell, drawn from a **hash of the cell index** rather
than from a stream, so the stone is mottled, the mottling is stable across
frames and across runs, and it costs no memory and no draws. A hash rather than a
stream specifically because the renderer must not be able to move the simulation.

Higher layers are tinted slightly paler, which does two things at once: it
separates a wall from the wall behind it when both are the same tone, and it
reads as the upper terraces being more weathered.

## Suggested implementation steps

1. Write the tone table: three multipliers, indexed by face orientation.
2. Write the per-cell hash — a cheap integer mix over the cell index, returning a
   small signed offset applied to all three channels.
3. Write the height tint as a function of layer over `layers`.
4. Put the base stone colour, the moss colour and the three tone multipliers in
   the palette file, which is the only file in the project that names a colour.
5. Compare against the reference picture side by side at the same zoom, and
   record any number that was changed as a result in `docs/balance-updates.md`.

## Related documents and tools

- [Drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md)
- [Open questions](../docs/026-open-questions.md) — question 10

## Still open

Open question 10: the palette is the only aesthetic decision in the project that
has not been made deliberately. Grey and tan limestone with green moss is assumed
because that is what the reference picture is.
