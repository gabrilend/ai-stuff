---
name: Toolbox in ARM — Sound Manager
phase: 11
status: pending
blockedBy: [1104a, 1102f]
parent: 1104
---

# 1104k — Toolbox in ARM: Sound Manager

ARM-assembly port of the IIds Sound Manager and Sound Tool Set.
Drives the Ensoniq 5503 (now emulated within the bare-metal Apple
IIds) and provides the program-level sound API.

## current behavior

The Sound Manager runs in emulation. The Ensoniq itself is also
emulated (since there's no physical Ensoniq on the RG DS).

## intended behavior

- Native ARM implementation of the Sound Manager API:
  `StartSound`, `StopSound`, `SetSoundVolume`, plus the
  oscillator-level controls.
- The Ensoniq 5503 emulation is itself ported to ARM assembly —
  this is a software simulation that takes Sound Manager commands
  and produces PCM samples (32 oscillators worth) that go to the
  HAL audio driver (1102f).
- Stereo mixing per program (from issue 507's staging-ground
  audio mixer) is preserved.

## suggested implementation steps

1. Study GS/OS Sound Manager source and the Ensoniq 5503 chip
   documentation.
2. Port the Sound Manager API surface.
3. Port the Ensoniq emulation (the 32-oscillator sample
   generator).
4. Wire the output to the HAL audio driver.
5. Test: play a known IIds tune (.SHR or similar); compare to
   emulated output.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1102f-hal-audio.md` — the underlying audio driver
- `issues/507-audio-mixer.md` — staging-ground precedent

## notes

- The Ensoniq simulation is delicate work — the chip has many
  subtle behaviors (sample reset, oscillator interrupts, etc.).
  Match the original exactly so software written for the real
  IIds plays correctly.
