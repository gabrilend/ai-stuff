---
name: Toolbox reentrancy audit
phase: 9
status: pending (pending soramech)
blockedBy: [901]
---

# 904 — Toolbox reentrancy audit *(pending soramech)*

Catalog every Toolbox routine in GS/OS by whether it is reentrant
(safe to call from concurrent tasks) or not. The output is the
specification for issues 905 and 906 — the fixes.

## current behavior

GS/OS's Toolbox was written under the assumption of a single thread
of execution. Many routines hold shared state in static variables
or in well-known memory locations. Calling them from concurrent
tasks (which issue 901 makes possible) breaks them silently or
loudly.

## intended behavior

- A document `docs/research/toolbox-reentrancy.md` lists every
  Toolbox routine (or every routine the source release covers)
  with one of three classifications:
  - **reentrant** — safe to call from any task without locks
  - **lockable** — has shared state, but adding a per-routine
    lock makes it safe (the fix is a wrapper)
  - **structural** — shared state is so entangled that the
    routine needs deeper rework (the fix is to refactor the
    state)
- For each non-reentrant routine, the document identifies:
  - which shared state is involved (specific variables / memory
    addresses)
  - which tasks could plausibly contend (small / large)
  - the proposed fix (lock granularity, refactor sketch)
- The output classification drives issue 905 ("the easy half" —
  lockable fixes) and 906 ("the hard half" — structural fixes).

## suggested implementation steps

1. Wait for issue 901 (we need tasks to exist before reentrancy
   matters).
2. Read every Toolbox source file. For each routine, identify
   shared state.
3. Classify each routine.
4. Estimate effort per non-reentrant routine: lock-wrapper
   (minutes) vs refactor (hours/days).
5. Write the report. Reference specific source files and routine
   names.
6. Prioritize: classify by estimated user-visible-impact-if-broken.
   The first ones to fix are those most likely to be called from
   multiple tasks (e.g., QuickDraw, Window Manager).

## related documents

- `issues/901-scheduler-primitives-asm.md` — the motivation
- `issues/905-toolbox-reentrancy-fixes-easy.md`,
  `issues/906-toolbox-reentrancy-fixes-hard.md` — what consumes
  the output of this issue

## known design questions

- The Toolbox is ~700 traps. Auditing every one is weeks of work.
  Prioritize: start with the routines that custom IIds software
  is most likely to call from a non-main task.
- Some Toolbox routines are in the ROM (not source-released).
  Auditing them requires disassembly. These get flagged as
  "needs Toolbox ROM patch (phase 10)" rather than fixed at the
  source level.

## notes

- This issue produces a *document*, not code. The document is
  load-bearing — issues 905 and 906 reference it on a per-routine
  basis.
- Multi-week task. Consider splitting into sub-issues by Toolbox
  manager (Window Manager audit, Event Manager audit, etc.).
