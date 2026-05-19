---
name: vibration tactile feedback
phase: 4
status: pending
blockedBy: [404]
---

# 410 — vibration tactile feedback

A brief vibration pulse fires when the radial keyboard commits a
character. The user feels the click, which improves typing rhythm
and confidence — especially in one-handed mode where there's no
right-stick "release" tactile cue.

## current behavior

The RG DS has a vibration motor but the broker doesn't use it.

## intended behavior

- On every radial-keyboard character commit, the broker triggers a
  short vibration: ~20 ms duration, light intensity.
- Different commit events can have subtly different patterns:
  - ordinary character commit: single short pulse
  - modifier-shifted commit (e.g., Shift+A): same short pulse
  - layer commit (L3 or R3 layer): same short pulse (the layer
    pre-action — pressing L3 — also pulses briefly so the user
    feels the layer engaged)
  - commit while no target is focused (error): a single longer
    pulse (~50 ms) at higher intensity to signal "your character
    didn't go anywhere"
- A settings option disables vibration entirely for users who don't
  like it or for battery preservation.
- The intensity / duration values are configurable; defaults are
  hand-tuned during phase 4 hardware testing.

## suggested implementation steps

1. Identify the Linux interface for the RG DS's vibration motor.
   Likely `/sys/class/leds/<name>/...` or a force-feedback `evdev`
   device. Document in `docs/002-hardware-target.md`.
2. Add `src/broker/haptics.lua` with `pulse(duration_ms,
   intensity)` and helper functions for the named patterns.
3. Hook the character-commit path (issue 404) to call `haptics.pulse`
   with the appropriate pattern.
4. Hook the layer-engagement path (issue 405's L3/R3 press) to
   call a layer-pulse pattern.
5. Add the settings toggle.
6. Hand-tune the durations and intensities until the click feels
   right. Subjective; defer to hardware-in-hand testing in phase 4.

## related documents

- `docs/003-input-system.md` — tactile feedback section
- `docs/002-hardware-target.md` — vibration motor capability
- `issues/404-character-emission-adb.md` — the commit path

## known design questions

- Should the vibration be different for stylus-tap commit vs
  right-stick commit? Default: no, same pattern. The vibration is
  the "this character was emitted" signal, not the "how you
  emitted it" signal. Revisit if hardware testing suggests
  differentiation helps.
- Battery cost? A 20-ms pulse at light intensity is negligible per
  use. At sustained typing (say 100 wpm = ~500 characters per
  minute) it's still negligible (~10 seconds of motor use per
  minute, light intensity). Document in the settings UI in case
  any user wants to verify.
