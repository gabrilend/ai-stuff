---
name: broker becomes a kernel component
phase: 11
status: pending
blockedBy: [1102, 1105]
---

# 1106 — broker becomes a kernel component

The broker, which was a LuaJIT process on Linux during staging,
becomes a kernel component on bare-metal Apple IIds — written in
ARM assembly, running as part of the system rather than as a Linux
userspace process.

## current behavior

The broker is `src/broker/*.lua` running on LuaJIT under Linux. It
mediates between the two GSplus instances, the input devices, the
shared filesystem, etc. All of its work happens above Linux.

## intended behavior

- The broker's role doesn't go away; the *implementation* changes.
  In bare-metal Apple IIds, there's no Linux to host LuaJIT.
  The broker becomes part of the system kernel.
- Implemented in ARM assembly. Uses the threading primitives
  (issue 1105), the HAL (issue 1102), and the ported Toolbox
  (issue 1104).
- Responsibilities:
  - Spawns the two Apple IIds instances (now ARM-native, not
    GSplus emulators).
  - Mediates shared filesystem, clipboard, IPC.
  - Routes input from HAL drivers to the appropriate instance.
  - Manages the radial keyboard overlay (now a kernel-level
    feature, not a Lua-drawn compositor layer).
  - Plays the one boot chime (same logic as issue 508, ported).
  - Handles audio mixing (same logic as issue 507, ported).
- The user-visible behavior is identical to staging-ground
  apple-IIds, just running on bare metal.

## suggested implementation steps

1. Wait for issues 1102 (HAL) and 1105 (threading primitives).
2. Port each broker responsibility from Lua to ARM assembly.
   Each `src/broker/*.lua` module gets an ARM-assembly equivalent.
3. Strip LuaJIT entirely — no Lua interpreter, no JIT, no
   garbage collection. Everything is static assembly.
4. Test progressively: HAL works first, then input routing, then
   shared FS, then the rest.
5. Verify behavioral equivalence with staging-ground apple-IIds
   by running the curated app library and the phase 5 demo
   scenarios.

## related documents

- `issues/1102-hardware-abstraction-layer.md`,
  `issues/1105-threading-primitives-arm.md` — the foundation
- All of `src/broker/` — the staging-ground source we're porting

## known design questions

- This is one of the issues where "no language but assembly"
  matters most. The broker has been Lua; lots of Lua-isms
  (closures, tables, garbage collection) don't translate
  one-to-one to assembly. The porting often requires reshaping
  the algorithm, not just translating it.
- Memory management: without Lua's GC, the broker's data
  structures need explicit allocation/free. Worth designing the
  per-task / per-device allocators carefully.

## notes

- After this issue, the staging-ground LuaJIT broker is no
  longer present in the bare-metal build. It still exists as
  source (we may need it for development on the host), but the
  device runs only the ARM-assembly version.
