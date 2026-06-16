# 106a — Visible heartbeat during long operations

## Current behavior

The LED layer in `src/004-led.c` sets a static pattern for each
boot stage and that pattern stays unchanged until the next stage
is reached. During phase 1's long-running steps — in particular
the eMMC-to-SD backup that copies 32 GB sector by sector and
takes several minutes — the LED gives no indication of progress.
A developer staring at the device cannot tell whether the kernel
is making forward progress, has hung partway through, or has
finished.

Additionally, the bootloader-default LED state (green on, per the
comments in `003-pwm.c` and `004-led.c`) is supposed to make
"the kernel has booted" visible the moment u-boot hands off. With
ROCKNIX's u-boot on the SD-card development path, this default-on
state is not reliably present — the first hardware test of the
SD-card boot showed all three LEDs dark at power-on. The first
stage signal `STAGE_KERNEL_MAIN` (green + amber, both on)
becomes ambiguous in that situation: "no LEDs at all" could
mean "the kernel never started" or "the kernel started but
never reached its first stage signal," and the developer has
no way to tell which.

## Intended behavior

Two additions to the LED layer.

`led_hello()` briefly lights all three LEDs together, holds the
flash for a fraction of a second, then turns all three off and
holds again. Called from `kernel_main` immediately after
`led_init()` and before the first stage signal. Its sole purpose
is the diagnostic message "the kernel reached `kernel_main`" —
independent of whether the bootloader left any LEDs lit. If the
developer sees the flash on power-up, the kernel ran. If they
see nothing at all, the boot chain failed somewhere upstream of
the kernel.

`led_heartbeat()` advances one step of a breathing pattern on
the amber LED. Each call moves the amber LED's PWM duty cycle
by one step along a fade-in / fade-out sequence, using the PWM
hardware's actual brightness control rather than just on/off.
Called from `emmc_backup_to_sd` at the same cadence as the
existing CDC-ACM progress narration (roughly every megabyte
copied). Over the course of the backup, the amber LED visibly
breathes — fades up, fades down, repeats — so the developer can
see "still working" at a glance.

Both functions rely on a small `delay_busy(cycles)` utility in
`src/002-main.c`: phase 1 has no clock source until interrupts
land, so timed pauses are produced by counting `nop` instructions
in a `volatile`-counter loop. The delay parameter is approximate
— the actual wall-clock time depends on what CPU frequency the
bootloader booted us at — but is calibrated for visibility at
typical RK3568 operating frequencies.

After this issue closes:

- The very first sign of life after power-on is the
  `led_hello()` flash — all three LEDs together, briefly. This
  is independent of which stage signal happens to share its
  pattern with the bootloader-default state.
- During the eMMC backup, the amber LED breathes at a roughly
  one-second cadence. If breathing stops mid-backup, the kernel
  is stuck on a particular sector.
- The diagnostic-codes document is updated with the new
  patterns so a developer with the document in hand can decode
  any moment of the boot.

## Why the LED matters as a diagnostic channel

It is the only feedback channel until USB CDC-ACM is connected
to a host. Even after USB enumeration, if no host is connected,
the LED remains the only signal. A static post-stage LED
pattern during a multi-minute operation is indistinguishable
from a hung kernel; the developer has no way to know whether to
wait or to power-cycle.

The hello flash is also the cheapest possible diagnostic for
the boot chain. The first hardware test of the SD-card boot
showed all-LEDs-dark — the hello flash makes future tests
unambiguous about whether the boot chain reached the kernel.

## Why breathing rather than blinking

The user requested a gentle "humming or breathing" signal — not
a strobing blink. PWM hardware is what drives the LEDs in this
project, so fading in and out is mechanically simple: each
`led_heartbeat()` call advances the amber LED's duty cycle by
one step in the current direction. The fade-in / fade-out cycle
spans about a hundred steps; at roughly one heartbeat call per
megabyte of backup, a full breath takes a small fraction of the
total backup time, and the developer sees many breaths over the
multi-minute run.

## Implementation steps

1. Add `delay_busy(uint64_t cycles)` to `src/002-main.c` — a
   `volatile`-counter busy-wait with a `nop` inside the loop
   body. Forward-declare it from `004-led.c` (no header file yet
   per phase 1 conventions).
2. Add `led_hello()` to `src/004-led.c` — all three LEDs on
   together, `delay_busy` pause, all three off, `delay_busy`
   pause again.
3. Add `led_set_brightness(color, brightness)` to
   `src/004-led.c` as a `static` helper — same shape as the
   existing `led_set` but accepting a duty cycle value rather
   than a boolean. `led_heartbeat` calls it.
4. Add `led_heartbeat()` to `src/004-led.c` — advances internal
   step + direction state, computes a duty cycle from the
   current step, applies it to the amber LED.
5. In `kernel_main` (`src/002-main.c`), call `led_hello()`
   right after `led_init()` and before the first stage signal.
6. In `emmc_backup_to_sd` (`src/016-emmc-backup.c`),
   forward-declare `led_heartbeat` and call it inside the
   existing progress check.
7. Update `docs/015-led-diagnostic-codes.md` — describe the
   hello flash, the breathing pattern, and add a row to the
   "Interpretation guide" for "a brief all-LEDs flash, then a
   stage signal" meaning "the kernel reached `kernel_main`."

## Related documents

- `docs/015-led-diagnostic-codes.md` — the pattern table the new
  flashes need to be documented in.
- `src/003-pwm.c`, `src/004-led.c` — the PWM and LED layers this
  extends.

## Blocked by

None.

## Blocks

Nothing structurally, but the hello flash is the prerequisite
for confidently iterating on the SD-card boot chain — without
it, the developer cannot distinguish a boot-chain failure from
a kernel-runtime hang on any given test cycle.

## Parent

106.
