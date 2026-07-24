# 006-pool — the particle pool

Every particle that will ever be alive at once, allocated before the
first is born, as parallel flat arrays (positions together, velocities
together, and so on — one particle is one index across all arrays).
Live particles always form a solid prefix; death is swap-with-last, so
indices are not stable across a reap and nothing may remember a
particle by index across ticks.

## Usable surface

- **new(capacity) → pool** — all arrays at once; never grows.
- **spawn(pool, asker) → index** — next slot past the live prefix.
  Overflow is a hard error naming the asking stroke: the sizing
  estimate lied and we want to hear it, not absorb it.
- **kill(pool, index)** — swap-with-last; refuses indices beyond the
  live prefix (a confused caller, said aloud).
- **size_for(demands) → capacity** — numeric peak of standing
  population over demands { rate, life, from, upto }, times headroom,
  plus a floor. Honest because the overflow wall backs it up.

Fields per particle: x, y, vx, vy, age, life, drag, jitter, seed
(brightness variation rolled at birth), hue (a seat number in the
score's declared hue list — colors live with the palette).
