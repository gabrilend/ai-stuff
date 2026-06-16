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
