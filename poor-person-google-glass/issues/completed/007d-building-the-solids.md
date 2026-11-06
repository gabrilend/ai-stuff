# 007d — Building the solids

**Phase:** 0 — Tools
**Parent:** 007
**Blocked by:** 007c
**Blocks:** 007e

## Current Behavior
Built in `src/015-building-the-solids.lua`, using the outward-facing helpers
from `src/002-the-test-shapes.lua` (now lent as its `kit`). Turns to an axis
are true rotations, so faces stay outward. Spheres end in triangles at the
poles (no slivers). Tested: every kind's bounds equal its extents in every
direction; convex solids' faces all point out.

## Intended Behavior
Each solved part becomes triangles in a shape record (001): box, cylinder
(and disc, rod), cone, sphere (and ball), ring (a torus whose hole runs
along the axis), built around a local upright axis, then turned to the
part's axis and moved to its centre. Every face points outward.

## Suggested Implementation Steps
1. src/015-building-the-solids.lua.
2. Tests: each kind's bounds equal its extents; normals point out.
