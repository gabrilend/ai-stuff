---
name: Loader reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905c]
parent: 906
---

# 906c — Loader reentrancy fixes (hard)

Structural refactor of Loader routines flagged as "structural."

## current behavior

After 905c, the Loader is lock-correct. Structural concerns
typically involve segment-faulting in a multi-task context.

## intended behavior

- Per-task segment-fault handling so two tasks faulting in
  segments don't serialize on a global loader lock.
- Refactor: split the segment-load critical section to release
  during disk I/O.
- Other audit-driven changes.

## suggested implementation steps

1. Wait for audit.
2. Design fixes.
3. Implement.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent

## notes

- May be minimal — segment faults are rare, contention is low.
