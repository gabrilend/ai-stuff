# 401 — SD card block driver

## Current behavior

The chip has an SD card controller (101 documents which). The
controller has not yet been initialized. The kernel cannot read
or write blocks on the card.

## Intended behavior

The kernel brings the SD card controller up, performs the SD
card's initialization sequence (reset, send-if-cond, send-op-cond,
all-send-cid, set-relative-addr, select-card), reads the card's
CSD register to learn its capacity and block size, and presents a
small block-level API:

- `sd_init()` — full power-on initialization. Called from
  `kernel_main` after the page allocator is up.
- `sd_block_read(block_number, buffer)` — read one 512-byte
  block.
- `sd_block_write(block_number, buffer)` — write one 512-byte
  block.
- `sd_block_count()` — total block count, learned from CSD.

The driver supports SDHC and SDXC cards (the only relevant
formats for the cards the user will plug in). SDSC support is
not in scope; if a card reports SDSC the driver refuses with a
hard error.

Block reads and writes use DMA where the controller supports it.
The synchronous API hides the DMA from callers; the driver
spins on the completion register until the transfer finishes
because phase 4 does not yet have a place to park a calling
thread without blocking it. Later phases may switch to an
event-driven completion model.

Diagnostic output goes through the CDC-ACM stream from 110.
Bring-up reports the card type, capacity, and the wall-clock
time the init sequence took.

## Suggested implementation steps

1. `sd_controller_init()` — clock, power, IRQ disable.
2. `sd_card_init_sequence()` — the spec'd command series.
3. `sd_block_read()` / `sd_block_write()` — synchronous DMA.
4. `sd_block_count()` — CSD parse.
5. Bring-up report through `debug_write`.

## Related documents

- `docs/011-filesystem.md` — the broader story this is the
  bottom of.

## Blocked by

101 (controller details), 108 (DMA buffers need allocation),
110 (diagnostic output).

## Blocks

402, every later phase 4 issue.
