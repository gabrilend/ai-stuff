# 012-splat — the frame snapshot and the glow splatter

The border between simulating and drawing: after each tick, the
pool's live prefix is frozen into a compact snapshot (positions,
fades, hues, bright-seeds — numbers only); the splatter stamps each
entry as a radial glow, additively, at its true fractional position.
The copy is the design — the clean testable border worker threads
will later stand on (strategems/pipeline-of-snapshots).

## Usable surface

- **colors_for(declared_names) → flat float array** — hue seats
  resolved to light colors once per render, three floats per hue.
- **snapshot(capacity) → snapshot** — sized once to the pool,
  reused every frame. Fade rides in doubles: it is the one value
  born at the border, and keeping it narrow made snapshot renders
  differ from pool renders in the last bits (the identity test
  caught it; the reasoning is a comment at the field).
- **take(pool, snapshot) → snapshot** — freeze the moment, fades
  computed now. Refuses a snapshot smaller than the pool.
- **render_snapshot(canvas, snapshot, colors)** — the pipeline's
  true path.
- **render_pool(canvas, pool, colors)** — the same light straight
  from the pool; exists only so tests can prove the border loses
  nothing. The pipeline never calls it.

Knobs (RADIUS, INTENSITY) at the file head; tuning belongs in
docs/balance-updates.md.
