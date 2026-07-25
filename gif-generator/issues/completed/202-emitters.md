# 202 — emitters

## Current Behavior

Complete. Recipes carry the documented defaults (misspelled fields
refused with the legal list — a typo must never silently mean "use
the default"); the emit step births by fractional carry, blends
scatter with heading by an aim weight, and rolls each particle's
bright-seed and lifetime once at birth. The xorshift32 generator
lives here too — one stream per render, machine-independent, seed
zero legal. One design note beyond the blueprint: the carry lives
with the caller, one per stroke, because recipes are shared and
carries must not be. Eleven assertions.

Amended with the fill-regions issue: the single birth and the
fractional-due arithmetic became public atoms, so field emitters can
place every birth at its own sampled point while the spot-tick step
remains one caller among others. Behavior byte-identical; the suite
passed unchanged.

## Intended Behavior

Emitter recipes and the emit step.

- A recipe is data: spawn rate (particles per second), positional
  spread, initial-velocity character (speed, direction bias — e.g.
  "inward" from the vision), lifetime range, hue name.
- Point emitters spawn at a given position (later: the moving tip of a
  path). Field emitters spawn across a region via a sampler function —
  the same mechanism will serve lines and growing fills in phase 3.
- Spawn counts accumulate fractionally across ticks: a rate of 400 per
  second at 25 fps yields exactly 16 per tick, and awkward rates never
  drift — the accumulator carries the remainder.
- All randomness (spread, velocity jitter, lifetime roll, bright-seed)
  draws from the render's seeded generator: same scene, same gif.
- Tests: exact counts for divisible rates, no drift for awkward ones
  over long runs, determinism across two runs with one seed,
  divergence across two seeds.

## Suggested Implementation Steps

1. The recipe table and its documented defaults (vocabulary, not
   fallback — absent optional fields have written-down meanings).
2. The emit step against the pool from the previous issue.
3. The fractional accumulator.
4. Tests as described.

## Blockers

- 201 (particle pool).

## Related Documents

- docs/datapath-particle-sim.md (one tick, in order — the emit stage)
