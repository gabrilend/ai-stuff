---
name: locks and atomic operations
phase: 9
status: pending (pending soramech)
blockedBy: [901]
---

# 902 — locks and atomic operations *(pending soramech)*

The synchronization primitives that make shared data safe to access
from multiple tasks. Lifted from soramech and ported to 65C816
assembly during staging, ARM assembly after bare-metal.

## current behavior

No locks exist because no preemption exists (yet). Issue 901
introduces preemption, making this issue's primitives necessary.

## intended behavior

- Lock primitives:
  - `lock_init(L)` — initialize a lock.
  - `lock_acquire(L)` — block until the lock is available, then
    take it.
  - `lock_release(L)` — release a held lock.
  - `lock_try(L)` — non-blocking attempt; returns success/failure.
- Atomic primitives (where possible on the 65C816):
  - `atomic_inc`, `atomic_dec` — increment/decrement a 16-bit or
    32-bit value atomically.
  - `atomic_swap` — exchange a register with a memory location
    atomically.
  - `atomic_cas` — compare-and-swap.
- 65C816 atomicity is achieved by **disabling interrupts** around
  the critical section. The 65C816 doesn't have CAS or LL/SC
  instructions; lock-free patterns aren't viable. Briefly disabling
  interrupts (a handful of cycles) is the affordance the platform
  provides.
- Lock metadata: each lock is a small structure with an owner
  field (the task ID), a waiting-list head, and a flags byte.
- Priority inheritance to avoid priority inversion (a lower-prio
  task holding a lock a higher-prio task wants). Soramech-aligned
  policy.

## suggested implementation steps

1. Translate soramech's lock implementation to 65C816 assembly,
   substituting interrupt-disable critical sections for ARM
   atomics.
2. Implement the lock data structure and the lock API.
3. Implement the atomic primitives with interrupt-disable
   wrappers.
4. Test with a contrived scenario: two tasks contending for the
   same lock, observe correct exclusion.
5. Test priority inheritance: low-prio task holds a lock,
   high-prio task waits; verify low-prio is boosted while waiting
   high-prio is blocked.
6. Document the maximum interrupt-disable duration (worst-case
   critical-section length). This determines the worst-case
   interrupt latency.

## related documents

- `issues/901-scheduler-primitives-asm.md` — depends on tasks
- Soramech source (external) — design alignment

## known design questions

- Interrupt-disable durations matter. If a lock acquisition takes
  too long (e.g., due to a long waiting-list walk), other
  interrupts (VBL, audio) are delayed. Cap critical-section length
  at, say, 50 microseconds.
- Spinlocks vs blocking locks: the 65C816 has one CPU; spinning is
  always wasted time. All locks block. (Spinlocks become an option
  in phase 11's ARM port where multiple cores exist.)

## notes

- The interrupt-disable approach feels primitive but it's the
  correct platform-aligned choice for the 65C816 staging port.
  Phase 11's ARM port can use proper atomics and lock-free
  structures.
