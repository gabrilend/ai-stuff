---
name: disk image management
phase: 1
status: pending
blockedBy: [103]
---

# 105 — disk image management

The user can insert and eject IIgs disk images while the system is
running.

## current behavior

A single GS/OS boot disk is hardcoded at launch (issue 103). The user
cannot mount a second disk to install software or load a game.

## intended behavior

- A configuration file (`assets/disks/inventory.lua`) lists all available
  disk images on the microSD card.
- The broker exposes a way to "insert" a disk into the running emulator
  without restarting it. GSplus supports runtime disk insertion via its
  configuration / control interface; the broker drives that interface.
- A way to "eject" likewise.
- For phase 1, the UI for this can be the crudest possible: pressing
  `Select` (right-side pair) opens a tiny on-screen list rendered by the
  broker on the bottom panel, d-pad navigates, A inserts.

## suggested implementation steps

1. Survey the microSD card for IIgs disk images. The IIgs ecosystem uses
   several formats:
   - `.2mg` — the most common, includes metadata
   - `.po` — ProDOS-ordered raw disk
   - `.do` — DOS 3.3-ordered raw disk
   - `.hdv` — hard-disk volume
   - `.dsk` — generic, ambiguous order
   Support `.2mg` and `.hdv` at minimum; warn on the others.
2. Build the inventory: scan the microSD's `disks/` directory, read each
   image's metadata where present, populate `inventory.lua`.
3. Add a broker command channel — for now, a Unix socket or pipe that
   accepts text commands like `insert /path/to/disk.2mg` and `eject 1`.
4. Implement the GSplus side of disk insertion. The relevant code paths
   are in GSplus's `iwm.c` (Integrated Woz Machine — the disk controller)
   and `smartport.c`; the patch is to expose runtime insert/eject
   programmatically.
5. Build the minimal `Select`-key disk picker UI as an overlay drawn by
   the broker on the bottom panel.
6. Test: boot GS/OS, insert a second disk image (e.g. a game), see it
   appear on the desktop, drag a file off it, eject it cleanly.

## related documents

- `docs/001-architecture-overview.md` — broker section
- GSplus source: `iwm.c`, `smartport.c`

## notes for future phases

- Once phase 3 lands the shared backing filesystem and phase 7 modifies
  GS/OS to know about the broker as a real device, individual disk
  images become a less common abstraction — the emulated IIgses see a
  single shared volume instead. Disk images stick around for booting
  real IIgs software that expects a specific disk to be mounted, and
  for installing new software (the original install path was always disk
  → hard drive).
