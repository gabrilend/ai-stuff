# Recovery and download-mode access

This is the working answer to the bricking doc's single most important
unknown — *can we push new code onto a wedged device without opening the
case?* (`notes/safety/000-bricking-and-recovery.md`, "The Maskrom access
question"). Most of it is read straight out of **Anbernic's own u-boot**,
carved from the factory archive (`archives/bootchain-20260701-130529.bin.gz`,
U-Boot SPL 2017.09 fwver v1.14), rather than guessed.

## What Maskrom is, and what "program it" means

Maskrom is not an OS and does not boot to one. It is the tiny loader
burned into the RK3568 silicon; on reset, if it finds no valid next-stage
loader on any boot medium (or a forcing pad is held), it turns the USB-C
port into a device — Rockchip vendor `0x2207`, product `0x350a` — and
**waits for a host to upload code**. The host tool is `rkdeveloptool`.

You cannot reprogram Maskrom itself: it is mask-programmed silicon, which
is exactly why it is the unbrickable floor. What you *can* do is drive it:
the host sends a small DDR-init loader into on-chip SRAM, and from there
pushes anything — a flasher, or images written straight to the eMMC. So
"program it" means *use it to program the device*, not *change the ROM*.

## Three doors into download mode

There are three distinct ways to reach a "push code over USB" state, and
they are easy to conflate:

1. **The ROM's own hardware Maskrom pad.** A test point the ROM samples at
   reset. Location on the RG DS is still undocumented — the outstanding
   item best answered by FCC-filing internal photos or a teardown. u-boot
   is *not* involved in this path.

2. **The ROM auto-entering Maskrom when no loader is valid.** If the eMMC
   loader is absent/corrupt *and* no bootable SD is inserted, the ROM
   falls through to Maskrom on its own — no button needed. This is the
   **wipe-and-push recovery lever** (see below), and it needs no secret
   pad.

3. **u-boot's own download triggers.** u-boot, once running, checks for
   its own escape sequences and can either serve a USB download protocol
   itself (rockusb / fastboot) or *request a reboot into Maskrom*. This is
   how u-boot "interacts with" Maskrom — not by knowing the ROM's pad, but
   by setting a reboot flag the ROM reads on the next reset. The combos
   below are u-boot's, read by u-boot.

## What Anbernic's u-boot actually checks (from its strings)

Pulled from the `uboot` partition of the factory archive:

- **`ctrl+b: Bootrom download!`** — the classic Rockchip serial escape.
  Sending Ctrl+B on the u-boot console reboots into Maskrom (door 3 →
  door 2). Needs UART access; the RG DS exposes no external UART header
  (`docs/016`), so this path likely means opening the case — less useful
  to us than the button path.
- **`volumeup-key`, `keyup-threshold-microvolt`, `press-threshold-microvolt`**
  — the recovery/download key is an **ADC-read Volume-Up**, defined with
  voltage thresholds (the standard Rockchip `adc-keys` binding, read
  through the SAR-ADC). This strongly indicates that **holding Volume Up
  at power-on** drops the device into u-boot's download/recovery mode —
  an *external* button, no case-opening required.

**Scope / honesty:** this is strings-level evidence — the mechanisms are
present in the binary and match Rockchip convention. It is not a full
disassembly of the key-check code, so which exact threshold maps to
which action (recovery vs. loader vs. Maskrom) is not yet proven. The
confirming test is cheap and non-destructive: hold Volume Up while
powering on with USB-C attached, and watch the host for either a Rockchip
download device (`0x2207:0x350a`) or a fastboot device enumerating.

## The wipe-and-push recovery lever

The most robust external recovery does not depend on finding any button:

1. Boot a recovery kernel **from SD** (the ROM prefers SD, and the SD
   carries its own independent loader — `libs/sd-image-parts/`).
2. From there, **erase the eMMC's loader region** (or the whole card).
3. Remove the SD and reset. With no valid loader on eMMC and no SD, the
   ROM **auto-enters Maskrom over USB-C** (door 2).
4. `rkdeveloptool` pushes whatever we want to the internal drive.

This is a software trigger for Maskrom that needs no secret pad and no
open case. Its one dependency is that Maskrom enumerates over the
*external* USB-C port — which is the same OTG controller and connector
the device already uses (`docs/014`), so it almost certainly does; it is
worth confirming once and recording here.

## How this moves the safety doc's #1 unknown

Before: "we may have no way back into a hard-bricked device without
opening the case." Now there are **two** candidate external paths that
avoid both the case and the stock Android boot the safety doc disliked:
the Volume-Up download key (to confirm), and the wipe-from-SD → Maskrom
lever (mechanically sound, one enumeration test to confirm). The unknown
is not closed, but it is narrowed from "unknown if any path exists" to
"two plausible paths, each one test from confirmed." Update
`notes/safety/000-bricking-and-recovery.md` and the `014` Maskrom entry
once either is verified on hardware.

## Source

- `archives/bootchain-20260701-130529.bin.gz` — Anbernic's boot chain;
  the u-boot strings above come from its `uboot` partition.
- `notes/safety/000-bricking-and-recovery.md` — the recovery-scenario
  ranking this narrows.
- `docs/024-emmc-partition-map.md` — where `uboot`/`trust` live on eMMC.
