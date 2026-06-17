# 110f — microSD controller driver

## Current behavior

`src/015-sdmmc.c` brings up the SDMMC0 controller — Synopsys
DW MSHC, distinct in IP from the SDHCI we drive the eMMC with.
The controller is software-reset through its CTRL register,
powered through its PWREN register, has its clock divider set
for an identification-rate ~400 kHz and then bumped to
transfer-rate after card-init completes. Interrupts are masked
in INTMASK; the driver polls RINTSTS for command-done,
data-over, and error bits.

The SD card walks through the standard SD-spec init sequence:
CMD0, CMD8 to confirm 2.0+ support, ACMD41 in a loop (wrapped in
CMD55) until the card reports ready, CMD2 to retrieve CID, CMD3
to receive the card-published RCA, CMD9 for capacity descriptor,
CMD7 to select the card into transfer state. The sequence
differs from the eMMC sequence in the three places the issue
called out (CMD8, ACMD41/CMD55, host-receives-RCA-vs-host-
assigns-RCA).

Two block-IO operations are exposed: `sd_read_block` (CMD17
single-block read) and `sd_write_block` (CMD24 single-block
write). Each polls the controller's FIFO at offset `0x200`,
draining 128 32-bit words for reads or filling them for writes,
and waits for DATA_OVER to confirm transfer completion. Errors
roll up into a return value the caller can act on.

`kernel_main` now calls `sd_init` after `emmc_init`, followed by
`emmc_backup_to_sd(0, 0x200000, 409600)` — 200 MB of eMMC
content written to the microSD card starting at LBA `0x200000`
(~1 GB offset, well above any region the Rockchip BootROM cares
about). The LED stage advances to `STAGE_BACKUP_COMPLETE` (all
three LEDs solid) when the backup finishes. The diagnostic-
codes table is updated to match.

The closing evidence on real hardware — the backup running to
completion on the device and a `dd`-readable dump on the
pulled microSD card — has not yet been observed because we
have not booted from the device. That validation lands when the
first boot test runs. If the backup hangs or the SD card has
no dump, the bug is in the DW MSHC register access or the SD
init-sequence ordering; both reopen this issue with the
specific failure mode.

## Reopened — CRU clock and reset setup missing, plus polling-loop and clock-update fixes

Phase-1 hardware testing surfaced multiple problems the
original implementation did not address. Symptom on
hardware: the SD bring-up panics at the very first MMIO
access *every time*, in contrast to the eMMC bring-up
(which is intermittently OK because u-boot uses the eMMC
to load the kernel and leaves its clocks on). The SD
controller is *untouched by u-boot* — it boots from the
SD card's bootable region via the BootROM and the
idbloader, not through the SDMMC0 controller at all — so
the controller arrives at our kernel with its clocks
gated and its resets asserted, the same way it left the
chip reset state. The driver's first MMIO access either
reads back `0x00000000` (block reset asserted),
`0xFFFFFFFF` (AHB clock gated), or stalls the bus enough
to trigger an exception the bootloader catches and resets
us on.

Two driver-side issues also need fixing — a missing error-
bit check in the command-completion poll, and a missing
"update clock" command sandwich around every clock change.
Both are subtle but bite in specific failure modes.

### Fix piece one — CRU clock-and-reset bring-up

Before any MMIO write to the controller at `0xFE2B_0000`,
ungate the two clocks and pulse the two resets. Both live
in the main CRU at `0xFDD2_0000`; the relevant registers
are `CLKGATE_CON(15)` at offset `0x33C` (bits 0-1 for
HCLK_SDMMC0 / CLK_SDMMC0) and `SOFTRST_CON(13)` at offset
`0x434` (bits 3-4 for SRST_H_SDMMC0 / SRST_SDMMC0). Four
writes:

```
mmio_write32(0xFDD2033Cu, 0x00030000u);  /* ungate HCLK_SDMMC0 / CLK_SDMMC0 */
mmio_write32(0xFDD20434u, 0x00180018u);  /* assert SRST_H_SDMMC0 / SRST_SDMMC0 */
rough_delay(1000);
mmio_write32(0xFDD20434u, 0x00180000u);  /* deassert both resets */
```

Unlike the eMMC, both resets are essential here — u-boot
doesn't pulse either of them. The SDMMC0_DRV / SDMMC0_SAMPLE
clocks are phase shifters, not gates; they sit on top of
CLK_SDMMC0 and are only programmed during tuning. Bring-up
does not need them.

### Fix piece two — diagnostic discriminator

Before issuing the controller reset, read `SDMMC_HCON` at
`0xFE2B_0070` (4-byte read). Three possible reads tell us
where we are:

- *Roughly `0x0003_E47A`*. Controller is reachable. Bus-level
  setup worked. Proceed.
- *`0x00000000`*. SD0 reset is still asserted —
  `SOFTRST_CON(13)` bit 3 or 4 needs clearing. Bring-up step
  panics.
- *`0xFFFFFFFF`*. AHB (HCLK) clock is gated —
  `CLKGATE_CON(15)` bit 0 needs clearing. Bring-up step
  panics.

### Fix piece three — controller-reset and the RINTSTS clear

The first writes after the CRU setup land at the controller
itself. The original driver's first write was the controller
reset (`CTRL` register at offset `0x00`, write
`CTRL_RESET | FIFO_RESET | DMA_RESET = 0x07`, poll for the
bits to clear). That is correct. But the *next* write must
clear `RINTSTS` (the raw-interrupt-status register) at offset
`0x44` with `0xFFFFFFFF`, before any later code reads
`RINTSTS` to check for CMD_DONE. The DW MSHC's `RINTSTS` bits
*survive controller reset* — if any bits were set from
before (likely after a SoC reset where the controller block
keeps its RINTSTS state), the CMD_DONE poll fires immediately
on a stale bit and the driver thinks the very first command
succeeded when the controller has not even seen it yet.

After the RINTSTS clear, the rest of the first-writes
sequence:

```
mmio_write32(0xFE2B0024u, 0u);            /* INTMASK = 0 (mask all) */
mmio_write32(0xFE2B0014u, 0xFFFFFFFFu);   /* TMOUT — max response/data timeout */
mmio_write32(0xFE2B004Cu, 0x207F0080u);   /* FIFOTH — watermark for fifo-depth 256 */
mmio_write32(0xFE2B0010u, 0u);            /* CLKENA = 0 before any clock change */
mmio_write32(0xFE2B000Cu, 0u);            /* CLKSRC = 0 */
mmio_write32(0xFE2B0004u, 1u);            /* PWREN = 1 */
```

The `FIFOTH` value comes from upstream Linux's FIFO setup
for the rk3568 case — fifo-depth shown by the chip is
`0x100`, watermark threshold is `fifo-depth/2 - 1 = 0x7F`
for receive, `fifo-depth/2 = 0x80` for transmit, with
multiple-transaction-size 2 = 0x2 in bits 28-30. Combined
value `0x207F_0080`.

### Fix piece four — the "update clock" dance around every clock change

Every clock change on the DW MSHC requires a sandwich of
"update clock" no-op commands. Without them, the CLKENA /
CLKDIV / CLKSRC writes do not take effect and subsequent
CMD0 hangs forever — the controller silently rejects every
later command because the previous one is "still in flight."

The dance is: write CMD register at offset `0x2C` with the
no-op encoding, then poll bit 31 (`START_CMD`) until it
clears. The no-op encoding is:

```
CMD register value = (1 << 31)   /* START_CMD */
                   | (1 << 29)   /* USE_HOLD_REG */
                   | (1 << 21)   /* UPDATE_CLK_ONLY */
                   | (1 << 13)   /* PRV_DAT_WAIT */
                   = 0xA0202000
```

A full clock-change sequence:

```
mmio_write32(0xFE2B0010u, 0u);            /* CLKENA off */
issue_update_clock_no_op();
mmio_write32(0xFE2B0008u, divider);       /* CLKDIV */
mmio_write32(0xFE2B000Cu, source);        /* CLKSRC */
issue_update_clock_no_op();
mmio_write32(0xFE2B0010u, 1u);            /* CLKENA on */
issue_update_clock_no_op();
```

The original driver writes CLKDIV and CLKENA but does not
issue the update-clock no-ops. That is the most common
"card never responds" bug in DW MSHC bring-up code.

### Fix piece five — polling-loop error checks

The current driver's command-completion poll watches for
`RINTSTS` bit 2 (CMD_DONE) and returns on it. That's not
enough. The polling loop also needs to check:

- *Bit 1 (RE — Response Error)*. Card returned a malformed
  response.
- *Bit 6 (RCRC — Response CRC Error)*. Response failed CRC.
  Card present but unhappy.
- *Bit 8 (RTO — Response Timeout)*. The *expected* indicator
  for a missing card. Not a wedged-controller indicator.
- *Bit 12 (HLE — Hardware Locked Error)*. **This one means
  the controller is wedged**: the host tried to write the
  CMD register while a previous command was still in flight.
  Almost always means the update-clock dance was skipped
  somewhere. If HLE fires, the controller needs a full
  CTRL_RESET to recover.

A 500 ms wall-clock timeout wrapping the whole poll catches
a wedged controller before the kernel watchdog does.

Also useful for diagnostics: `STATUS` register at offset
`0x48`. Bit 9 (`data_busy`) and bit 10 (`data_state_mc_busy`)
both stuck high after reset indicates the BIU clock is
gated.

### Note on the divider math

The DW MSHC controller's CCLK source has a fixed extra `/2`
divider built into the IP, plus the divider you program into
`CLKDIV` at offset `0x08`. The effective card clock is
`source_clock / (2 * (CLKDIV + 1))` if CLKDIV is non-zero,
or `source_clock / 1` if CLKDIV is zero (pass-through). So
to target the SD identification rate of 400 kHz, the source
clock must already be 800 kHz (or the closest divisible
value); CLKDIV=0 then yields 400 kHz at the card. If the
source clock is at a higher rate, set CLKDIV accordingly.

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
