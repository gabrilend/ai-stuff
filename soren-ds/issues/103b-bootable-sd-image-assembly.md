# 103b — Bootable SD card image assembly

## Current behavior

`output/kernel.img` is the raw 64-bit ARM kernel binary the
build system produces — text + rodata + data, no header. The
air-gap flash workflow (103a) writes that binary directly to
the SD card with `dd`. Inserting the SD card into the device
does not boot the kernel.

The reason: the RK3568's BootROM expects an **IDBlock** at
sector 64 of the bootable medium, not a kernel image. The
IDBlock is small executable code that runs in the chip's
on-chip SRAM at boot, initializes the DRAM memory controller
(without which nothing else can run), then loads the next
stage (a miniloader, the SPL), which in turn loads u-boot,
which finally loads the kernel.

Without an IDBlock at sector 64, the BootROM gives up on the
SD card and falls through to the eMMC — where it finds
Anbernic's Android boot chain, which is exactly what the
project's vision says never to run.

## Intended behavior

A new script `scripts/build-bootable-sd` assembles a complete
bootable SD card image at `output/bootable-sd.img` from the
kernel image plus pre-built Rockchip boot chain components.
The flash workflow (103a) is updated to write
`output/bootable-sd.img` instead of `output/kernel.img`.

Concretely:

- The script reads a downloaded community image (ROCKNIX's
  release for the RG DS, primarily because their builds for
  this device are publicly available and known to boot). It
  extracts the IDBlock, the miniloader, and the u-boot binary
  from the right offsets.
- It also reads `output/kernel.img` and wraps it in the Android
  boot.img envelope u-boot expects (this matches the wrapping
  110b does for the eMMC write).
- It assembles a GPT-partitioned image with the same partition
  layout the community image uses (idbloader at sector 64,
  miniloader at the offset listed in the GPT for that partition,
  u-boot at its GPT offset, boot partition with our wrapped
  kernel).
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

A future iteration of the project will pull Anbernic's u-boot
out of the eMMC backup (once we have one) and substitute it
for the ROCKNIX u-boot we're using as a bootstrap. That swap
should be one constant change in the assembler script — not a
re-run of a manual workflow each time. A script captures the
assembly steps as code.

## Trust posture on the borrowed binaries

The IDBlock and miniloader come from Rockchip's binary releases
(RKBin), distributed for free and used by every embedded Linux
project on the chip family. They are well-understood opaque
blobs. We treat them with the same trust posture as the chip
silicon itself: not vendor-of-the-device trust, but
foundry-of-the-silicon trust. They live in the boot chain
because they have to; replacing them would mean writing our own
DRAM init from reverse-engineered or NDA-acquired
documentation, which is not in scope for this project.

The u-boot starts as ROCKNIX's build (we trust their build
process and the source they built from), and is replaced with
Anbernic's once we have a verified copy from the eMMC backup.

## Suggested implementation steps

1. Download a ROCKNIX RG DS release image to a host machine.
   Verify the download against ROCKNIX's published checksums.
2. With `gdisk -l` and `dd`, identify the offsets and sizes of
   the IDBlock, miniloader, and u-boot partitions in the ROCKNIX
   image. Write down what's at what offset.
3. Extract each of those three components into separate files
   in the project's `libs/sd-image-parts/` directory. Each gets
   a SHA-256 stored alongside it (similar to the cross-toolchain
   sources).
4. Write `scripts/build-bootable-sd` (probably bash + dd, or
   small C program if dd alone is awkward). It reads the three
   parts plus `output/kernel.img`, wraps the kernel in an
   Android boot.img header, assembles them into
   `output/bootable-sd.img` with a GPT that matches ROCKNIX's
   partition layout but with the boot partition pointing at our
   kernel.
5. Update `scripts/push-to-usb` to also ship the new
   `bootable-sd.img` artifact.
6. Update `scripts/lab-side/flash-sd` to look for
   `bootable-sd.img` rather than `kernel.img`, and write that
   image to the SD card.
7. After the first eMMC backup runs and we have Anbernic's
   u-boot bytes verified, swap that into the assembler in place
   of ROCKNIX's u-boot.

## Related documents

- `docs/014-hardware-overview.md` — the boot chain stages this
  assembler produces.
- `notes/safety/000-bricking-and-recovery.md` — why the boot
  chain matters and what happens when it fails.

## Blocked by

103 (the build produces `kernel.img` which this issue wraps
into a bootable image), 110b (the Android boot.img wrapping
this script reuses).

## Blocks

Every hardware test from this point on, since without a
bootable SD image the kernel cannot be invoked from removable
storage.

## Parent

103.
