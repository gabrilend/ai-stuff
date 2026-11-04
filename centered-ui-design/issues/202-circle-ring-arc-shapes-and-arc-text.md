# 202 — Circle, ring, arc and half-circle shapes, and text along arcs

**Phase:** 2 — Glass and metal
**Blocked by:** 201

**Blocks**: 203, 204, 206, 208
**Related documents:** docs/visual-language.md (Shapes),
docs/datapath-glass-and-metal.md

## Current Behavior

Nothing is drawn but phase 1's debug view.

## Intended Behavior

- Drawing functions for the shapes every console element is made of: full
  circle, ring (inner and outer radius), arc segment (a ring between two
  angles), half-circle, each as a mesh with texture coordinates that run
  *around* the circle (angle) and *across* it (radius), so shaders can brush
  metal in circles.
- Text placed along an arc: each glyph positioned and turned to follow the
  curve, reading clockwise on the top half and counter-clockwise on the
  bottom half so it is never upside down.
- Hit testing for each shape: is this pixel inside this ring segment.

## Suggested Implementation Steps

1. `src/NNN-round-shapes.lua`: mesh builders with polar texture coordinates.
2. `src/NNN-arc-text.lua`: glyph placement along an arc.
3. `src/NNN-round-hit-tests.lua`.
4. Tests: hit tests at segment borders; arc text glyph angles for the top and
   bottom halves.
