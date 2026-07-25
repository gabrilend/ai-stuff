# 305 — two-clocks demo (phase 3 capstone)

## Current Behavior

Complete — the vision renders and was watched act by act: hands
converging inward mid-sweep with ember trails, the violet seal-line
arriving whole and breathing in between the resting tips, the
triangle flooding downward while the tips ember at its corners. Six
tracks, 114 frames, peak population at 74% of the pool's estimate.
Two interpretation choices recorded: the vision's text swaps the
hands' resting hours in its second mention, and the line description
("between 7 on the left clock and 5 on the right") settles it — left
rests at 7, right at 5; and the triangle's unnamed third vertex is a
low center point, stated as a choice in the demo where the vertices
are defined. The dress rehearsal surfaced one vocabulary need that
already made it into the fills issue: lines that arrive whole
(at-once) versus lines that draw themselves (along).

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
