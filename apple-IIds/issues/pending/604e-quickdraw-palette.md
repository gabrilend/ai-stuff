---
name: QuickDraw II native — palette / color table management
phase: 6
status: pending (pending soramech)
blockedBy: [604a]
parent: 604
---

# 604e — QuickDraw II native: palette / color table management

Native ARM implementation of QuickDraw's color-table and palette
management: the 16-color-per-line palette that gives the IIds its
distinctive 4096-color Super Hi-Res capability.

## current behavior

Palette management runs in emulation. Programs that animate palettes
(e.g., color-cycling demos like Cogito) pay full emulation tax on
every palette change.

## intended behavior

- Native implementations of: `NewColorTable`, `DisposeColorTable`,
  `RestoreColorTable`, `SetColorTable`, `GetColorTable`,
  `MakeRGB`, palette manager calls (`Palette2CTab`, `CTab2Palette`,
  `SetEntries`, `NSetPalette`, etc.).
- Color table data structures preserved byte-for-byte.
- Hardware palette setup: writing to the IIds Super Hi-Res palette
  hardware (the SCB and palette RAM). On bare metal (phase 11)
  this maps to the panel's native color path; during staging the
  emulator's palette state is updated.

## suggested implementation steps

1. Study QuickDraw's color-table / palette routines and the
   hardware they program.
2. Implement the data-structure manipulation routines first.
3. Implement the hardware-write routines (SCB updates, palette RAM
   writes).
4. Test with a palette-cycling demo (Cogito or similar).
   Verify color animation is at native speed.

## related documents

- `issues/604-quickdraw-ii-native.md` — parent issue
- `docs/002-hardware-target.md` — panel mapping

## notes

- This is the smallest of the QuickDraw sub-rewrites by code
  volume. It's worth doing because palette animation is one of
  the IIds's signature visual capabilities, and emulated palette
  animation is noticeably less fluid.
