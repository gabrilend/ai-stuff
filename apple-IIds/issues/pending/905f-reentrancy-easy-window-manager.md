---
name: Window Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905f — Window Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Window Manager. The window list is the
shared state.

## current behavior

The Window Manager's global window list is accessed by every
window-related call. Concurrent calls cause corruption.

## intended behavior

- `wm_lock` held during: window creation, disposal, layering
  changes (`SelectWindow`, `BringToFront`, `SendBehind`),
  hit-testing (`FindWindow`).
- Drawing operations that the Window Manager kicks off (update
  events) acquire QuickDraw's lock; the WM lock is released
  during draw.

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Group as `patches/205-wm-locks.gsos.s.patch`.
4. Test concurrent window operations.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Window list is small; lock contention is low. Easy fix.
