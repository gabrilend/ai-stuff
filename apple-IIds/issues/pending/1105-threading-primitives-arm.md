---
name: threading primitives in ARM assembly
phase: 11
status: pending
blockedBy: [1101]
---

# 1105 — threading primitives in ARM assembly

Port the phase 9 threading primitives (scheduler, locks, channels)
from 65C816 assembly to ARM assembly. Soramech's primitives are the
direct reference.

## current behavior

The phase 9 primitives are in 65C816 assembly, designed to run
inside an emulated IIds. Bare-metal runs on ARM with multiple
cores and proper atomic instructions — a completely different
landscape.

## intended behavior

- Scheduler primitives (issue 901's analogues) in ARM assembly,
  taking advantage of ARM features:
  - Multiple cores (RK3568 has 4 A55 cores) → tasks can run
    truly in parallel, not just preemptively interleaved.
  - Proper atomic instructions (LDXR / STXR, CAS) → lock-free
    primitives become viable.
  - WFE / SEV for efficient waiting.
- Lock primitives (issue 902's analogues): real spinlocks with
  ARM atomics, real ticket locks for fairness, real read-write
  locks where useful.
- Channels (issue 903's analogues): lock-free MPMC ring buffers
  where the message size permits; lock-based otherwise.
- The API matches phase 9's API — ARM code calling
  `task_create`, `lock_acquire`, `channel_send` gets the same
  semantics. The implementation underneath is much more efficient.
- Soramech's primitives are imported wholesale (per the
  bare-metal-core memory).

## suggested implementation steps

1. Wait for soramech's ARM-assembly primitives to be available.
   Read them carefully.
2. Adapt to the RG DS's RK3568 specifics: cache line sizes,
   barrier requirements, interrupt controller.
3. Port the API one primitive at a time, testing each
   independently.
4. Run the phase 9 demo's scenarios against the ARM primitives
   to verify behavioral equivalence.
5. Measure: context-switch latency, lock acquire/release latency,
   channel send/recv latency. Targets: each under 1 microsecond
   on the 2 GHz A55s.

## related documents

- `issues/901-scheduler-primitives-asm.md`,
  `issues/902-locks-atomics.md`,
  `issues/903-channels-message-passing.md` — the staging-ground
  precedents
- Soramech ARM source (external)
- `notes/vision/000-vision.md` — threading by default section

## known design questions

- The four A55 cores mean true parallelism. Do all tasks share
  one runqueue or does each core have its own? Per-core runqueue
  with work-stealing is the modern default; soramech's design
  presumably picks one.
- Lock-free vs locked choice on a per-primitive basis. Lock-free
  is faster but more complex; locked is sufficient for low-
  contention cases. Soramech-aligned defaults.

## notes

- This is one of the more elegant issues in phase 11. The 65C816
  port (phase 9) had to make do with interrupt-disable for
  atomicity; the ARM port has proper hardware support and gets to
  use it cleanly.
