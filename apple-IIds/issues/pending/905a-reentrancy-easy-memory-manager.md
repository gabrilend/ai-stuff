---
name: Memory Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905a — Memory Manager reentrancy fixes (easy)

Lock-wrapper fixes to the IIds Memory Manager identified by the
issue 904 audit as "lockable." A single `memmgr_lock` serializes
all the heap operations that share global state.

## current behavior

The Memory Manager assumes single-threaded callers. Concurrent
`NewHandle` from two tasks corrupts the heap silently.

## intended behavior

- Every Memory Manager entry point that touches shared heap state
  acquires `memmgr_lock` on entry and releases on exit.
- The lock is per-instance (not per-Toolbox-global), so the two
  emulated IIdses each have their own lock.
- Critical sections are short — heap ops are O(handles) at worst.
  Contention should be low.

## suggested implementation steps

1. Wait for the issue 904 audit's Memory Manager section.
2. For each entry point in the list, add the lock wrapper.
3. Group as a patch (`patches/200-memmgr-locks.gsos.s.patch`).
4. Test: two tasks both allocating; verify no heap corruption.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent issue
- `issues/904-toolbox-reentrancy-audit.md` — the input
- `issues/902-locks-atomics.md` — the lock primitive

## notes

- Memory Manager fixes are the first 905 sub-issue to land, because
  every other manager depends on safe heap access.
