---
name: touch and stylus as native GS/OS mouse events
phase: 8
status: pending
blockedBy: [702, 408]
---

# 801 — touch and stylus as native GS/OS mouse events

Touch and stylus events flow into GS/OS through the Broker Input
device (issue 702) directly, with no emulated ADB layer. Stylus
differentiation (issue 408) flows through as event metadata so GS/OS
applications can act on it.

## current behavior

Touch and stylus events enter the emulator via emulated ADB mouse
events. The differentiation between finger and stylus from issue
408 is broker-side only; the emulator and GS/OS see ordinary mouse
events.

## intended behavior

- The broker writes touch and stylus events directly to the Broker
  Input device (issue 702). Each event carries:
  - position (panel-relative, mapped to IIds framebuffer coords)
  - button state (down / up / held)
  - tool type (finger / stylus)
  - optional pressure or tilt if the digitizer reports them
- GS/OS's Event Manager receives these as native input events. The
  driver translates them to standard `mouseDown` / `mouseUp` /
  `null` events with the tool type stored in a low-bit of the
  modifier mask (or in a new event field, depending on GS/OS source
  flexibility).
- A small GS/OS extension exposes the tool-type bit to applications
  via a new Event Manager call (e.g.,
  `GetLastMouseToolType() → finger | stylus`).
- The right-click equivalent from issue 408 is now a true GS/OS
  event with the control modifier bit set, not a broker-injection
  fiction.

## suggested implementation steps

1. Define the event-record format on the Broker Input device's
   wire protocol. Document.
2. Update the broker's touch / stylus pipeline (from issues 104,
   202, 408) to emit events via `broker.post_input` instead of
   injecting through ADB.
3. Patch GS/OS's Event Manager to consume input events from the
   Broker Input device.
4. Add the `GetLastMouseToolType` extension and document it.
5. Write a test program that prints "finger" or "stylus" for each
   tap; verify both cases.
6. Test: existing GS/OS software still works (the new mouse events
   are compatible with the old ADB-shaped events). Software that
   wants stylus awareness can opt in via the new call.

## related documents

- `issues/702-broker-input-device.md` — the channel
- `issues/408-stylus-vs-finger.md` — the staging-ground precedent
- `docs/003-input-system.md` — touch and stylus

## known design questions

- The IIds mouse event format is fixed; adding tool-type breaks no
  existing apps but stretches the format. The right way is a
  side-channel (the new `GetLastMouseToolType` call). Don't try to
  shoehorn it into the event record itself.
- Pressure / tilt: the digitizer may report these. Worth exposing
  via a similar side channel for software that wants them. Add as
  a follow-up if any applications would benefit.

## notes

- After this lands, the broker doesn't pretend to be ADB for
  mouse/stylus anymore. The IIds sees real, first-class input from
  what is, from its perspective, a broker peripheral.
