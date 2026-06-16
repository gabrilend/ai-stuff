# 110f — microSD controller driver

## Current behavior

The external microSD card slot is wired to the RK3568's SDMMC0
controller — a Synopsys DesignWare Mobile Storage Host Controller
(DW MSHC), not the SDHCI host we already wrote a driver for in
110a. Different IP, different register set, different command-
issue and data-transfer model. The eMMC driver from 110a is not
reusable here.

The controller has been initialized by Anbernic's u-boot during
boot (u-boot reads the microSD to load SoreOS), but by the time
our kernel takes control we have no idea what state u-boot
left it in. Even if it is in a usable state, we have no code
that knows how to talk to it.

Without this driver, the kernel can read and write the internal
eMMC but cannot touch the external microSD card. Issue 110e's
SD-card-based eMMC-backup path is therefore blocked.

## Why we need this driver specifically

The threat model the project committed to during issue 101's
research requires us to overwrite the internal eMMC with our own
code before we trust the device with a USB-C connection to any
machine that holds anything of value. To overwrite the eMMC
safely we first need to confirm where the boot partition lives,
which means dumping the eMMC's first ~200 MB and parsing the
partition table.

The dump destination cannot be a USB-C connection (would
violate the trust posture) and cannot be the eMMC itself (would
not survive the boot we are trying to bootstrap). The only
remaining surface is the microSD card the device is already
booting from. We write the dump there, eject the SD card from
the device, and analyze it on a trusted machine via a raw `dd`
copy that never executes anything from the card.

That entire flow blocks on this driver existing.

## Intended behavior

SoreOS brings up the SDMMC0 controller in polled, blocking,
read-and-write-blocks-by-index mode — the same shape as 110a's
eMMC driver. The driver exposes exactly two operations:

- *read block.* Inputs are an LBA block number and a 512-byte
  buffer pointer. The function returns when the block has been
  read into the buffer or the controller has reported an error.
- *write block.* Inputs are an LBA block number and a 512-byte
  buffer pointer. The function returns when the block has been
  written and acknowledged or the controller has reported an
  error.

Block size is the SD spec's fixed 512 bytes. The driver does not
buffer, does not cache, does not retry. Each call is one
transaction.

The driver's bring-up sequence follows the SD card initialization
protocol — distinct from the eMMC protocol the SDHCI driver
implements:

1. Software-reset the DW MSHC controller through its reset
   register.
2. Set the internal clock divider for identification (~400 kHz).
3. Power-cycle the card slot via the controller's power-enable
   register.
4. Issue CMD0 (GO_IDLE_STATE).
5. Issue CMD8 to check 2.0+ spec compatibility (eMMC skipped
   this; SD requires it).
6. Loop ACMD41 (SD_SEND_OP_COND, an application command preceded
   by CMD55) until the card reports ready in its OCR response.
7. Issue CMD2 (ALL_SEND_CID) to retrieve the card's identifying
   info.
8. Issue CMD3 — for SD cards this is PUBLISH_RCA, where the
   *card* returns the relative address it has chosen (the
   opposite of eMMC's SET_RELATIVE_ADDR where we assign the
   address).
9. Issue CMD9 (SEND_CSD) for capacity information.
10. Issue CMD7 (SELECT_CARD) with the published RCA to put the
    card in transfer state.
11. Bump the clock to a transfer-mode rate.

After this sequence the kernel can issue CMD17 / CMD24 for
single-block read / write the same way the eMMC driver does.

## Why this is its own issue rather than an extension of 110a

The IP block is different. The register set is different. The
command-issue protocol is different (DW MSHC uses one register
for both command and data; SDHCI separates them). The
initialization sequence has different commands (SD's ACMD41 vs
eMMC's CMD1; SD's PUBLISH_RCA semantic vs eMMC's
SET_RELATIVE_ADDR). The transfer-mode mechanism is different
(DW MSHC uses a FIFO drained word by word; SDHCI uses a
buffer-data port).

Nothing in `src/012-emmc.c` translates. The DW MSHC driver is a
separate ~300-400 lines of file written from upstream Linux
references.

## Suggested implementation steps

1. Pull DW MSHC register layout from upstream Linux's
   `drivers/mmc/host/dw_mmc.c` and the Rockchip-specific
   adaptation in `dw_mmc-rockchip.c`. Note that the Rockchip
   variant may have a small wrapper around the standard DW MSHC
   register set; check what's required.
2. Bring the controller out of reset through its reset register.
3. Set clock divider for identification, power on the card slot,
   wait for the slot to come up.
4. Implement the SD card initialization sequence above. Differs
   from the eMMC sequence in 110a in three places: CMD8 instead
   of being skipped, ACMD41 instead of CMD1, RCA is reported by
   the card instead of assigned by us.
5. Implement single-block read and write using the controller's
   FIFO transfer mechanism. The FIFO is drained word-by-word for
   read and filled word-by-word for write — similar shape to
   SDHCI's buffer-data port but at a different register.
6. Bring-up status flows through the CDC-ACM debug stream from
   110.
7. Round-trip test: read a known block, write a different known
   block, read it back, confirm.

## What this is deliberately not

The eventual phase 4 work that wraps an FAT32 filesystem around
this driver (per `011-filesystem.md`) is separate. This is the
raw block driver. The filesystem layer comes later.

## Related documents

- `docs/014-hardware-overview.md` — confirms microSD lives on
  SDMMC0.
- `docs/016-physical-memory-map.md` — SDMMC0 register base
  (`0xFE2B_0000`).
- `notes/safety/000-bricking-and-recovery.md` — why writing to
  the microSD is the safest dump destination during phase 1
  bring-up.

## Blocked by

108 (page allocator for buffers), 110 (CDC-ACM for bring-up
narration).

## Blocks

110e (the eMMC-to-microSD backup that 110e's safety gate
depends on).
