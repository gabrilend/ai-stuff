---
name: broker virtual peripheral infrastructure
phase: 7
status: pending
blockedBy: [106]
---

# 701 — broker virtual peripheral infrastructure

The generic mechanism by which the broker exposes virtual peripherals
to GS/OS. Once this lands, subsequent issues (702 Broker Input
device, 703 Broker Filesystem device) become applications of the
same pattern rather than each inventing their own protocol.

## current behavior

Each cross-boundary mechanism is ad hoc. The shared volume uses
SmartPort, the shared clipboard uses GS/OS source patches with
direct calls, the IPC channel uses emulated LocalTalk. No common
framework.

## intended behavior

- A **uniform peripheral protocol** between the broker and each
  emulated IIds, exposing virtual devices in a way GS/OS's Device
  Manager naturally understands.
- The protocol has three primitives:
  - `register_device(name, type, ops)` — broker tells the emulator
    about a new device.
  - `device_call(name, op, args)` — emulator (or GS/OS code) calls
    into the device.
  - `device_event(name, event)` — broker pushes an asynchronous
    event up to the emulator (e.g., "data ready").
- Implementation:
  - GSplus-side: a virtual MMIO range that the broker writes into
    and the emulator reads from, plus an interrupt line.
  - GS/OS-side: a Device Manager-shaped driver (`DOpen`,
    `DRead`, `DWrite`, `DStatus`, `DControl`, `DClose`,
    `DFlush`) that dispatches to the broker via the MMIO range.
  - Broker-side: a Lua API for declaring devices and handling
    calls.
- Each device gets a unique name and type. GS/OS can enumerate
  registered devices via the standard `DInfo` call.

## suggested implementation steps

1. Decide the MMIO address layout (pick a region GS/OS doesn't
   use). Document.
2. Implement the GSplus-side virtual MMIO region with an
   associated interrupt line.
3. Implement the GS/OS-side dispatcher driver. The driver routes
   `DOpen`/`DRead`/etc. through the MMIO region to the broker.
4. Implement the broker-side Lua API:
   `broker.register_device(name, type, ops)` registers a device
   whose ops are Lua functions; the dispatcher calls into them on
   demand.
5. Provide a simple test device — e.g., a "echo" device that
   returns whatever you write to it.
6. Write the corresponding GS/OS source patch and bundle as
   `patches/110-broker-peripherals.gsplus.patch` +
   `patches/110-broker-peripherals.gsos.s.patch`.
7. Verify the echo test from a 65C816 program: `DWrite("echo",
   "hello")`, `DRead("echo")` returns "hello."

## related documents

- `docs/001-architecture-overview.md` — broker as a real GS/OS
  device, the future seam
- `docs/005-patch-conventions.md` — the patch-numbering convention
- `issues/106-gs-os-source-toolchain.md` — prerequisite (we need
  source to write the dispatcher driver)
- `issues/702-broker-input-device.md` — first user of the infra
- `issues/703-broker-filesystem-device.md` — second user

## known design questions

- Synchronous vs async device calls? Most ops are synchronous (the
  emulator blocks until the broker responds). But events (issue
  702's "key ready" signal, etc.) need to be async. The protocol
  supports both.
- MMIO range size? Pick something generous (e.g., 64 KB) to
  accommodate many devices. The broker carves it into per-device
  sub-ranges as devices register.

## notes

- This is the most important plumbing of phase 7. Once it lands,
  every subsequent OS-level integration uses it. Worth investing
  in a really clean API.
