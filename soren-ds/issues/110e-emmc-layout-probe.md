# 110e — eMMC layout probe

## Current behavior

The eMMC writer in 110b assumes the boot partition lives at LBA
`0x4000` — a hard-coded value picked because it is a typical
Rockchip Android offset. We do not actually know whether this
address lands in the boot partition on Anbernic's specific
layout. If the assumption is wrong and the address lands in
u-boot's region or the loader area, the writer corrupts the
bootloader chain and the device fails to boot from eMMC at all.

We can recover from such a corruption by booting from SD — the
Rockchip BootROM tries SD first if a card is present. But this
relies on always having a known-good SD card available, and it
means the first hardware run of the writer is a one-strike
test.

Worse, we have no way today to verify the LBA *before* writing.
The eMMC controller from 110a can read blocks; CDC-ACM from 110
can stream text back to the host. What is missing is the code
to use those two capabilities together: read the eMMC's
partition-table sectors and dump them out so a host script can
parse the GPT and tell us where the boot partition actually
lives.

## Intended behavior

The kernel exposes — and `kernel_main` calls automatically after
the CDC-ACM channel is up — a function that dumps the first
~100 sectors of the eMMC through CDC-ACM as hex. The host
captures the dump, a small host-side script parses the GPT,
the developer reads off the boot partition's real LBA, and the
constant in `013-boot-image.c` gets updated to the correct
value.

The dump format is a hex byte stream broken into lines that a
host script can re-assemble. Each sector is preceded by a
sector marker line. Each row is sixteen hex bytes plus an ASCII
fallback. This is essentially `xxd` output transmitted over
serial.

After this issue closes, before any START-held flash trigger is
exercised on real hardware:

1. Boot from SD card.
2. Capture CDC-ACM output to a file.
3. Run a host script against the dump that finds the GPT
   header (signature `"EFI PART"` at LBA 1) and walks the
   partition entries to find the one named "boot."
4. Update `BOOT_PARTITION_LBA` in `013-boot-image.c`.
5. Then — and only then — the flash trigger is safe to use on
   real hardware.

## Why this is its own issue

The probe function is small (a few hundred lines of C, mostly
a hex-formatting helper). But splitting it out makes the
"do not flash until probe is done" gate explicit. As long as
this issue exists open or completed-but-LBA-not-yet-confirmed,
the project explicitly tracks that the eMMC writer's LBA is a
guess. When this issue closes with the LBA constant updated to
the real value, the writer becomes safe to invoke.

## Suggested implementation steps

1. Write `src/014-emmc-probe.c`. It exposes one function:
   `void emmc_dump_to_debug(uint32_t start_lba, uint32_t count)`.
2. The function loops over sectors. For each: read the sector
   into a 512-byte buffer through `emmc_read_block`, then
   format the buffer as hex through `debug_write`.
3. The hex-formatting helper converts each byte to two hex
   digits using a 16-character lookup table. Line layout per
   the `xxd` convention: 8-digit hex offset, two columns of
   eight bytes each, ASCII fallback at the right margin.
4. `kernel_main` calls `emmc_dump_to_debug(0, 100)` after the
   CDC-ACM channel is up (i.e. after the polling loop has
   processed at least one `SET_CONFIGURATION` from the host).
   For phase 1's simple flow, this can happen after a fixed
   delay or by polling a flag the polling loop sets.
5. Write a small host-side script under
   `scripts/parse-emmc-dump` that takes the captured serial
   text and prints out the partition layout.
6. Run on real hardware, get the dump, parse the GPT, update
   `BOOT_PARTITION_LBA` in `013-boot-image.c`, commit the
   update. Mark this issue complete at that point.

## Related documents

- `notes/safety/000-bricking-and-recovery.md` — why this gate
  matters and what happens if we skip it.

## Blocked by

110a, 110.

## Blocks

The next safe use of 110b's writer on real hardware, and
therefore the closing evidence on 109a / 109b / 109c / 110 /
110a / 110b / 110c (which all need a successful eMMC boot to
observe their claimed behavior).
