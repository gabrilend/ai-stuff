# 103b — Bootable SD card image assembly

## Current behavior

Two scripts work together to produce a Rockchip-bootable SD
card image.

`scripts/extract-sd-image-parts` runs once. It downloads a
pinned ROCKNIX nightly into the project's RAM-backed `tmp/`
directory, verifies its upstream-published SHA-256 against
a constant baked into the script, decompresses the
`.img.gz`, prints the partition layout, and carves three
durable blobs into `libs/sd-image-parts/` with a `.sha256`
sibling next to each: the idbloader (sector 64 of the
ROCKNIX image, 8 MiB padded slot), the u-boot FIT (sector
16384, 8 MiB padded slot), and the RG DS device tree blob
(copied out of partition 1's FAT32 filesystem with
`mcopy`). After this runs the ROCKNIX image is no longer
needed; the three blobs are the durable inputs to every
subsequent build. The pinned date and SHA-256 are
top-of-file constants — upgrading is an explicit
re-run-with-new-pin event.

`scripts/build-bootable-sd` runs on every build. It
verifies the kernel image and the three blobs (re-checks
each blob against its `.sha256`), allocates an empty 272
MiB image, writes an MBR partition table with one bootable
FAT32 LBA partition starting at sector 32768, splices the
idbloader at sector 64 and the u-boot FIT at sector 16384
into the unpartitioned pre-partition region, builds a 256
MiB FAT32 partition image in `tmp/` with `mkfs.fat` +
`mtools`, populates it with the kernel as `/KERNEL`, the
DTB as `/device_trees/rk3568-anbernic-rg-ds.dtb`, and a
minimal `extlinux.conf` pointing u-boot at both, then dd's
the partition into the output image at sector 32768. The
result lands at `output/bootable-sd.img`.

The downstream flash pipeline picked up the new artifact
with one change. `scripts/push-to-usb` rsync's the entire
`output/` directory onto the air-gap drive, so the new
file ships automatically alongside `kernel.img` and the
existing goodbye log. `scripts/lab-side/flash-sd` was
updated to look for `bootable-sd.img` specifically rather
than "any single `.img` in `output/`" — the previous
"exactly one .img" rule died now that two files share
that extension, and the kernel image alone is not a
Rockchip-bootable artifact.

The closing evidence on real hardware — the BootROM
loading the idbloader from sector 64, the miniloader
bringing up DRAM, u-boot reading `extlinux.conf` from the
FAT partition, and `booti` jumping into our kernel — lands
when we flash a card and power the device on for the
first time. Until then this issue is "code complete,
hardware-test pending" same as the rest of phase 1 from
110a onward.

## Why we needed this in the first place

The RK3568's BootROM expects a Rockchip idbloader at
sector 64 of the bootable medium, not a kernel image. The
idbloader is a Rockchip-format container (magic `RKNS` at
its first byte) holding the IDBlock that runs in the
chip's on-chip SRAM at boot, initializes the DRAM memory
controller (without which nothing else can run), and a
miniloader (the SPL) that loads the next stage. The next
stage is u-boot proper, conventionally written to sector
16384 (the 8 MiB mark) as a FIT image (`u-boot.itb`,
magic `d00dfeed`) that often bundles TF-A/BL31 alongside
the u-boot binary. u-boot then finally loads the kernel.

Without an idbloader at sector 64, the BootROM gives up
on the SD card and falls through to the eMMC — where it
finds Anbernic's Android boot chain, which is exactly
what the project's vision says never to run.

Crucially, the boot chain does **not** live inside named
partitions. The BootROM doesn't read a partition table;
it reads raw bytes from fixed sector offsets. The
partition table only describes where the operating
system's filesystems live, and the first partition
conventionally starts at sector 32768 (the 16 MiB mark),
leaving the sectors between the partition table and the
first partition free for the boot chain.

## Intended behavior

A new script `scripts/build-bootable-sd` assembles a complete
bootable SD card image at `output/bootable-sd.img` from the
kernel image plus pre-built Rockchip boot chain components.
The flash workflow (103a) is updated to write
`output/bootable-sd.img` instead of `output/kernel.img`.

Concretely:

- A one-shot bootstrap script reads a downloaded community
  image (ROCKNIX's release for the RG DS, primarily because
  their builds for this device are publicly available and
  known to boot). It extracts three blobs into
  `libs/sd-image-parts/`, with a SHA-256 stored alongside
  each: the idbloader (sector 64), the u-boot FIT (sector
  16384), and the RG DS device tree blob (from inside
  partition 1). After this runs once, the ROCKNIX image is
  no longer needed; the extracted blobs are the durable
  inputs.
- The assembler script assembles an MBR-partitioned image
  matching ROCKNIX's layout: the idbloader at sector 64,
  the u-boot FIT at sector 16384, both in the unpartitioned
  pre-partition region the BootROM reads by fixed offset.
  The image's first partition starts at sector 32768 and is
  FAT32 labelled `ROCKNIX` (the label ROCKNIX's u-boot
  scans for). It holds `output/kernel.img` as `/KERNEL`,
  the RG DS DTB as `/device_trees/rk3568-anbernic-rg-ds.dtb`,
  and an `/extlinux/extlinux.conf` that names both. ROCKNIX's
  u-boot reads that config and launches our kernel via
  `booti`.
- The kernel image needs a 64-byte ARM64 Linux Image header
  (issue 103c) so `booti` recognizes it. That is a
  build-system change, not part of this issue's assembler —
  the assembler treats `output/kernel.img` as an opaque blob
  with the header already in place.
- The output is written to `output/bootable-sd.img` — a single
  binary that 103a's `flash-sd` script can `dd` directly to the
  SD card.

After this issue closes:

- `./scripts/build-bootable-sd` produces `output/bootable-sd.img`.
- `./scripts/push-to-usb` ships that image (alongside the rest of
  the output tree) to the air-gap drive.
- On the lab laptop, `./scripts/flash-sd` writes
  `output/bootable-sd.img` to the SD card.
- The device boots from the SD card into our kernel.

## Why this script rather than a one-time manual extraction

The SD card is a development bootstrap. Its job is to launch
our kernel once, so the kernel can dump the eMMC and probe
the device. We iterate on the kernel and re-flash the SD
card many times during phase 1; a script captures the
assembly steps as code so each iteration is fast and the
same every time. Once we understand the eMMC layout from
the dumps the kernel produces, the eMMC overwrite work
(110b-family) takes over and the SD card becomes a
recovery medium rather than a daily driver.

## Trust posture on the borrowed binaries

The idbloader (which packages Rockchip's DRAM init code and a
miniloader together) comes from Rockchip's binary releases
(RKBin), distributed for free and used by every embedded Linux
project on the chip family. It is a well-understood opaque
blob. We treat it with the same trust posture as the chip
silicon itself: not vendor-of-the-device trust, but
foundry-of-the-silicon trust. It lives in the boot chain
because it has to; replacing it would mean writing our own
DRAM init from reverse-engineered or NDA-acquired
documentation, which is not in scope for this project.

The u-boot is ROCKNIX's build for the SD card's entire
lifetime (we trust their build process and the source they
built from). The SD card never carries Anbernic's u-boot —
that one is on the eMMC, where we will eventually overwrite
it directly with our own boot chain. SD and eMMC are
separate boot paths.

## Suggested implementation steps

1. Write `scripts/extract-sd-image-parts` — a one-shot bootstrap
   script that downloads a pinned ROCKNIX RG DS nightly into the
   project's RAM-backed `tmp/` directory, verifies its
   upstream-published SHA-256 against a constant baked into
   the script, decompresses the `.img.gz`, inspects its
   partition table, and extracts three blobs into
   `libs/sd-image-parts/` with a `.sha256` next to each: the
   idbloader (sector 64, padded 8 MiB slot), the u-boot FIT
   (sector 16384, padded 8 MiB slot), and the RG DS device
   tree blob (copied out of partition 1's FAT32 filesystem
   with `mcopy`). The pinned date and SHA-256 are top-of-file
   constants; upgrading is an explicit re-run-with-new-pin event.
2. Write `scripts/build-bootable-sd` (bash + dd + mtools). It
   assembles `output/bootable-sd.img` with an MBR partition
   table matching ROCKNIX's layout. The boot chain blobs go
   in the unpartitioned pre-partition region at their fixed
   offsets (idbloader at sector 64, u-boot.itb at sector
   16384). The first partition is FAT32 labelled `ROCKNIX`,
   holding `output/kernel.img` as `/KERNEL`, the RG DS DTB
   as `/device_trees/rk3568-anbernic-rg-ds.dtb`, and
   `/extlinux/extlinux.conf` with `LINUX /KERNEL`,
   `FDT /device_trees/rk3568-anbernic-rg-ds.dtb`, and an
   empty `APPEND` line.
3. Update `scripts/push-to-usb` to also ship the new
   `bootable-sd.img` artifact.
4. Update `scripts/lab-side/flash-sd` to look for
   `bootable-sd.img` rather than `kernel.img`, and write that
   image to the SD card.

## Related documents

- `docs/014-hardware-overview.md` — the boot chain stages this
  assembler produces.
- `notes/safety/000-bricking-and-recovery.md` — why the boot
  chain matters and what happens when it fails.

## Blocked by

103 (the build produces `kernel.img`), 103c (the kernel image
gains the ARM64 Linux Image header u-boot's `booti` requires).

## Blocks

Every hardware test from this point on, since without a
bootable SD image the kernel cannot be invoked from removable
storage.

## Parent

103.
