# 205 — burst demo (phase 2 capstone)

## Current Behavior

Complete. Both pieces render and both were watched: the bloom is a
breath of gold that rings outward and embers (frame 12 shows the
ring mid-flight); the fountain is a teal jet with a rose heart whose
white-hot core sheds sparks that rise against gravity and fall. Peak
populations landed at 75-78% of the pool's estimates — the headroom
is honest. One extension made along the way and recorded where it
lives: the integrator gained an explicit constant-force argument
(zero when unwanted, at every call site — no optional-nil games)
because a fountain must fall; the completed physics issue carries
the cross-note. The demo's piece-runner is a hand-made preview of
what compiled scores will hand the phase-4 runner.

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
