---
name: HAL — analog sticks
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102d — HAL: analog sticks

ARM-assembly driver for the two clickable analog sticks. Reports
continuous (x, y) per stick plus a click bit per stick.

## current behavior

Linux's joystick / evdev subsystem handles the sticks. On bare
metal, raw ADC reads.

## intended behavior

- Initialize the ADC channels the sticks are wired to.
- Sample each stick at ~1 kHz (well above the rate the radial-
  keyboard quantizer needs).
- Sample the click bits (digital inputs).
- Provide a query API: `stick_read(which) → {x, y, click}`.

## API surface

- `sticks_init`
- `stick_read(which) → {x, y, click}`
- (poll-based; the broker reads at its own rate)

## suggested implementation steps

1. Identify the ADC channels for the four stick axes (2 sticks × 2
   axes). Document in
   `docs/research/rgds-hardware/analog-sticks.md`.
2. Identify the digital pins for the stick clicks.
3. Implement ADC initialization and reading.
4. Implement digital-input reading.
5. Calibrate against the issue 401 calibration script's expectations.
6. Test: tilt each stick, observe (x, y) values; click each stick,
   observe the click bit.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/401-stick-quantization.md` — consumes raw (x, y) data

## notes

- Cheap analog sticks drift over time. The driver should report
  raw values; calibration (dead-zone, range) lives one layer up.
