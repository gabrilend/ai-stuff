---
name: Process Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905m]
parent: 906
---

# 906m — Process Manager reentrancy fixes (structural)

Structural refactor of Process Manager. The deep entanglement with
the scheduler is the main concern.

## current behavior

After 905m, Process Manager is lock-correct. The scheduler and
Process Manager both touch process-record state, requiring careful
coordination.

## intended behavior

- Move the canonical process-record state into the scheduler's
  task-control-block, with Process Manager keeping a thin wrapper
  view. Eliminates the dual-ownership issue.
- Refactor: foreground / background determination becomes a
  scheduler-priority change rather than a Process Manager flag.

## suggested implementation steps

1. Wait for audit and design the unified state model.
2. Implement.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent
- `issues/901-scheduler-primitives-asm.md` — the scheduler

## notes

- This is a clean-slate-ish refactor. Worth doing right since
  Process Manager / scheduler interaction is foundational to the
  preemptive system.
