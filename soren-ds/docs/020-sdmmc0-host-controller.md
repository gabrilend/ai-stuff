# Soren DS — SDMMC0 host controller (DW MSHC) bring-up notes

This document captures what phase-1 hardware testing has taught
us about the SDMMC0 controller — the Synopsys DesignWare Mobile
Storage Host Controller (DW MSHC) that owns the external microSD
card slot. Sibling to `docs/018-emmc-host-controller.md`. Where
this document and the upstream Linux dw_mmc driver disagree, the
readback values from the phase-1 bring-up test suite are the
ground truth.

The base address is `0xFE2B_0000` (the same value catalogued in
`docs/016-physical-memory-map.md`).

The IP is different from the eMMC's dwcmshc. Different register
layout, different command-issue model, different bus-protocol
quirks. Nothing in this file applies to the eMMC; nothing in
`docs/018` applies to SDMMC0.

## What the BootROM does for us

The Rockchip BootROM reads our kernel image off the microSD
card before u-boot ever runs. To do that it:

- Sets up the SDMMC0 pinmux (the eight pins in GPIO1_D/GPIO2_A
  catalogued in `docs/019-board-pinmux.md`) to function 1.
- Powers the card slot through whatever PMIC rail feeds it.
- Reads sectors from the card to bootstrap u-boot.

What it does NOT do:

- Walk the SD card through the protocol-level identification
  sequence (CMD0 / CMD8 / ACMD41 / CMD2 / CMD3 / CMD9 / CMD7).
  The BootROM reads via fixed-offset reads, bypassing the
  SDMMC0 controller's protocol stack entirely.
- Configure the SDMMC0 controller for our use. Clocks are
  gated, resets are asserted, every register reads either
  zero or all-ones on first access.

So our `sd_init` has to do both the CRU bring-up and the SD
identification sequence. Phase-1 testing confirmed both
sequences work; this document captures what they look like.

## CRU bring-up — the two clocks and two resets

The SDMMC0 controller depends on two clocks and two resets,
all in the main CRU at `0xFDD2_0000`:

- HCLK_SDMMC0 — AHB clock for register access.
- CLK_SDMMC0 — controller's internal clock.
- SRST_H_SDMMC0 — AHB reset.
- SRST_SDMMC0 — controller reset.

These are catalogued in `docs/017-clocks-and-timers.md`. The
ungate-and-pulse-reset sequence:

```
mmio_write32(0xFDD2033Cu, 0x00030000u);  /* ungate both clocks */
mmio_write32(0xFDD20434u, 0x00180018u);  /* assert both resets */
rough_delay(1000);
mmio_write32(0xFDD20434u, 0x00180000u);  /* deassert both resets */
```

## Diagnostic discriminator — HCON

The controller's hardware-config register at offset `0x70`
returns a constant the chip designer baked in. On RK3568 it
reads `0x0003_E47A`. Three possible reads tell us where we are
after the CRU bring-up:

- *roughly `0x0003_E47A`* — controller is reachable, bus-level
  setup worked, proceed.
- *`0x00000000`* — SDMMC0 reset is still asserted.
- *`0xFFFFFFFF`* — AHB clock is gated.

## The post-reset configuration writes

After the CRU bring-up and the controller's CTRL-register
software reset, the controller needs several configuration
writes before the first command can succeed:

```
mmio_write32(0xFE2B0044u, 0xFFFFFFFFu);   /* RINTSTS — clear stale interrupt bits */
mmio_write32(0xFE2B0024u, 0u);            /* INTMASK — mask all (we poll) */
mmio_write32(0xFE2B0014u, 0xFFFFFFFFu);   /* TMOUT — max response/data timeout */
mmio_write32(0xFE2B004Cu, 0x207F0080u);   /* FIFOTH — fifo-depth 256 watermarks */
mmio_write32(0xFE2B0004u, 1u);            /* PWREN = 1 */
```

The RINTSTS clear at the start is critical. DW MSHC's interrupt-
status bits survive controller reset. Any bits set when the chip
came out of reset would otherwise make the very first command's
CMD_DONE poll fire on stale state — the driver would think the
command succeeded before the controller had even seen it.

The FIFOTH value `0x207F_0080` comes from upstream Linux's setup
for this controller variant: fifo-depth `0x100`, RX watermark
`0x7F`, TX watermark `0x80`, multiple-transaction-size 2 in
bits 28-30.

## The "update clock" no-op CMD dance

Every clock change on DW MSHC requires a sandwich of "update
clock" no-op commands. Without them, the CLKENA / CLKDIV /
CLKSRC writes don't take effect and subsequent CMD0 hangs
forever.

The no-op is a write to the CMD register at offset `0x2C` with
this specific encoding:

```
CMD register value = (1 << 31)   /* START_CMD */
                   | (1 << 29)   /* USE_HOLD_REG */
                   | (1 << 21)   /* UPDATE_CLK_ONLY */
                   | (1 << 13)   /* PRV_DAT_WAIT */
                   = 0xA0202000
```

After the write, poll bit 31 of CMD until it clears.

A full clock-change sequence:

```
mmio_write32(0xFE2B0010u, 0u);    /* CLKENA off */
update_clock_no_op();
mmio_write32(0xFE2B0008u, div);   /* CLKDIV */
mmio_write32(0xFE2B000Cu, src);   /* CLKSRC */
update_clock_no_op();
mmio_write32(0xFE2B0010u, 1u);    /* CLKENA on */
update_clock_no_op();
```

## The clock divider math

The DW MSHC controller's CCLK source has a fixed extra `/2`
divider built into the IP, plus the divider you program into
`CLKDIV` at offset `0x08`:

- `f_card = f_src / (2 * (CLKDIV + 1))` if CLKDIV != 0
- `f_card = f_src / 1` if CLKDIV == 0 (pass-through)

For SD identification at 400 kHz, `f_src` must already be at
800 kHz (or the closest divisible value) with `CLKDIV = 0`.
For transfer mode at 25 MHz, `CLKDIV = 1` from a 50 MHz source.

## Polling-loop error checks

The DW MSHC fires several error bits in RINTSTS the polling
loop must check explicitly:

- *bit 1 (RE — Response Error)*. Card returned a malformed
  response.
- *bit 6 (RCRC — Response CRC Error)*. Response failed CRC.
- *bit 8 (RTO — Response Timeout)*. The expected indicator
  for a missing card. Not a wedged-controller indicator.
- *bit 12 (HLE — Hardware Locked Error)*. **The controller is
  wedged**: the host tried to write the CMD register while a
  previous command was still in flight. Almost always means
  the update-clock dance was skipped somewhere. Recovery
  requires a full CTRL_RESET.

A 500 ms wall-clock timeout wrapping the whole poll catches a
wedged controller before the kernel watchdog does.

## Pinmux summary

Catalogued fully in `docs/019-board-pinmux.md`. Summary:

| Signal       | Pin       | Function |
|--------------|-----------|----------|
| D0           | GPIO1_D5  | 1        |
| D1           | GPIO1_D6  | 1        |
| D2           | GPIO1_D7  | 1        |
| D3           | GPIO2_A0  | 1        |
| CLK          | GPIO2_A2  | 1        |
| CMD          | GPIO2_A1  | 1        |
| card-detect  | GPIO0_A4  | 1        |
| pwren        | GPIO0_A5  | 1        |

`sd_init` doesn't write these — the BootROM already did, and
the readback in the phase-1 diagnostic dump confirmed function
1 was set at boot time.

## Related documents

- `docs/014-hardware-overview.md` — the chip's SDMMC0 at the
  board level.
- `docs/016-physical-memory-map.md` — the controller's
  `0xFE2B_0000` base address.
- `docs/017-clocks-and-timers.md` — the two clocks and two
  resets the controller depends on.
- `docs/018-emmc-host-controller.md` — the SDHCI sibling for
  the internal eMMC, for comparison; the two share almost no
  bring-up steps.
- `docs/019-board-pinmux.md` — full peripheral pin reference.
- `issues/110f-microsd-controller-driver.md` — the bring-up
  issue this controller closes.
