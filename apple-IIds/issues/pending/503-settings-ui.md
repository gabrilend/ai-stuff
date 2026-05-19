---
name: settings UI
phase: 5
status: pending
blockedBy: [501]
---

# 503 — settings UI

A user-visible settings interface that exposes the broker's
configurable options. The user adjusts brightness, volume, radial
keyboard layout, training mode, vibration, audio panning,
file-conflict log view, etc., without editing config files.

## current behavior

All settings live in `~/.apple-IIds/config.lua`. To change anything,
the user has to ssh into the device and edit the file. This is fine
for developers but unacceptable for normal use.

## intended behavior

- A settings application appears in each instance's Applications
  folder (or, alternatively, as a "Settings" entry in the Apple
  menu). The application is itself a small IIds program that
  communicates with the broker via the AppleTalk IPC channel (issue
  304) to read and update settings.
- Settings categories:
  - **Display**: brightness, screen assignment (top = A or B),
    integer-scale vs centered-letterbox mode.
  - **Audio**: master volume, per-program panning defaults, mute.
  - **Input**: radial keyboard layout (with the calibration UI from
    issue 407), training mode, modifier mode (held vs sticky),
    vibration on/off and intensity.
  - **Storage**: shared-volume location, view of recent conflicts
    (from issue 305's audit log).
  - **Power**: sleep behavior, brightness on idle.
  - **About**: broker version, GS/OS version, build timestamp,
    license info.
- Changes apply immediately where safe; some changes (e.g., screen
  assignment) require a broker restart, which the UI announces.

## suggested implementation steps

1. Decide the technology: a native IIds program (in 65C816 assembly)
   that uses the Toolbox for its UI, talking to the broker over
   AppleTalk. Aesthetic-coherent with GS/OS.
2. Define the settings IPC protocol: get_setting(category, name),
   set_setting(category, name, value), list_settings(category).
3. Implement the broker side of the protocol.
4. Write the settings app in 65C816 assembly. Borrow the GS/OS
   Toolbox's standard UI controls (dialogs, lists, sliders).
5. Surface settings categorically with tabs or a list-detail layout.
6. Test: change a setting in the UI; observe the broker pick it up
   and the change apply.

## related documents

- `issues/304-appletalk-ipc-channel.md` — the IPC transport
- `issues/406-training-mode.md`, `issues/407-wedge-layout-calibration.md`,
  `issues/410-vibration-feedback.md`, `issues/507-audio-mixer.md` —
  the settings being surfaced

## known design questions

- Should settings be per-instance or global? Mostly global (the
  device is one unit), but a few are reasonably per-instance (e.g.,
  panel brightness, audio panning bias). Default: settings are
  global unless explicitly tagged "per-instance."
- Two settings apps running simultaneously, one per screen — should
  they see each other? Yes (they're talking through the broker and
  share state). The second-opener should see the first's changes
  live, refreshed via a notification on the IPC channel.

## notes

- Writing the settings app in 65C816 assembly is itself useful: it's
  one of the first non-trivial IIds programs we write, exercising
  the Toolbox, the IPC channel, and our build pipeline.
