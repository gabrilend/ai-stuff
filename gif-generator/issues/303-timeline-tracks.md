# 303 — timeline tracks

## Current Behavior

Paths and easings exist as loose parts; nothing binds an emitter to a
path under a schedule.

## Intended Behavior

The track: one actor's complete instructions, and the timeline: the
array of tracks the simulator iterates each tick.

- A track binds: an activation window (start, duration), an easing, a
  path (or region sampler), and an emitter recipe.
- Asked about a frame time, a track answers inactive, or active-with-
  state: current position (window → raw fraction → eased progress →
  path), current tangent, current emission strength (full, or ramped
  when the easing governs intensity, as with fade-in tracks).
- Sequencing is expressed by windows ("after the sweep" = starts when
  the sweep's window ends); the timeline is dumb about causality on
  purpose — all ordering is numbers, decided at compile time, so the
  runtime never resolves dependencies.
- The simulator's emit step (from the emitters issue) is rewired to
  consult tracks instead of fixed positions; the tangent feeds the
  velocity bias ("oriented inward").
- Tests: window edges are exact (a track is active on its first tick
  and inactive the tick after its last); eased motion along a known
  arc lands at precomputed waypoints; an intensity-ramped track emits
  proportionally.

## Suggested Implementation Steps

1. The track record and its per-frame interrogation.
2. The timeline container and the simulator rewiring.
3. Tests as described.

## Blockers

- 301 (paths), 302 (easings), 202 (emitters).

## Related Documents

- docs/datapath-scene-script.md (the compiled timeline is this)
- docs/datapath-particle-sim.md (the tick that consults it)
