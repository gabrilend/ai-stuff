# 110j — fast eMMC path (HS200, 8-bit, DMA)

## Current behavior

The eMMC works, but slowly. `src/012-emmc.c` brings the card up and
transfers in the most conservative mode there is: a 1-bit data bus, a
~24 MHz card clock (`CCLK_EMMC` mux at its 24 MHz setting), and
programmed I/O one block at a time — each 512-byte block is its own
`CMD17` with the CPU copying the data register word by word. The
`emmc_backup_to_sd` path in `src/002-main.c` copies 200 MB this way and
it takes minutes (~3 MB/s). The full multi-GB stock-OS pull the backup
is a down-payment on is impractical at this rate.

The hard prerequisite for going faster is now answered. The
`emmc-dll-tune` probe (issue 110i) drove `CCLK_EMMC` to 200 MHz, reset
and started the controller's delay-locked loop, and **the DLL locked
on the first poll** — `DLL_STATUS0 = 0x0000013B` (lock bit 8 set, lock
value 0x3B), per-line delays `DLL_STATUS1 = 0x0010011E`. The controller
can clock the bus at 200 MHz with a stable sampling point. What remains
is putting the *card* and the *transfer engine* into the matching fast
mode.

## Intended behavior

Read and write the eMMC at HS200: an 8-bit data bus, a 200 MHz SDR
clock, and DMA instead of PIO, so a block transfer is a descriptor the
controller walks on its own rather than a CPU copy loop. This turns the
multi-minute backup into a multi-second one and makes the full stock-OS
pull (and, later, a real filesystem) practical.

HS200 is reached by negotiating four things into agreement — bus width,
card timing mode, controller mode, and sampling — then switching the
data path to DMA:

1. **Bus width → 8-bit.** A `CMD6` SWITCH writes the card's `EXT_CSD`
   `BUS_WIDTH` (byte 183) to the 8-bit setting, and the controller's
   `HOST_CONTROL_1` bus-width bits are set to match. (Today both sides
   are 1-bit.)
2. **Card timing → HS200.** A `CMD6` SWITCH writes `EXT_CSD`
   `HS_TIMING` (byte 185) to the HS200 value (0x2). The card now expects
   a 200 MHz clock and 1.8 V (or 1.2 V) I/O signalling.
3. **Controller mode → HS200 + 200 MHz.** Set the SDHCI
   `HOST_CONTROL_2` UHS mode field to HS200 and the 1.8 V-signalling
   bit, switch the `CCLK_EMMC` CRU mux to 200 MHz (the same write the
   probe made: `0xFDD20170 <= 0x70001000`), and run the DLL bring-up the
   probe validated (reset `DLL_CTRL` bit 1, release, start with
   start-point/increment, poll `DLL_STATUS0` bit 8 for lock).
4. **Sampling.** With the DLL locked, either trust the DLL-derived
   sampling point or run the SDHCI tuning sequence (`CMD21`, the eMMC
   tuning block, watching the controller's execute-tuning bit clear).
   The probe shows the DLL locks immediately, so DLL-only may suffice;
   tuning is the fallback if reads come back corrupt.
5. **Transfers → DMA.** Replace the PIO `CMD17` single-block loop with
   ADMA2: build a descriptor table pointing at the destination buffer,
   program the ADMA address register, and issue `CMD18` multi-block
   reads so the controller bursts whole runs of blocks without the CPU
   in the inner loop.

### The signalling-voltage dependency

HS200 runs the eMMC's `VCCQ` I/O rail at 1.8 V (or 1.2 V), not the 3.3 V
legacy mode tolerates. Two outcomes are possible and the probe tells us
which:

- If the board hardwires eMMC `VCCQ` to 1.8 V (common on handhelds),
  nothing extra is needed — the DLL already locking at 200 MHz is
  consistent with the pads already being at 1.8 V.
- If `VCCQ` is software-controlled, it goes through the RK817 PMIC —
  **which currently does not answer over i2c0** (issue surfaced by the
  `pmic-dump` probe). In that case this issue is *blocked on the PMIC
  i2c path* until the rail can be commanded to 1.8 V.

The first read at HS200 settles it: real data means the rail is already
right; all-`0xFF`/corruption with a locked DLL points at the voltage.

## Why now

Legacy mode is ~3 MB/s; HS200 8-bit is an order of magnitude faster.
The 200 MB safety backup drops from minutes to seconds, and the
multi-GB stock-OS image pull — currently impractical — becomes a normal
operation. Every later eMMC-touching feature (a real boot image, a
filesystem, runtime re-flash) rides on this path. The one unknown that
made it speculative (does the DLL lock at speed?) is now measured.

## Suggested implementation steps

1. Read and cache the card's `EXT_CSD` (`CMD8`) so the device's
   declared HS200 support and current widths are known before switching.
2. Add an 8-bit-bus `CMD6` SWITCH + the controller bus-width change;
   re-verify a legacy-speed read still works at 8-bit before raising the
   clock (isolates width from speed).
3. Add the HS200 `CMD6` SWITCH, the `HOST_CONTROL_2` mode set, the
   200 MHz mux switch, and the DLL bring-up (lift the exact sequence the
   `emmc-dll-tune` probe ran and `src/012-emmc.c`'s existing low-speed
   DLL config).
4. Read block 0 at HS200 and compare against the known legacy-mode read
   (the `emmc-dll-tune` / `health-check` probes already capture a
   golden value) — this is the go/no-go and the signalling-voltage test.
5. Implement the ADMA2 descriptor path and switch transfers to `CMD18`
   multi-block; keep the PIO path as a fallback selected by a flag.
6. Re-run the backup and record the new throughput in
   `docs/018-emmc-host-controller.md`.

## Related documents and tools

- `src/012-emmc.c` — the controller driver this extends; already drives
  `CCLK_EMMC` directly and carries the low-speed DLL bypass config.
- `input/probes/emmc-dll-tune.probe` — the probe that measured the DLL
  lock at 200 MHz; re-run it (`scripts/build --probes`) after each
  controller change to confirm the lock survives.
- `docs/018-emmc-host-controller.md` — the host-controller write-up;
  update it with the HS200 register settings and the new throughput.
- `tmp/uboot-ref/rockchip_sdhci.c` — u-boot's driver, the ground truth
  for the dwcmshc HS200 + DLL sequence (it was the source of the
  low-speed fix).
- `docs/datasheets/` — RK3568 TRM (dwcmshc registers) and the JEDEC
  eMMC 5.1 spec (`EXT_CSD` byte map, `CMD6` SWITCH, HS200 timing).

## Blocked by

110a (eMMC controller driver) — up and working. The 200 MHz DLL lock
prerequisite is confirmed (110i). Soft dependency: if eMMC `VCCQ` is
software-controlled rather than board-fixed at 1.8 V, blocked on the
RK817 PMIC i2c0 path (the `pmic-dump` finding) until the rail can be
set; the first HS200 read decides whether this dependency is live.
