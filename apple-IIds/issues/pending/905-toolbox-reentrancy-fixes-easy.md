---
name: Toolbox reentrancy fixes (pass 1, lockable)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
---

# 905 — Toolbox reentrancy fixes (pass 1) *(pending soramech)*

Fix every "lockable" Toolbox routine from the issue 904 audit by
adding per-routine or per-manager locks. The easy half.

## current behavior

The Toolbox has many lockable routines (per issue 904's audit). Each
holds shared state that can be made safe with a wrapper lock.
Without the lock, concurrent calls produce silent corruption.

## intended behavior

- Each lockable Toolbox routine grows a lock-acquire / lock-release
  wrapper. The acquire blocks competing callers; the release lets
  them proceed.
- Lock granularity: typically one lock per **manager** (Window
  Manager has its lock, Event Manager has its lock, etc.). Fine-
  grained per-routine locks are an optimization, deferred to a
  follow-up unless contention bites.
- Lock-acquire critical sections are short (the routines are small).
  Contention is low expected for typical use.
- A new convention in the GS/OS source: every Toolbox entry point
  has its lock wrapper visible in the source so future readers can
  see what's protected.

## suggested implementation steps

1. Wait for issues 902 (locks) and 904 (audit).
2. For each lockable routine in the audit, add the wrapper.
3. Group routines by manager: one lock per manager, named like
   `wm_lock`, `em_lock`, etc.
4. Patch the GS/OS source with the wrappers. This is a large patch
   set; group by manager.
5. Test: run a contrived multi-task scenario that hammers Window
   Manager from two tasks; verify no corruption.
6. Measure contention: per-lock acquisition counts in heavy use.
   If any one lock is hot, split it (per-routine instead of per-
   manager).

## related documents

- `issues/904-toolbox-reentrancy-audit.md` — what we're fixing
- `issues/902-locks-atomics.md` — the primitives we're using
- `issues/906-toolbox-reentrancy-fixes-hard.md` — the harder pass

## sub-issues

Split per Toolbox manager. The letters map to the same managers as
1104a–1104n (and 906a–906n), so a manager's port + reentrancy work
share a letter:

- `905a-reentrancy-easy-memory-manager.md` — heap, handles
- `905b-reentrancy-easy-resource-manager.md` — resource forks
- `905c-reentrancy-easy-loader.md` — segment loading
- `905d-reentrancy-easy-event-manager.md` — event queue
- `905e-reentrancy-easy-quickdraw.md` — graphics state
- `905f-reentrancy-easy-window-manager.md` — window list
- `905g-reentrancy-easy-menu-manager.md` — menu bar
- `905h-reentrancy-easy-control-manager.md` — controls per window
- `905i-reentrancy-easy-dialog-manager.md` — modal/modeless dialogs
- `905j-reentrancy-easy-standard-file.md` — Open/Save
- `905k-reentrancy-easy-sound-manager.md` — sound + IRQ
- `905l-reentrancy-easy-scrap-manager.md` — clipboard (may no-op)
- `905m-reentrancy-easy-process-manager.md` — process table
- `905n-reentrancy-easy-print-manager.md` — print queue

This issue (905) remains as the umbrella; sub-issues land per
manager. Patches land in the 200-249 range (one numeric block per
manager).

## notes

- Many small patches across 14 sub-issues. Order of attack follows
  dependency depth: Memory Manager first, UI managers next, Print
  last.
- Per-manager locks are coarse. For phase 9 they're good enough;
  phase 11's ARM port can refine to per-routine where contention
  warrants.
