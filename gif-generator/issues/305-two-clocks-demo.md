# 305 — two-clocks demo (phase 3 capstone)

## Current Behavior

Every choreography part exists tested and alone; the vision's founding
gesture has never been rendered.

## Intended Behavior

The phase-3 demo: the vision, choreographed directly in Lua (the scene
*language* is phase 4; this proves the machinery it will compile to):

- Left clock: hand sweeping clockwise from 12 to 7, stroke easing,
  ember glow at the tip, velocity biased inward.
- Right clock: mirrored — 12 sweeping counterclockwise to 5.
- When both hands rest: a line fades in between the two tips
  (zero-thickness field emitter, fade-in easing).
- Then the triangle between the tips and the lower midpoint fills
  slowly, downward sweep. (The vision says "the triangle" without
  naming a third vertex; the demo picks the natural reading — the two
  tips plus a low center point — and states this choice in a comment
  where the vertices are defined, so a future reader knows it was a
  choice, not a fact.)
- Rendered to `output/`, registered with the phase-picker, statistics
  printed: track count, peak particles, frames, bytes.

## Blockers

- 301–304, and all of phase 2.

## Suggested Implementation Steps

1. Translate the vision prose into tracks, keeping a side-by-side
   comment: prose phrase → track element. This mapping is the dress
   rehearsal for the scene language — anything that translates
   awkwardly here is a vocabulary bug to fix *before* phase 4 freezes
   the format.
2. The demo script, picker registration, measurements.
3. Watch it against the vision text, phrase by phrase. Tune timings in
   docs/balance-updates.md entries, not silently.

## Related Documents

- notes/vision (the text being staged)
- docs/roadmap.md (phase 3)
