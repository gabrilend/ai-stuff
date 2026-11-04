# 209 — The far camera

**Phase:** 2 — Glass and metal
**Blocked by:** 101

**Blocks**: 208, 210, 211, 301, 212, 213, 214
**Related documents:** docs/visual-language.md (The far camera)

## Current Behavior

Mostly built (2026-10-10) in `src/003-the-far-camera.lua`: the camera sits 10
million units away (from `input/`); points are measured from the map's
center and projected with the distance only ever divided (w = 1 − ez ÷
distance), so the faint true perspective survives in 32-bit floats; depth is
linear across the scene's band. The same arithmetic exists as a shader
snippet and in Lua (for clicks and tests). Tests: a sheet sized for the view
lands on the screen's corners within 1e-5 at distances 2,000, 10 million and
1 billion; a click finds the ground point it was drawn at. Not built yet: the
z-fighting check with two thin models a hair apart at the map's edge.

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
