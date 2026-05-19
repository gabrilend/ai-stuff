---
name: QuickDraw II reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905e — QuickDraw II reentrancy fixes (easy)

Lock-wrapper fixes to QuickDraw II. The current GrafPort, color
table, and font state are all globals; `qd_lock` serializes their
mutation.

## current behavior

QuickDraw's global state (current port, current pen, current
foreground / background colors) is one of the most-mutated shared
states in GS/OS. Concurrent calls trivially corrupt it.

## intended behavior

- `qd_lock` held during every operation that reads or writes
  current-port state.
- Compound operations (e.g., `SetPort` + `MoveTo` + `LineTo`)
  benefit from being grouped under one lock acquisition; the
  caller may take the lock explicitly.
- For most apps, the lock is per-task — each task gets its own
  shadow of the current-port state and serializes only at the
  framebuffer-write boundary.

## suggested implementation steps

1. Wait for the audit's QuickDraw section.
2. Add per-call lock wrappers.
3. Group as `patches/204-qd-locks.gsos.s.patch`.
4. Performance-test: this is a hot path; ensure the lock doesn't
   dominate.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent
- `issues/604-quickdraw-ii-native.md` — staging-ground native
  (does its own locking)

## notes

- QuickDraw locking is the heaviest of the 905 sub-issues. If
  performance suffers, the 906e structural refactor (per-task
  shadow ports) is the answer.
