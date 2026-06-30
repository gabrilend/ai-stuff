# 114 — i2c0 and the RK817 PMIC

## Current behavior

The kernel can read, write, and program the power-management chip. The
RK817 PMIC — the companion chip that generates every voltage rail (CPU
core, DRAM, the 1.8 V / 3.3 V supplies, the eMMC's I/O rail), charges the
battery, and carries a fuel gauge and a real-time clock — sits on the
i2c0 bus at 7-bit address 0x20. The probe engine's `pmic_dump`,
`pmic_write_test`, and `pmic_ldo_test` CALL targets
(`src/019-probe-engine.c`) bring i2c0 up (ungate its PMU-domain clocks,
route the SCL/SDA pins, set a slow SCL divider) and exercise it. Getting
the bus working took the debugging recorded below.

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
**Confirmed on hardware: the RK817 answers** with real, varied register
values where every read used to time out. The TRM i2c chapter (Part1
Ch22) and both reference drivers (`rk_i2c.c`, `i2c-rk3x.c`) are in
`tmp/uboot-ref/`.

**All three layers are done (2026-06-30):**

- **Layer 1 — read.** The RK817 returns real RTC/alarm registers (a BCD
  timestamp), proving reachability.
- **Layer 2 — write.** `i2c0_write_reg` (TX mode, modeled on u-boot's
  `rk_i2c_write`) plus a non-destructive RTC-register round-trip logged
  `WRITE PASS` (wrote 0x5A, read back 0x5A, restored the original).
- **Layer 3 — rail control.** `rk817_ldo_get_mv` / `rk817_ldo_set_mv`
  read and set any of the nine LDOs (`mV = 600 + sel*25`, register
  `0xCC + (n-1)*2`, range 600–3400 mV — from the Linux rk808 driver,
  `tmp/uboot-ref/`). The sweep read all nine as sensible voltages
  (LDO1/7/8 = 1.8 V, LDO2/3 = 0.9 V, LDO4/5/6 = 3.3 V, LDO9 = 2.8 V) and
  round-tripped the set path.

The original `VCCQ` motivation — the eMMC's I/O rail for HS200 (110j) —
turned out NOT to need any of this: the eMMC device-tree node has no
`vqmmc-supply`, so its VCCQ is a fixed board rail, not PMIC-controlled,
and the board's 1.8 V LDOs plus the DLL locking at 200 MHz say that fixed
rail is already 1.8 V. So 110j's voltage dependency is resolved without
programming a regulator. The rail-control capability stands on its own
for the power work ahead (DVFS, battery, thermal).

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
