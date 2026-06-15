# 110a — eMMC controller driver

## Current behavior

The internal 32 GB eMMC is the storage device the stock Android
install lives on and the storage device our SoreOS install will
eventually live on. The Rockchip RK3568 talks to it through its
dedicated SDHCI host (separate from the SDMMC0/1/2 controllers,
which handle external SD, secondary slots, and SDIO peripherals
like the WiFi module). The eMMC is wired as an 8-bit bus
running up to 200 MHz with the `non-removable` property set —
the kernel does not poll it for hot-swap. Today, with SoreOS
booted from the external microSD, the eMMC is sitting there
powered but ignored. SoreOS cannot read a block from it, cannot
write a block to it, and therefore cannot make any progress
toward the eMMC-resident install that issue 110b wants to
produce.

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
