# 008-emit — recipes, the seeded generator, the emit step

A recipe is data: rate, spread, speed, aim (0 scatter to 1
ride-the-heading), life and its jitter, drag, jitter, hue seat. The
emit step births the right number of particles for one tick of one
stroke. All chance flows from one xorshift32 stream per render — the
same score and seed always make the same gif, on any machine.

## Usable surface

- **rng(seed) → generator** — seed 0 is legal (nudged internally so
  the stream never locks at zero).
- **uniform(generator) → [0,1)** — the generator's only voice.
- **recipe(block, hue_index) → recipe** — documented defaults filled
  in (that is vocabulary, not fallback); misspelled fields refused
  with the legal list, because a typo silently meaning "default"
  is the exact lie this project bans.
- **step(pool, rng, recipe, asker, x, y, hx, hy, strength, dt, carry)
  → new carry** — births `rate x strength x dt` particles plus the
  carried fraction; the carry lives with the caller (one per stroke;
  recipes are shared, carries are not). Birth scatter is uniform in
  a disc; velocity blends scatter with the heading by aim;
  bright-seed rolled once at birth.
