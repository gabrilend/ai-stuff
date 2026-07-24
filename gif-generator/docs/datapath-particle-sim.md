# Datapath — from timeline to particle states

This document follows one tick of simulated time: the timeline answers
"where is everything," and a block of memory fills with glowing motes.

## The particle pool: memory first

All particles live in one preallocated pool, sized at render start from
the scene (spawn rates x lifetimes, summed over overlapping tracks,
with headroom — the sizing arithmetic lives with the pool, and refusing
to grow is deliberate: overflowing the pool is a hard error naming the
track that asked, because silently dropping particles would quietly
change the picture).

The pool is laid out as parallel flat arrays — all x-positions
together, all y-positions together, likewise velocity, age, lifetime,
hue-index, and a bright-seed (per-particle brightness variation, rolled
at birth). One particle is one index across all arrays.

Why parallel arrays instead of an array of little tables: the update
loop touches every particle every frame; flat FFI arrays keep that loop
in cache and keep LuaJIT compiling it as tight machine code. And a
future worker thread can own "indices 0 through 4095" as its span with
no coordination beyond the boundary numbers.

Death is a swap: when a particle's age passes its lifetime, the last
live particle is copied into its slot and the live-count drops by one.
The arrays never fragment; live particles are always a solid prefix.

## One tick, in order

1. **Emit.** For each active track: the easing shapes the time-
   fraction, the path turns it into a position (or the fill's region
   sampler yields points inside the covered area), and the emitter
   recipe says how many particles to spawn this tick. Spawn count
   accumulates fractionally across ticks so a rate of 400-per-second at
   25 fps emits exactly 16 per tick, not a rounded lie. New particles
   inherit small random spread in position and velocity, and their hue
   from the recipe.

2. **Integrate.** Every live particle: velocity is damped by drag,
   nudged by jitter (seeded RNG — same scene, same nudge), position
   moves by velocity, age increases by the tick.

3. **Reap.** Age past lifetime → swap-with-last, as above.

The tick equals the frame interval exactly (one sim step per frame).
The simulator neither knows nor cares about pixels — its entire output
is "the first N slots of the pool are alive, here are their numbers."

## The frame snapshot

After each tick, the live prefix of the pool is copied into a compact
frame snapshot (positions, remaining-life fractions, hues, bright-
seeds). The snapshot is what crosses the border to the renderer — the
copy is what will let rendering run on other threads later while the
sim keeps ticking, and it is small: tens of kilobytes, not megabytes.

## Relevant pieces

- the particle pool (parallel arrays, live-count, swap-with-last reaping)
- the emitter step (tracks consulted, fractional spawn accumulator)
- the integrator (drag, jitter, aging)
- the frame snapshot (the compact hand-off record)
