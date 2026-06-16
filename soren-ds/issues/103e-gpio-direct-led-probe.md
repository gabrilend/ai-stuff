# 103e — Direct-GPIO LED probe at the kernel's entry point

## Current behavior

The very first instructions the kernel runs after the boot
chain hands control off — sitting between the asynchronous-
exception mask in `_start` and the stack-pointer setup that
follows it — are a four-write diagnostic sequence that drives
the three indicator LEDs directly through the chip's GPIO
controller, bypassing the PWM hardware the existing LED layer
uses. The four writes are:

- Pin-multiplexer override. The PMU general register file
  holds a four-bit function field for each chip pin in the
  always-on power domain. The three LED pins
  (GPIO0_C4 / C5 / C6 in the chip's naming) are reset to
  function zero (plain GPIO) by a single write into the
  function field of the high-half pin-multiplexer register at
  PMU_GRF + 0x14. The bootloader may have left them in any
  function — PWM, SARADC, GPIO, or some passthrough — and the
  override guarantees the GPIO controller owns them when the
  next two writes go through.
- Direction. The GPIO0 controller's data-direction high-half
  register at GPIO0 + 0x0c gets a write that flips bits 4, 5,
  and 6 (the bits that correspond to pins 20, 21, and 22 in
  the controller's flat-numbering view of its 32 pins) to one,
  marking those three pins as outputs.
- Output value. The GPIO0 controller's data high-half register
  at GPIO0 + 0x04 gets the same bits set to one, driving the
  three pins high.
- A busy-wait pattern. The kernel waits, drops the pins low,
  waits again, and brings them back high before continuing.
  The pattern reads as a wink: about two seconds of light, a
  second of darkness, and the lights come back on and stay on
  through whatever happens next.

All three register writes use the chip-family's write-mask
convention. Each thirty-two-bit write splits into an upper-half
mask that picks out which lower-half bits the hardware will
actually update, and a lower-half value the hardware copies
into the picked bits. Bits the mask does not pick stay
unchanged. The convention lets us touch the three pins we care
about without disturbing the fourth pin sharing each register
or any other config bits the bootloader may have set.

The probe runs once. After its third write completes the rest
of `_start` runs normally (stack-pointer setup, BSS zeroing,
vector-table install, branch to `kernel_main`). The existing
PWM-driven LED layer still calls into the PWM controller as
before, but because the probe took the three pins out of PWM
function and into GPIO function, the PWM controller's output
goes nowhere — the LEDs stay in whatever GPIO state the probe
left them in (high, on), regardless of what `led_set_stage` or
`led_hello` later try to do. This is intentional. The probe is
diagnostic and lives at the top of `_start`; once we know
whether the kernel reaches it, the probe and the
incompatibility with the PWM-driven LED layer come out
together.

## Why this exists

The previous boot-from-SD test, after the linker-and-bootloader
load-address mismatch was repaired, still produced no LED
activity. Hardware-side observation could not distinguish:

- the kernel is not reaching its entry point at all (a boot
  chain failure upstream of `_start`),
- the kernel is reaching its entry point but the PWM
  controller cannot drive the LEDs because the bootloader did
  not configure the three pins' pin-multiplexer to route them
  to PWM output, or
- the kernel is reaching its entry point but the PWM
  controller's clock is gated and writes to its registers are
  ignored.

The first hypothesis is the most catastrophic — it means
nothing the kernel does will be observable, ever, until
something upstream of the kernel changes. The second and third
hypotheses are recoverable from inside the kernel by writing
to the right peripheral and clock-controller registers. We
cannot decide between them while the LED layer's only output
path runs through the PWM controller, because that path
itself depends on both pin-multiplexer state and clock state.

The probe takes the simplest path that lights an LED: it talks
to the GPIO controller directly. GPIO is the chip's reset
default for these pins, requires no separate clock enable in
the PMU power domain (the GPIO0 controller is in the always-on
PMU clock subtree), and produces an immediate observable
signal. If the LEDs light, the kernel reached `_start`, the
chip's bus is responsive enough for us to touch the PMU GRF and
the GPIO0 controller, and the PWM-layer silence is downstream
of these things — fixable from inside the kernel by walking
through pin-multiplexer and clock-gate registers. If the LEDs
still stay dark with the probe in place, the kernel is not
reaching `_start`, and the next investigation moves further
upstream (the bootloader, the recognition envelope, the load
address).

## Things this issue does not do

- *Stay in the codebase.* The probe is a temporary diagnostic.
  After it tells us which side of the kernel-reaches-`_start`
  question we are on, the probe and the GPIO-function override
  it does at `_start` time both come out — either replaced by a
  proper PWM-side fix to the LED layer, or replaced by a
  permanent GPIO-driven LED layer that does not collide with
  the PWM driver further down the boot. The probe is marked in
  source as temporary so a future reader is not surprised by
  the override surviving past its diagnostic purpose.
- *Drive the LEDs as part of the kernel's regular operation.*
  Setting the three pins high once at the start of `_start` is
  not a substitute for the LED layer's boot-stage-encoded
  signal vocabulary. The probe answers a single yes/no
  question; it does not encode anything else.
- *Investigate the PWM clock or pin-multiplexer state.* If
  the probe confirms the kernel is reaching `_start`, the next
  issue picks up the PWM-side investigation — walking the
  clock-gate register that holds the PWM1 controller's enable
  bit, and the pin-multiplexer registers that route the three
  LED pins to PWM output. That work has its own constants and
  its own register sequence; it is out of scope here.

## Implementation steps

1. Add a comment-block-led sequence of assembly instructions
   to `src/001-boot.s`, inserted immediately after the existing
   `msr DAIFSet, #0xF` mask and immediately before the
   stack-pointer setup. The sequence performs the four writes
   described in the current-behavior section, using `movz` /
   `movk` pairs to construct the register addresses and data
   words (no literal-pool loads, because the literal pool has
   not been reached yet when execution arrives at this code).
2. Use Rockchip's write-mask convention for all three peripheral
   writes. For the PMU GRF write, the mask is bits 16-27 and
   the value is zero, clearing the function fields for
   GPIO0_C4 / C5 / C6 to function 0 (GPIO). For the GPIO0 DDR
   and DR high-half writes, the mask is bits 20-22 and the
   value is bits 4-6 set to one, marking the three pins as
   outputs and driving them high.
3. Calibrate the busy-wait counts so the wink pattern is
   visible at the chip's typical 1.8 GHz operating point but
   does not stretch to minutes if the bootloader handed off
   running at the chip's 24 MHz crystal frequency. Two
   different counters (long and short) give the wink its
   asymmetric on-off-on shape.
4. Document the probe's lifetime in source so a future reader
   does not assume the GPIO-function override is the kernel's
   permanent policy on these pins.
5. Build, push, flash, observe. If the LEDs light, this issue
   closes with the kernel-reaches-`_start` question answered
   yes, and a follow-on issue picks up the PWM-side work. If
   the LEDs stay dark, this issue stays open while the next
   investigation moves further upstream of `_start`.

## Related documents

- `docs/016-physical-memory-map.md` — peripheral register
  windows table, the source-of-truth for the PMU GRF and GPIO0
  base addresses the probe writes to.
- `docs/015-led-diagnostic-codes.md` — the existing LED-pattern
  documentation, which the probe deliberately does not match.
  Once we know the probe works, the diagnostic-codes document
  gains a row describing the wink pattern; while the probe is
  in place, the existing patterns are unreachable because the
  PWM-driven LED layer has no path to the pins.

## Blocked by

103d (the load-address fix, without which the kernel does not
run from the address its own pointers name and the probe
cannot run correctly even if `_start` were reached).

## Blocks

Closing the open hardware-side question on whether any of the
phase 1 kernel issues that depend on the kernel running
(everything from 109a onward) have ever observed real
hardware. While that question is open, the no-LEDs symptom
masks all downstream behavior.

## Parent

103.
