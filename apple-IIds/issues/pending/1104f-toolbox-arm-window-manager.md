---
name: Toolbox in ARM — Window Manager
phase: 11
status: pending
blockedBy: [1104d, 1104e]
parent: 1104
---

# 1104f — Toolbox in ARM: Window Manager

ARM-assembly port of the IIds Window Manager. Manages window
creation, layering, dragging, resizing, and the
window-list data structure.

## current behavior

The Window Manager runs in emulation. Phase 9's reentrancy work
(905f / 906f) makes it concurrent-safe; phase 11 ports it natively.

## intended behavior

- Native ARM implementation of: `NewWindow`, `CloseWindow`,
  `DisposeWindow`, `SelectWindow`, `BringToFront`, `SendBehind`,
  `DragWindow`, `GrowWindow`, `FindWindow`, `FrontWindow`,
  `GetWMgrPort`, the update-region machinery.
- Preserves window-record data structures byte-for-byte.
- Integrates with QuickDraw II (1104e) for drawing and Event
  Manager (1104d) for input.

## suggested implementation steps

1. Study GS/OS Window Manager source.
2. Port window creation and disposal.
3. Port layering (front-to-back ordering).
4. Port drag / resize / grow.
5. Port the FindWindow hit-testing.
6. Port the update-region machinery (interacts heavily with
   QuickDraw's regions).
7. Test against the curated app library — the Finder is the
   heaviest Window Manager user.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104d-toolbox-arm-event-manager.md`,
  `issues/1104e-toolbox-arm-quickdraw-ii.md` — dependencies

## notes

- The Window Manager interacts with the Toolbox ROM (the visual
  parts of windows — title bars, close boxes — are partly in ROM).
  If phase 10's ROM patches haven't fully covered this, some
  Window Manager calls may need to coexist with emulated ROM
  routines.
