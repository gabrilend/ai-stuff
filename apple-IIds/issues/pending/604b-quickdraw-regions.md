---
name: QuickDraw II native — region manipulation
phase: 6
status: pending (pending soramech)
blockedBy: [604a]
parent: 604
---

# 604b — QuickDraw II native: region manipulation

Native ARM implementation of QuickDraw's region data type and the
operations on it: intersect, union, difference, xor, copy, framing,
hit-testing.

## current behavior

Regions execute in emulation. Region ops are heavy (variable-size
data structures, complex polygon-ish algorithms), so this is one of
the more impactful native ports.

## intended behavior

- Native implementations of: `NewRgn`, `DisposeRgn`, `CopyRgn`,
  `SetRectRgn`, `RectRgn`, `OpenRgn`, `CloseRgn`, `OffsetRgn`,
  `InsetRgn`, `SectRgn`, `UnionRgn`, `DiffRgn`, `XorRgn`,
  `PtInRgn`, `RectInRgn`, `EqualRgn`, `EmptyRgn`, `FrameRgn`,
  `PaintRgn`, `EraseRgn`, `InvertRgn`.
- Region data structure preserved byte-for-byte (variable-size
  scan-line-based representation). External code that introspects
  regions still works.
- Memory allocation goes through GS/OS's Memory Manager (or its
  native equivalent once phase 11's 1104a lands).

## suggested implementation steps

1. Study QuickDraw's region data layout in detail. Document.
2. Implement allocation / disposal first.
3. Implement primitive constructors (Set, Rect, OpenRgn / CloseRgn).
4. Implement the binary ops (Sect, Union, Diff, Xor).
5. Implement queries (PtInRgn, RectInRgn, etc.).
6. Implement the draw ops (Frame, Paint, Erase, Invert).
7. Regression-test: build complex regions via Open/Close sequences,
   compare byte-for-byte to emulated output.

## related documents

- `issues/604-quickdraw-ii-native.md` — parent issue
- `issues/604a-quickdraw-primitives.md` — predecessor pattern

## notes

- Regions are sneaky: the algorithms look simple but the edge
  cases (empty regions, single-point regions, regions with
  thousands of scan lines) are many. Comprehensive testing pays
  off.
