---
name: radial keyboard as native GS/OS key events
phase: 8
status: pending
blockedBy: [702, 404]
---

# 802 — radial keyboard as native GS/OS key events

The radial keyboard's character emission flows through the Broker
Input device directly. No emulated ADB; native GS/OS key events.

## current behavior

Radial keyboard characters are injected through emulated ADB (issue
404). Each commit takes a trip through the emulated keyboard
controller before reaching GS/OS.

## intended behavior

- The broker's commit handler (issue 404) is updated to write key
  events to the Broker Input device instead of injecting through
  ADB.
- Each commit emits one event record: `{type=key, code,
  modifiers, char, timestamp}`. GS/OS's Event Manager picks it up
  and routes it to the focused window via standard key-event flow.
- Modifier-state handling moves to be carried per-event rather than
  managed via emulated ADB modifier flags. The broker is the
  authoritative source for modifier state; each emitted event
  carries it.
- The "last-input target" tracking (issue 403) gets richer because
  the broker can now observe which GS/OS window receives each
  emitted character — the broker queries GS/OS via a tiny
  side-channel on the Broker Input device.

## suggested implementation steps

1. Extend `broker.post_input` to handle key event records.
2. Update issue 404's commit handler to call `broker.post_input`
   with key events instead of going through emulated ADB.
3. Patch GS/OS's Event Manager to accept key events from the
   Broker Input device. Same shape as existing keyboard events.
4. Add the side-channel for "which window has insertion point" so
   the broker can populate `last_input.window` / `program`.
5. Test typing: same observable behavior as issue 404, but lower
   latency (no ADB controller, no interrupt simulation).
6. Measure: stick-tilt-to-character-visible time. Should drop
   from ~30ms to under 5ms.

## related documents

- `issues/404-character-emission-adb.md` — the staging-ground
  precedent
- `issues/702-broker-input-device.md` — the channel
- `issues/403-last-input-target.md` — the tracking this enriches

## known design questions

- ADB stays around for software that polls the emulated keyboard
  hardware directly. That's a small but real population (some
  games). Default: keep ADB working in parallel; the radial
  keyboard just doesn't use it anymore.
- What about Caps Lock state? In phase 4 / 5 this was a broker-
  side virtual lock. In phase 8, GS/OS's standard CapsLock state
  is authoritative; the broker reads it via a side-channel and
  reflects it in the overlay.

## notes

- This is where the radial keyboard finally feels like a *real*
  keyboard. The emulated-ADB indirection is the last fiction
  layer; removing it makes the typing experience first-class.
