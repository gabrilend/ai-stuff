# Phase 2 progress — particle life

Goal: a living population — preallocated pool, emitters with
fractional spawn honesty, drag-jitter-fade physics, additive glow
splatting, a bloom and a fountain on screen.

- [x] 201 particle pool — solid prefix, swap-with-last, an overflow
      wall that names its asker; churn-fuzzed.
- [x] 202 emitters — fractional carry, aim-blended velocities, one
      seeded voice of chance per render.
- [x] 203 particle physics — drag, frame-rate-honest jitter, backward
      reaping with its reasoning written where it happens.
- [x] 204 glow rendering — the snapshot border proven lossless to
      the last float; sub-pixel stamps lean the way they move.
- [x] 205 burst demo (capstone) — the bloom rings outward in gold,
      the fountain rises teal against real gravity; both watched;
      pool estimates held at honest headroom.

Phase 2 is complete: particles are born with character, move and
wander and die on schedule, and a living population renders through
the lossless snapshot border onto the phase-1 substrate untouched.
The integrator learned one honest extension along the way (a
constant force, explicit everywhere) so fountains can fall.
Choreography is next: time learns to steer.
