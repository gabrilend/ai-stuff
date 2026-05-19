---
name: scheduler primitives in 65C816 assembly
phase: 9
status: pending (pending soramech)
blockedBy: []
---

# 901 — scheduler primitives in 65C816 assembly *(pending soramech)*

The foundation of preemptive multithreading: a context-switching
scheduler running on the 65C816 (during staging) and later in ARM
assembly (after bare-metal). Primitives are lifted directly from
soramech, minus its language-spec system.

## current behavior

GS/OS is cooperatively single-tasked. Programs run until they
explicitly yield via the Event Manager. No preemption, no
concurrent execution within an instance.

## intended behavior

- A scheduler in 65C816 assembly that:
  - Maintains a list of tasks (programs / threads).
  - Switches between them on a timer interrupt (preemptive).
  - Saves and restores 65C816 register state on switch.
  - Provides primitives: `task_create`, `task_yield`, `task_exit`,
    `task_sleep`.
- The scheduler is **lifted from soramech**: same algorithm, same
  data structures, ported to the 65C816 instruction set. Where
  soramech uses ARM atomic instructions, the 65C816 version uses
  interrupt-disabled critical sections (the 65C816 doesn't have
  atomic compare-and-swap).
- Timer source: an existing IIds timer (e.g., the VBL interrupt at
  60 Hz, or one of the SCC channels) reprogrammed for the scheduler's
  tick.
- Tick rate: starts at 60 Hz; tunable.

## suggested implementation steps

1. Wait for soramech's scheduler design to stabilize. Read its
   source carefully.
2. Translate the design to 65C816 assembly. Document each register
   convention, stack-frame layout, and save-restore sequence.
3. Implement timer setup: program the chosen IIds timer for the
   tick rate.
4. Implement context save/restore: on tick, save current task's
   65C816 registers (A, X, Y, DBR, PBR, D, S, P) and switch to
   the next runnable task's saved state.
5. Test with two trivial tasks: each prints a character in a loop.
   Verify both print interleaved (preemption working).
6. Measure context-switch cost: target under 100 microseconds on
   the 2 GHz ARM running emulated 65C816.

## related documents

- `docs/004-roadmap.md` — phase 9 entry; soramech alignment
- `notes/vision/000-vision.md` — threading by default section
- Soramech source (external)

## known design questions

- Where does task memory live? The 65C816 has 24-bit addressing
  (16 MB total). IIds RAM is usually 1–8 MB. Each task needs its
  own stack; per-task heap is optional. For phase 9 staging, all
  tasks share one heap (the IIds memory manager), and we audit
  for thread safety per issue 904.
- Interrupt safety: the scheduler tick is itself an interrupt. The
  scheduler must be reentrant against other IIds interrupts (VBL,
  SCC, etc.). Document the interrupt-priority hierarchy.

## notes

- This is foundational for all of phase 9. Without scheduler
  primitives, locks (issue 902) and channels (issue 903) have no
  meaning, and the Toolbox reentrancy work (issues 904–906) has
  nothing to be reentrant against.
- The 65C816 implementation is staging; phase 11 re-ports this to
  ARM assembly directly. Keep the design portable.
