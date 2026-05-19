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

## sub-issues

Split per Toolbox manager, with the same letter mapping as 905x and
1104x. Each sub-issue's actual scope is heavily audit-dependent —
some sub-issues may turn out to be no-ops, others may be the most
significant refactor in phase 9.

- `906a-reentrancy-hard-memory-manager.md` — high-impact
- `906b-reentrancy-hard-resource-manager.md` — lock-during-I/O
- `906c-reentrancy-hard-loader.md` — likely modest
- `906d-reentrancy-hard-event-manager.md` — **highest-impact**
  (per-task event queues)
- `906e-reentrancy-hard-quickdraw.md` — **second-highest** (per-task
  shadow GrafPorts)
- `906f-reentrancy-hard-window-manager.md` — update-region work
- `906g-reentrancy-hard-menu-manager.md` — likely empty
- `906h-reentrancy-hard-control-manager.md` — likely empty
- `906i-reentrancy-hard-dialog-manager.md` — modeless dialogs
- `906j-reentrancy-hard-standard-file.md` — likely empty
- `906k-reentrancy-hard-sound-manager.md` — IRQ-path latency
- `906l-reentrancy-hard-scrap-manager.md` — likely empty (601
  supersedes)
- `906m-reentrancy-hard-process-manager.md` — scheduler unification
- `906n-reentrancy-hard-print-manager.md` — likely empty

This issue (906) remains as the umbrella. Patches land in the
250-299 range.

## notes

- This is the hardest part of phase 9. Easily months of work
  spread across the 14 sub-issues. Many are likely no-ops; the
  big ones (906a, 906d, 906e) carry the load.
