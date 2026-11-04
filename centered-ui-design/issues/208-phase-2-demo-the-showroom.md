# 208 — Phase 2 demo: the showroom

**Phase:** 2 — Glass and metal
**Blocked by:** 201, 202, 203, 204, 205, 206, 207, 209, 210, 211

**Blocks**: 307
**Related documents:** docs/roadmap.md (Phase 2)

## Current Behavior

No phase 2 demo.

## Intended Behavior

A window that shows every element of the kit, live: all five metal and glass
tones side by side, dials turning to new values on their own, a two-level
nested calendar dial, readouts counting up, every button state, a row of
small 3D models under the far camera, and each voxel effect at near and far
distance. Live statistics on dials: frame time, draw calls, shader switches,
voxels drawn, depth-precision margin. A combination from phase 1: the dials
show live numbers from a running headless simulation (tick, courier count),
and its stands are drawn as the new models. Settings (tone, voxel density)
are changed by painted buttons, never by turning dials.

## Suggested Implementation Steps

1. `issues/completed/demos/phase-2-demo` script + its Lua scene.
2. Hook the phase 1 simulation thread in to feed the readouts.
