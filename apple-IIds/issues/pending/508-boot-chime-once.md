---
name: boot chime exactly once
phase: 5
status: pending
blockedBy: [501, 507]
---

# 508 — boot chime exactly once

The Apple //gs chime is iconic. We keep it. The broker plays it
exactly once on power-on and suppresses the second emulator's chime
by muting its audio output for the first ~2 seconds of boot.

## current behavior

Both emulators play the //gs chime on boot. The result is a doubled
chime — same sound playing twice, slightly offset. Distracting; not
faithful to the original; doesn't fit the "one machine, two
desktops" feel.

## intended behavior

- On cold boot (broker initial start, both emulators launching):
  - Instance A boots normally; its chime plays through the mixer.
  - Instance B boots, but the broker mutes its audio output for the
    first ~2 seconds, suppressing its chime.
  - After the suppression window, instance B's audio is unmuted;
    any post-boot sounds (Finder sounds, app sounds) come through
    normally.
- On warm boot (broker restarting one instance after a crash, etc.):
  - The restarted instance is the only one starting up; its chime
    plays normally.
  - No suppression needed.
- The 2-second window is configurable (in case the boot time
  changes); default 2.0s, settable in config.
- The chime sound itself is unchanged — it's whatever the Apple //gs
  ROM plays. We just control which speaker hears it.

## suggested implementation steps

1. Identify the moment "boot begins" for each instance. This is
   the moment the broker spawns the GSplus process for that
   instance, plus a small delay to account for emulator startup.
2. Tag the second instance to spawn with a "muted for 2 seconds"
   flag.
3. In the audio mixer (issue 507), respect the per-instance mute
   flag.
4. After the configured window, clear the mute flag.
5. Confirm cold-boot behavior: only one chime audible.
6. Confirm warm-boot behavior: a restarted single instance chimes
   normally.

## related documents

- `docs/001-architecture-overview.md` — broker responsibility #7
- `notes/vision/000-vision.md` — the boot chime section
- `issues/507-audio-mixer.md` — provides the mute hook

## known design questions

- Which instance gets to chime? Default: instance A (top screen).
  Settable, in case the user wants the other order. The user
  rarely cares which; the point is that there's only one chime.
- What if the user actively *wants* two chimes (because they think
  it's a cute reminder of the two-machine architecture)? A
  setting to disable suppression. The default is "one chime," but
  the option exists.

## notes

- This is a small, finishable issue. Resolves a real annoyance in
  the phase 2 demo. Worth banging out early in phase 5 just for
  the QoL win.
