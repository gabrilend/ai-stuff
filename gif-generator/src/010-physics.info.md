# 010-physics — the integrator

The one loop that touches every live particle every tick: velocity
gives up to drag (clamped at rest, never vibrating backward), wanders
by seeded jitter scaled to the square root of the tick (so wander
does not depend on frame rate), position moves, age advances, and
whoever ages out is reaped — walking backward, because swap-with-last
pulls the tail into the current slot and a forward walk would let the
swapped-in particle live one tick too long.

## Usable surface

- **tick(pool, rng, dt)** — integrate everyone, then reap.
- **fade_of(pool, index) → 0..1** — remaining-life fraction shaped by
  the fade curve (fast bright youth, long ember tail). Derived, never
  stored: stored derived state is state waiting to desync.

Knob (FADE_POWER) at the file head; tuning belongs in
docs/balance-updates.md.
