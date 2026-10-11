# 207 — Complication windows onto lower discs

**Phase:** 2 — Glass and metal
**Blocked by:** 203, 204

**Blocks**: 208, 302, 306
**Related documents:** docs/visual-language.md (Materials),
docs/console-layout.md (Calendar complication)

## Current Behavior

Every element is drawn at one depth.

## Intended Behavior

- A complication is a window (arc-shaped slot or round hole) cut through a
  surface, with a disc behind it at a lower depth, drawn darker, carrying
  printed words or numbers around its edge. The disc turns (a rotor) to bring
  the right word under the window.
- Windows can be nested: a window in the face, and behind it a disc that has
  its own window onto a disc below — "a number, on one level lower".
- The window's edge is beveled metal; a thin glass cover sits over it.
- Implemented with a stencil so anything drawn on the lower disc only shows
  through the window.

## Suggested Implementation Steps

1. `src/NNN-complication.lua`: window shape, disc rotor, list of printed
   entries; stencil drawing.
2. Demonstrate a two-level complication: weekday words on the upper disc,
   numbers 1–31 on the lower.
