---
name: second emulator instance on screen B
phase: 2
status: pending
blockedBy: [103]
---

# 201 — second emulator instance on screen B

A second GSplus process runs alongside the first, with its framebuffer
on screen B. The two emulators are independent processes with isolated
state; the broker supervises both.

## current behavior

A single GSplus instance is running on screen A (issue 103). Screen B
is blank or shows a placeholder.

## intended behavior

- The broker spawns and supervises **two** GSplus instances.
- Each instance is a separate OS process with its own memory, its own
  ROM image, its own boot disk image, its own audio buffer, and its
  own MMIO regions.
- Instance A's framebuffer is sent to the top panel; instance B's to
  the bottom panel.
- Each instance has its own GS/OS boot image. For phase 2 these can
  be identical copies; they diverge as soon as the user installs
  different software on each, or once the shared filesystem from
  phase 3 lands.
- If one instance crashes, the broker restarts it without touching
  the other. The user's view: screen A keeps working while screen B
  reboots.
- On clean device shutdown, the broker signals both instances to halt
  cleanly before powering down.

## suggested implementation steps

1. Refactor the broker's GSplus launcher (from issue 103) into a
   parameterized function: launch with (rom_path, disk_path,
   panel_target, audio_target, mmio_base).
2. Spawn the first instance with the screen-A parameters (as today).
3. Spawn the second instance with the screen-B parameters (panel
   target = bottom panel `/dev/fb1` or DRM connector, distinct audio
   buffer, distinct MMIO base for the broker-peripheral devices
   that arrive in phase 7).
4. Verify the two instances do not collide on any shared resource:
   each has its own SDL window (if SDL is still in the loop), its
   own input event source, its own MMIO range.
5. Add a supervisor loop: poll each instance's process state, restart
   on unexpected exit, log crashes to `tmp/broker.log`.
6. Add a clean-shutdown protocol: on broker termination, signal both
   instances with SIGTERM, wait up to 2 seconds, escalate to SIGKILL.

## related documents

- `docs/001-architecture-overview.md` — layer 2 broker responsibilities
- `docs/002-hardware-target.md` — panel mapping
- `issues/103-single-screen-boot.md` — the single-instance prerequisite

## known design questions

- Where does the second instance's boot disk image come from? For
  phase 2, copy from screen A's. Once phase 3 lands, both instances
  share a single backing volume.
- ROM is the same file for both instances (one Apple //gs ROM image).
  GSplus loads its own copy into memory at launch; no contention.
- Audio: the broker mixes both instances' Ensoniq outputs (see issue
  507). For phase 2, both can route to mono center; per-program
  stereo is a phase 5 concern.
