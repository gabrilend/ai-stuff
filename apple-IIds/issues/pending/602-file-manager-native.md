---
name: File Manager native
phase: 6
status: pending (pending soramech)
blockedBy: [301, 601, 703]
---

# 602 — File Manager native *(pending soramech)*

Replace the emulated File Manager with a native ARM implementation.
The shared volume (issue 301) becomes a first-class GS/OS device
without the virtual-disk fiction (which is what issue 703 — Broker
Filesystem device — partly does at a different layer).

## current behavior

GS/OS's File Manager runs in emulation. Every file op (Open, Read,
Write, Close, Catalog) executes 65C816 assembly. The shared volume
is exposed via emulated SmartPort, which adds another layer.

## intended behavior

- A native File Manager runs on its own thread under soramech.
- It implements the same GS/OS File Manager API surface (full).
  Code talking to the File Manager doesn't notice anything has
  changed.
- The shared volume from issue 301 / 703 is the File Manager's
  primary volume; per-instance boot volumes are also exposed via
  the same native code path.
- File ops cross from the emulated IIds to the native File Manager
  via soramech channels.
- ProDOS and HFS variants are both supported (real IIds software
  expects both).
- **Pending soramech**: thread-safety, channels, all that.

## suggested implementation steps

1. Wait for issues 601 and 703 to land (601 establishes the
   native-rewrite pattern; 703 establishes the Broker Filesystem
   device as the destination volume).
2. Read GS/OS's File Manager source. Map its API surface and
   state machine to a native equivalent.
3. Build a native File Manager (initially in C against soramech;
   eventually in ARM assembly).
4. Hook GSplus's interception layer for File Manager calls.
5. Performance test: open large files, catalog large directories,
   compare before and after.
6. Compatibility test: run a wide variety of IIds software that
   exercises the File Manager (compilers, copy utilities,
   archivers). All should work unchanged.

## related documents

- `issues/301-shared-backing-filesystem.md`,
  `issues/703-broker-filesystem-device.md` — the underlying volume
  surface
- `issues/601-scrap-manager-native.md` — the precedent
- `docs/004-roadmap.md` — phase 6

## known design questions

- File Manager is much bigger than Scrap Manager. Estimate: 5–10x
  the code, 100x the test cases.
- Caching: the native File Manager can maintain better caches than
  the emulated one (because it's not constrained to the IIds's
  128 KB direct page). What's the right cache size? Probably
  dynamic, sized to a fraction of available RAM.
- Performance target: opening a file should drop from ~50 ms
  (emulated) to ~1 ms (native).

## notes

- The File Manager rewrite is a significant chunk of work — easily
  weeks. It's the second-easiest of the four phase 6 issues but
  still substantial.
