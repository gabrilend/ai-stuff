<!-- made by scripts/file-screenshot on 2026-10-11 00:10, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 24 a -8 --screenshot 24.5 -->

# 101 — jointed-limbs-walking-near

- **Picture:** 101-jointed-limbs-walking-near.png
- **Commit:** 5c34442db 2026-10-11 centered-ui-design: no colour snap, a spacing dial, and console shapes that keep their size
- **Run:** `run --wheel-with 24 a -8 --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/017-the-tests.test.lua
  -  M src/018-the-body-plan.lua

## What changed

Compared with picture 100:
- commit: 3cba5ed0a -> 5c34442db
- changed: src/017-the-tests.test.lua
- changed: src/018-the-body-plan.lua


## What it shows

Zoomed in to 0.5 near the console: only terrain circles in view, no villager close enough to show the limbs.

## The story so far

The owner turned to the walk: arms should bend at the elbow, not curve,
and legs bend at hip and knee with the knee only ever pointing forward.
Each limb now turns rigidly in two halves about its joint. These pictures
were zoomed too far in to catch a villager; a see-in-3d model built from
the body plan's own formula shows one villager at six moments of a stride
(kept in mind/).
