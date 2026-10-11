# 209 — The far camera

**Phase:** 2 — Glass and metal
**Blocked by:** 101

**Blocks**: 208, 210, 211, 301
**Related documents:** docs/visual-language.md (The far camera)

## Current Behavior

There is no 3D scene.

## Intended Behavior

- The map is a true 3D scene seen by a camera placed impossibly far away
  through a very long lens, so the world looks nearly flat and evenly scaled
  like a map, yet models keep their depth, light and shadow.
- Accurate at that distance: geometry is sent to the GPU relative to the
  camera's target (large world coordinates subtracted on the CPU in double
  precision before conversion to the GPU's single precision), and depth uses
  a scheme that keeps precision across the range (reversed or logarithmic
  depth, whichever LÖVE 11.5's depth buffers support).
- The 3D scene draws into a canvas; the dashboard is composited on top.

## Suggested Implementation Steps

1. `src/NNN-far-camera.lua`: projection and view matrices from the long-lens
   settings; target-relative transform.
2. A depth-precision test scene: two thin models a hair apart, at the far
   edge of the map, must never flicker (z-fighting check by rendering twice
   and comparing).
3. Record measured precision in the issue.
