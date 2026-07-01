# 110j — fast eMMC path (HS200 waypoint → HS400 target)

Originally scoped to HS200 only; broadened to carry the card all the way
to HS400, because HS400 is reached *through* HS200 (the spec routes the
transition that way) and the two share all their machinery — one CMD6
SWITCH primitive, one DLL-lock routine, one 200 MHz clock path. Building
both at once is the "solid foundation while we're in the hardware
interface" call: the HS400 capability is there the day a fast enough
destination wants it, without a context-switch back into eMMC internals.

## Current behavior

The eMMC works, but slowly. `src/012-emmc.c` brings the card up in the
most conservative mode there is: a 1-bit data bus, a ~24 MHz card clock
(`CCLK_EMMC` mux at its 24 MHz tap), and programmed I/O one block at a
time. At that rate (~3 MB/s) the full ~29 GiB card dump is impractical
— the motivation for the fast path below.

Two prerequisites are now measured and clear:

- **The DLL locks at 200 MHz.** The `emmc-dll-tune` probe drove
  `CCLK_EMMC` to 200 MHz, reset and started the controller's
  delay-locked loop, and it locked on the first poll: `DLL_STATUS0 =
  0x0000013B` (lock bit 8 set, lock value 0x3B). The controller can
  clock the bus at 200 MHz with a stable sampling point.
- **The card advertises both fast modes.** The `emmc-extcsd` probe read
  `EXT_CSD` and decoded `DEVICE_TYPE[196] = 0x57` — bit 4 (HS200 @ 1.8 V)
  **and** bit 6 (HS400 @ 1.8 V) both set. It is an eMMC 5.0 card
  (`EXT_CSD_REV = 7`), currently in legacy timing, 1-bit bus
  (`HS_TIMING = 0`, `BUS_WIDTH = 0`).

The EXT_CSD reader (`emmc_read_ext_csd`, step 1) is implemented and
hardware-confirmed. What remains is putting the *card* and the *transfer
engine* into the matching fast modes.

## Intended behavior

Two staged transitions on top of the existing legacy bring-up, each
additive and independently testable. The legacy path is left untouched,
so a failure in either stage cannot regress the working slow path.

### Stage A — HS200 (8-bit SDR, 200 MHz, tuned)

From the legacy transfer state `emmc_init()` leaves the card in:

1. **8-bit SDR bus.** `CMD6` SWITCH writes `EXT_CSD BUS_WIDTH (183) = 2`
   (8-bit SDR); the host's `HOST_CONTROL_1` bit 5 (extended 8-bit width)
   is set to match.
2. **HS200 card timing.** `CMD6` SWITCH writes `EXT_CSD HS_TIMING (185)
   = 2`. The card now expects a 200 MHz clock and 1.8 V signalling.
3. **Host mode + clock.** `HOST_CONTROL_2` UHS field → SDR104 encoding
   (the eMMC HS200 selector) with the 1.8 V-signalling bit; `CCLK_EMMC`
   mux → 200 MHz; the locked-DLL config (below) replaces the bypass one.
4. **Sampling.** Run the controller's tuning (`CMD21` SEND_TUNING_BLOCK,
   watching `HOST_CONTROL_2`'s execute-tuning bit clear and tuned-clk
   bit set). The DLL lock gives a usable fallback sampling point, so
   tuning is treated as a refinement, not a hard gate, for the first
   bring-up.

Go/no-go: read block 0. A real (non-`0xFFFFFFFF`) word means the HS200
read path works — the order-of-magnitude win. All-ones with a locked DLL
points at sampling or signalling.

### Stage B — HS400 (8-bit DDR, 200 MHz DDR, data strobe)

HS400 cannot be entered cold; the spec routes `HS200 → HS → HS400`. From
a working HS200 state:

1. **Step down to High-Speed.** `CMD6 HS_TIMING = 1` (HS), host back to
   the HS/SDR25 encoding at ≤52 MHz, DLL restored to bypass — a quiet
   low-speed window in which to reconfigure the bus.
2. **DDR 8-bit bus.** `CMD6 BUS_WIDTH = 6` (8-bit DDR).
3. **HS400 card timing.** `CMD6 HS_TIMING = 3`.
4. **Host mode + clock.** `HOST_CONTROL_2` UHS field → the dwcmshc HS400
   value (0x7); `CCLK_EMMC` → 200 MHz (DDR doubles the effective rate).
5. **Re-lock the DLL with the HS400 taps**, adding the command-output
   path (negative-edge, both-edge) and the data-strobe-in tap that HS400
   uses to sample the card's returned strobe (DQS). Plain HS400 (not
   Enhanced Strobe) to start; the `EMMC_CONTROL` enhanced-strobe bit
   (8) and a `CMD6 BUS_WIDTH = 0x86` are the HS400ES upgrade for later.

Go/no-go: read block 0 again. A real word means the DDR + data-strobe
path is good.

### The signalling-voltage dependency — resolved

HS200/HS400 run the eMMC `VCCQ` I/O rail at 1.8 V. It is a fixed board
rail at 1.8 V: the device-tree node (`mmc@fe310000`) has no
`vqmmc-supply` (so VCCQ is hardwired, not software-controlled) and the
board declares `max-frequency = 200 MHz`, which only works at 1.8 V. The
PMIC bring-up (114) corroborated it and is *not* needed here. The first
HS200 read is the final confirmation.

### Deferred: DMA (ADMA2)

The reads above stay PIO (`CMD17` single-block), which is correct and
already an order of magnitude faster than legacy at 8-bit/200 MHz — it
proves the modes. ADMA2 (descriptor-walked `CMD18` multi-block bursts)
is a *throughput* optimisation orthogonal to the *speed mode*; it is a
separate later step, not part of "have HS400." Note: the reference warns
PIO multi-block (`CMD18`) past 4 blocks trips a data-end-bit error below
HS200, so DMA is the right vehicle for big multi-block transfers.

## Register derivations (rk3568, from `tmp/uboot-ref/rockchip_sdhci.c`)

The DLL words fold the `rk3568_data` tap numbers into the bit layout
`rk3568_sdhci_config_dll` builds, with `dll_tap_value = 0` (rk3568 has
no `FLAG_TAPVALUE_FROM_SW`) and the RX no-inverter bit set (rk3568 has
`FLAG_INVERTER_FLAG_IN_RXCLK`). Locked (≥100 MHz) branch:

- `AT_CTRL (0x540)  = 0x001F0000`  — post(3)<<19 | pre(3)<<17 | tune-clk-stop(1<<16)
- `DLL_CTRL start   = 0x00050201`  — start-point 5<<16 | inc 2<<8 | START
- `DLL_RXCLK (0x804)= 0xA8000000`  — DLYENA(27) | ORI_GATE(31) | NO_INVERTER(29)
- `DLL_TXCLK (0x808)`: HS200 `= 0x29000010` (DLYENA|FROM_SW(24)|NO_INVERTER(29)|tap 0x10);
  HS400 `= 0x29000008` (tap 0x8)
- `DLL_STRBIN(0x80C)= 0x09000004`  — DLYENA(27) | FROM_SW(24) | tap 0x4
- `DLL_CMDOUT(0x810)= 0x59000008`  — SRC_CLK_NEG(28) | BOTH_EDGE(30) | DLYENA(27) | FROM_SW(24) | tap 0x8 (HS400 only)
- lock poll: `DLL_STATUS0 (0x840)` bit 8 set, bit 9 (timeout) clear

CMD6 SWITCH "Write Byte" argument = `(3<<24) | (index<<16) | (value<<8)`:

- 8-bit SDR bus: `0x03B70200`   · 8-bit DDR bus: `0x03B70600`
- HS_TIMING HS: `0x03B90100` · HS200: `0x03B90200` · HS400: `0x03B90300`

`HOST_CONTROL_2 (0x3E)` UHS field + 1.8 V bit: HS = `0x0009`, HS200 =
`0x000B`, HS400 = `0x000F`.

## Suggested implementation steps

1. **EXT_CSD reader** (`CMD8`) — done, hardware-confirmed.
2. **CMD6 SWITCH primitive** + CMD13 status check; the 8-bit bus-width
   helper (card + host); the 200 MHz clock helper; the locked-DLL config
   (parameterised HS200 vs HS400); the bypass-DLL helper (factored from
   the existing init); the tuning routine.
3. **`emmc_switch_hs200()`** orchestrating Stage A; a `CALL emmc_hs200`
   probe target; read block 0 to confirm. Flash and confirm the HS200
   read before touching HS400.
4. **`emmc_switch_hs400()`** orchestrating Stage B; a `CALL emmc_hs400`
   target; the `emmc-hs400` probe ships compiled-in but **de-selected**
   (`#NEEDED 0`, the 110k run-list) until the HS200 read is green — then
   flip it to 1 and flash to exercise the HS400 leg. (Staging the
   capstone behind the run-list is the first production use of 110k.)
5. **ADMA2 / `CMD18`** — deferred throughput step (see above).
6. Update `docs/018-emmc-host-controller.md` with the confirmed register
   settings and the measured throughput **once the reads are green** (no
   unverified numbers in the docs).

## Related documents and tools

- `src/012-emmc.c` — the controller driver this extends; carries the
  command machinery, the low-speed DLL bypass, and the 1.8 V constant.
- `tmp/uboot-ref/rockchip_sdhci.c` — ground truth for the dwcmshc
  HS200/HS400 + DLL sequence; every magic number above traces to it.
- `input/probes/emmc-extcsd.probe` / `emmc-dll-tune.probe` — the
  reconnaissance that confirmed HS200/HS400 support and the 200 MHz lock.
- `input/probes/emmc-hs200.probe` / `emmc-hs400.probe` — the bring-up
  exercisers (HS400 de-selected until HS200 is proven).
- `docs/018-emmc-host-controller.md` — host-controller write-up; update
  after the modes are hardware-confirmed.

## Blocked by

Nothing. 110a (controller driver) is up; the 200 MHz DLL lock (110i) and
the card's HS200/HS400 support (EXT_CSD) are confirmed; the signalling
rail is board-fixed 1.8 V. Ready to implement and flash-debug stage by
stage.
