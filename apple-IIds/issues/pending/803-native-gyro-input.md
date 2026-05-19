---
name: gyro as a native GS/OS input source
phase: 8
status: pending
blockedBy: [702]
---

# 803 — gyro as a native GS/OS input source

The six-axis gyroscope flows into GS/OS through the Broker Input
device as a "fine cursor mode" input — held shoulder button + wrist
motion moves the mouse pointer precisely, useful for pixel-art and
close-box hunting.

## current behavior

The gyro is unused. The RG DS has it; the broker hasn't wired it
up.

## intended behavior

- A modal **fine cursor mode**: while a configured shoulder button
  (e.g., L2) is held, the gyro takes over cursor control on the
  focused screen. Releasing the button returns to touch / stylus
  control.
- In fine cursor mode:
  - Pitch / yaw of the device → fine cursor delta (sub-pixel
    accumulation in the broker, integer panel pixels emitted to
    GS/OS).
  - Sensitivity is configurable (settings UI).
  - The cursor doesn't move while the device is at rest; gyro is
    differential, so wrist motion is required.
- Fine cursor events are emitted through the Broker Input device
  as ordinary mouse-move events. GS/OS doesn't know it's gyro;
  it just sees the cursor moving smoothly in tiny increments.
- Other potential gyro uses (screen rotation detection) are out
  of scope for phase 8.

## suggested implementation steps

1. Identify the gyro's Linux IIO device. Confirm during issue
   101's hardware survey.
2. Add a broker reader that samples the gyro at, say, 100 Hz.
3. Implement the fine-cursor-mode state machine: shoulder button
   pressed → engage; sample gyro delta; multiply by sensitivity;
   emit mouse-move events; release → disengage.
4. Add the sensitivity setting to the settings UI.
5. Test: enter fine cursor mode, draw a 1-pixel-wide line in a
   paint program, verify the line is straight (no jitter).

## related documents

- `docs/003-input-system.md` — gyroscope section
- `docs/002-hardware-target.md` — gyro capability
- `issues/702-broker-input-device.md` — the channel

## known design questions

- Which shoulder button engages it? L2 by default (R2 is reserved
  for the Control modifier in the radial keyboard). Configurable.
- Sensitivity calibration: 1° of wrist motion → how many pixels?
  Defer to feel testing during phase 8.
- Drift compensation: gyros drift over time. Either reset to zero
  on engage, or use a complementary filter with the accelerometer
  for a stable orientation. Simpler: reset to zero on engage.
  The user re-engages frequently enough that drift never builds
  up.

## notes

- This is a small, optional feature. Worth the effort because it
  shows off the device's modern hardware (the IIds was never
  shipped with a gyroscope) without being load-bearing for
  anything else. A nice "look what the modernized version can do"
  demo.
