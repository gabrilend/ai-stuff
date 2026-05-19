---
name: Process Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905m — Process Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Process Manager. The process-record
table is the shared state.

## current behavior

The Process Manager assumes single-threaded mutation of the
process list.

## intended behavior

- `proc_lock` held during: process insertion, removal, lookup,
  iteration.
- Foreground / background switches lock briefly.
- Integration with the scheduler (issue 901) — the scheduler is
  the primary mutator; Process Manager ops layer over it.

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Coordinate with the scheduler's process-table accesses.
4. Group as `patches/212-proc-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent
- `issues/901-scheduler-primitives-asm.md`

## notes

- The Process Manager and the scheduler share state. Coordination
  between this issue and 901 matters.
