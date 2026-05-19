---
name: Event Manager native
phase: 6
status: pending (pending soramech)
blockedBy: [702, 601]
---

# 603 — Event Manager native *(pending soramech)*

Replace the emulated Event Manager with a native ARM implementation.
Once this lands, the radial keyboard, touch, and stylus all flow
through the native event queue with minimal latency, instead of
being injected through emulated ADB.

## current behavior

The Event Manager runs in emulation. Input from the radial keyboard
arrives via emulated ADB (phase 4) and is queued via the emulated
Event Manager's `PostEvent`. Latency: stick-tilt-to-character
visibility is around 30–50 ms.

## intended behavior

- A native Event Manager runs on its own thread under soramech.
- The Broker Input device (issue 702) writes events directly into
  the native queue, bypassing ADB emulation.
- IIds programs polling for events (`GetNextEvent`,
  `EventAvail`, `WaitNextEvent`) get the queue contents via the
  same API as before, but the queue itself is native.
- Latency drops: stick-tilt-to-character should be under 5 ms.
- **Pending soramech**: thread sync, lock-free queue (or
  soramech-channel-backed), all that.

## suggested implementation steps

1. Wait for issues 702 (Broker Input device) and 601 (the
   precedent).
2. Read GS/OS's Event Manager source. Map state and API.
3. Implement the native event queue with appropriate sync primitive
   (lock-free is ideal; soramech-channel is acceptable).
4. Hook GSplus's interception for Event Manager entry points.
5. Update the Broker Input device (issue 702) to write into the
   native queue directly when this issue is complete.
6. Latency-test: type a character on the radial keyboard, measure
   the time until it appears in the focused window. Compare to
   pre-issue baseline.

## related documents

- `issues/702-broker-input-device.md` — the input source that
  benefits most
- `issues/601-scrap-manager-native.md` — the precedent
- `docs/003-input-system.md` — the radial keyboard's commit path

## known design questions

- Lock-free vs locked queue? Lock-free is faster but harder to
  write correctly in assembly. Locked is sufficient (events are
  small, lock-hold is brief). Start with locked; consider
  lock-free in a follow-up.
- IIds software that relies on emulated-ADB timing details might
  break. Mostly harmless (the timing is *better*), but some games
  poll at specific cycle counts. Test against the game in the
  curated library; document any issues found.

## notes

- This is where the radial keyboard *feels* fast. The
  staging-ground version (phases 4 / 8 ADB injection) was good
  enough; the native version makes typing feel like a real
  keyboard.
