---
name: HAL — SD card
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102a — HAL: SD card

ARM-assembly driver for the RG DS's microSD card slot. **The most
foundational HAL driver** — without it, the system cannot read its
own code, disk images, or user files from storage.

## current behavior

Linux's MMC/SD driver handles the SD card. On bare metal, there's
no Linux; we read the card directly.

## intended behavior

- Block-level read and write of the microSD card via the RK3568's
  on-board MMC/SD controller.
- API surface:
  - `sd_init` — initialize the controller, identify the card,
    determine capacity.
  - `sd_read_block(lba, buf)` — read one 512-byte block.
  - `sd_write_block(lba, buf)` — write one 512-byte block.
  - `sd_read_blocks(lba, count, buf)` — bulk read.
  - `sd_write_blocks(lba, count, buf)` — bulk write.
- DMA support if the controller exposes it (RK3568 typically does;
  confirm during implementation).
- The driver does not interpret filesystem contents — that's the
  layer above (the eventual native File Manager, issue 1104k's
  Standard File alongside the broker filesystem).

## suggested implementation steps

1. Read Linux's `drivers/mmc/host/sdhci-of-arasan.c` (or whichever
   driver the RK3568 uses) for the register layout and
   initialization sequence.
2. Document the register map in
   `docs/research/rgds-hardware/sd-card.md`.
3. Implement `sd_init` — clock setup, voltage selection, card
   identification.
4. Implement block read.
5. Implement block write.
6. Add DMA support.
7. Test against the inserted microSD: read block 0 (MBR), parse,
   verify against known content.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/1101-bare-metal-boot.md` — needs SD card driver early
  for booting

## notes

- The SD card driver gates everything else in phase 11. Tackle it
  first.
- Bare-metal SD writes don't have Linux's page cache helping us;
  the write-coalescing from phase 5 (issue 506) becomes part of
  this driver or a layer immediately above.
