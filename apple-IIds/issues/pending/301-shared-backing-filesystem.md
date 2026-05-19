---
name: shared backing filesystem
phase: 3
status: pending
blockedBy: [201]
---

# 301 — shared backing filesystem

Both emulated IIdses see the same files. A file written by instance A
is visible to instance B and vice versa. There is one source of truth
on the host's microSD card.

## current behavior

Each instance has its own boot disk image (issue 201). Files written
on screen A are invisible to screen B. Copying a document between the
two requires manual disk-image juggling.

## intended behavior

- The broker exposes a **shared volume** to both instances. From each
  IIds's perspective it looks like an ordinary HFS or ProDOS volume
  mounted alongside its boot disk.
- Files in the shared volume live as **plain host files** on the
  microSD card under a directory like `~/.apple-IIds/shared/`. They
  are not stored inside a `.2mg` or `.hdv` image — that would make
  the host's view opaque and break the "the broker is the source of
  truth" property.
- File metadata (creator code, type code, finder info) is preserved
  via xattrs on the host file (or a sidecar `.applefile` per AppleSingle
  conventions, depending on what's easier).
- Concurrent writes are governed by issue 302 (file locking).
- The broker maintains a small in-memory mirror of the shared volume's
  catalog for fast lookup; the on-disk state is authoritative.
- For phase 3, the IIds sees the shared volume via a **SmartPort
  device** that the broker provides — same protocol GSplus already
  speaks for hard-disk volumes. Once phase 7 lands the Broker
  Filesystem device (issue 703), the SmartPort fiction goes away in
  favor of a first-class GS/OS device driver.

## suggested implementation steps

1. Decide the on-disk layout: `~/.apple-IIds/shared/` containing files
   that look ordinary to the host, plus a `.metadata/` directory or
   xattr-based sidecar for IIds-specific attributes.
2. Build a Lua module `src/broker/shared-volume.lua` that translates
   between IIds file ops (SmartPort read/write block, ProDOS catalog
   operations) and host filesystem ops.
3. Extend GSplus's SmartPort emulation (or add a new SmartPort device
   handler) that calls into the Lua module for read/write/list.
4. Mount the shared volume in each instance's GS/OS at boot. The
   volume should appear in the Finder with a recognizable name
   ("Shared" or "Both").
5. Test the round trip: create a file on screen A, see it on screen B,
   open it on B, verify contents.
6. Test edge cases: large file, file with HFS attributes (creator/type),
   long filename, ProDOS path-length limits.

## related documents

- `docs/001-architecture-overview.md` — layer 2 broker, shared FS
- `docs/004-roadmap.md` — phase 3 and phase 7 (703 supersedes the
  SmartPort fiction)
- `issues/302-file-locking.md` — what happens on concurrent open

## known design questions

- HFS vs ProDOS for the shared volume? HFS supports longer filenames
  and richer metadata; ProDOS is more native to IIds software.
  Default: HFS, since most modern IIds software prefers it. Confirm
  during phase 3 hardware testing.
- AppleSingle vs xattr for metadata? AppleSingle is portable to
  non-Linux hosts; xattrs are zero-overhead on Linux. The RG DS is
  Linux, so xattrs win. If anyone ever runs this on macOS, AppleSingle
  is the alternative path.
- Performance: SmartPort over the broker is slow compared to native
  disk I/O. For phase 3, "works correctly" matters more than "fast."
  Phase 7's Broker Filesystem device addresses the speed.

## notes

- The shared volume's existence does not eliminate per-instance boot
  disks. Each instance still boots from its own .2mg. The shared
  volume is mounted *in addition to* the boot disk, not instead of
  it.
- Once an application writes to the shared volume from screen A, the
  Finder on screen B doesn't auto-refresh. The user has to manually
  refresh the window. This is a GS/OS Finder limitation; we may fix
  it in phase 7 (704 — Finder dual-desktop awareness).
