# 106c — Bring up the PWM controllers properly for phase 1

## Current behavior

The PWM driver in `src/003-pwm.c` writes to the per-channel
registers of the PWM1 controller block, but the controller
itself is not in a state where those writes drive output. Two
things the bootloader on the SD-card path does not configure
for us — both of which the PWM driver currently assumes are
already in place — keep the PWM signal from reaching the LED
pins. The first SD-card boot test surfaced this as silent
LEDs when the LED layer drove its PWM channels at full duty;
the diagnosis (issue 103e) confirmed the kernel reaches the
PWM writes and the writes are landing at the right addresses,
which leaves "the controller isn't running" and "the pins
aren't routed to the controller's output" as the remaining
possibilities. The LED layer pivoted to GPIO output in issue
106b so phase 1 hardware bring-up can proceed without
waiting on this work.

The deferred work is to add two register-write sequences to
the PWM driver:

- A clock-gate write into the chip's main clock-reset unit
  (CRU) at `0xFDD20000`. The PWM1 controller block draws
  both a per-channel "pwm" clock and a peripheral-bus
  "pclk" clock from the CRU; the device tree's clock-cells
  entry for `pwm@fe6e0010` names clock IDs `0x15a` (the pwm
  clock) and `0x159` (the pclk). The CRU's clock-gate
  registers (`CLKGATE_CON_<n>`) carry one bit per gated
  clock, write-mask-encoded the same way the GRF and GPIO0
  registers are. Writing the appropriate bit to zero
  ungates the clock; the controller's counter then ticks
  and its output toggles per the duty register.
- A pin-multiplexer write into the PMU general register
  file at `0xFDC20014` (`PMU_GRF_GPIO0C_IOMUX_H`). The
  three LED pins — `GPIO0_C4 / C5 / C6` — currently sit in
  pin function zero (plain GPIO), the function the GPIO-
  driven LED layer set them to. Routing them to function
  one (PWM) lets the PWM controller's output reach the
  pads. The write-mask convention is the same one
  `led_init` uses for its function-zero write; only the
  value half changes (each four-bit function field becomes
  `0x1` instead of `0x0`).

A possible third step: deasserting the controller's reset in
the CRU's `SOFTRST_CON_<n>` registers. Investigate during
implementation; not every Rockchip controller block needs
explicit reset deassertion, but PWM1 might.

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

Bringing PWM up cleanly requires register-by-register
investigation across two peripheral blocks (the CRU and the
PMU GRF) and a bit-position discovery from the chip's
technical reference manual that the project has not
harvested yet. The bring-up is not strictly necessary for
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
  register window addresses. The clock-gate register
  offsets and bit positions identified during step 1 are
  recorded here.
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
