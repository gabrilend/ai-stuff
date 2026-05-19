---
name: Memory Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905a]
parent: 906
---

# 906a — Memory Manager reentrancy fixes (hard)

Structural refactor of Memory Manager routines flagged by issue 904
as "structural" — needing more than a lock wrapper.

## current behavior

After 905a, the Memory Manager is lock-correct but possibly slow
under contention, or some routines have lock-hold-times that block
other tasks unacceptably long.

## intended behavior

- Candidate structural fixes (specifics depend on the audit):
  - **Per-task block-tracking pools** so common allocation paths
    don't always hit the global heap lock.
  - **Splitting** of long compaction operations into chunks so
    other tasks aren't blocked for the full compaction duration.
  - **Lock-free** handle dereferences (the common case) using ARM
    LL/SC for the master-pointer read.
- The fixes preserve the public API exactly. Internal restructure
  only.

## suggested implementation steps

1. Wait for the audit's Memory Manager section, specifically the
   structural-classification entries.
2. Design each refactor in detail.
3. Implement, one refactor per patch under `patches/250-NNN-memmgr-*`.
4. Performance-test before / after.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent
- `issues/905a-reentrancy-easy-memory-manager.md` — prerequisite

## notes

- Memory Manager structural fixes have the highest payoff because
  every other manager allocates through it. Even a 2x speedup
  here propagates everywhere.
