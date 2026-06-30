# Soren DS — PMIC and regulator rails

This document catalogues the board's power-management IC and
every regulator rail it provides. The information comes from
the `rk3568-anbernic-rg-ds` device tree's `i2c@fdd40000/pmic@20`
node and its `regulators` subnode. The board PMIC is a Rockchip
**RK817**, an integrated PMU + audio codec + battery charger
in a single I²C-controlled package.

The PMIC sits on I²C bus 0 (the PMU-domain I²C controller) at
7-bit address `0x20`. The bus and its pinmux are catalogued in
`docs/019-board-pinmux.md`; the controller lives at
`0xFDD4_0000` in the PMU domain, separately from the
main-domain I²C controllers.

## Why this document exists

Phase-1 hardware bring-up established a working SD card and
USB controller without ever talking to the PMIC, because every
rail those peripherals need is `regulator-always-on` and
`regulator-boot-on` — the BootROM / TF-A blob initializes the
PMIC before u-boot, and the rails stay powered through hand-
off. The kernel inherits a fully-powered chip and can drive
the peripherals it owns without touching the PMIC at all.

The PMIC becomes relevant when:

- A rail needs voltage *switching* (e.g. eMMC HS200/HS400 mode
  switches `vccio_sd` from 3.3 V to 1.8 V — but we're nowhere
  near high-speed modes in phase 1).
- A rail that's NOT always-on needs to be enabled.
- The kernel wants to handle low-battery / power-button events
  (phase 2 or later).
- The audio codec embedded in the RK817 is needed.

For phase 1 the PMIC is read-only knowledge: knowing what each
rail powers and at what voltage explains why the eMMC slot is
3.0 V (it comes from `vcc_3v3` post-divider, or possibly via
the chip's internal IO buffer that limits to 3.0 V — see the
SDHCI CAPABILITIES discussion in `docs/018`).

## Regulator inventory

The RK817 has four buck (switching) regulators and nine LDO
(linear) regulators, plus a boost converter and a USB OTG
switch.

### Buck (DCDC) regulators

| Reg          | Rail name    | Voltage      | What it powers |
|--------------|--------------|--------------|----------------|
| DCDC_REG1    | vdd_logic    | 0.9-1.35 V (adjustable) | Chip's logic domain, DVFS-controlled |
| DCDC_REG2    | vdd_gpu      | 0.825-1.35 V (adjustable) | Mali GPU |
| DCDC_REG3    | vcc_ddr      | (unconstrained) | DDR memory power |
| DCDC_REG4    | vcc_3v3      | 3.3 V fixed | The main 3.3 V rail |

`vdd_logic` and `vdd_gpu` are the DVFS rails — the kernel can
ask the PMIC to lower them at lower clock speeds for power
savings. Phase 1 doesn't touch these. `vcc_ddr` is what
keeps the memory alive during suspend.

### LDO regulators

| Reg        | Rail name      | Voltage         | What it powers |
|------------|----------------|-----------------|----------------|
| LDO_REG1   | vcca1v8_pmu    | 1.8 V fixed     | PMU 1.8 V analog |
| LDO_REG2   | vdda_0v9       | 0.9 V fixed     | Main 0.9 V analog (PHY references) |
| LDO_REG3   | vdda0v9_pmu    | 0.9 V fixed     | PMU 0.9 V analog |
| LDO_REG4   | vccio_acodec   | 3.3 V fixed     | Audio codec I/O |
| LDO_REG5   | vccio_sd       | 1.8-3.3 V (switchable) | SD card I/O voltage |
| LDO_REG6   | vcc3v3_pmu     | 3.3 V fixed     | PMU 3.3 V rail |
| LDO_REG7   | vcc_1v8        | 1.8 V fixed     | General 1.8 V |
| LDO_REG8   | vcc1v8_dvp     | 1.8-3.3 V (switchable) | DVP (camera) I/O |
| LDO_REG9   | vcc2v8_dvp     | 2.8 V fixed     | DVP analog |

### Other outputs

| Output     | Rail name      | Voltage         | Purpose |
|------------|----------------|-----------------|---------|
| BOOST      | dcdc_boost     | 4.7-5.4 V       | USB VBUS / 5 V supply |
| OTG_SWITCH | otg_switch     | (switched)      | USB OTG power role select |

## The eMMC voltage observation, explained

`docs/018-emmc-host-controller.md` notes that the SDHCI
controller's CAPABILITIES register reports 3.0 V support, not
3.3 V. The PMIC has no 3.0 V rail — `vcc_3v3` is 3.3 V fixed.
So either:

1. The eMMC slot's VCC is `vcc_3v3` (3.3 V) and the controller's
   CAPABILITIES register reports "3.0 V" because of how the
   chip designer wired the internal VDDQ signal, not what the
   board provides.
2. The eMMC slot's VCC comes from a board-level voltage divider
   or LDO downstream of `vcc_3v3`.

Either way, writing 3.0 V to POWER_CONTROL works (the chip's
SDHCI accepts and asserts the slot is now powered), and writing
3.3 V doesn't (the chip refuses because its CAPABILITIES
disclaims 3.3 V support). The phase-1 working configuration is
3.0 V in POWER_CONTROL; the actual rail voltage at the card is
whatever the board hardware delivers.

A future hardware investigation could measure the actual VCC
voltage at the eMMC chip's VCC pin to settle the question, but
phase 1 doesn't depend on it.

## Talking to the PMIC

When we eventually need to write to the RK817 (for voltage
switching or for the audio codec), the path is:

1. Bring up the i2c0 controller at `0xFDD4_0000` (PMU-domain
   I²C, distinct from the main-domain i2c1-i2c5).
2. Configure i2c0's pinmux per `docs/019-board-pinmux.md`:
   **SCL on GPIO0_B1** function 1, **SDA on GPIO0_B2** function 1
   (note the ordering — confirmed against TRM Part 1 Ch3). Also
   set `PMU_GRF_SOC_CON0` (`0xFDC20100`) bit 1 = 1 to route the
   pads to the I²C0 controller rather than the audio codec.
3. Issue 7-bit-address writes/reads to address `0x20`.

The RK817's register map is documented in the Rockchip RK817
datasheet (not in this repository). Common operations are
voltage-set on a buck/LDO regulator (writing a 6-bit value to
the regulator's voltage register) and event-status reads
(reading the IRQ status register after a wake-up event).

The kernel doesn't need any of this for phase 1.

## Battery and charger

The RK817 includes a battery charger; the device tree also
references a CW2015 fuel gauge IC at I²C address `0x62`. These
are out of scope for phase 1 — the device runs off whatever
charge the battery already has, and on-screen battery indicator
work waits for a later phase.

## Related documents

- `docs/014-hardware-overview.md` — the chip's I²C buses at
  the board level.
- `docs/016-physical-memory-map.md` — the i2c0 controller's
  `0xFDD4_0000` base address.
- `docs/018-emmc-host-controller.md` — the voltage observation
  this document explains.
- `docs/019-board-pinmux.md` — i2c0 pinmux entries.
