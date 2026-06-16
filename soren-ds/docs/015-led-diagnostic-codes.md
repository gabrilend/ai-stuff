# LED diagnostic codes

The Anbernic RG DS has three LEDs visible on the front edge of
the lower case. The kernel drives all three through the
RK3568's PWM hardware — green on PWM5, amber on PWM6, red on
PWM7 — using the small driver in `src/003-pwm.c` underneath the
LED abstraction in `src/004-led.c`.

Their state at any moment encodes roughly where in the boot
sequence the kernel is, or that it has hit a fatal exception.
A developer staring at the device with this table in hand can
decode "did the kernel make it past X?" without any cable
connected.

This document and the `boot_stage_t` enum in `src/004-led.c`
must stay in sync. Updating one without the other turns this
document into a lie.

## Pattern table

| Green | Amber | Red | Meaning |
| :---: | :---: | :-: | :-- |
| on    | off   | off | Either the bootloader is running but our kernel has not yet touched the LEDs (boot code did not start, or started but did not reach `kernel_main`), OR `STAGE_USB_CONTROLLER` (the kernel reached `kernel_main`, ran the allocator self-test, and brought up the USB controller successfully — the controller is alive but enumeration has not yet happened). The two states share an LED pattern because power-on default and our post-USB state happen to agree; the difference between them is observable only on the laptop side via plug-in `dmesg`. |
| on    | on    | off | `STAGE_KERNEL_MAIN`. The kernel reached its first C function but USB bring-up has not yet run. If you see this for more than a fraction of a second, USB bring-up hung or the controller failed identification. |
| off   | off   | on  | `STAGE_PANIC_GENERIC`. A fatal exception fired before any other diagnostic channel was up — or USB controller identification mismatched. Reserved for use by issue 105's panic handler and as the USB-bring-up failure signal. |
| on    | on    | on  | An unknown stage value was passed to `led_set_stage`. This is a kernel bug — the caller passed something the switch doesn't know about. |
| any   | any   | any | Patterns added by later phase 1 issues land here as those issues complete. |

## Reading the LEDs

The LEDs sit at the bottom of the lower screen on the front edge.
Hold the device closed (cover the top screen) to compare them
most easily. The amber LED is slightly brighter than green at
full duty; this is a property of the LED rather than a kernel
choice.

## Interpretation guide

**You see no LEDs lit at all.** The bootloader did not even
reach the point of lighting the power LED, or the power LED's
PWM channel was somehow disabled before our kernel ran. Either
your kernel image did not load (the SD card was empty, the
bootloader rejected the image, the kernel was linked at the
wrong address) or the bootloader was itself broken. The fix is
upstream of the kernel — check the build output, the flash
workflow, and the linker script's load address.

**You see only the green LED.** The bootloader handed off to
our kernel's load address, but our code never reached
`kernel_main`. Possible causes: a fault in the boot code at
`src/001-boot.s` before the branch into C, a bad linker script
that put `_start` somewhere other than the load address, a
mismatched expectation about which exception level the
bootloader hands off at. Inspect the disassembly of the kernel
ELF in `tmp/build/kernel/kernel.elf` and confirm the symbol
addresses match what the linker script pins.

**You see green + amber solid.** The kernel is alive and idle.
This is `STAGE_KERNEL_MAIN`. The kernel reached its first C
function, set its LED pattern, and is now sitting in WFI waiting
for the next phase 1 issue to give it something to do.

**You see green + amber + red, all three solid.** The kernel
called `led_set_stage` with a stage value the switch statement
does not know about. Look for a recently added `boot_stage_t`
enum member that doesn't have a matching switch case yet.

**You see green off, amber off, red solid.** The kernel hit a
fatal exception before any richer reporting channel was up. The
LED pattern is the only output. Future issue 110 (USB CDC-ACM
debug stream) will enrich the panic output with a text
description, but until then a solid red is all we have. The
appropriate response is to power-cycle the device, re-flash a
known-good kernel image, and inspect what changed since the last
successful boot.

## Adding new patterns

Adding a stage means three coordinated changes:

1. Add a new value to `boot_stage_t` in `src/004-led.c`.
2. Add a matching `case` in the `switch` inside `led_set_stage`
   that sets the LED state for that stage.
3. Add a row to the pattern table above with the LED columns
   filled in.

The order is to write the pattern row first — saying what the
LEDs should mean in human language gives you a clearer name for
the enum constant than starting from code.
