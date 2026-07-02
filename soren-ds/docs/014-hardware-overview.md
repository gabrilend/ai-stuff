# Hardware overview — Anbernic RG DS

This is the answer to issue 101 — what is the device, chip by chip,
peripheral by peripheral, with the level of detail every later
phase will need. Each section ends in a list of *known unknowns*
that we could not answer from public sources alone. Those gaps
will be closed by later probing (chiefly by lifting values out of
the ROCKNIX or KNULLI device tree, which is publicly available
and known to boot on this exact device) and by the dedicated
research issues they spawn.

The Anbernic RG DS is a 2026 dual-screen clamshell handheld. As
of this writing it is the only Anbernic device named "RG DS" — no
disambiguating SKU is required.

## SoC — Rockchip RK3568

Four ARM Cortex-A55 cores at up to 2.0 GHz. ARMv8-A, 64-bit.
Integrated Mali-G52 2EE GPU. The Cortex-A55 carries a full MMU
in every core, which makes the phase 9 protection-mode work in
`docs/007-memory-model.md` feasible without any external hardware
help.

The RK3568 is one of the better-documented Rockchip parts. The
authoritative datasheet is published openly by Rockchip; the
canonical version we are working against is V2.1 dated June 2024
(see Sources). The RKDDRBin and miniloader binaries that occupy
layer 1 of the boot chain (per
`notes/safety/000-bricking-and-recovery.md`) are also Rockchip-
provided and supported by every community OS that targets this
SoC family — ROCKNIX, KNULLI, GammaOS, Anbernic Linux, mainline
Linux, Armbian.

One image in the wild (`ROCKNIX-RK3566.aarch64-...img.gz`) names
the RK3566 rather than the RK3568. The RK3566 and RK3568 are
sibling parts with mostly overlapping peripherals and a shared
SDK; ROCKNIX may simply use one image for both. The KNULLI build
for this device (`knulli-rk3568-rg-ds-scarab-...img.gz`)
explicitly names the RK3568, which matches Anbernic's own spec
sheet. We treat the SoC as RK3568.

**Partly answered by phase-1 bring-up.** The clock trees and
gates the phase-1 drivers actually touch are now confirmed live:
the `cpu-clock-recon` probe read the ARM PLL locked at ~816 MHz
in normal (PLL-driven) mode and the peripheral PLLs at their
standard taps (GPLL 1200 MHz, CPLL 1000 MHz, NPLL 1200 MHz), and
the i2c0 (PMU-domain), PWM1, eMMC/SDHCI, SDMMC0, and USB3-OTG
clock gates and resets were each ungated and driven successfully
(issues 114, 106c, 110a, 110f, 109a). **Still unknown:** the
gates and PMU sub-blocks for the blocks phase 1 does not touch —
the display / DSI clock tree, the WiFi-SDIO gate, the audio
path — which later phases will confirm as they bring each block
up.

## Memory — 3 GB LPDDR4 / LPDDR4X

Anbernic's product page lists 3 GB total. The RK3568's memory
controller supports DDR3, DDR3L, DDR4, LPDDR3, LPDDR4, and
LPDDR4X; on a battery-powered handheld this is overwhelmingly
likely to be LPDDR4 or LPDDR4X. The DRAM is mapped into the
chip's standard Rockchip address space — DRAM begins at a base
physical address documented in the RK3568 datasheet, with
chip-internal SRAM and a system ROM at lower addresses. The exact
physical map is what `docs/007-memory-model.md` step one needs to
commit to, and it is read straight out of the datasheet rather
than guessed.

**Known unknowns:** the exact RAM type (LPDDR4 vs LPDDR4X) and
the manufacturer, and the size and offset of any reserved-for-GPU
carve-out the boot chain has already claimed at the moment our
kernel takes control. The page allocator built in issue 108 must
not hand out memory the GPU or the display controller already
holds. What *is* now settled: the DRAM physical map is committed
in `docs/016-physical-memory-map.md` (base `0x0000_0000`, 3 GB
populated to `0xC000_0000`, verified against the u-boot load
address on the SD-boot path), and the memtest probe passed a
marching-pattern test in the middle of the range. The type bit
and the carve-out both live in state the DDR-init firmware left
behind — the DRAM-init scratch registers in the PMU GRF for the
type, the Anbernic u-boot boot argument for the carve-out —
neither of which phase 1 needs, so both wait on the phase that
does.

## Storage — 32 GB internal eMMC plus external microSD

Two distinct storage devices in the system:

- **Internal eMMC, 32 GB.** Soldered to the board. Holds the
  stock Anbernic Android 14 install today. Visible to a running
  Linux kernel at `/dev/block/mmcblk2`. The boot ROM looks for a
  loader here when no bootable external SD is present.
  Partition 8 (`mmcblk2p8`) is the Android recovery partition.
  The Rockchip miniloader and the u-boot environment live at
  fixed low-sector offsets that long predate any partition
  table.

- **External microSD slot.** Accessible from outside the case.
  Supports cards up to 2 TB (per Anbernic). Visible to a running
  Linux kernel at `/dev/block/mmcblk0p*`. When a bootable SD
  card is inserted, the Rockchip boot ROM checks it before the
  eMMC and loads the loader from there if it finds one.

The two devices use two distinct controllers inside the SoC.
The eMMC sits on the RK3568's **dedicated SDHCI controller**
(the SDIO/MMC host designed specifically for the soldered
eMMC), configured for an 8-bit bus running up to 200 MHz, with
the `non-removable` property set so the kernel does not poll
it for hot-swap. The external microSD sits on **SDMMC0**
configured for a 4-bit bus and UHS-SDR104 mode, with the
card-detect signal on GPIO0 PA4. (This corrects an earlier
guess in this document that put eMMC on SDMMC2; SDMMC2 actually
hosts the WiFi SDIO module — see the WiFi section.)

This is the foundation of the install path we adopted in the
section below.

**Mostly answered by the eMMC bring-up (110a, 110j).** The card
was brought up and interrogated on hardware: it reports as an
**eMMC 5.0** device (`EXT_CSD_REV = 7`) whose `DEVICE_TYPE`
advertises both **HS200 and HS400 at 1.8 V** (`0x57`, bits 4 and
6), the controller's delay-locked loop locks at 200 MHz, and the
`VCCQ` I/O rail is a board-fixed 1.8 V (no `vqmmc-supply` in the
device tree — confirmed while bringing up the PMIC, 114). The card's
CID register reads real values (it answers the identification
sequence) and the host's capability register reads back
correctly. **Still unknown:** the manufacturer
and part number decoded out of the full CID (the init reads the
CID but nothing decodes its manufacturer-ID and product-name
fields yet), and the exact partition layout Anbernic shipped
(`mmcblk2p1` through `mmcblk2pN`) — the `emmc-scan` probe maps the
card's non-zero regions when re-selected, which is the tool that
answers it.

## Displays — dual 4-inch 640×480 IPS, capacitive touch

Two identical IPS panels, each 4 inches and 640×480 (4:3 each,
not "480p"). OCA full-lamination. Capacitive multi-touch on each,
with capacitive-stylus support advertised.

**Panel IC: Jadard JD9365DA-H3** on both screens, driven over
MIPI DSI. The bottom panel hangs off the RK3568's DSI0
controller; the top panel off DSI1. The shared VOP2 (Video
Output Processor v2) display controller fans video data to both
DSI lanes simultaneously — one controller, two output paths, two
panels, which matches what `docs/005-display-and-compositor.md`
and issues 111a/111b assume.

**Panel reset GPIOs:** bottom panel on GPIO0 PB3, top panel on
GPIO0 PB4. Each panel must be reset (pulled low, held, released)
during bring-up; the JD9365DA-H3 datasheet specifies the timing.

**Touch controllers: Goodix GT911** on each panel, one per
screen, both at I2C address `0x14`. The bottom panel's GT911
sits on I2C bus 3 (RK3568 i2c3), the top panel's on I2C bus 5
(i2c5). Identical part on identical-looking address but on two
separate buses, so they don't collide.

**Known unknowns, narrowed.** The display controller itself is
now confirmed reachable: the `VOP2` version register reads
`0x40158023` on hardware, and both DSI D-PHY bases are catalogued
in `docs/016-physical-memory-map.md` (DSI0 `0xFE85_0000`, DSI1
`0xFE86_0000`). The JD9365DA-H3 initialization sequence no longer
needs the paper datasheet — the upstream Linux panel driver
`drivers/gpu/drm/panel/panel-jadard-jd9365da.c` carries the DCS
command table (issue 111c); it is transcribed from there. **Still
to extract:** that command table (into our own driver), the
backlight PWM channel and its rated maximum current, and the
touch controllers' reset and interrupt GPIOs (the DTS pinctrl
groups name them; pull the exact pins on demand when 504 work
starts).

## Sensors and switches

- **Hall switch for cover-closed sleep.** Labeled "LID" in the
  device tree. Wired to **GPIO0 PC3**, active low, with the
  `wakeup-source` property set so it can pull the device out of
  PMIC sleep. This is exactly the signal phase 9 issue 908
  ("asleep and wake signals") needs, and it doubles as the
  wake-on-open input the PMIC's sleep mode lists.
- **Six-axis gyroscope.** Listed on Anbernic's product page but
  **not present in the mainline device tree**. Either Anbernic's
  own kernel includes it on a bus not pulled into upstream yet,
  or the spec sheet is aspirational and there is no gyro. The
  modeller (phase 10) is the only launch-or-near-launch
  consumer; deferring until we have a reason to confirm. Note
  that probing for it later means scanning I2C0 / I2C2 / I2C3 /
  I2C5 for addresses other than the ones already named below.

**Known unknowns:** whether the gyro physically exists; if so,
its I2C bus and address. The resolution is a targeted scan of the
common six-axis-IMU addresses (0x68 / 0x69 / 0x6A / 0x6B) across
i2c0 / i2c2 / i2c3 / i2c5, looking for an ACK at an address none
of the chips catalogued elsewhere in this document occupy. The
probe engine can drive i2c0 today (the PMIC-bus setup in
`src/019-probe-engine.c`) but not the other three buses, so this
scan waits on a generalized i2c-bus-scan CALL target — the
clearest remaining hardware probe to write.

## Buttons and analog sticks

D-pad and L1/L2 on the left side. ABXY and R1/R2 on the right
side. Four center buttons in a row at the bottom of the lower
screen: `[start1][select1][select2][start2]`. Two clickable
analog sticks. Power and volume on the side edges.

All digital buttons are direct GPIO inputs (no I2C input
expander), all active low. The full mapping, from the device
tree:

| Button       | GPIO        |
| ------------ | ----------- |
| A (EAST)     | GPIO3 PB7   |
| B (SOUTH)    | GPIO3 PC0   |
| X (NORTH)    | GPIO3 PA7   |
| Y (WEST)     | GPIO3 PB0   |
| D-pad UP     | GPIO2 PD4   |
| D-pad DOWN   | GPIO2 PD5   |
| D-pad LEFT   | GPIO2 PD7   |
| D-pad RIGHT  | GPIO2 PD6   |
| L1 (TL)      | GPIO3 PA3   |
| L2 (TL2)     | GPIO3 PA4   |
| R1 (TR)      | GPIO3 PA5   |
| R2 (TR2)     | GPIO3 PA6   |
| START        | GPIO3 PB1   |
| SELECT       | GPIO3 PB2   |
| Left stick click  (THUMBL) | GPIO2 PD2 |
| Right stick click (THUMBR) | GPIO2 PD3 |
| HOME (Menu)  | GPIO2 PD1   |
| Volume Up    | GPIO3 PA1   |
| Volume Down  | GPIO3 PA2   |

Two more inputs are routed through the SAR-ADC rather than
through GPIO: a HOME button on **SAR-ADC channel 0** and a PLAY
button on **SAR-ADC channel 2**. The vision (`004-input-model`)
maps these against the four center buttons; the device tree's
HOME and PLAY labels are Anbernic's labels and we are free to
rebind in the input driver.

The two analog sticks themselves are not in the discrete
section of the device tree we read; they're handled through the
joystick-mux pinctrl group, which suggests two SAR-ADC channels
multiplexed across the two stick axes. Issue 503 (analog stick
surface) will confirm the wiring when it gets there.

**Known unknowns:** the analog-stick SAR-ADC channels and the
mux-select GPIO; the exact location of the **Maskrom trigger
button** inside the case (the button or pad that, when held
during power-on, forces the chip ROM into recovery mode
regardless of what is on storage — still nothing public for the
RG DS specifically). One concrete finding narrows the ADC work:
the `saradc-gamepad` probe established that this part's SAR-ADC is
a **v2 controller**, not the v1 layout the RK3568 TRM documents —
driven with v1 register offsets every channel reads a constant
`0x3FF` and channels 1–5 time out, the fingerprint of reading the
wrong registers. Mapping the stick channels therefore needs a
probe rewritten to the v2 register layout (the `SARADC_V2_*`
offsets in the kernel's `rockchip_saradc.c`); the existing probe
is kept compiled-in but de-selected to host that rewrite.

## USB-C controller

The RK3568 has an integrated USB 3.0 OTG controller plus a USB
2.0 host. On the RG DS the USB-C port is wired to the OTG
controller, which can operate as either host or device. Device
mode is what issue 109 brings up. The chip ROM's Maskrom mode
also enumerates over this same port — it is the same physical
controller and the same physical connector, but the bytes coming
out the wire are decided by either the silicon (in Maskrom) or
our code (once SoreOS is running), never by Anbernic.

When Maskrom is active, the device enumerates as USB vendor
0x2207 product 0x350a (Rockchip, RK3568 family). The laptop-side
tool that talks to it is `rkdeveloptool`.

**Known unknowns:** whether the USB-C port supports the full
PD profile or only basic charging, and whether the type-C
orientation detection is handled in the chip or in a separate
USB-C PHY chip. The controller side, by contrast, is confirmed:
the DWC3 core reads its `GSNPSID` as `0x5533300A` at base
`0xFCC0_0000`, the USB2 PHY sits in its OTG-normal state, and the
device-mode enumeration path is implemented (issues 109a–109c).
The PD / orientation questions are about the analog front-end
(the CC pins), which nothing in phase 1 exercises.

## WiFi and Bluetooth

802.11a/b/g/n/ac (WiFi 5, dual-band 2.4 / 5 GHz) and Bluetooth
4.2.

**WiFi: a Realtek chip on SDMMC2** (the RK3568's secondary
SDMMC controller, here used as an SDIO bus rather than as a
storage host — `sdio_wifi` at SDIO address 1). The device tree
does not name the exact Realtek part number, but the Bluetooth
side (below) is RTL8821CS, and Realtek's RTL8821CS-equivalent
WiFi half is the matching radio in the same package. Treating
the WiFi as RTL8821CS pending confirmation.

**Bluetooth: Realtek RTL8821CS on UART1**, enabled by GPIO0 PD5
(the BT module's power-on / wake line). This is the same
package as the WiFi above; one chip serves both radios, with
WiFi over SDIO and Bluetooth over UART, which is the standard
Realtek combo configuration.

**IBSS support.** Realtek WiFi parts of the 882x family
generally support IBSS through the in-kernel rtl88xx-au driver,
though some firmware revisions disable it. Confirming on real
hardware is a phase 7 task; it remains the single biggest
hardware-side risk for that phase.

**Known unknowns:** the exact Realtek WiFi part number (almost
certainly RTL8821CS based on the BT pairing, but the device
tree doesn't quote it); whether the shipped firmware
specifically enables IBSS or whether we will need to swap a
firmware blob.

## Audio

Stereo speakers, 3.5 mm headphone jack.

**Audio codec: the RK817 PMIC's integrated codec block.** The
same chip that handles voltage regulation also contains a
combined ADC/DAC for audio. The codec lives on I2C0 at the
same address as the PMIC itself (`0x20`); they are two
sub-functions of one physical part. The DSP path is `RK817 codec
→ I2S → SoC`.

**Speaker amplifiers: two Awinic AW87391** parts, one per
channel — left at I2C2 address `0x58`, right at `0x5b`. These
are class-D mono amplifiers; the codec produces the analog
signal, the AW87391s amplify it to drive the speakers. The
headphone jack bypasses them and is driven directly by the
codec.

Phase 1 does not bring up audio. Phase 8's apps don't make
sound either. Audio is deferred; this section exists so the I2C
addresses are accounted for and a future audio issue knows the
chain.

## Power management

Two regulator chips share the work:

- **Rockchip RK817 PMIC** at I2C0 address `0x20`. Handles
  most rails (DCDC and LDOs for I/O voltages, RTC, GPIO,
  audio codec, battery monitor, charging). This is the chip the
  safety doc's scenario S5 ("never write voltage-setting
  registers") refers to.
- **SYR827 CPU regulator** at I2C0 address `0x40`. A high-current
  DC-DC dedicated to powering the four Cortex-A55 cores'
  voltage rail. Separate from the PMIC because the CPU rail
  needs more current than the RK817's internal DC-DCs can
  deliver. Same safety rule applies — we read it, we don't write
  it.
- A **CW2015** fuel gauge sits at I2C0 address `0x62` but is
  marked `disabled` in the device tree, which suggests Anbernic
  uses the RK817's own battery-monitor block instead.

The battery is a 4000 mAh polymer lithium cell, sealed.
Replacement requires opening the case, which the project rules
forbid. Battery monitoring and safe-shutdown thresholds are
therefore mandatory, not optional.

Wake sources for PMIC sleep mode include at least the power
button (always present), the USB-connect event (visible via
PMIC USB-detect bit), and the Hall switch re-opening (GPIO0 PC3
is marked `wakeup-source` in the device tree, so the kernel can
configure it as a wake input).

**Answered for the rails, still open for the gauge.** The PMIC
bring-up (114) reached the RK817 over i2c0 and read, wrote, and
set-path-tested it on hardware: all nine LDO rails read as
sensible voltages (LDO1/7/8 = 1.8 V, LDO2/3 = 0.9 V,
LDO4/5/6 = 3.3 V, LDO9 = 2.8 V; `mV = 600 + sel*25`, register
`0xCC + (n-1)*2`), a write round-trip passed on a safe register,
and the set path round-tripped without moving a rail. **Still
unknown:** the exact battery-gauge register surface of the RK817
vs the disabled CW2015 — likely irrelevant unless we re-enable
CW2015, which we won't.

## LEDs — three PWM channels, two physical lights

The device tree describes three PWM channels driving three pin
names — green, amber, red — but issue 103e's on-device diagnostic
(cycling each pin alone and watching which light responded)
established that on this board variant those three pins drive
**two physical lights**, not three: a bicolor top window with
independent green and red emitters behind one diffuser, and a
single-color amber bottom window. The full account and the
boot-stage pattern table live in
`docs/015-led-diagnostic-codes.md`.

Each pin is tied to a PWM channel rather than a plain GPIO, so
brightness is controllable: for on/off we drive 0% or 100% duty,
and the graded-brightness path is what the long-operation
"breathing" heartbeat uses. Issue 106c brought the PWM1 controller
up on hardware — ungating its gate (`CLKGATE_CON(31)`), deasserting
its reset, and routing the three pins to PWM function 1 via
`PMU_GRF_GPIO0C_IOMUX_H` — and a partial-duty test dimmed the red
emitter to confirm the duty path.

| PWM channel | Pin      | Drives                     |
| ----------- | -------- | -------------------------- |
| PWM5        | GPIO0_C4 | top window — green emitter  |
| PWM6        | GPIO0_C6 | bottom window — amber       |
| PWM7        | GPIO0_C5 | top window — red emitter    |

This is the data issue 106 (LED earliest boot signal) needed to
move from blocked to implemented: the boot-stage encoding maps
onto the two windows' eight combined states — green for healthy
progress, amber for in-progress slow operations, red for panic —
and the exact pattern table now lives in
`docs/015-led-diagnostic-codes.md`.

## Stock OS — Android 14 (we do not run it)

The shipped operating system is Android 14, built by Anbernic on
top of the Rockchip Android BSP. The vision (
`notes/vision/000-vision.md`) is explicit: we never run the stock
OS, not once. We achieve that by booting SoreOS from microSD on
the very first power-on of this project, never letting the boot
ROM fall back to eMMC until our own code is on eMMC.

The Anbernic Android image is irrelevant to us beyond the fact
that we will eventually overwrite the boot partition holding its
kernel. We do not interact with it, do not enumerate over USB
under its USB stack, do not let it touch the laptop. The risk
analysis behind that posture lives in the conversation that led
to issue 101 being closed, and the bricking implications of
overwriting the boot partition live in
`notes/safety/000-bricking-and-recovery.md`.

## Bootloader chain

The boot path on power-on, by layer (
`notes/safety/000-bricking-and-recovery.md` enumerates the same
chain in more depth):

1. Chip ROM (Maskrom). Burned into silicon. Checks SD first,
   then eMMC, then falls back to USB-Maskrom recovery if
   neither has a valid loader.
2. Rockchip miniloader (RKDDRBin). Initializes DDR. Loads u-boot.
3. u-boot. Reads partition table, loads kernel image, jumps.
4. Kernel image. Today: Android's. After issue 110b: SoreOS's.

Layers 1 and 2 are Rockchip's own and we keep them. Layer 3
(u-boot) is Anbernic's build today and we keep it (the safety
doc forbids overwriting it during routine flashing). Layer 4 is
what we replace.

## The install path SoreOS commits to

This is the answer to the "install path" question in issue 101,
and it differs from the path the roadmap and `phase-1-progress`
originally assumed. The original plan was to use chip ROM
recovery (Maskrom) for every kernel install during phase 1. The
new plan, decided during issue 101 to address concerns about
trusting closed-source Anbernic firmware on the USB bus, is:

1. **Boot from microSD for early phase 1.** Issues 102 through
   110 are iterated by writing the kernel image to a microSD card
   on the laptop (with a card reader the device never sees) and
   moving the card to the device. The Rockchip boot ROM picks
   the SD over the eMMC and SoreOS runs. Stock Android on eMMC
   is never invoked.

2. **Overwrite the eMMC boot partition once SoreOS can.** Three
   new issues — 110a (eMMC controller driver), 110b (bootable
   eMMC overwrite), 110c (USB-C flash protocol) — are inserted
   into phase 1 after the original 110. By the end of 110b, the
   SoreOS image lives on the eMMC's boot partition wrapped in
   the Android boot.img format that Anbernic's u-boot expects.
   u-boot loads our wrapped image and jumps into SoreOS. Stock
   Android's kernel is gone; u-boot, the miniloader, and the
   chip ROM are all untouched.

3. **Daily iteration runs over USB-C through SoreOS itself.**
   Issue 110c makes SoreOS-on-eMMC enter a flash-receive mode at
   boot if a flag is set (a button held, or a recent reset
   reason). The laptop-side build tool sends the new image over
   the USB CDC channel from issue 110, SoreOS writes it to the
   eMMC, SoreOS reboots. Both ends of the USB bus are code we
   wrote. Anbernic's firmware never participates.

4. **Recovery paths beneath this, in increasing order of pain.**
   - First failure (SoreOS on eMMC is broken): insert SD card
     with last-known-good SoreOS, boot from SD, re-flash eMMC.
   - Second failure (boot partition signature corrupted, u-boot
     refuses): re-flash via SD-boot with a tool that writes raw
     blocks to the boot partition.
   - Third failure (u-boot itself or the miniloader corrupted —
     a scenario the safety doc says to never enter intentionally):
     chip ROM Maskrom. Reachable from outside the case is
     unconfirmed for this device; the safety doc's research item
     stands.

Maskrom remains the deepest safety net but is not the daily
loop. We test it once, document the result, and never use it for
routine flashing.

## Open research items that fall out of this overview

These items are not blockers for starting issue 102 (cross-
compilation toolchain) and beyond, but each one will be needed
by a specific later issue. Tracked here so they don't get lost.

- ~~**Pull the ROCKNIX device tree for the RG DS**~~ — done.
  Source pulled from Heiko Stuebner's linux-rockchip `for-next`
  branch (the staging tree where Rockchip ARM device trees
  upstream into mainline). Harvested into every section above:
  LEDs, button GPIO map, Hall switch, touch controllers, panel
  IC, WiFi/Bluetooth chip family, audio codec, PMIC and CPU
  regulator, eMMC / microSD / WiFi-SDIO controller assignments.
  Several "known unknowns" that the rest of this document
  marked are now resolved; the remaining ones are listed
  in-section.
- **Phase-1 bring-up closed several more gaps.** The eMMC's
  HS200/HS400 capability and 200 MHz DLL lock, the RK817's rail
  map and read/write reachability, the DWC3 / USB2-PHY state, the
  VOP2 version, the APLL/GPLL/CPLL/NPLL frequencies, and the
  SAR-ADC's v2 lineage are all now measured on hardware — folded
  into the sections above and recorded with dates in
  `issues/phase-1-progress.md`.
- **Confirm IBSS support** on the Realtek WiFi chip on real
  hardware. Affects whether phase 7's plan needs adjustment.
- **Confirm Maskrom triggerability from outside the case.** The
  safety doc identifies this as the highest-priority outstanding
  research item independent of issue 101. If it cannot be
  triggered from outside, the design rules in the safety doc
  become mandatory rather than recommended.
- ~~**Read the JD9365DA-H3 panel datasheet** for issue 111a's
  initialization-register sequence.~~ — superseded. The sequence
  is carried by the upstream Linux panel driver
  `drivers/gpu/drm/panel/panel-jadard-jd9365da.c` (issue 111c);
  the DCS command table is transcribed from there rather than from
  the paper datasheet.
- **Probe for the six-axis gyro** when an app needs it. The
  mainline DTS doesn't list one; Anbernic's spec sheet does.
  Resolution waits on an actual scan of I2C0/I2C2/I2C3/I2C5 for
  unaccounted addresses (or alternatively, Anbernic's own
  Android device tree, which is harder to obtain). The probe
  engine drives i2c0 today but not the other three buses, so the
  scan needs a generalized i2c-bus-scan CALL target first.

## Sources

Public sources consulted during this research:

- Anbernic product page: https://anbernic.com/products/rgds
- Notebookcheck specifications coverage:
  https://www.notebookcheck.net/Anbernic-RG-DS-Global-launch-closing-in-as-Anbernic-reveals-specifications-for-new-Nintendo-DS-lookalike.1152291.0.html
- Handhelds Wiki repair guide:
  https://handhelds.wiki/Anbernic_RG_DS:RG-DS_Repair
- Retro Handhelds custom-OS install guide for the RG DS:
  https://retrohandhelds.gg/anbernic-rg-ds-how-to-install-gammaos-anbernic-linux-rocknix-and-knulli/
- ROCKNIX install gist for RG DS:
  https://gist.github.com/ggtylerr/75750b7b26627d6b9cd95edf12b6b92d
- Rockchip RK3568 datasheet V2.1 (June 2024):
  https://www.rockchips.net/wp-content/uploads/2025/03/Rockchip-RK3568-Datasheet-V2.1-20240621.pdf
- Rockchip Maskrom mode procedure:
  http://rockchip.wikidot.com/how-to-enter-rockusb-maskrom-mode
- Heiko Stuebner's linux-rockchip tree, where the RG DS DTS
  lives ahead of mainline:
  https://kernel.googlesource.com/pub/scm/linux/kernel/git/mmind/linux-rockchip/+/for-next/arch/arm64/boot/dts/rockchip/rk3568-anbernic-rg-ds.dts
