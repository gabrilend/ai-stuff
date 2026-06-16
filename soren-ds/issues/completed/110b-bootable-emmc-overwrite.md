# 110b — Bootable eMMC overwrite

## Current behavior

`src/013-boot-image.c` exposes a `write_kernel_to_emmc_boot_partition`
function that wraps the running kernel image in an Android
boot.img header (version 0, the simplest variant) and writes the
header followed by the kernel bytes to the eMMC's boot
partition through the block driver from 110a. The function does
not run automatically on boot — it is meant to be triggered
deliberately (by 110c's USB-C flash protocol, or by a button-
held-at-boot dispatch the eventual phase 1 demo can wire) so a
boot from SD does not re-flash the eMMC every time.

A new linker-script symbol `__image_end` marks the on-disk end
of the kernel image, so the boot.img header's `kernel_size`
field can be populated correctly from a linker symbol rather
than from a hand-maintained constant.

The boot.img header sets `kernel_addr` to `0x00280000` — the
same address the linker script in `src/kernel.ld` pins as the
kernel's load address — so u-boot copies the kernel bytes into
the exact memory region they were linked against. The remaining
header fields (ramdisk, second-stage, tags, OS version, SHA-1
ID, command line) are zero-filled because phase 1's kernel has
none of them.

After writing, the function reads the first block of the boot
partition back and compares the eight-byte magic string against
`"ANDROID!"`. A mismatch fails loudly through the CDC-ACM
channel from 110.

What this issue deliberately does not yet do:

- *Parse the GPT to find the boot partition's location.* The
  partition LBA is hard-coded to a placeholder value
  (`0x4000`); the first hardware run will check whether that
  address actually lands in the boot partition. If not, the
  constant changes. Dynamic GPT parsing is a separate piece of
  work that can land later without changing the function's
  interface.
- *A/B slot management.* The eMMC writer overwrites the boot
  partition's current contents whatever they are. A/B safety
  is the design rule the safety doc proposes for routine
  flashing; phase 1's first eMMC overwrite is a one-shot bootstrap
  from "Anbernic Android on eMMC" to "SoreOS on eMMC," and the
  rollback path is the SD card with last-known-good SoreOS we
  always keep inserted during phase 1 testing.

The closing evidence on real hardware — a boot with no SD card
present that lights up `STAGE_KERNEL_MAIN` and then advances
through the rest of the kernel's signals — lands when we
actually trigger this function on the device. Until then, this
issue is "code complete, hardware-test pending" same as the rest
of phase 1 from 109a onward.

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
