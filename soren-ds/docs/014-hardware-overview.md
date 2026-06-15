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

**Known unknowns:** which of the RK3568's clock trees, PMU
sub-blocks, and power gates Anbernic actually wired up — the chip
is configurable enough that the same datasheet covers a range of
board designs.

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

**Known unknowns:** the exact RAM type (LPDDR4 vs LPDDR4X), the
manufacturer, the size and offset of any reserved-for-GPU
carve-out the boot chain has already claimed at the moment our
kernel takes control. The page allocator built in issue 108 must
not hand out memory the GPU or the display controller already
holds.

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

The two devices use two distinct controllers inside the SoC. The
RK3568 has multiple SDMMC controllers; on the standard reference
design SDMMC0 owns the external microSD slot and SDMMC2 owns the
eMMC. We expect Anbernic to follow that convention but will
confirm against the device tree.

This is the foundation of the install path we adopted in the
section below.

**Known unknowns:** the exact eMMC manufacturer and part number,
the exact partition layout Anbernic shipped (the names and
offsets of the rest of `mmcblk2p1` through `mmcblk2pN`), the
SDMMC clock configuration Anbernic chose.

## Displays — dual 4-inch 640×480 IPS, capacitive touch

Two identical IPS panels, each 4 inches and 640×480 (4:3 each,
not "480p"). OCA full-lamination. Capacitive multi-touch on each,
with capacitive-stylus support advertised. Driven by the RK3568's
integrated VOP2 (Video Output Processor v2) display controller,
which has two independent video output paths (VP0 and VP1) — one
controller fans out to both screens, which is what
`docs/005-display-and-compositor.md` and issues 111a/111b assume.

**Known unknowns:** the panel's driver IC and its full
initialization register sequence (the long table of writes issue
111a depends on), the touch controller's chip and I2C address,
the backlight PWM channel and its rated maximum current.

## Sensors and switches

- **Six-axis gyroscope.** Mentioned on Anbernic's product page.
  Probably an InvenSense / TDK MPU-6xxx or STMicro LSM6 family
  part on the I2C bus. Not used by the launch apps but available
  to the modeller (phase 10) or any future app that wants
  orientation.
- **Hall switch for cover-closed sleep.** Mentioned on Anbernic's
  product page. Trips when the clamshell is shut. Wired to a
  GPIO that the kernel reads. This is exactly the signal phase 9
  issue 908 ("asleep and wake signals") needs.

**Known unknowns:** the exact gyro and Hall switch parts, their
GPIO/I2C wiring.

## Buttons and analog sticks

D-pad and L1/L2 on the left side. ABXY and R1/R2 on the right
side. Four center buttons in a row at the bottom of the lower
screen: `[start1][select1][select2][start2]`. Two clickable
analog sticks. Power and volume on the side edges.

Each digital button is wired to a GPIO pin (high or low depending
on whether the pull is configured). The analog sticks are routed
through an ADC for X and Y axes per stick. The exact GPIO and
ADC channel mappings are not in any public source we found —
they will come from the ROCKNIX device tree.

**Known unknowns:** the entire GPIO map of every button. The ADC
channel assignment of every analog axis. Whether any of the
buttons are wired through an I2C input expander instead of
direct GPIO. The exact location of the **Maskrom trigger button**
inside the case (the button or pad that, when held during power-
on, forces the chip ROM into recovery mode regardless of what is
on storage). Public sources do not name a hold-this-key recovery
combo for the RG DS specifically; either Anbernic exposed one and
no one has documented it, or there isn't one outside the case and
Maskrom can only be reached by removing the eMMC's boot signature
or by the running-OS path described in
`notes/safety/000-bricking-and-recovery.md`.

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
PD profile or only basic charging. Whether the type-C orientation
detection is handled in the chip or in a separate USB-C PHY chip.

## WiFi and Bluetooth

802.11a/b/g/n/ac (WiFi 5, dual-band 2.4 / 5 GHz) and Bluetooth
4.2. The actual chip is not named on Anbernic's spec sheet. On
similar-era handhelds the WiFi/BT combo chip is typically a
Realtek RTL8821 or RTL8852, an AIC AIC8800, or a SDIO module
that wraps one of those. The Rockchip reference designs route
WiFi over an SDIO controller (SDMMC1 in the standard pinout) so
that is the likely path.

The vision (phase 7) requires the radio to support **IBSS mode**
(ad-hoc, no router). Not every consumer WiFi chip supports IBSS;
Realtek chips generally do, AIC chips mostly do, but it is not
guaranteed. This is the single biggest hardware-side risk in
phase 7 and we should confirm IBSS support before phase 7 work
begins.

**Known unknowns:** the actual WiFi/Bluetooth chip part number,
whether it sits on SDIO or PCIe or UART, whether the driver in
the ROCKNIX device tree supports IBSS for it, the BT antenna
sharing arrangement.

## Audio

Stereo speakers, 3.5 mm headphone jack. The RK3568 has integrated
I2S/PCM controllers; an external audio codec sits on the I2S bus
and drives the analog outputs. On Rockchip reference designs the
codec is usually a Realtek ALC5640/RT5651, an Everest ES8316, or
Rockchip's own RK817 PMIC's combined audio block. Phase 1 does
not bring up audio. Phase 8's apps don't make sound either.
Audio is therefore deferred until something needs it; this
section exists so we know which I2C address ranges and I2S clocks
are claimed already.

**Known unknowns:** the codec part and its register surface. The
speaker amplifier (if any) and its enable GPIO.

## Power management

A separate PMIC handles the voltage rails, charging, and battery
gauging. On Rockchip RK3568 reference designs the PMIC is almost
always the Rockchip RK809 (a sibling part designed to pair with
the SoC). The PMIC sits on the chip's main I2C bus, exposes
register access to its rails and to battery percentage / USB
power presence / temperature, and is the source of the safety
rules in `notes/safety/000-bricking-and-recovery.md` scenario S5
("never write voltage-setting registers") and S7 ("monitor
battery voltage every few seconds").

The battery is a 4000 mAh polymer lithium cell, sealed.
Replacement requires opening the case, which the project rules
forbid. Battery monitoring and safe-shutdown thresholds are
therefore mandatory, not optional.

**Known unknowns:** PMIC part confirmation (RK809 expected, not
verified), the I2C address of the PMIC, the wake source list
(which signals can pull the device out of PMIC sleep — the power
button at minimum, ideally also USB-connect and the Hall switch
re-opening).

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

- **Pull the ROCKNIX device tree for the RG DS** and harvest
  the GPIO map, the WiFi chip identification, the touch
  controller, the audio codec, the gyro part, and the Hall
  switch wiring. Single biggest win for known-unknowns reduction.
- **Confirm IBSS support** on the WiFi chip identified above.
  Affects whether phase 7's plan needs adjustment.
- **Confirm Maskrom triggerability from outside the case.** The
  safety doc identifies this as the highest-priority outstanding
  research item independent of issue 101. If it cannot be
  triggered from outside, the design rules in the safety doc
  become mandatory rather than recommended.
- **Read the panel datasheet** (once the panel part is known
  from the device tree) for issue 111a's initialization
  sequence.
- **Confirm the PMIC is RK809** and read its register surface
  for safe-shutdown thresholds, wake source configuration, and
  the registers we are forbidden to write under safety scenario
  S5.

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
