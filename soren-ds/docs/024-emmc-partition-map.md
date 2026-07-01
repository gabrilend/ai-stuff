# Soren DS — stock eMMC partition map

The factory GPT partition layout of the internal 32 GB eMMC, read
off a real device. Confirmed against the full eMMC→SD dump (the
`emmc-dump` probe, issue 110m): the kernel copies the whole card
to the microSD's dump region, the lab-side `dump-from-sd` pulls
and gunzips it, and `gdisk -l` on the image walks the GPT. A
separate, de-selectable `emmc-backup` probe copies just the
16 MiB boot chain as a restore safety net (issue 110e); earlier
revisions of that gate blindly copied the first 200 MB instead.

This is the authoritative reference for any code that touches the
eMMC by partition — the boot-image writer (110b), the eventual
factory-restore tooling, and the USB-C re-flash path (110c). It
also confirms, finally, that the eMMC bring-up reads **genuine**
card content (a valid GPT with named Android partitions, the
`rockchip-rk817` PMIC driver, the Rockchip trust blob), not the
stale SD data the pre-fix runs produced.

## The layout

Disk: ~29.1 GiB usable (last usable sector 61071326), 512-byte
sectors. GPT, protective MBR. Disk GUID
`F808D051-1602-4DCD-9452-F9637FEFC49A` (this unit; will differ
per device).

| # | Name | Start LBA | End LBA | Size | Role |
|---|------|-----------|---------|------|------|
| 1 | security | 8192 | 16383 | 4 MiB | secure-boot data |
| 2 | uboot | 16384 | 24575 | 4 MiB | u-boot proper |
| 3 | trust | 24576 | 32767 | 4 MiB | ARM trusted firmware / OP-TEE |
| 4 | misc | 32768 | 40959 | 4 MiB | bootloader control block (boot/recovery select) |
| 5 | dtbo | 40960 | 49151 | 4 MiB | device-tree overlays |
| 6 | vbmeta | 49152 | 51199 | 1 MiB | Android Verified Boot metadata |
| 7 | boot | 51200 | 182271 | 64 MiB | kernel + ramdisk (Android boot.img) |
| 8 | recovery | 182272 | 378879 | 96 MiB | recovery ramdisk |
| 9 | backup | 378880 | 1165311 | 384 MiB | vendor backup area |
| 10 | cache | 1165312 | 1951743 | 384 MiB | Android cache |
| 11 | metadata | 1951744 | 2082815 | 64 MiB | encryption metadata |
| 12 | frp | 2082816 | 2083839 | 512 KiB | factory reset protection |
| 13 | baseparameter | 2083840 | 2085887 | 1 MiB | display/board base parameters |
| 14 | super | 2085888 | 14832639 | 6.1 GiB | dynamic partition (system / vendor / product) |
| 15 | userdata | 14832640 | 61071295 | 22 GiB | user data |

The Rockchip pre-GPT loader blobs (idbloader / miniloader) live
below the first partition, at the BootROM's fixed sector offsets
(idbloader at sector 64, u-boot/trust FIT around sector 24576 via
the `uboot`/`trust` partitions). The GPT primary header is at LBA
1; its entries span LBA 2-33.

## What the 16 MiB boot-chain backup captures

16 MiB = 32,768 sectors covers LBA 0 through 32,767 — the GPT
plus **partitions 1 through 3** (security, uboot, trust), ending
exactly where `misc` begins (LBA 32768). That is the raw Rockchip
boot chain the BootROM and u-boot load — the idbloader (sector
64), u-boot, and the ARM trusted-firmware / OP-TEE blob — enough
to bring the device back to a working **bootloader**. It stops
short of the Android `misc` / `boot` / `recovery` partitions on
purpose; the older blind 200 MB copy (partitions 1-8, through
recovery) was trimmed to just this once the layout was known.

## What a full factory-restore backup needs

"Restore to factory default" needs the factory software, which is
the boot chain (have it) plus **`super`** (the 6.1 GiB OS). It
does **not** need `userdata` (22 GiB) — that is user state, wiped
on a factory reset anyway.

So a complete restore image is partitions 1-14, ending at LBA
14832639 ≈ **7.1 GiB**. Practical considerations:

- At the current legacy 1-bit / 24 MHz PIO rate (~3 MB/s) that is
  ~40 minutes. Tolerable as a one-time job, but the obvious
  motivation for the high-speed eMMC path (8-bit bus + HS200 +
  DMA), which would bring it to a few minutes.
- The restore direction (writing these partitions back) goes
  through `emmc_write_block`, which exists but has only ever been
  exercised against the boot-partition writer (110b). A restore
  tool is its own issue.

## Related documents

- `docs/018-emmc-host-controller.md` — how the eMMC controller is
  brought up to read these sectors.
- `docs/014-hardware-overview.md` — the eMMC at the board level.
- `issues/110e-emmc-layout-probe.md` — the issue this map closes.
- `issues/110b-bootable-emmc-overwrite.md` — the writer that now
  knows the real `uboot` / `boot` partition LBAs.
