---
name: Toolbox in ARM — Event Manager
phase: 11
status: pending
blockedBy: [1104a]
parent: 1104
---

# 1104d — Toolbox in ARM: Event Manager

ARM-assembly port of the IIds Event Manager. Distributes
keyboard, mouse, system, and update events to running programs.

## current behavior

The Event Manager runs in 65C816 emulation, with phase 8's input-
liberation work integrating modern inputs and phase 9's preemptive
extension making it concurrent-safe.

## intended behavior

- Native ARM implementation of: `EventAvail`, `GetNextEvent`,
  `WaitNextEvent`, `PostEvent`, `FlushEvents`, plus the
  event-queue data structures.
- Integrates with the threading model from issue 1105 — each task
  can have its own event mask and queue position.
- Receives events from the Broker Input device (1106's bare-metal
  successor) as native-input events.

## suggested implementation steps

1. Study GS/OS Event Manager source and phase 8/9 patches.
2. Port the event-queue data structures.
3. Port the queue management routines.
4. Port the per-task event-mask handling from phase 9.
5. Wire the Broker Input device's bare-metal equivalent as the
   event source.
6. Test: launch an app, send events, verify the app receives them
   identically to staging-ground.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/603-event-manager-native.md` — staging-ground precedent
- `issues/907-preemptive-task-switching.md` — preemption integration

## notes

- Small subsystem, central role. Worth porting early for the
  bring-up demo.
