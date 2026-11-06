# 203 — Brushed-metal and glass-refraction shaders

**Phase:** 2 — Glass and metal
**Blocked by:** 202

**Blocks**: 205, 207, 208
**Related documents:** docs/visual-language.md (Materials),
docs/datapath-glass-and-metal.md

## Current Behavior

Shapes draw in flat color.

## Intended Behavior

- **Metal shader**: base tone; fine streaks running around the circle (from
  a seeded noise texture sampled by angle); a soft broad highlight at a fixed
  screen angle, so turning the part makes the highlight appear to slide over
  it.
- **Glass shader**: samples the canvas beneath (drawn first to an offscreen
  canvas), shifted outward from the lens center by an amount that grows
  toward the edge (refraction), tinted by the glass tone, with a thin bright
  rim and one curved highlight.
- **Paint**: no shader; flat color, with a darker inset ring when pressed.
- Tone 1–5 for each material maps to palette tokens.

## Suggested Implementation Steps

1. `src/NNN-metal-shader.lua` with its GLSL source inline.
2. `src/NNN-glass-shader.lua`; the layered draw order (back canvas, then
   glass) set up in a small compositor.
3. Check on LÖVE 11.5 with both an integrated and a discrete GPU if
   available; record any shader-precision differences in the issue.
