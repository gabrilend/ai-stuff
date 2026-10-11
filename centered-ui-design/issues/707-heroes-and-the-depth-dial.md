# 707 — Heroes and the depth dial

**Phase:** 7 — Growing outward
**Blocked by:** 706, 301

**Blocks**: 708
**Related documents:** docs/core-terms.md (hero, depth dial),
docs/console-layout.md

## Current Behavior

There are no heroes.

## Intended Behavior

- Heroes are special single-unit stands bought from the heroes budget, with
  gear from the choice catalog.
- The depth dial (right screen edge) sets how many tiers out a hero
  adventures. An "adventure" order (button, then click a direction on the
  map) sends the hero out to that depth past the current front, where it
  fights generated encounters scaled to the depth and returns with aether
  and occasionally a held choice.
- Deeper is riskier and richer. A hero lost far out is gone.

## Suggested Implementation Steps

1. Hero stands; adventure order; encounter resolver (data side, seeded).
2. Depth dial (view side), kept per seat.
3. Tests: reward and risk both rise with depth across many seeded runs.
