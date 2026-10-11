# 208 — Phase 2 demo: the showroom

**Phase:** 2 — Glass and metal
**Blocked by:** 201, 202, 203, 204, 205, 206, 207

**Blocks**: 307
**Related documents:** docs/roadmap.md (Phase 2)

## Current Behavior

No phase 2 demo.

## Intended Behavior

A window that shows every element of the kit, live: all five metal and glass
tones side by side, rings with arc text, a rotor to fling, readouts counting
up, every button state, a two-level complication. Live statistics in glass
readouts: frame time, draw calls, shader switches. Sliders (themselves
half-circle dials) for tone and rotation speed. A combination from phase 1:
the readouts show live numbers from a running headless simulation (tick,
courier count).

## Suggested Implementation Steps

1. `issues/completed/demos/phase-2-demo` script + its Lua scene.
2. Hook the phase 1 simulation thread in to feed the readouts.
