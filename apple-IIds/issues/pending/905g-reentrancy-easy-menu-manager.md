---
name: Menu Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905g — Menu Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Menu Manager. The menu bar and menu list
are the shared state.

## current behavior

The Menu Manager assumes single-threaded mutation of the menu bar.

## intended behavior

- `menu_lock` held during: menu insertion / removal, item
  modification, `MenuSelect` tracking loop.
- The `MenuSelect` tracking loop is the long-held case; runs while
  the user is dragging through menus. Holding the lock for the
  whole tracking loop is acceptable because menu tracking is
  modal (no other input is processed concurrently anyway).

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Group as `patches/206-menu-locks.gsos.s.patch`.
4. Test menu changes during display.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Menu modifications are user-mediated (clicked / typed shortcut),
  so contention with concurrent background tasks is rare.
