# 020-fills — fill regions and field tracks

"Fill the triangle, slowly" — a fill is a field emitter whose
covered portion grows, not a rasterizer. Particles land uniformly in
the covered part, so the advancing frontier glows and leaves
settling light behind. Two vertices make a line region (the
zero-thickness case, the vision's seal-line); three or more make a
polygon.

Sweep styles (a dispatch table — adding one is adding a row):
at-once (whole region from the first breath), downward (a frontier
descends), radial (a disc grows from the centroid), along
(two-vertex lines drawing themselves tip to tip).

Sampling proposes points inside a shape that already respects the
frontier (a strip, a disc, a prefix) and rejects only on the polygon
test — so tiny opening coverages never starve. Hundreds of straight
misses means a degenerate region, said aloud.

## Usable surface

- **region{vertices, sweep} → region** — with sample(rng, coverage)
  → x, y. Refuses flat polygons, dot lines, unknown sweeps (legal
  words taught back).
- **track{name, from, lasts, ease, envelope, region, recipe} →
  track** — same record shape as a spot track; the timeline never
  asks. Births land at their own sampled points, headings zero (a
  field scatters by recipe; aim honestly means nothing here). Zero
  coverage births nothing and banks nothing — the reasoning is a
  comment at the decision.
