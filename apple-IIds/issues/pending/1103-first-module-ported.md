---
name: first module ported (smallest GS/OS subsystem)
phase: 11
status: pending
blockedBy: [1102]
---

# 1103 — first module ported

The smallest GS/OS subsystem is ported from 65C816 assembly to ARM
assembly. This establishes the porting pattern for everything else
in phase 11.

## current behavior

GS/OS runs in 65C816 emulation. No part of it has been ported to
ARM.

## intended behavior

- Pick the smallest GS/OS subsystem. Candidate: the Date / Time
  Manager (a handful of routines, simple state, no shared
  resources).
- Port it from 65C816 assembly to ARM assembly. The port
  preserves the API surface (same calling conventions adapted
  to ARM, same semantics).
- The ported module **replaces** the emulated version in the
  bare-metal build. IIds programs calling the Date / Time Manager
  get the ported native version.
- The porting process is documented carefully — this is the
  template for issues 1104 (the big Toolbox port) and 1105
  (threading primitives).

## suggested implementation steps

1. Pick the subsystem. Confirm it's small enough to port in a
   reasonable time.
2. Study its 65C816 implementation. Document the calling
   convention, the registers used for arguments / return, the
   shared state.
3. Translate routine by routine to ARM assembly. Keep notes on
   each translation decision (e.g., how 65C816's
   bank-register-relative addressing maps to ARM addressing).
4. Adapt the calling convention: when emulated 65C816 code calls
   a ported native routine, it crosses a boundary. The boundary
   handler unmarshals 65C816 arguments into ARM registers,
   invokes the native routine, marshals the return value back.
5. Test: an emulated 65C816 program calls the Date / Time Manager
   via the standard Toolbox call interface; the call lands in
   the ported routine; the return is correct.
6. Document the porting template in `docs/research/porting-template.md`.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — the foundation
- `issues/1104-iigs-toolbox-arm.md` — the big follow-up

## known design questions

- 65C816 → ARM calling convention bridge: 65C816 uses
  register-based argument passing for some Toolbox calls and
  stack-based for others. The bridge handler needs to know which
  convention each routine uses. Catalog this during the port.
- Shared state across the boundary: if the ported routine
  accesses memory that 65C816 code also accesses, the addresses
  must align. The MMU is set up so the IIds emulated address
  space maps to identifiable ARM addresses; ported routines see
  the same memory.

## notes

- This issue is the proof-of-concept for the entire phase. A
  successful port of even one trivial subsystem proves the
  approach works. Without it, all the larger ports are
  speculation.
