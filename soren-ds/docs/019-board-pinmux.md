# Soren DS — board pinmux reference

This document catalogues every peripheral's pin assignment on
the Anbernic RG DS as recorded in the `rk3568-anbernic-rg-ds`
device tree. The source of truth is the device tree blob at
`libs/sd-image-parts/rk3568-anbernic-rg-ds.dtb`; running `dtc
-I dtb -O dts` on it produces the upstream-syntax decompilation
this document was extracted from.

USB pins are NOT in this document because USB on the RK3568
uses fixed-function pads that aren't muxable with GPIO. The
USB controller and its PHYs reach the connectors directly.

## Decoding the device tree's pin entries

Each pin entry in the device tree is a four-tuple:

```
rockchip,pins = <bank pin function config-phandle>;
```

- *bank* — GPIO bank number 0-4. Bank 0 is in the PMU domain;
  banks 1-4 are in the main domain.
- *pin* — index within the bank. The bank's 32 pins are named
  A0-A7 (0-7), B0-B7 (8-15), C0-C7 (16-23), D0-D7 (24-31).
- *function* — which alternate function the pin selects.
  Function 0 is plain GPIO; functions 1-7 are peripheral-
  specific and documented in the RK3568 TRM.
- *config-phandle* — pull-up / pull-down / drive-strength /
  schmitt-trigger configuration. Not needed for basic pin
  routing; the chip defaults are typically usable.

The IOMUX registers that select each pin's function live in
the chip's general register files (GRFs):

- *PMU GRF* at `0xFDC2_0000` covers bank 0 (GPIO0). Always-on
  power domain.
- *main GRF* at `0xFDC6_0000` covers banks 1-4 (GPIO1-4).

All offsets below are confirmed against RK3568 TRM Part 1
Chapter 3 (main GRF) and the PMU GRF register map.

### IOMUX (pin function select)

Per-bank IOMUX window offsets:

| Bank | GRF       | Window offset |
|------|-----------|---------------|
| GPIO0 | PMU GRF (`0xFDC2_0000`) | `0x00` |
| GPIO1 | main GRF (`0xFDC6_0000`) | `0x00` |
| GPIO2 | main GRF | `0x20` |
| GPIO3 | main GRF | `0x40` |
| GPIO4 | main GRF | `0x60` |

Within a bank's window:
- group A IOMUX_L at `+0x00` (pins A0-A3)
- group A IOMUX_H at `+0x04` (pins A4-A7)
- group B IOMUX_L at `+0x08`, IOMUX_H at `+0x0C`
- group C IOMUX_L at `+0x10`, IOMUX_H at `+0x14`
- group D IOMUX_L at `+0x18`, IOMUX_H at `+0x1C`

Each pin occupies a 4-bit nibble: the function selector is the
low **3** bits, bit 3 is reserved/read-only. Write-mask
convention: upper 16 bits select which lower 16 bits change.
Setting all four pins in a register to function N without
touching the reserved bits is
`(0x7777 << 16) | (N | (N << 4) | (N << 8) | (N << 12))`.

### Pull, drive-strength, and input-enable — mind the offsets

These three property registers sit at *different* base offsets,
and getting them confused is a real trap (it cost the eMMC
bring-up a flash cycle — see `docs/018`). For the **main GRF**
(GPIO1-4):

| Property | Block start | Layout | Bits/pin | Encoding |
|----------|-------------|--------|----------|----------|
| Pull (`_P`) | `+0x80` | 1 register per 8-pin group (stride `0x10` per bank) | 2 | `00`=none, `01`=pull-up, `10`=pull-down |
| Input-enable (`_IE`) | `+0xC0` | 1 register per group | — | pad input buffer enable |
| Drive-strength (`_DS`) | `+0x200` | **4 registers per group** (`DS_0..DS_3`, 2 pins each, stride `0x40` per bank) | 6 | thermometer: `000001`=L0, `000011`=L1, `000111`=L2, `001111`=L3, `011111`=L4, `111111`=L5 |

So for GPIO1 group B: `GRF_GPIO1B_P` = `0xFDC60084`,
`GRF_GPIO1B_IE` = `0xFDC600C4`, and the drive-strength for pins
B4/B5 is `GRF_GPIO1B_DS_2` = `0xFDC60218` (not `0xC4`). **The
`0xC4`/`0xC8` offsets are input-enable, NOT drive-strength** —
writing drive-strength bit patterns there clears the pad input
buffers and makes the controller unable to read the pins. The
eMMC data pins reset to drive level 3, which is already adequate,
so phase-1 leaves drive strength at its reset default.

The **PMU GRF** (GPIO0) uses the same `_P` / `_IE` / `_DS`
scheme but with its own layout: pull `_P` at `+0x20`
(`GPIO0A_P` = `0xFDC20020`), drive-strength `_DS_0..3` starting
at `+0x70` (2 pins per register, 6-bit thermometer, same
encoding). See the PMIC-bus section below for the specific
GPIO0 pins.

## eMMC — handled separately

See `docs/018-emmc-host-controller.md` for the full eMMC pinmux
plus the rest of the controller-side bring-up. eMMC pins are in
GPIO1's B and C banks, function 1.

## SDMMC0 — external microSD card slot

Lives in GPIO1's D bank and GPIO2's A bank. All function 1.

| Signal       | Pin           |
|--------------|---------------|
| D0           | GPIO1_D5      |
| D1           | GPIO1_D6      |
| D2           | GPIO1_D7      |
| D3           | GPIO2_A0      |
| CLK          | GPIO2_A2      |
| CMD          | GPIO2_A1      |
| card-detect  | GPIO0_A4      |
| pwren        | GPIO0_A5      |

The BootROM sets these up on the SD-card boot path because it
reads our kernel image off the SD card before u-boot runs. As
a result `sd_init` finds them already in the eMMC-equivalent
function and doesn't need to write them itself.

## SDMMC1 — WiFi SDIO interface

| Signal | Pin       |
|--------|-----------|
| D0     | GPIO2_A3  |
| D1     | GPIO2_A4  |
| D2     | GPIO2_A5  |
| D3     | GPIO2_A6  |
| CLK    | GPIO2_B0  |
| CMD    | GPIO2_A7  |
| det    | GPIO2_B2  |
| pwren  | (see below — SDIO power sequence) |

All function 1. The SDIO power sequence drives WiFi enable
through GPIO4_A2 (separate from the SDMMC1 pwren above).

## I²C buses

Six I²C controllers (i2c0-i2c5). Only i2c0 has its pinmux
explicitly overridden on this board:

| Bus  | SCL       | SDA       | Notes |
|------|-----------|-----------|-------|
| i2c0 | GPIO0_B1  | GPIO0_B2  | PMIC bus, function 1 (PMU domain). **B1 = SCL, B2 = SDA** per TRM Part 1 Ch3 — note the ordering, it is easy to get backwards. IOMUX register `PMU_GRF_GPIO0B_IOMUX_L` = `0xFDC20008` (B1 sel bits 6:4, B2 sel bits 10:8). |

There is also a routing switch: `PMU_GRF_SOC_CON0` = `0xFDC20100`
bit 1 (`i2c0_iomux_sel`) chooses whether these two pads are driven
by the I²C0 controller (`1`) or the audio codec's digital I²C
(`0`). Set it to `1` before talking to the PMIC.

The other I²C buses inherit their pinmux from upstream
`rk3568.dtsi` defaults; check that file for i2c1-i2c5.

## UART — debug-capable channels

| UART | Pinmux variant | RX        | TX        | Function |
|------|----------------|-----------|-----------|----------|
| uart2 | m0 (default) | GPIO0_D0  | GPIO0_D1  | function 1 (PMU) |
| uart2 | m1           | GPIO1_D6  | GPIO1_D5  | function 2 (main) |

uart2 is the Rockchip debug UART. The "m0" variant goes to PMU
pins; "m1" to main-GRF pins. The RG DS doesn't expose either
without case removal, which is why we route debug through
USB CDC-ACM instead (issue 110).

## PWM controllers

Eight PWM channels (pwm0-pwm7), all routable to PMU-domain
pins (GPIO0). Several have alternate "m1" pinmux variants on
GPIO0_C/D pins.

| PWM  | Default pin | Function | Alternate (m1)      |
|------|-------------|----------|---------------------|
| pwm0 | GPIO0_B7    | 1        | GPIO0_C7 function 2 |
| pwm1 | GPIO0_C0    | 1        | GPIO0_B5 function 4 |
| pwm2 | GPIO0_C1    | 1        | GPIO0_B6 function 4 |
| pwm3 | GPIO0_C2    | 1        | (none)              |
| pwm4 | GPIO0_C3    | 1        | (none)              |
| pwm5 | GPIO0_C4    | 1        | (none)              |
| pwm6 | GPIO0_C5    | 1        | (none)              |
| pwm7 | GPIO0_C6    | 1        | (none)              |

The on-device LEDs are driven by PWM5/PWM6/PWM7 per the
upstream device tree's `pwm-leds` node; phase 1 routes them
through GPIO instead (issue 106b), and issue 106c eventually
brings them back to PWM for smooth brightness control.

## Audio

| Group       | Pin       | Function | Purpose |
|-------------|-----------|----------|---------|
| acodec      | GPIO1_B1  | 5        | audio codec data line |
| acodec      | GPIO1_A1  | 5        | audio codec data line |
| acodec      | GPIO1_A0  | 5        | audio codec data line |
| acodec      | GPIO1_A7  | 5        | audio codec data line |
| acodec      | GPIO1_B0  | 5        | audio codec data line |
| acodec      | GPIO1_A3  | 5        | audio codec clock |
| acodec      | GPIO1_A5  | 5        | audio codec clock |
| audiopwm    | GPIO1_A0  | 4        | left audio PWM out |
| audiopwm    | GPIO1_A1  | 4 / 6    | left audio PWM out (n/p) |
| audiopwm    | GPIO1_A0  | 6        | left audio PWM out positive |
| audiopwm    | GPIO1_A1  | 4        | right audio PWM out |
| audiopwm    | GPIO1_A7  | 4        | right audio PWM negative |
| audiopwm    | GPIO1_A6  | 4        | right audio PWM positive |
| hp-detect   | GPIO4_B2  | 0 (GPIO) | headphone-detect input |

The acodec and audiopwm groups conflict on several GPIO1_A
pins. The board uses one or the other depending on whether
the speakers (audiopwm) or the headphone-coupled codec
(acodec) is active.

## Display — LCD panel control and power

The two LCD panels (top and bottom screens) are reset and
powered via dedicated GPIOs. The actual LCD data pins go
through the VOP2 / MIPI DSI controllers and are part of the
fixed-function path the chip provides — they're not in the
pinmux table.

| Signal         | Pin       | Function | Purpose |
|----------------|-----------|----------|---------|
| lcd0-rst       | GPIO0_B3  | 0 (GPIO) | top screen panel reset |
| lcd1-rst       | GPIO0_B4  | 0 (GPIO) | bottom screen panel reset |
| vdd-lcd0-h     | GPIO0_C7  | 0 (GPIO) | top screen VCC enable |
| vccio-lcd0-h   | GPIO0_B0  | 0 (GPIO) | top screen I/O voltage enable |
| vdd-lcd1-h     | GPIO0_C2  | 0 (GPIO) | bottom screen VCC enable |
| vccio-lcd1-h   | GPIO0_C1  | 0 (GPIO) | bottom screen I/O voltage enable |

## Touch — touchscreens

| Signal     | Pin       | Function | Purpose |
|------------|-----------|----------|---------|
| touch0-rst | GPIO0_B5  | 0 (GPIO) | top touch panel reset |
| touch0-irq | GPIO0_B6  | 0 (GPIO) | top touch panel interrupt |
| touch1-rst | GPIO0_B7  | 0 (GPIO) | bottom touch panel reset |
| touch1-irq | GPIO0_C0  | 0 (GPIO) | bottom touch panel interrupt |

## Gamepad — button inputs

The d-pad, ABXY, shoulder buttons, and analog stick clicks are
all GPIO inputs in GPIO2's D bank and GPIO3's A bank.

| Group           | Pins (GPIO2_D1..D7, GPIO3_A3..A10) |
|-----------------|-------------------------------------|
| gamepad-keys-l  | GPIO2_D1, D2, D3, D4, D5, D6, D7, GPIO3_A3, A4, A5, A6, A7, B0, B1, B2, B7, GPIO3_C0 |
| vol-keys_l      | GPIO3_A1, GPIO3_A2                  |

All function 0 (GPIO). The Linux upstream driver scans these
as keyboard codes via `gpio-keys`.

## Sensors and miscellaneous

| Signal             | Pin       | Function | Purpose |
|--------------------|-----------|----------|---------|
| pmic-pins          | GPIO0_A2  | 1        | PMIC sleep/wake control |
| pmic-int-l         | GPIO0_A3  | 0 (GPIO) | PMIC interrupt |
| hall-sensor int    | GPIO0_C3  | 0 (GPIO) | lid open/close detect |
| sdio-pwrseq        | GPIO4_A2  | 0 (GPIO) | WiFi power enable |
| wifi-irq           | GPIO4_A1  | 0 (GPIO) | WiFi host wake interrupt |
| vcc-wifi-h         | GPIO0_A0  | 0 (GPIO) | WiFi VCC enable |
| vcc-amp-h          | GPIO4_C3  | 0 (GPIO) | speaker amp enable |
| jtag               | GPIO1_D7, GPIO2_A0 | 2 | JTAG TCK/TMS |

## Where these go in the bring-up sequence

The bring-up rule: write the pinmux for a peripheral *before*
any MMIO write to the peripheral's controller. The eMMC's
phase-1 failure was exactly this rule being violated — pinmux
defaulted to GPIO, the controller drove commands into pads
that weren't connected to the eMMC die, and every response
came back as the floating-bus all-ones pattern.

For pins in GPIO0 (PMU domain), the IOMUX writes go to PMU
GRF at `0xFDC2_0000`. For pins in GPIO1-4, the writes go to
main GRF at `0xFDC6_0000`. The masked-write convention is the
same for both.

## Related documents

- `docs/014-hardware-overview.md` — the chip's peripherals at
  the board level.
- `docs/016-physical-memory-map.md` — the GRF base addresses
  and every peripheral's register window.
- `docs/017-clocks-and-timers.md` — the CRU clock-gate and
  reset registers each peripheral depends on (separate from
  pinmux, runs in parallel during bring-up).
- `docs/018-emmc-host-controller.md` — the eMMC-specific
  bring-up; pinmux for those pins lives here.
