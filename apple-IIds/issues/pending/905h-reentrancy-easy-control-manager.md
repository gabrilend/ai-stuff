---
name: Control Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905h — Control Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Control Manager. Per-window control
lists are the shared state.

## current behavior

The Control Manager assumes single-threaded mutation of control
lists.

## intended behavior

- `ctl_lock` held during: control creation, disposal, value
  changes, `TrackControl` loops.
- Scroll-bar tracking acquires the lock and holds during the drag
  loop (modal, like menus).

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Group as `patches/207-ctl-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Lowest-contention of the UI manager locks.
