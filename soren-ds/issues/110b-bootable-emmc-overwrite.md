# 110b — Bootable eMMC overwrite

## Current behavior

SoreOS can read and write blocks on the internal eMMC (110a) but
runs from the external microSD. The eMMC still holds Anbernic's
stock Android: the Rockchip miniloader and u-boot at fixed low
offsets that the boot ROM expects, then a partition table, then
the boot partition with Android's kernel and ramdisk, then the
system partition with Android's userland, then userdata. When
the external microSD is removed and the device is powered on, the
boot ROM falls through to the eMMC and Android comes up — which
the vision (`notes/vision/000-vision.md`) forbids. The only thing
keeping that from happening is the developer remembering to keep
an SD card inserted.

## Intended behavior

The SoreOS kernel image, wrapped in the Android boot.img format
that Anbernic's u-boot already knows how to load, is written into
the eMMC's boot partition in place of Android's kernel. After
this issue closes:

- Powering the device on with no SD card present causes the
  Rockchip boot ROM to load the miniloader from eMMC, the
  miniloader to load u-boot from eMMC, u-boot to read its
  partition table and load the boot partition's image into RAM,
  and that image to be SoreOS (not Android).
- The miniloader, u-boot, and the partition table are untouched.
  Only the contents of the boot partition change.
- The vision constraint is structurally enforced rather than
  enforced by developer discipline: there is no Android kernel
  on the device to fall through to.

The Android boot.img format is a documented, simple structure: a
header with magic `ANDROID!`, a kernel size and load address, a
ramdisk size and load address, command line and tags, followed
by the kernel and (optionally) the ramdisk concatenated at
sector boundaries. The build system from issue 103 produces the
SoreOS image; this issue wraps that image in the boot.img
envelope u-boot expects, and writes the wrapped image to the
boot partition's first sector through the block driver from 110a.

## Why this design rather than replacing u-boot

`notes/safety/000-bricking-and-recovery.md` makes the case
explicitly: u-boot is layer 2 and its corruption is a
hard-brick path that only Maskrom can recover from. Maskrom
reachability from outside the closed case is unconfirmed for the
RG DS. Touching u-boot, the miniloader, or the partition table
is therefore a Rule One Violation. The boot partition, in
contrast, is a recoverable layer: a botched write here leaves
u-boot intact, the SD card still boots, and we recover by
re-writing.

The cost we accept in exchange is one small wrapper around our
kernel image. The cost we avoid is the entire u-boot replacement
work, which would itself require a working DDR init, a working
partition reader, and a working storage abstraction — all of
which we currently get for free from Rockchip's existing chain.

## Find the boot partition without trusting Android's name for it

The partition table on the eMMC is a standard GPT (or Rockchip's
parameter-file equivalent on older firmwares). The boot partition
is the one labeled `boot` in that table. Issue 110b does not
hard-code an offset; it reads the partition table from eMMC,
finds the `boot` entry, and writes there. This makes the issue
survive Anbernic shipping a slightly different layout on a future
firmware revision.

If the partition table is unreadable (corrupt, unrecognized
format), the issue fails loudly. It does not guess.

## Single-shot, verify-after-write, recovery-aware

This is the first-ever eMMC write our project performs. The
safety doc lists it under "extra careful" item 3. Every write
the issue performs is followed by a read-back-and-compare of the
same block before moving on. Any mismatch fails the operation
immediately and reports through CDC-ACM. The SD card with
last-known-good SoreOS is the recovery path; the issue assumes
the developer has one inserted as insurance, even though the
operation does not need it.

## What this issue does not do

- It does not enable USB-C flashing yet. The image still has to
  be installed by writing the SD card and running this issue's
  on-device tool. That changes in 110c.
- It does not implement A/B slot management. There is one boot
  partition; we write to it. A/B was discussed in the safety doc
  as a future enhancement and is appropriate to defer until
  110c needs it for resilient over-USB updates.
- It does not touch the Android recovery partition, the system
  partition, or userdata. Those remain bit-for-bit what Anbernic
  shipped and become reclaimable storage in a later phase if we
  want them.

## Suggested implementation steps

1. Read the GPT (or Rockchip parameter equivalent) from the
   beginning of the eMMC using the 110a block driver. Parse and
   locate the `boot` partition's start LBA and size in blocks.
2. From the build artifact produced by issue 103, build the
   Android boot.img wrapper: header, kernel section, no
   ramdisk for now (zero-length ramdisk). Compute the boot.img
   header checksums u-boot expects.
3. Write the wrapped image into the boot partition's first
   sectors using 110a, one block at a time, reading each block
   back and comparing after writing.
4. On success, report through CDC-ACM and the LED, then
   power-cycle the device with the SD card removed and confirm
   the device comes up into SoreOS-from-eMMC.
5. Re-insert the SD card afterward so the recovery path stays
   available for future flashes.

## Related documents

- `docs/014-hardware-overview.md` — boot chain, the Anbernic
  u-boot we are sitting on top of, why it accepts a boot.img.
- `notes/safety/000-bricking-and-recovery.md` — design rules
  for first-time flashes, why u-boot must not be touched, why
  reads-after-writes are non-negotiable.

## Blocked by

110a (eMMC reads and writes), 110 (CDC-ACM for live status).

## Blocks

110c (USB-C flash protocol — the daily-loop tool that replaces
SD-swap entirely).
