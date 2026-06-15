# 106 — LED earliest-boot signal

## Current behavior

The kernel drives the device's three indicator LEDs through the
RK3568's PWM controllers — green on PWM5 (power), amber on
PWM6 (charging), and red on PWM7 (status). A small PWM driver in
`src/003-pwm.c` configures channels 5, 6, and 7 of the PWM1
controller block for continuous output with full-period duty,
exposing pwm_channel_set_duty as the on/off primitive. A higher-
level LED abstraction in `src/004-led.c` wraps that with a
boot-stage table — `kernel_main` calls `led_init` then
`led_set_stage(STAGE_KERNEL_MAIN)`, which turns green and amber
on and leaves red off as the first observable signal that the
kernel reached its C entry. `STAGE_PANIC_GENERIC` is reserved
for issue 105's panic handler, which sets red on and the others
off.

The pattern table lives in
`docs/015-led-diagnostic-codes.md`. The original sketch in this
issue listed two LEDs because the hardware overview at the time
hadn't pulled the device tree; pulling the tree showed three
LEDs, and the implementation uses all three.

Brightness gradations (the actual reason PWM was chosen over
plain GPIO) are not wired up at this layer; the LED driver only
ever drives full duty or zero duty. The PWM channels are still
configured, so any later issue that wants smooth fades can add a
brightness control without re-configuring hardware.

Blink rates (fast / slow blinking) are not implemented yet
either — they require a timer source we don't have until later
in phase 1. The boot-stage encoding for now is just solid
colors; the blink-coded panic patterns the original intended
behavior sketched are added when 105 brings up exception
handlers and a free-running counter is available.

## Intended behavior

The kernel drives the device's three LEDs to encode boot stages.
Specific colors encode specific kernel states. A developer
watching the LEDs can tell, without any cable connected, roughly
where the kernel is in its boot sequence and whether it has
hung.

The pattern table lives in `docs/015-led-diagnostic-codes.md`.
Indicative shapes (final choices made during implementation):

- Green only → bootloader running, our kernel has not yet
  touched the LEDs.
- Green + amber solid → kernel reached its C entry.
- Red solid (with green and amber off) → panic before any
  richer reporting channel was up.
- More patterns added by later phase 1 issues land in the same
  table.

The point is not rich diagnostic information — the LEDs cannot
transmit a stack trace. The point is *the device has a voice
when it has nothing else.* Once USB CDC-ACM is up (110), most
detail goes through that; the LEDs remain the backstop for
situations where USB itself is what's broken.

## Suggested implementation steps

1. From the hardware overview, identify which PWM channels
   drive the three LEDs, their colors, and their default state
   at boot.
2. Write a small PWM driver (`src/003-pwm.c`) that initializes
   the three channels, exposes per-channel duty control, and
   trusts the bootloader to have left clocks and pinctrl in
   the right state.
3. Write the LED abstraction (`src/004-led.c`) with a
   boot-stage enum and a switch that maps stages to LED
   patterns.
4. Wire `kernel_main` to call `led_init` and
   `led_set_stage(STAGE_KERNEL_MAIN)`.
5. Document the codes in `docs/015-led-diagnostic-codes.md` so
   a developer with a manual can decode what their device is
   stuck on.
6. Add a reserved `STAGE_PANIC_GENERIC` slot for issue 105 to
   use, even though 105 wires it up.

## Related documents

- `docs/002-roadmap.md` — phase 1.

## Blocked by

101 (LED GPIO mapping), 104.

## Blocks

105, 109.
