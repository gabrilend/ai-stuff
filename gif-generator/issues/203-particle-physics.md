# 203 — particle physics

## Current Behavior

Particles are born with position and velocity and then nothing happens
to them; there is no motion, aging, or death.

## Intended Behavior

The integrator: the loop that touches every live particle every tick.

- Velocity damped by drag (a per-recipe coefficient), nudged by seeded
  jitter, position advanced by velocity, age advanced by the tick.
- Aging past lifetime triggers the pool's swap-with-last reap.
- A fade value derived from remaining life (young blazes, old embers)
  is computed here and carried to rendering — the fade *curve* is an
  aesthetic knob and its constants live where docs/balance-updates.md
  can reach them.
- The loop is written to stay on LuaJIT's happy path: flat array
  indexing, no table allocation per particle, no closures inside.
- Tests: a drag-only particle slows exponentially; zero-drag zero-
  jitter motion is exactly linear; a cohort with one lifetime dies on
  the same tick; the tick is deterministic under a fixed seed.

## Suggested Implementation Steps

1. The integrate-and-reap pass over the live prefix.
2. The fade curve.
3. Tests as described, including a two-run determinism check.

## Blockers

- 201 (particle pool), 202 (emitters — for realistic test setups).

## Related Documents

- docs/datapath-particle-sim.md (one tick, in order — integrate and
  reap stages)
