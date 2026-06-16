# 106b — LED layer drives the indicator lights through GPIO for phase 1

## Current behavior

The LED abstraction layer in `src/004-led.c` drives the three
indicator LED pins through the chip's GPIO controller. The
PWM-driven implementation it had before (described in issue
106 and extended in 106a) is replaced with GPIO writes that
do the same observable thing — turn each pin on or off —
without depending on the PWM controller's clock gate or the
pin-multiplexer being routed to PWM function. The existing
API the rest of the kernel uses (initialize the layer, set a
boot stage, raise a hello flash, advance the long-operation
heartbeat) is preserved; only the underlying register writes
change.

`led_init` opens the layer by writing once into the PMU
general register file to route the three LED pins
(GPIO0_C4 / C5 / C6) to pin function zero (plain GPIO),
once into the GPIO0 controller's data-direction high-half
register to mark those three pins as outputs, and once into
the GPIO0 controller's data high-half register to drive all
three pins low (all lights off). After this call returns, the
layer is ready to accept `led_set` calls.

`led_set` is the one-pin primitive every other LED operation
builds on. It maps a color name (green / amber / red — the
device tree's labels, kept for source compatibility with the
PWM-era code) to a specific pin bit in the GPIO0 data
high-half register and writes the appropriate value. The
write uses the chip-family's write-mask convention so the
pin not being changed by this call (and the fourth pin
sharing the register) stays untouched.

`led_hello`, `led_set_stage`, and `led_heartbeat` keep their
former signatures. The hello flash and the stage signal call
through to `led_set` with the same color / on-off arguments
the PWM-era code used; the patterns those arguments produce
on the actual hardware are described in the next section.
The heartbeat from issue 106a — which used the PWM
brightness register to fade a single LED in and out — is
replaced with a discrete amber-toggle: each call flips the
bottom amber LED between on and off. The signal content
("kernel still making forward progress through a long
operation") is preserved; the aesthetic loses the smooth
breathing in exchange for a steady blink.

## What hardware actually responds to each pin

The pin-mapping diagnostic from issue 103e found two
physical lights on the device's case rather than three, and
identified what each pin drives:

- The top window contains a bicolor LED — separate green and
  red emitters behind one diffuser. Driving GPIO0_C4 (the pin
  the device tree labels green) lights its green emitter;
  driving GPIO0_C6 (the device tree's red) lights its red
  emitter; driving both at once additively mixes to a
  yellow-amber appearance.
- The bottom window contains a single-color amber LED,
  driven by GPIO0_C5 (the device tree's amber pin).

The boot-stage table the rest of the kernel uses produces
this set of visible patterns:

| Stage signal              | Top window         | Bottom window |
|---------------------------|--------------------|---------------|
| `STAGE_KERNEL_MAIN`       | Green              | Dark          |
| `STAGE_USB_CONTROLLER`    | Dark               | Amber         |
| `STAGE_USB_ENUMERATED`    | Yellow-amber (G+R) | Amber         |
| `STAGE_BACKUP_COMPLETE`   | Red                | Amber         |
| `STAGE_PANIC_GENERIC`     | Red                | Dark          |

Each pattern is visibly distinct from every other, and from
the dark / power-on state. If the kernel hangs partway
through bring-up, the lights show the most recent stage it
reached — which is exactly the diagnostic needed to find
which bring-up step is blocking.

## Why GPIO instead of PWM for phase 1

The PWM-driven LED layer from issue 106 didn't work on
hardware. After the load-address fix (issue 103d) and the
GPIO probe (issue 103e) confirmed the kernel reaches its
entry point, the LEDs still showed no PWM activity. The PWM
controller needs more than register writes to its channels —
at minimum, its clock gate has to be opened in the chip's
clock-reset unit, and the three LED pins' pin-multiplexer
fields have to be routed to PWM function. The bootloader on
the SD-card path does not do that setup; the assumption in
`src/003-pwm.c`'s top comment that it does was wrong.

Bringing PWM up properly is a separate piece of work tracked
in issue 106c. For the immediate goal — getting the kernel
to boot far enough that the next bring-up step's failure is
observable — boot-stage signaling is binary, and GPIO is the
simplest mechanism that drives an LED on this chip. The
breathing heartbeat that 106a added comes back when 106c
lands.

The PWM driver code in `src/003-pwm.c` stays in source. It
is unused while this issue's GPIO-driven LED layer is the
one in effect, but issue 106c will call it again once the
clock and pinmux registers it depends on are configured.

## Calibration

The hello-flash and heartbeat constants from the 106a-era
code were calibrated for a 1.8 GHz CPU clock. Hardware
testing during 103e revealed the CPU is currently running at
something like the crystal frequency, at most a few tens of
megahertz — none of the bootloader stages on the SD-card
path ramp up the CPU's phase-locked loops. Every busy-wait
in the kernel takes roughly a hundred times longer than its
comments predict.

`HELLO_FLASH_CYCLES` is reduced from three hundred million
to seven million so each half of the flash lands at about a
quarter-second at the observed clock speed. When some
future issue brings the CPU clock up to its rated speed, the
constant scales back up to give the same wall-clock
duration. The comment on the constant names the calibration
point so a future reader knows to rescale rather than to
preserve the literal value.

## Implementation steps

1. Rewrite `src/004-led.c` so the implementation writes to
   the PMU general register file (at `0xFDC20014`) and the
   GPIO0 controller's data-direction and data registers
   (at `0xFDD6000C` and `0xFDD60004`) instead of to the PWM
   channel registers. The API the rest of the kernel calls
   (`led_init`, `led_set`, `led_hello`, `led_set_stage`,
   `led_current_stage`, `led_heartbeat`) keeps its existing
   signatures.
2. Replace the brightness-stepping heartbeat with a discrete
   amber-toggle. Drop the brightness state variables.
3. Recalibrate `HELLO_FLASH_CYCLES` from `300_000_000` to
   `7_000_000`, with the comment naming the observed clock
   speed the new constant is tuned against.
4. Remove the cycling probe from `src/001-boot.s` — the LED
   layer's `led_init` now performs the pin-mux override and
   direction setup the probe was doing, and the GPIO writes
   that drive the lights come from the LED layer on demand
   rather than from a forever-loop at the top of `_start`.
   `_start` returns to its normal shape: mask exceptions,
   set the stack pointer, zero `.bss`, install the vector
   table, branch to `kernel_main`.
5. Update `docs/015-led-diagnostic-codes.md` to describe the
   two-window vocabulary (top bicolor + bottom amber)
   instead of the three-discrete-LED model the document was
   written against. The pattern table and the "interpretation
   guide" both change shape; everything below ("adding new
   patterns," etc.) stays.
6. Leave `src/003-pwm.c` in place, untouched, as deferred
   code that issue 106c brings back to life.

## Related documents

- `docs/015-led-diagnostic-codes.md` — the pattern table
  this issue rewrites.
- `docs/016-physical-memory-map.md` — the PMU GRF and GPIO0
  register window addresses the new `led_set` uses.

## Blocked by

103e (the probe that mapped pins to physical lights).

## Blocks

Every remaining phase 1 issue that depends on observing
which kernel-side bring-up step is failing. Without a
working LED diagnostic, the next-step investigations
(USB / eMMC / SD bring-up failure modes) have no observable
signal.

## Parent

106.
