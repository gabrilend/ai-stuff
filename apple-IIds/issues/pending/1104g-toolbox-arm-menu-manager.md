---
name: Toolbox in ARM — Menu Manager
phase: 11
status: pending
blockedBy: [1104e, 1104f]
parent: 1104
---

# 1104g — Toolbox in ARM: Menu Manager

ARM-assembly port of the IIds Menu Manager. Manages menu bars,
menu tracking, hierarchical menus, and the menu definitions.

## current behavior

The Menu Manager runs in emulation.

## intended behavior

- Native ARM implementation of: `NewMenu`, `DisposeMenu`,
  `InsertMenu`, `DrawMenuBar`, `MenuSelect`, `MenuKey`,
  `HiliteMenu`, `EnableItem`, `DisableItem`, `SetItemMark`,
  `AppendMenu`, plus the various item-style routines.
- Menu data structures preserved byte-for-byte.
- Integrates with Window Manager (1104f) and QuickDraw II
  (1104e) for drawing.

## suggested implementation steps

1. Study GS/OS Menu Manager source.
2. Port the menu data structures.
3. Port `DrawMenuBar` (probably the most-called routine).
4. Port `MenuSelect` (the click-and-track loop).
5. Port hierarchical menus.
6. Port keyboard equivalents (`MenuKey`).
7. Test: every menu in every curated app, plus the Finder's
   menus.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104f-toolbox-arm-window-manager.md` — dependency

## notes

- Medium-complexity port. The hierarchical-menu logic is the
  trickiest piece.
