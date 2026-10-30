# 037-fluid — the liquid

A small liquid sloshing in an invisible tilting box, worked out once ahead
of filming so every frame and every worker sees the same drops. The same
recipe and seed always give the same drops.

## Usable surface

- **simulate(spec, frames) → { frames, start, seam }** — the drops at
  every frame of one loop.
- **tilt_matrix(tilt, t)** — the box's turn at loop moment t.

Details in `039-shape-films.info.md`, under "The parts".
