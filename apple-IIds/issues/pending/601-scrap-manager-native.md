---
name: Scrap Manager native
phase: 6
status: pending (pending soramech)
blockedBy: [303, 702]
---

# 601 — Scrap Manager native *(pending soramech)*

Replace the emulated Scrap Manager with a native ARM implementation
of the same API. The native implementation runs on its own thread
(once soramech's primitives land) and talks to the still-emulated
GS/OS through a thin boundary.

## current behavior

The Scrap Manager runs inside the emulated IIds, executing 65C816
assembly. The shared clipboard from issue 303 hooks into it via a
patch. Functional, but every scrap operation pays the emulation
overhead.

## intended behavior

- A new module `src/native/scrap-manager.c` (or `.s` for ARM
  assembly — see notes) implements the full Scrap Manager API
  natively.
- GS/OS calls into the Scrap Manager are intercepted by GSplus and
  routed to the native implementation instead of running through
  the 65C816 interpreter.
- The native implementation does the same work the emulated one
  did, but at native speed. Cross-instance shared scrap (from
  issue 303) is now mediated entirely at the native level.
- This is the **simplest seam to cut**: the Scrap Manager API is
  small (a handful of calls), its state is small (the current
  scrap data + type), and the cross-cutting concern (clipboard
  sharing) is already broker-mediated.
- **Pending soramech**: the native scrap manager runs on its own
  thread under the soramech scheduler. Calls into it from the
  emulated IIds cross a thread boundary. The boundary is
  implemented with soramech's channel primitives.

## suggested implementation steps

1. Read GS/OS's Scrap Manager source carefully. Document the API
   surface in `info.md` alongside the source.
2. Wait for soramech to provide thread-creation, lock, and channel
   primitives we can call from C / ARM assembly.
3. Implement the native Scrap Manager. Same data structures, same
   semantics, native execution.
4. Implement the GSplus interception: when 65C816 code calls into
   the Scrap Manager's entry points, GSplus catches the call,
   crosses the thread boundary via soramech, runs the native
   implementation, and returns the result back to the emulator.
5. Test by running existing scrap-using software (e.g., a
   copy-paste between TextEdit and Teach). The behavior should be
   identical to the emulated version.
6. Measure: scrap operations per second, before and after.
   Expectation: native is at least 10x faster, but since scrap
   is rare, the user doesn't notice. The win is architectural,
   not perceptual.

## related documents

- `docs/001-architecture-overview.md` — the future seam
- `docs/004-roadmap.md` — phase 6 entry, pending soramech
- `issues/303-shared-clipboard.md` — the staging-ground version
- `issues/702-broker-input-device.md` — the precedent for a
  similar cross-boundary device

## known design questions

- C or ARM assembly for native subsystems? **Pending soramech**:
  soramech's primitives are in ARM assembly per the threading
  model. Writing the Scrap Manager in ARM assembly is the
  bare-metal-aligned choice. Writing it in C is faster to develop
  and still wins the performance argument. Compromise: write the
  initial port in C against the soramech primitives, then port
  to ARM assembly for phase 9/11 alignment.
- Thread safety for the scrap state: with multitasking on (phase
  9), multiple programs may copy/paste at once. The native
  implementation must lock the scrap state with soramech's lock
  primitive. The lock has to be very short-held (microseconds)
  since scrap ops are common.

## notes

- The scrap manager is the canonical "small native rewrite" — it's
  the proof that the native-cuts-through-emulation pattern works.
  After this lands, the pattern can be reapplied to larger
  subsystems with confidence.
