# 114 — i2c0 and the RK817 PMIC

## Current behavior

The kernel cannot talk to the power-management chip. The RK817 PMIC —
the companion chip that generates every voltage rail (CPU core, DRAM,
the 1.8 V / 3.3 V supplies, the eMMC's I/O rail), charges the battery,
and carries a fuel gauge — sits on the i2c0 bus at 7-bit address 0x20.
A bring-up and a single-register read already exist as the probe
engine's `pmic_dump` CALL target (`src/019-probe-engine.c`): it ungates
i2c0's PMU-domain clocks, routes the SCL/SDA pins, sets a slow SCL
divider, and issues Rockchip "register-address then read" transactions.

The original read routine timed out on every register. Instrumenting it
(setup-register read-back plus capturing the controller status the
instant it gave up) ruled out the physical layer entirely: clock,
pinmux, and pad-source all read back correct; the TRM confirms the
ungated PMU gate bits are `pclk_i2c0`/`clk_i2c0`; the i2c's SCL is
derived from PCLK (plainly on, since register access works); and a
line-level read showed SCL and SDA both idle-high. The bus is healthy —
the bug was in our transaction *sequence*.

Comparing against u-boot's `rk_i2c.c` (saved under `tmp/uboot-ref/`)
found three sequencing errors, all now fixed:

- **START is its own step.** Write `CON = EN | START` *alone*, wait the
  start interrupt, clear it — then proceed. We had folded START into the
  same `CON` write as the transfer mode.
- **The slave address carries the read bit** (`(addr<<1)|1`); we left it
  off.
- **Writing `MRXCNT` is the trigger** for the controller to clock the
  bus, so it must be the *last* write, after the mode `CON`. We wrote it
  *first*, so the controller issued the start condition and then sat
  there — exactly the "STARTIPD, then nothing" the capture showed.

The read routine now follows the canonical order (START alone → address
with read bit → mode `CON` → `MRXCNT` → wait byte/NAK → STOP).
**Confirmed on hardware (2026-06-29): the RK817 answers** with real,
varied register values (`0x07=0x25`, `0x08=0x17`, `0x0C=0x26`, …) where
every read used to time out — so reachability, this issue's layer 1, is
done. The TRM i2c chapter (Part1 Ch22) and both reference drivers
(`rk_i2c.c`, `i2c-rk3x.c`) are in `tmp/uboot-ref/`. Still open: a write
path (layer 2) and identifying the `VCCQ` rail (layer 3), both of which
want the RK817 datasheet for the register map.

## Intended behavior

The kernel reliably reads and writes RK817 registers over i2c0. Three
layers, in order of need:

1. **Reachability** — a register read returns the chip's real values
   (not all-`0xFF`, not timeout). This is the layer that unblocks
   everything else and the one we are on now.
2. **Writes** — set an RK817 register (the SWITCH from read-only
   reachability to commanding the chip), with the register map read
   from the RK817 datasheet.
3. **Regulator control** — command specific rails. The first concrete
   consumer is the eMMC I/O rail (`VCCQ`): the fast-storage path (110j)
   needs it at 1.8 V for HS200, and if that rail is software-controlled
   it is set through this bus. Later consumers: DVFS voltage scaling,
   battery/charge state, safe shutdown.

## Why now

110j (fast eMMC) hinges on whether the eMMC's 1.8 V signalling rail is
board-fixed or PMIC-controlled; we cannot answer that until we can talk
to the PMIC. Beyond 110j, nothing about power, battery, or thermal is
reachable without this bus, so it is foundational regardless. It also
has a built-in test harness — the `pmic-dump` probe — making it a clean
fit for the compiled-in-probe iterate loop (110i).

## Suggested implementation steps

1. **Instrument before fixing.** Extend `pmic_dump` to read back the
   setup registers after `i2c0_setup` (the PMU clock-gate and reset,
   the pin IOMUX, the pad-source select, the controller's `CON` and
   `CLKDIV`) so we can see whether the writes took, and to capture and
   log the controller's pending-interrupt register at the moment of
   timeout. One flash then localises the failure: a NAK bit set means
   the bus works and the chip is silent (pins / address / the chip's
   own clock); an all-zero status means the controller never ran a
   transaction (its functional clock is gated).
2. Fix what the instrumentation points at. Leading suspects: the i2c0
   **functional clock** (an i2c controller needs both a register-access
   clock and a separate clock that toggles SCL; the bring-up may ungate
   only one) and the **pad-source routing** (those pins are shared with
   the audio codec the RK817 also contains).
3. Once a read returns real data, add a write path and confirm a
   read-after-write round-trips.
4. Identify the `VCCQ` rail in the RK817 register map and expose a
   "set eMMC I/O to 1.8 V" call for 110j to use; settle the board-fixed
   vs software-controlled question by reading the rail's current
   setting.

## Related documents and tools

- `docs/021-pmic-and-regulators.md` — the RK817, the bus, the rails,
  and the `VCCQ` dependency for HS200.
- `docs/019-board-pinmux.md` — the i2c0 SCL/SDA pin entries.
- `docs/016-physical-memory-map.md` — the i2c0 controller base
  (`0xFDD4_0000`) and the PMU register windows.
- `input/probes/pmic-dump.probe` + the `pmic_dump` CALL target in
  `src/019-probe-engine.c` — the test harness; iterate by editing,
  `scripts/build --probes`, flash, `dump-from-sd`.
- RK817 datasheet (register map) — needed for steps 3 and 4; not yet
  in `docs/datasheets/`.

## Blocked by

Nothing — i2c0 and the PMU clock/reset windows are reachable now.

## Blocks

110j's signalling-voltage dependency (the eMMC `VCCQ` rail), if that
rail turns out to be software-controlled rather than board-fixed.
