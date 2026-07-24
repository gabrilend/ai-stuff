# 201 — particle pool

## Current Behavior

Phase 1 moves a single hand-driven glow; there is no notion of a
particle as a thing with its own life.

## Intended Behavior

The pool: one preallocated block of memory holding every particle that
will ever be alive at once, laid out as parallel flat FFI arrays —
positions, velocities, ages, lifetimes, hue indices, per-particle
bright-seeds. One particle is one index across all arrays.

- Sized once at render start from the scene (spawn rates × lifetimes
  over overlapping activation windows, plus headroom). The sizing
  arithmetic lives beside the pool with its reasoning in comments.
- Refusing to grow is deliberate: overflow is a hard error naming the
  track that asked. Silently dropping particles would silently change
  the picture — the exact fallback this project bans.
- Spawn hands out the next index past the live prefix; death is
  swap-with-last, so live particles always form a solid prefix and
  iteration never checks a liveness flag.
- Tests: spawn/kill churn keeps the prefix solid and the count honest;
  overflow raises the named error; a fuzz of random churn never leaks
  a slot.

## Suggested Implementation Steps

1. The pool record and its FFI allocations (memory first, then work).
2. Spawn and reap operations.
3. The sizing arithmetic from a list of (rate, lifetime, window)
   triples.
4. Tests as described.

## Related Documents

- docs/datapath-particle-sim.md (the pool section is the spec, layout
  rationale included)
