# 205 — burst demo (phase 2 capstone)

## Current Behavior

Pool, emitters, physics, and splatting each pass their tests; no gif
has ever shown a living particle population.

## Intended Behavior

The phase-2 demo: two short gifs rendered by one script —

- a **bloom**: a point emitter fired for a fraction of a second, its
  particles expanding outward, dragging to a halt, and embering out;
- a **fountain**: a continuous emitter with directional velocity and
  gentle gravity-like bias, running the full loop.

The demo script lives in `issues/completed/demos/` (phase-2), writes
both gifs to `output/` and its own directory, registers itself with the
root phase-picker, and prints measured statistics: peak live particles,
pool headroom actually used, frames, bytes. It reuses phase 1's encoder
path untouched — the phases compose rather than repeat.

## Blockers

- 201, 202, 203, 204 — all of phase 2's machinery.

## Suggested Implementation Steps

1. Choreograph both pieces directly in Lua (phase 3 owns real paths;
   here emitters sit still or are nudged by hand).
2. The demo script with the DIR convention and printed measurements.
3. Update the root phase-picker's inventory.
4. Watch both. The bloom is the aesthetic checkpoint: if it does not
   look *alive*, tune fade and drag before calling this done, and
   record the tuning in docs/balance-updates.md.

## Related Documents

- docs/roadmap.md (phase 2)
