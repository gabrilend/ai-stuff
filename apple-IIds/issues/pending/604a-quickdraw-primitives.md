---
name: QuickDraw II native — primitive draw operations
phase: 6
status: pending (pending soramech)
blockedBy: [601]
parent: 604
---

# 604a — QuickDraw II native: primitive draw operations

Native ARM implementation of QuickDraw's primitive drawing operations:
lines, rectangles, ovals, polygons, arcs. The smallest of the
QuickDraw II sub-rewrites; the right place to start.

## current behavior

Primitives execute in 65C816 emulation. A complex drawing (e.g., the
border decoration of a Finder window) chews through many emulated
cycles.

## intended behavior

- Each primitive routine has a native ARM implementation matching the
  GS/OS API exactly: `MoveTo`, `LineTo`, `FrameRect`, `PaintRect`,
  `EraseRect`, `InvertRect`, `FrameOval`, `PaintOval`, `FrameArc`,
  `PaintArc`, `FramePoly`, `PaintPoly`.
- Pixel-exact equivalence with the emulated version. QuickDraw's
  rasterization details (Bresenham line endpoints, oval pixel
  selection, polygon scan-conversion) are reproduced.
- Operations run on the current `GrafPort`'s framebuffer; the port
  switch and clip-region apply.

## suggested implementation steps

1. Read GS/OS QuickDraw's primitive routines in detail.
2. For each primitive, write an ARM equivalent in C-on-soramech
   (initial port) or ARM assembly (final).
3. Build a regression suite: render every primitive at every size,
   every clip configuration, every color. Compare bit-for-bit to
   the emulated output.
4. Hook GSplus's QuickDraw intercept to call native primitives.
5. Performance measure: how fast does each primitive run vs
   emulated.

## related documents

- `issues/604-quickdraw-ii-native.md` — parent issue
- `issues/601-scrap-manager-native.md` — pattern precedent

## notes

- Primitive ops are the easiest QuickDraw work — no large data
  structures, no shared state beyond the current port. Right
  starting point.
