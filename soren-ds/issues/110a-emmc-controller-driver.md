# 110a — eMMC controller driver

## Current behavior

`src/012-emmc.c` brings up the RK3568's dedicated SDHCI
controller and walks the eMMC card through the JEDEC
identification sequence. The controller is software-reset
through its reset register, powered at 3.3 V, its internal
clock divider set for a ~400 kHz identification rate. CMD0
puts the card into idle state; CMD1 polls for operating-
condition readiness; CMD2, CMD3, CMD9, and CMD7 carry the card
through identifying itself, accepting a relative address of 1,
reporting its capacity descriptor, and selecting itself into
transfer state. After identification, the clock bumps to a
compatibility-mode transfer rate (~25 MHz from the controller's
typical 200 MHz input).

Two block-IO operations are exposed: `emmc_read_block` and
`emmc_write_block`. Each takes a 32-bit logical block address
(eMMC uses block addressing — addresses are sectors, not bytes)
and a 512-byte buffer. The implementation programs the
controller's block size and block count, sets the transfer
direction in the transfer-mode register, issues the matching
command (CMD17 for single-block read, CMD24 for single-block
write), waits on the present-state buffer-ready bit, and
streams 128 32-bit words through the data port. The function
returns when the controller signals transfer-complete or when
an error or timeout fires.

The driver is polled and blocking — no DMA, no interrupts. Each
public call is one transaction; the function does not return
until the transaction completes or fails. The CDC-ACM debug
stream from 110 narrates each step of bring-up so a failure
mid-sequence is visible to a developer with a host computer
attached.

The closing evidence on real hardware — successful round-trip
of a known pattern to a safe block, narrated through CDC-ACM —
has not yet been observed because we have not booted from the
device. That validation lands when 110b lights up. If the
round-trip fails, the SDHCI controller's Rockchip-specific
quirks (a small set of vendor extensions to the base SDHCI
register surface) and the controller's input-clock rate are
the first places to look.

## Reopened — CRU clock and reset setup missing, plus dwcmshc vendor-area writes

Phase-1 hardware testing surfaced two related problems the
original implementation did not address. Symptom on hardware:
the eMMC controller bring-up panics intermittently at the
very first MMIO access — sometimes succeeds, sometimes fails.
The intermittency is real and has a specific cause.

**The controller depends on five clocks and five resets.** The
driver currently assumes the bootloader has enabled all of
them. ROCKNIX's u-boot reads the kernel image from the SD
card, not the eMMC, so it leaves the eMMC controller in an
indeterminate state at hand-off — some clocks on, some off;
some resets deasserted, others not. The first MMIO access
then either reads back `0x00000000` (block reset still
asserted), reads `0xFFFFFFFF` (AHB clock gated), or stalls
the bus enough to trigger an exception the bootloader catches
and resets us on. Each fresh power-on can land any of those.

**The Rockchip vendor-area register set holds u-boot's
residual DLL configuration.** Without three specific clearing
writes, subsequent commands can be silently rejected for
reasons that look like generic timeouts but are actually the
command-conflict-check logic firing on stale state.

### Fix piece one — CRU clock-and-reset bring-up

Before any MMIO write to the controller at `0xFE31_0000`,
ungate the five clocks and pulse the five resets. Both live
in the main CRU at `0xFDD2_0000`; the relevant registers
are `CLKGATE_CON(9)` at offset `0x324` (bits 5-9 for
ACLK / HCLK / BCLK / CCLK / TCLK) and `SOFTRST_CON(7)` at
offset `0x41C` (same bit positions for the corresponding
soft-resets). Write-mask convention applies — upper 16 bits
mask, lower 16 bits value. Four writes:

```
mmio_write32(0xFDD20324u, 0x03E00000u);  /* ungate ACLK/HCLK/BCLK/CCLK/TCLK */
mmio_write32(0xFDD2041Cu, 0x03E003E0u);  /* assert all 5 eMMC resets */
rough_delay(1000);                       /* a few microseconds */
mmio_write32(0xFDD2041Cu, 0x03E00000u);  /* deassert all 5 eMMC resets */
```

The **BCLK reset (bit 7) is the most commonly missed one**.
Deasserting only the AHB and CCLK resets is enough to make
register reads succeed but leaves writes silently dropping.
Deassert all five together.

### Fix piece two — diagnostic discriminator

Before the SDHCI software reset, read `SDHCI_CAPABILITIES` at
`0xFE31_0040` (4-byte read). Three possible reads tell us
where we are:

- *Non-zero*. Controller is reachable. Bus-level setup
  worked. Proceed.
- *`0x00000000`*. BCLK (block) reset is still asserted —
  `SOFTRST_CON(7)` bit 7 needs clearing. Bring-up step
  panics.
- *`0xFFFFFFFF`*. AHB (HCLK) clock is gated —
  `CLKGATE_CON(9)` bit 6 needs clearing. Bring-up step
  panics.

This discriminator is cheap (one read), tells us whether the
fix piece one writes actually landed, and gives the developer
a concrete LED-codable failure indication on a regression.

### Fix piece three — dwcmshc vendor-area writes plus a full SDHCI reset

The Rockchip vendor-area registers live at SDHCI base + `0x500`
(the offset is encoded in `SDHCI_P_VENDOR_AREA1` at `0xE8`,
low 12 bits, but on RK3568 it resolves to `0x500`). Three
writes clear u-boot's residual state:

```
mmio_write32(0xFE310500u + 0x08u, 0u);  /* DWCMSHC_HOST_CTRL3 — disable cmd-conflict-check */
mmio_write32(0xFE310808u, 0u);          /* DWCMSHC_EMMC_DLL_TXCLK — clear */
mmio_write32(0xFE31080Cu, 0u);          /* DWCMSHC_EMMC_DLL_STRBIN — clear */
```

Then a full SDHCI software reset: write `0x01` (the
`SDHCI_RESET_ALL` bit in `SDHCI_SOFTWARE_RESET`) to the
single byte at `0xFE31_002F`, then poll the same byte until
it reads zero. Linux uses a 10-second timeout for this poll;
something in the same ballpark is fine.

After that, the original driver's standard SDHCI bring-up
(clear `SDHCI_INT_STATUS`, set `SDHCI_TIMEOUT_CONTROL` to
`0x0E`, set `SDHCI_HOST_CONTROL` to `0`, enable internal
clock through `SDHCI_CLOCK_CONTROL` and wait for the
clock-stable bit, set `SDHCI_POWER_CONTROL` to `0x0B` for
1.8 V eMMC operation, issue CMD0) continues as before.

### Fix piece four — polling-loop error checks

The current driver's command-completion poll watches for
`SDHCI_INT_STATUS` bit 0 (CMD_COMPLETE) and returns on that
bit firing. It does not check the command-level error bits:
bits 16-19 are CMD_TIMEOUT, CRC, END_BIT, INDEX errors
respectively. The polling loop should treat any of those as
a failure return rather than waiting indefinitely for the
success bit that will never come if an error fires instead.
Upstream Linux uses a 100 ms timeout for command completion
at init time.

### Diagnostic Note — DWCMSHC_EMMC_DLL_CTRL is for HS200/HS400, not bring-up

`DWCMSHC_EMMC_DLL_CTRL` lives at offset `0x800` from the SDHCI
base (so `0xFE31_0800`). Writing bit 0 = 1 to it issues a DLL
reset. *Do not write this register during CMD0-era bring-up* —
the DLL only matters at card clocks above 50 MHz (HS200 / HS400),
neither of which phase 1 reaches. Touching it during bring-up
can wedge the controller. Leave it alone until a later issue
specifically brings up high-speed modes.

## What this reopen does not do

The five-clock, five-reset bring-up plus the vendor-area
clears is the minimum the controller needs to respond to
register access. It is not a full re-implementation of the
upstream Linux driver. Topics explicitly out of scope here:

- HS200 / HS400 high-speed modes (need DLL bring-up at
  `DWCMSHC_EMMC_DLL_CTRL`, which must NOT be written during
  CMD0-era bring-up).
- Tuning.
- I/O voltage switching beyond what u-boot already set up at
  1.8 V via the PMIC.
- Hot-removal handling. eMMC is non-removable.

## Intended behavior

SoreOS brings up the SDHCI controller in a polled, blocking,
read-and-write-blocks-by-index mode. No interrupts, no DMA — both
are deferred to a later issue that justifies their complexity.
The driver exposes exactly two operations to the rest of the
kernel:

- *read block.* Inputs are an LBA block number and a buffer
  pointer. The function returns when the block has been read
  into the buffer or the controller has reported an error.
- *write block.* Inputs are an LBA block number and a buffer
  pointer. The function returns when the block has been
  acknowledged by the eMMC as written or the controller has
  reported an error.

Block size is the eMMC's native sector size, which on every
modern part is 512 bytes. The driver does not buffer, does not
cache, does not retry. Each call is one transaction.

The driver's bring-up sequence is the standard one for the JEDEC
eMMC card-initialization protocol on top of Rockchip's controller
register surface: bring the controller out of reset, set the
clock to a safe low rate, issue the protocol's identification
commands (CMD0 reset, CMD1 send-op-cond, CMD2 all-send-cid, CMD3
set-relative-address, CMD9 send-csd, CMD7 select-card), switch
the card into high-speed transfer state, and from there issue
CMD17/CMD24 (single-block read/write) for each operation. The
exact controller register offsets and the bit positions of the
controller's status and command registers come from the RK3568
TRM (`docs/014-hardware-overview.md` identifies the datasheet).

Bring-up status is reported through the CDC-ACM debug stream
(110) at each step: "SDHCI controller out of reset," "card
identified, manufacturer ID = N, capacity = N MB," "transfer
state entered." Failures emit a short reason and the LED falls
into the diagnostic code from 106 for the failure class.

## What is deliberately not in scope here

Wear-leveling, bad-block remapping, partitioning, filesystem
formatting, and anything resembling a transaction log. SDMMC2
for WiFi SDIO and SDMMC0 for the external microSD are bring-up
jobs for later phases (phase 4 in the case of microSD, phase 7
in the case of WiFi) and use entirely different RK3568
controllers — they share none of the SDHCI register layout this
issue brings up. The block driver here is the minimum that 110b
needs to write its payload.

## Suggested implementation steps

1. From the RK3568 datasheet, write down the SDHCI register
   block base address, the bit fields for clock control, command
   issue, status, and the block-data FIFO or DMA descriptor
   layout.
2. Write the controller-out-of-reset and clock-enable sequence
   against those registers.
3. Implement the JEDEC eMMC initialization command sequence
   (CMD0 through CMD7) and confirm the card responds with a
   plausible CID (manufacturer ID is a one-byte field; common
   values are 0x11 Toshiba, 0x15 Samsung, 0x70 Kingston).
4. Implement single-block read and single-block write.
5. Verify with a round-trip test: write a known pattern to a
   block in a safe region (chosen by inspecting the partition
   layout via the device tree — never overwrite the loader, the
   miniloader, u-boot, or u-boot's environment), read it back,
   compare. Report through CDC-ACM and through LED on success
   and failure.

## Related documents

- `docs/014-hardware-overview.md` — eMMC physical layer, the
  Rockchip controller, the safe regions the round-trip test
  may touch.
- `notes/safety/000-bricking-and-recovery.md` — scenario S1
  (power loss during flash) sets the design rules this driver
  must follow when 110b builds on top of it; scenario S12 (eMMC
  wear) explains why we avoid frivolous writes.

## Blocked by

108 (page allocator — the block buffers come from it), 110
(CDC-ACM debug — diagnostic output during bring-up).

## Blocks

110b (eMMC overwrite needs working block reads and writes),
indirectly every later phase that wants persistent storage on
the internal eMMC.
