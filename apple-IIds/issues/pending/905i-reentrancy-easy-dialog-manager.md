---
name: Dialog Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905i — Dialog Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Dialog Manager. The current modal-dialog
state is the shared state.

## current behavior

The Dialog Manager assumes single-threaded modal-dialog driving.

## intended behavior

- `dlg_lock` held during: dialog creation, disposal, modal-dialog
  event loop.
- Modal dialogs are by definition serialized; the lock just
  enforces what the API contract implies.

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Group as `patches/208-dlg-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Easy.
