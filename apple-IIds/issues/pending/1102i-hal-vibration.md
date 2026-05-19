---
name: HAL — vibration motor
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102i — HAL: vibration motor

ARM-assembly driver for the vibration motor. Provides on/off and
duration control for haptic feedback.

## current behavior

Linux's force-feedback or LED subsystem typically controls the
motor. On bare metal, direct PWM or GPIO toggling.

## intended behavior

- Initialize the GPIO or PWM controller wired to the motor.
- API for short pulses (used by the radial-keyboard commit
  feedback from issue 410) and arbitrary on / off control.

## API surface

- `haptic_init`
- `haptic_pulse(duration_ms, intensity)` — pulse on for
  duration_ms.
- `haptic_set(on_or_off, intensity)` — direct control.

## suggested implementation steps

1. Identify the motor's control GPIO or PWM channel. Document.
2. Configure the PWM if applicable (for intensity control); else
   GPIO toggle (binary on/off).
3. Implement the pulse function with a timer interrupt for
   precise duration.
4. Test: trigger pulses of varying durations; confirm motor
   responds.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/410-vibration-feedback.md` — the layer above

## notes

- Smallest HAL driver. Easy win to round out the set.
