---
name: Standard File reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905j — Standard File reentrancy fixes (easy)

Lock-wrapper fixes to Standard File. The file-list cache is the
shared state.

## current behavior

Standard File's file-list caches assume single-threaded use.

## intended behavior

- `sf_lock` held during: dialog construction, file-list
  enumeration, filter application.
- Like modal dialogs in general, Standard File is invoked in a
  modal context. Concurrency is rare.

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Group as `patches/209-sf-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Easy fix.
