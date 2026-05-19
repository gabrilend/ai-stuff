---
name: hardware abstraction layer (HAL)
phase: 11
status: pending
blockedBy: [1101]
---

# 1102 — hardware abstraction layer

A minimal driver layer in ARM assembly that gives the bare-metal
runtime access to the RG DS hardware: panels, digitizers, sticks,
audio, Hall switch, gyro, vibration motor, SD card.

## current behavior

The bare-metal boot from issue 1101 has a "hello world" but no
hardware support. Each driver Linux provided (input, framebuffer,
audio, etc.) is gone; we need to write the equivalents.

## intended behavior

- A set of small drivers, each in ARM assembly:
  - **Panels.** Initialize the IPS panels, push framebuffers to
    them, handle refresh and DPMS (sleep).
  - **Digitizers.** Read multi-touch events from the panel
    digitizers; distinguish finger / stylus.
  - **Analog sticks.** Sample stick positions.
  - **Buttons.** Read button states (d-pad, face, shoulder,
    Start, Select).
  - **Audio.** Configure the audio DAC, push PCM data.
  - **Hall switch.** Detect lid open / closed.
  - **Gyro.** Sample six-axis motion.
  - **Vibration motor.** Pulse on / off.
  - **SD card.** Block-level read / write via the on-board
    controller.
- Each driver exposes a tight API surface (10–30 calls each).
- The HAL is what the Apple IIds runtime calls into for any
  hardware interaction.

## suggested implementation steps

1. Reverse-engineer the RG DS's hardware interfaces. The Linux
   driver source is the primary reference (we read it to learn
   the register layouts). Document each driver's register map in
   `docs/research/rgds-hardware/`.
2. Implement each driver in ARM assembly. Start with the panels
   (the most visible) and the SD card (the most necessary).
3. Build each driver as a separate `.s` file under `src/hal/`.
   They link into the bare-metal binary.
4. Test each driver independently with a minimal bare-metal test
   program before integrating into the main runtime.

## related documents

- `issues/1101-bare-metal-boot.md` — the prerequisite
- `docs/002-hardware-target.md` — what we're driving
- Linux driver source — our reference

## known design questions

- Why assembly and not C? The threading primitives are in
  assembly (phase 9); the HAL is the lowest layer of the system;
  keeping the entire bottom of the stack in assembly maintains
  the "no C runtime fighting assembly" property. The cost is
  development time; the gain is a coherent low-level system.
- Should HAL drivers be reentrant? Yes — the threading model
  requires concurrent access. Each driver owns a lock per-device-
  instance and serializes access.

## sub-issues

This issue is split into nine sub-issues, one per device. The order
below is foundation-first: SD card and panels first (without these
the device can't boot to a visible state), then input devices
(digitizers, sticks, buttons), then audio and the smaller sensors.

- `1102a-hal-sd-card.md` — block-level SD card I/O (the gating
  driver for everything)
- `1102b-hal-panels.md` — the two 640×480 IPS panels
- `1102c-hal-digitizers.md` — multi-touch + stylus on both panels
- `1102d-hal-analog-sticks.md` — the two clickable sticks
- `1102e-hal-buttons.md` — d-pad, face, shoulder, dual Start /
  Select, volume, power
- `1102f-hal-audio.md` — DAC and PCM playback
- `1102g-hal-hall-switch.md` — sleep / wake sensor
- `1102h-hal-gyro.md` — six-axis IMU
- `1102i-hal-vibration.md` — haptic motor

This issue (1102) remains as the umbrella; the sub-issues are the
actual deliverables.

## notes

- All nine drivers are individually tractable. The complexity is in
  the SD card and panels (each is its own week of work); the
  others are days.
