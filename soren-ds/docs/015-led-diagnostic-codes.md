# LED diagnostic codes

The Anbernic RG DS has two indicator lights visible on the
front edge of the lower case, not three. The chip-side device
tree describes three PWM channels driving three pin names —
green, amber, red — but on this board variant those three
pins drive two physical lights: a bicolor top window with
separate green and red emitters behind one diffuser, and a
single-color amber bottom window. Issue 103e's hardware
diagnostic mapped this out by cycling each pin alone and
watching which physical light responded.

The kernel currently drives all three pins through the chip's
GPIO controller, not its PWM controller (issue 106b). Boot
stage signals are binary on/off; the PWM-side smooth-fade and
breathing-heartbeat vocabulary returns when issue 106c brings
the PWM controllers up cleanly. Until then the layer's
vocabulary is "each pin on or off, no in-between."

Their state at any moment encodes roughly where in the boot
sequence the kernel is, or that it has hit a fatal exception.
A developer staring at the device with this table in hand can
decode "did the kernel make it past X?" without any cable
connected.

This document and the `boot_stage_t` enum in `src/004-led.c`
must stay in sync. Updating one without the other turns this
document into a lie.

## The vocabulary

Each physical light has a small vocabulary of states.

**Top window** — bicolor, with green and red emitters that
can be lit independently:

| Green pin | Red pin | Top window appearance |
| :-------: | :-----: | :-------------------- |
| off       | off     | dark                  |
| on        | off     | green                 |
| off       | on      | red                   |
| on        | on      | yellow-amber (additive mix of green + red, visibly brighter than either alone) |

**Bottom window** — single-color amber:

| Amber pin | Bottom window appearance |
| :-------: | :----------------------- |
| off       | dark                     |
| on        | amber                    |

Combined, eight distinct visible states are available. Five
of them are used by the boot-stage signaling vocabulary
below; the remaining three are reserved for later phase 1
issues if they need them.

## Boot-stage pattern table

| Stage signal              | Top window         | Bottom window | Meaning |
| :-----------------------: | :----------------: | :-----------: | :-- |
| (none yet)                | dark               | dark          | Either the kernel never started, or the kernel started but did not reach its first stage signal. The first sub-second after power-on is also dark while `led_hello` runs through its flash; if the device stays dark past about a second, the boot chain failed somewhere upstream of the kernel. |
| `STAGE_KERNEL_MAIN`       | green              | dark          | Kernel reached its first C function. From here, whichever stage signal follows decodes by the rows below. |
| `STAGE_USB_CONTROLLER`    | dark               | amber         | Kernel passed allocator self-test and brought up the USB controller successfully. Controller is alive but enumeration has not yet happened. |
| `STAGE_USB_ENUMERATED`    | yellow-amber (G+R) | amber         | Host has enumerated us and CDC-ACM is live. `debug_write` can push text to the host. |
| `STAGE_BACKUP_COMPLETE`   | red                | amber         | The eMMC-to-microSD backup finished cleanly. Power off, pull the microSD card, analyze the dump on a separate machine via raw `dd`. |
| `STAGE_PANIC_GENERIC`     | red                | dark          | A fatal exception fired, the allocator self-test failed, USB controller identification mismatched, eMMC bring-up failed, microSD bring-up failed, or the eMMC-to-SD backup hit a fatal error. Decoding which requires CDC-ACM serial capture or eyeball inspection of where in the boot sequence the LED last advanced from. |

The hello flash from `led_hello` is a transient pattern, not
a stage: top window yellow-amber, bottom window amber, held
for about a quarter-second, then both dark for another
quarter-second, then the kernel paints the first steady stage
signal. The flash is visibly indistinguishable from
`STAGE_USB_ENUMERATED` *while it is in flight*; the
distinguishing feature is duration.

## Long-operation heartbeat

During the multi-minute eMMC-to-microSD backup, the bottom
amber LED blinks on and off at roughly a one-second cadence —
each call to `led_heartbeat` in the backup loop flips the
amber pin. Visually, the bottom window pulses between dark
and amber while the top window holds whatever stage signal
was last set. If the blinking stops mid-operation, the kernel
is stuck on a particular sector.

(The PWM-era heartbeat from issue 106a was a smooth breathing
fade rather than a discrete blink. The blink replaces the
fade until issue 106c brings the PWM controller up.)

## Reading the lights

The two lights sit at the bottom of the lower screen on the
front edge — top and bottom relative to the developer's view
with the device held normally. Hold the device closed (cover
the upper screen) to compare them most easily. The bottom
amber LED's brightness and the top window's yellow-amber
brightness when both emitters are lit are both higher than
the top window's green-alone or red-alone brightness; this is
a property of the LEDs rather than a kernel choice.

## Interpretation guide

**You see a brief flash within a second of power-on — top
window yellow-amber, bottom amber, both for about a quarter
of a second, then both dark for the same — followed by the
steady stage signal.** That is `led_hello` — the kernel
reached its first C function. Whichever stage signal follows
decodes by the table above.

**You see no lights at all, ever — no flash, no stage
signal.** The kernel never reached `kernel_main`. The boot
chain failed somewhere upstream — most likely u-boot did not
recognise our kernel image (header malformed, recognition
magic missing, FAT path wrong), or BootROM did not recognise
the idbloader, or `booti` rejected the image, or the
load-address mismatch from issue 103d's territory re-emerged.
The fix is upstream of the kernel — check the build output,
the flash workflow, and the linker script's load address.

**You see the hello flash and then the top window stays
green, bottom dark, indefinitely.** The kernel is at
`STAGE_KERNEL_MAIN` and has not advanced. The hang is in the
allocator self-test, the USB PHY / controller bring-up, or
the USB endpoint-zero configuration. The next bring-up issue
to investigate is whichever the kernel calls first after the
stage signal — currently the USB PHY work.

**You see the bottom amber alone, top dark, indefinitely.**
The kernel is at `STAGE_USB_CONTROLLER` and has not advanced.
USB endpoint-zero bring-up succeeded; the hang is in the eMMC
controller bring-up, the microSD controller bring-up, the
debug-log init, or the backup itself.

**You see top yellow-amber + bottom amber, blinking the
bottom amber against a steady top yellow-amber.** The kernel
is mid-backup; the blink is the heartbeat. Wait. If the
blink stops without the LEDs advancing to
`STAGE_BACKUP_COMPLETE`, the kernel is stuck on a particular
sector.

**You see top red, bottom amber, steady.** The kernel
finished its backup successfully. Power the device off and
pull the microSD card.

**You see top red alone, bottom dark, steady.** The kernel
hit a fatal exception or one of the bring-up steps failed
and the kernel routed the failure through `STAGE_PANIC_GENERIC`.
The LED pattern is the only output until issue 110's CDC-ACM
debug stream is up and connected to a host. The appropriate
response is to power-cycle the device and inspect what
changed since the last successful boot.

## Adding new patterns

Adding a stage means three coordinated changes:

1. Add a new value to `boot_stage_t` in `src/004-led.c`.
2. Add a matching `case` in the `switch` inside
   `led_set_stage` that sets the LED pin state for that
   stage.
3. Add a row to the pattern table above with the top-window
   and bottom-window columns filled in.

The order is to write the pattern row first — saying what
the lights should mean in human language gives a clearer
name for the enum constant than starting from code.

Currently used patterns: `STAGE_KERNEL_MAIN`,
`STAGE_USB_CONTROLLER`, `STAGE_USB_ENUMERATED`,
`STAGE_BACKUP_COMPLETE`, `STAGE_PANIC_GENERIC`. Three of the
eight available two-window combinations remain unused
(top green + bottom amber; top red + bottom dark is the
panic; the panic-or-default case lights all pins).
