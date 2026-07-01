# 106c — Bring up the PWM controllers properly for phase 1

## Current behavior

The PWM1 controller is up and drives the indicator lights through
its duty-cycle hardware — brought up, proven dim on real hardware,
and already carrying the two places where smooth brightness matters
most. What the SD-boot bootloader leaves undone, the driver now
does itself (`led_pwm_init` in `src/003-pwm.c`): three register
moves before the per-channel setup.

- **Ungate the PWM1 clock.** `CLKGATE_CON(31)` at `0xFDD2037C`,
  bits 10 (`PCLK_PWM1`) and 11 (`CLK_PWM1`) written to zero
  (mask-and-value word `0x0C000000`) so the block's counter ticks.
  Belt-and-braces: the block is already clocked at u-boot handoff
  (the green light is lit then), so this is harmless if redundant.
- **Release the PWM1 resets.** `SOFTRST_CON(23)` at `0xFDD2045C`,
  bits 0 (`SRST_P_PWM1`, APB) and 1 (`SRST_PWM1`, functional),
  deasserted (`0x00030000`).
- **Route the pins to PWM.** The three LED pins `GPIO0_C4/C5/C6`
  sit in plain-GPIO function zero (where the GPIO-driven LED layer
  left them); `PMU_GRF_GPIO0C_IOMUX_H` at `0xFDC20014` moves all
  three to function one (value `0x0FFF0111`) so the controller's
  output reaches the pads.

With those in place the per-channel PERIOD (`+0x04`) and DUTY
(`+0x08`) registers behave as the TRM describes, and brightness is
just a `current/max` fraction written as duty. The top window
blends its red and green emitters by their two duty ratios into a
colour; the bottom window is amber brightness only (`led_top` /
`led_bottom` in `003-pwm.c`). The register offsets, bit positions,
and mask convention are all recorded in
`docs/017-clocks-and-timers.md`.

**The cross-domain-routing worry turned out to be a non-issue.**
The three channels live in the *main-domain* PWM1 block while the
pins are in the *PMU-domain* GRF; hardware confirmed function-1 on
those pins does reach these channels.

**A latent driver bug surfaced and was fixed.** The original driver
had the per-channel PERIOD and DUTY offsets swapped (TRM Part1 Ch15
puts PERIOD at `+0x04`, DUTY at `+0x08`). It stayed invisible
because the LED layer only ever drove full-on or full-off duty,
where the swap does not show; the first partial-duty test came back
*bright* instead of dim and exposed it. Fixed in both `003-pwm.c`
and the bring-up probe.

**Confirmed on hardware (2026-06-29).** The bring-up probe
(`input/probes/pwm-bringup.probe`) ungates/deasserts PWM1, drives
the red channel at ~10% duty, and re-muxes only its pin — leaving
green and amber on the GPIO diagnostic as a control. It came back a
steady **dim red**: controller clocked, partial duty honoured,
function-1 routing working. (Commit: "PWM dimming — confirmed on
device.")

**Where the PWM path is used today.** Three layers drive it:

- The **boot-stage indicator layer** (`src/004-led.c`) now drives
  every ordinary stage signal, the hello flash, and the backup
  heartbeat through the PWM duty path — `led_init` calls
  `led_pwm_init`, `led_set` writes full/zero duty, and the heartbeat
  breathes again (a tenth-of-full triangle on the amber channel).
  The GPIO code — the PMU-GRF pinmux to function zero, the GPIO0
  direction and data writes — is gone. The visible on/off stage
  vocabulary is unchanged, so the diagnostic-codes table still holds;
  graded brightness and the top-window colour blend are now available
  to any future stage that wants them.
- The **probe sweep** (`src/019-probe-engine.c`) calls
  `led_pwm_init` at the start of a run, shows a green "running" top
  window, fills the amber bottom window as a smooth progress bar
  across the probe count, and ends on red = done.
- The **eMMC long operations** (`src/012-emmc.c`) drive the amber
  window as a breathing progress heartbeat during a backup or dump
  — the smooth "still working" signal issue 106a wanted and 106b
  had downgraded to a discrete toggle.

**What remains.** Only a hardware smoke-test. The boot-stage layer
rewrite (step 5) is done in source; the one thing to confirm on
device is that the earliest "kernel alive" signal — the hello flash
and `STAGE_KERNEL_MAIN` — still lights now that it depends on the PWM
bring-up rather than the always-on GPIO controller. PWM1 is already
clocked at u-boot handoff (the green light is lit before our kernel
runs) and the main-domain clock unit is already reached at the top of
`kernel_main` for the watchdog silence, so the risk is low — but the
signal is load-bearing enough (it is the "did the kernel start at
all?" tell) to warrant an explicit look before the issue closes.

## Intended behavior

After this issue closes, the PWM1 controller drives the
three LED pins through its duty-cycle hardware. The LED
layer (`src/004-led.c`) returns to PWM-based control of the
indicator lights — `led_set` calls `pwm_channel_set_duty`,
the heartbeat from issue 106a's design replaces the discrete
amber-toggle that 106b put in its place, and the breathing
heartbeat is observable during the multi-minute eMMC-to-SD
backup. The three LED pins are no longer GPIO-controlled;
the kernel writes to PWM duty registers and the chip's
internal multiplexer carries those writes to the pads.

## Why deferred

Bringing PWM up cleanly required register-by-register
investigation across two peripheral blocks (the CRU and the
PMU GRF) and a bit-position discovery from the chip's
technical reference manual — all now harvested and recorded in
`docs/017-clocks-and-timers.md`, and the controller itself is up
(see current behavior). The remaining deferral is only the
boot-stage LED layer rewrite (step 5). The bring-up is not
strictly necessary for
any kernel feature that phase 1's roadmap calls for — the
GPIO-driven LED layer carries the boot-stage signal
vocabulary the diagnostic-codes document specifies, and the
discrete heartbeat is a sufficient if uglier substitute for
the breathing one during the long backup. Deferring lets
phase 1's downstream work (USB / eMMC / SD bring-up,
framebuffer, etc.) proceed with a working diagnostic
channel.

## Implementation steps

1. Identify the CRU clock-gate register offset and bit
   position for clock IDs `0x159` (pclk_pwm1) and `0x15a`
   (clk_pwm1) from the chip's TRM or the Rockchip CRU
   driver in the mainline Linux tree
   (`drivers/clk/rockchip/clk-rk3568.c`). Record the
   findings in `docs/016-physical-memory-map.md` so they are
   available to future driver work.
2. Add a `pwm_clock_enable()` function to `src/003-pwm.c`
   that writes the ungate value to the appropriate
   `CLKGATE_CON` register. Reference the recorded findings
   from the doc.
3. Add a `pwm_pinmux_set()` function to `src/003-pwm.c`
   that writes function one (PWM) to the three LED pins'
   fields in `PMU_GRF_GPIO0C_IOMUX_H`. The write-mask
   convention matches the GPIO-function write in
   `led_init`; only the value half changes.
4. Update `pwm_init` to call the clock-enable and pinmux
   functions before configuring the per-channel registers.
   Reset deassertion goes in here too if it turns out PWM1
   needs it.
5. Rewrite `src/004-led.c` to call `pwm_init` and route
   `led_set` back through `pwm_channel_set_duty`, replacing
   the GPIO-based implementation from issue 106b. The
   heartbeat returns to the brightness-stepping design from
   106a. Update the comment block in `004-led.c` so the
   "what's happening underneath" matches the new mechanism.
6. Rebuild the boot test and confirm the heartbeat breathes
   visibly during the eMMC-to-SD backup. Update the LED
   diagnostic-codes document if the visible vocabulary
   changes (e.g., new brightness gradations between off and
   on become available for stage signals).

## Related documents

- `docs/016-physical-memory-map.md` — CRU, PMU GRF, GPIO0
  register window base addresses.
- `docs/017-clocks-and-timers.md` — the CRU clock-gate and
  soft-reset register layout. The PWM1 clock-gate offsets
  and bit positions identified during step 1 are recorded
  there alongside the USB and watchdog entries already in
  the catalogue.
- `docs/015-led-diagnostic-codes.md` — pattern table the
  LED layer rewrite touches.
- `src/003-pwm.c` — the PWM driver this issue brings back
  to life.

## Blocked by

106b (the GPIO-driven LED layer must work for diagnostics
while PWM is being brought up; investigating PWM bring-up
without a working LED signal would be flying blind).

## Blocks

The breathing heartbeat from issue 106a being available as a
diagnostic during long operations. The discrete blink from
106b is a sufficient substitute; the breathing is a nice-
to-have, not a hard dependency for any other issue.

## Parent

106.
