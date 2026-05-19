---
name: audio mixer (per-program stereo channel)
phase: 5
status: pending
blockedBy: [201]
---

# 507 — audio mixer

Each emulated program owns its own stereo channel in software. The
broker mixes the two Ensoniq 5503 outputs (one per IIds) plus
per-program panning into the device's stereo speakers or headphone
jack.

## current behavior

Each emulator has its own audio output. Phase 2 left this as "both
to mono center" or "each instance to one channel" — not a
per-program decision.

## intended behavior

- The broker provides a software audio mixer. Each emulator's
  Ensoniq output is treated as a 32-channel source (the Ensoniq has
  32 oscillators). Per-oscillator panning is in the Ensoniq's
  hardware model already, but we treat each **program** as a
  panning unit, not each oscillator.
- A program is "the foreground program on each emulator." When
  program X is in the foreground on instance A, all audio from
  instance A is panned according to X's pan setting. When program
  X moves to the background and Y becomes foreground, the mixer
  swaps pan settings.
- Defaults:
  - Instance A's foreground program: pan slightly left (-0.2).
  - Instance B's foreground program: pan slightly right (+0.2).
  - The user can adjust these in the settings UI (issue 503).
- Per-program pan settings persist across launches (stored in the
  shared volume's settings file).
- Master volume control adjusts both instances' total output.
- A "focused screen takes priority" alternative mode: when this is
  on, the unfocused emulator's audio is attenuated by 50%, so the
  user hears the focused screen more clearly. Disabled by default
  (it breaks the dual-machine fiction); available in settings.

## suggested implementation steps

1. Identify GSplus's audio output. Likely SDL2 audio callback or
   ALSA PCM. The patch redirects this into our mixer instead of
   the device's audio output directly.
2. Implement `src/broker/audio-mixer.lua`: takes two stereo streams
   (from the two emulators), applies panning, mixes, sends to the
   device's PCM device.
3. Identify the "foreground program" per instance. For phase 5,
   poll GS/OS's Process Manager (or its predecessor in GS/OS 6.0)
   to read the current foreground process.
4. Maintain per-program pan settings: a Lua table keyed by program
   name, persisted to the settings file.
5. Wire the settings UI to the pan table.
6. Test: launch a music app on each screen, observe stereo
   separation. Switch programs; observe pan settings change.

## related documents

- `docs/001-architecture-overview.md` — broker responsibility #6
- `issues/503-settings-ui.md` — surfaces pan settings
- `issues/508-boot-chime-once.md` — uses the mixer's mute on second
  emulator

## known design questions

- Per-program identification: GS/OS doesn't always have a clean
  "current foreground program" concept (it's cooperative single-
  task during phases 1–8; multithreading arrives in phase 9). For
  phase 5, use the application that owns the top window. Adjust
  in phase 9 when multitasking becomes real.
- Sample rates: the Ensoniq sample rate is variable (programmable
  per oscillator). Mix everything at 44.1 kHz internally; resample
  per-source on the fly.

## notes

- The two-Ensoniq stereo is one of the project's quiet joys. Don't
  let the mixer get in the way — it should be invisible when
  working correctly.
