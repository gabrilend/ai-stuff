---
name: QuickDraw II native — bitmap blits
phase: 6
status: pending (pending soramech)
blockedBy: [604a, 604b]
parent: 604
---

# 604c — QuickDraw II native: bitmap blits

Native ARM implementation of QuickDraw's `CopyBits` and friends —
the bitmap-copy operations that move pixels between framebuffers,
optionally with scaling, masking, and color-table translation.

## current behavior

Blits execute in emulation. This is the single most performance-
sensitive QuickDraw operation: scrolling a window, drawing animated
content, rendering UI updates — all of these go through `CopyBits`.

## intended behavior

- Native implementations of: `CopyBits`, `CopyMask`, `CopyPixels`,
  the underlying scan-conversion logic, the source-rect /
  destination-rect mapping with scaling.
- Pixel-exact equivalence with the emulated version, including the
  edge cases of off-screen sources, clipped destinations, and
  transfer modes (srcCopy, srcOr, srcXor, srcBic, plus the not-
  variants).
- ARM-optimized inner loops: SIMD where applicable for large blits,
  efficient unaligned-word handling, cache-friendly access
  patterns.

## suggested implementation steps

1. Study QuickDraw's `CopyBits` and the underlying scan converter.
2. Implement the basic blit (srcCopy mode, no scaling, aligned
   addresses).
3. Add scaling support (the source-rect / destination-rect can
   have different sizes; QuickDraw does nearest-neighbor).
4. Add the transfer modes.
5. Add masking (`CopyMask`).
6. ARM SIMD optimization: use NEON for the inner loops where the
   pixel format permits.
7. Performance-test: measure blits per second on representative
   workloads (paint program selection drag, Finder window scroll).

## related documents

- `issues/604-quickdraw-ii-native.md` — parent issue

## notes

- This is the QuickDraw sub-rewrite the user *will notice*. Going
  from emulated to native here typically turns a 30 FPS UI into a
  60 FPS UI. The other sub-rewrites are infrastructure; this is
  what they pay off into.
