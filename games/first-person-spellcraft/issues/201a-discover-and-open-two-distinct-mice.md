# 201a — Discover and open two distinct mice

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** hard (this is the technical taproot of the whole phase)
> **Depends on / blockers:** Phase 1 game loop must exist to own the input hook
> ([datapath-engine-foundation.md](../docs/datapath-engine-foundation.md)).
> **Blocks:** 201b (read loop), and through it everything else in Phase 2.
> **Parent issue:** 201 (raw multi-device mouse reading), split into 201a
> discovery/opening and 201b the read loop.

## Current Behavior

None of this exists yet — greenfield. There is no code that enumerates input
devices, and nothing distinguishes one mouse from another. Left unaddressed, the
operating system does what it does by default: it **merges every mouse into a
single shared cursor**, which is precisely the thing this game must undo.

## Intended Behavior

At startup (or on demand) the game can find the pointer devices attached to the
machine, present them, and **acquire two of them as two independent handles** —
one destined to be the left hand, one the right. After this issue, we hold two
open device handles that will each deliver *their own* motion, with the OS's
merged cursor no longer stealing their input.

Concretely, this issue is responsible for:

- **Enumeration.** Find the candidate pointer devices on the system. On Linux the
  input devices live at `/dev/input/eventX`. A device is a mouse-like pointer if
  it advertises relative-motion capability (a relative X axis in particular).
- **Identification.** Give each candidate a human-readable identity (its device
  name, its stable node path) so the player can tell "the mouse on the left" from
  "the mouse on the right." Two identical mice are the common case, so identity
  must include something stable and distinguishing (the node/physical-port path),
  not just the model name.
- **Acquisition.** Open the two chosen devices for reading, non-blocking, and
  **grab them exclusively** so their motion stops feeding the merged OS cursor.
  Exclusive grab is the mechanism that makes "two mice, two hands" possible
  instead of "two mice, one jittery cursor."
- **Release.** Cleanly ungrab and close the handles on shutdown or when input is
  handed to a different source (so switching away from dual-mouse does not leave a
  mouse frozen/grabbed for the whole OS).

Fallback discipline: if fewer than two suitable devices are found, or the chosen
device cannot be grabbed (usually a permissions problem), this must **error
loudly with a diagnostic**, not silently fall back to one mouse or the merged
cursor. A silent single-mouse fallback would hide the signature feature failing.

## Suggested Implementation Steps

1. **Enumerate `/dev/input/event*`.** List the event nodes. For each, determine
   whether it is a relative pointer. Two workable routes, most-reliable first:
   - Read the kernel's text summary at `/proc/bus/input/devices`, which lists each
     device's name, its `Handlers` (look for `mouse`/`event`), and its capability
     bitmasks — parseable as plain text, no ioctl needed. Good first
     implementation.
   - Or, via LuaJIT FFI, `ioctl` each node with the "get name" and "get capability
     bits" requests (`EVIOCGNAME`, `EVIOCGBIT`) and test for the relative-X axis
     bit. More precise, but requires computing the ioctl request numbers.
2. **Build a candidate list.** Each entry: node path, human name, and a stable
   distinguishing key (physical/port path from `/proc/bus/input/devices`'s `Phys`
   line, or the `by-id`/`by-path` symlink target). This key is what lets the
   left/right assignment (issue 202) survive a replug.
3. **Selection.** Provide a way to pick the two devices: a config value (persisted
   assignment), or an interactive "wiggle the mouse you want to be your LEFT hand"
   prompt that watches which node emits motion first. Keep selection separate from
   acquisition so it is testable against a recorded candidate list.
4. **Acquire.** Open each chosen node read-only and non-blocking (LuaJIT FFI
   `open` with the non-blocking flag), then issue the exclusive-grab request
   (`EVIOCGRAB`) so the OS cursor stops receiving that device.
5. **Release path.** Implement ungrab + close, and make sure it runs on any exit
   path (normal shutdown, error, or source switch).
6. **Permissions note as a comment.** Reading `/dev/input/eventX` needs the user
   to have read access (root, membership in the `input` group, or a udev rule).
   When acquisition fails on permissions, the error message should say exactly
   this — it is the single most common first-run failure and the fix is
   environmental, not code.

## Structures & Functions By Role

- A **device candidate** record: node path, human name, stable distinguishing key,
  is-pointer flag.
- An **enumerate candidates** function (text-parse route and/or ioctl route).
- A **select two devices** function (config-driven and interactive-wiggle
  variants), returning the two chosen candidates tagged left / right.
- An **open + grab** function producing a *device handle* (fd + identity + grabbed
  flag), and its **release** counterpart.

## Data-Format Facts To Record As Comments

- Input device nodes: `/dev/input/eventX`. Human summary: `/proc/bus/input/devices`
  (fields `N:` name, `P:` phys, `H:` handlers, `B:` capability bitmasks).
- Exclusive grab is `EVIOCGRAB`; name is `EVIOCGNAME`; capability bits are
  `EVIOCGBIT`. The relative-motion event class is `EV_REL`; its X-axis code is
  `REL_X`. Presence of the `REL_X` capability bit is the "this is a pointer" test.

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — stage [1] "raw evdev event stream."
- Next: [201b — per-device evdev read loop](201b-per-device-evdev-read-loop.md)
  consumes the handles this issue produces.
- Consumer of the left/right tagging:
  [202 — per-hand state and hand-role assignment](202-per-hand-state-and-hand-role-assignment.md).
