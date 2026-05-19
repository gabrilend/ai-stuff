---
name: Toolbox reentrancy fixes (pass 2, structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905]
---

# 906 — Toolbox reentrancy fixes (pass 2) *(pending soramech)*

Fix every "structural" Toolbox routine from the issue 904 audit by
refactoring its shared state, not just wrapping with a lock. The
hard half.

## current behavior

After issue 905, the "lockable" routines are safe. The "structural"
ones remain — these have shared state so entangled with the
single-thread assumption that a lock wrapper is not enough.

## intended behavior

- Each structural routine is refactored:
  - Either: move shared state from a global to per-task storage
    (each task gets its own copy).
  - Or: refactor the algorithm to not hold long-lived shared state
    across calls.
  - Or: introduce explicit state-management calls (e.g., "enter
    drawing context X" + "exit drawing context X") so concurrent
    callers explicitly arbitrate.
- The refactor preserves the public API surface — IIds software
  doesn't notice anything has changed.
- The audit document (issue 904) is updated as each routine is
  refactored, with notes on what was done.

## suggested implementation steps

1. Wait for issue 905. The lockable fixes shake out where the
   real structural problems are.
2. For each structural routine, design the refactor in detail.
   Some will require breaking up large procedures.
3. Implement the refactor as a numbered patch (250-299 range).
4. Test extensively — structural changes are easy to break
   subtly. Regression-test against the curated app library.
5. Update the audit document.

## related documents

- `issues/904-toolbox-reentrancy-audit.md`,
  `issues/905-toolbox-reentrancy-fixes-easy.md` — predecessors

## known design questions

- Per-task storage requires a per-task storage convention. The
  IIds memory manager doesn't natively have per-task contexts.
  Either we add one (a Toolbox-level extension that allocates
  task-local state on `task_create` and frees it on `task_exit`)
  or we shoehorn into existing per-task structures (the user
  application's task control block, for example).
- Some refactors will change observable behavior in edge cases
  (e.g., what happens if a task is killed mid-routine). Document
  these.

## notes

- This is the hardest part of phase 9. Easily months of work
  spread across many small refactors. Worth splitting into
  sub-issues by manager once the audit document scopes it.
