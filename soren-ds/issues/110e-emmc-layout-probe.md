# 110e — eMMC layout probe (via microSD dump)

> **RESOLVED.** With the eMMC bring-up working (110a), the
> kernel copied the first 200 MB of the eMMC to the microSD,
> `dump-from-sd` pulled it, and `gdisk -l` walked a valid GPT.
> The full factory layout is recorded in
> `docs/024-emmc-partition-map.md`. **Critical correction it
> surfaced:** 110b's hard-coded boot-partition LBA `0x4000`
> (16384) is actually the **`uboot`** partition — writing a
> kernel there would corrupt u-boot. The real `boot` partition
> starts at **LBA 51200** (64 MiB, partition 7); `recovery` is at
> LBA 182272. 110b must be corrected to target LBA 51200 before
> it is ever enabled. The dump also confirmed the eMMC reads
> genuine content (named Android partitions, the Rockchip trust
> blob) rather than the stale SD data the pre-fix runs produced.
>
> **Since resolved:** the ongoing boot-chain safety copy was
> retargeted from that blind 200 MB front-of-card dump to a
> 16 MiB targeted copy (GPT + uboot + trust, eMMC LBA 0..32767)
> and moved out of the boot flow into the de-selectable
> `emmc-backup` probe (`backup_boot` → `emmc_backup_to_sd(0,
> 0x200000, 32768)`); whole-layout capture is now the `emmc-dump`
> probe (110m). `docs/024` and `dump-from-sd`'s `BACKUP_SECTORS`
> follow the 16 MiB size.

## Current behavior

The eMMC writer in 110b assumes the boot partition lives at LBA
`0x4000` — a hard-coded value picked because it is a typical
Rockchip Android offset. We do not actually know whether this
address lands in the boot partition on Anbernic's specific
layout. If the assumption is wrong and the address lands in
u-boot's region or the loader area, the writer corrupts the
bootloader chain and the device fails to boot from eMMC at all.

A previous version of this issue dumped eMMC sectors out through
the CDC-ACM debug channel and asked the developer to capture the
text on a USB-connected host. The threat model the project
committed to during issue 101 — Anbernic the company we trust,
but the import path the device travelled through we do not —
rules that out: until the eMMC has been completely overwritten
with our own code, we do not plug the device into anything
holding data we care about over USB-C. The dump cannot leave the
device through USB-C.

The dump cannot stay on the eMMC either; the bytes we are trying
to read are in danger of being overwritten by the very write we
are trying to make safe.

The remaining surface is the external microSD card the device is
already booting from. We write the dump there and pull the card
out. That requires the microSD driver from 110f to exist before
this issue can run on real hardware. (The CDC-ACM dump from the
previous version of this issue is preserved in
`src/014-emmc-probe.c` for use after the eMMC has been
overwritten and USB-C is trusted, but it is no longer the
mechanism this issue's success depends on.)

## Intended behavior

`kernel_main` automatically, after a successful boot:

1. Brings up the eMMC controller (110a).
2. Brings up the microSD controller (110f).
3. Reads the first 200 MB of the eMMC, sector by sector, and
   writes those sectors out to a reserved region of the
   microSD card.
4. Narrates progress through CDC-ACM (text only, not the dump
   itself — small enough that observing it on a sacrificial host
   is acceptable; the bulk binary dump never goes over USB-C).
5. Lights an LED stage signalling "dump complete; safe to power
   off and pull the card."

The reserved region on the microSD card sits at a high LBA
(somewhere past where Rockchip's BootROM looks for the loader,
typically LBA 0x40 through 0x100000 — pick something past that,
maybe LBA 0x200000, well above any region the BootROM cares
about). The dump occupies the next 200 MB / 4 KB blocks = ~50000
blocks from that base.

After this issue closes:

1. Boot the device from microSD with the kernel that has 110e
   wired into it.
2. Wait for the LED stage that says "dump complete."
3. Power off the device, pull the microSD card.
4. On the lab laptop, with auto-mount disabled, raw-`dd` the
   microSD's reserved region into a binary file. No mount, no
   execution.
5. Analyze the binary file with standard host tools — `gdisk
   -l` against the LBA 1 GPT, `xxd` for general byte inspection,
   a small parser script if helpful.
6. Update `BOOT_PARTITION_LBA` in `013-boot-image.c` to the
   verified value.

Only then is 110b's writer safe to invoke on real hardware.

## Why we dump 200 MB rather than just the partition table

The partition table itself is in the first ~17 KB of the eMMC
(GPT header at LBA 1, partition entries at LBAs 2-33). But we
also want to capture the u-boot bytes and the bootloader chain
that precede the boot partition, so a future analysis can
confirm those bytes look like a known-good u-boot and that
nothing visibly tampered-with sits between the loader and our
target partition. 200 MB covers everything below typical
Android-layout boot partitions and gives the host analysis
room to look beyond just "where is the GPT entry."

## Safety guarantees during the dump

The dump only reads from eMMC and writes to microSD. No eMMC
writes happen during this phase. The kernel is fully in control
of both controllers; nothing the device's prior firmware did
can interfere with what we read or what we write to the SD card.

The microSD card itself has been in contact with the
potentially-compromised device, so the bytes on the card after
the dump are bytes we wrote. The lab laptop's first contact
with that microSD card uses `dd` against the raw block device
and never mounts the filesystem, so even if hostile firmware
managed to write something malformed onto the card's filesystem
metadata regions, the lab laptop never feeds those bytes to a
filesystem driver — they are just bytes in a binary file.

## Suggested implementation steps

1. Implement 110f first.
2. Write `src/015-emmc-backup-to-sd.c`. It exposes one function:
   `void emmc_backup_to_sd(uint32_t emmc_start_lba,
   uint32_t sd_start_lba, uint32_t sector_count)`.
3. The function loops sector by sector: `emmc_read_block` from
   the eMMC source into a 512-byte buffer, `sd_write_block` from
   the buffer to the SD destination. Narrates every ~1000
   sectors through CDC-ACM so progress is visible.
4. `kernel_main` calls this after USB enumeration completes,
   passing `(0, 0x200000, 409600)` — 200 MB of eMMC starting at
   LBA 0, written to microSD starting at LBA 0x200000.
5. After the function returns, advance the LED stage to a new
   `STAGE_BACKUP_COMPLETE` pattern so the developer knows to
   power off and pull the card.

## Closing condition

The first hardware run produces a microSD card with the dump on
it. The dump is `dd`-copied off the card on the lab laptop.
Host-side analysis finds the boot partition's real LBA.
`BOOT_PARTITION_LBA` in `013-boot-image.c` is updated to that
LBA. Commit. Issue closed.

## Related documents

- `notes/safety/000-bricking-and-recovery.md` — why this gate
  matters and what happens if we skip it.

## Blocked by

110a (eMMC reads), 110f (microSD writes), 110 (CDC-ACM for
narration).

## Blocks

The next safe use of 110b's writer on real hardware.
