# Phase 1 progress — hardware bring-up

Phase 1 builds the smallest kernel that boots on the device. By
the end of the phase, the device powers on into our code, brings
up its two LEDs as the earliest-stage diagnostic signal, brings
up the USB controller and exposes a virtual serial port for live
debug streaming, sets up its own memory layout, brings both
output paths of the shared display controller live so the top
and bottom screens are both being scanned out, and draws a bright
pixel at the center of each screen. The developer's iteration
loop runs entirely over the USB cable — no SD card reader, no
stock OS touching the laptop, no stock OS running at all, just
the chip's ROM recovery mode for installing the kernel image and
USB CDC-ACM for streaming everything the kernel says afterward.

## The story of the phase

Each issue builds on the ones before. Read them in order for a
walkthrough of how the kernel comes to life:

1. `101-hardware-specification-research.md` — learn what the
   hardware is, including which chip ROM recovery mode is the
   install path.
2. `102-cross-compilation-toolchain.md` — get a compiler that
   targets it.
3. `103-project-build-system.md` — build a kernel image with that
   compiler.
4. `104-boot-and-reset-vector.md` — make the image actually take
   control after firmware hands off.
5. `105-exception-and-interrupt-vectors.md` — make failures
   legible instead of silent.
6. `106-led-earliest-boot-signal.md` — give the kernel a voice
   through the two LEDs, before either USB or the screen come up.
7. `107-flat-memory-layout.md` — commit to where things live in
   physical RAM.
8. `108-flat-page-allocator.md` — let the kernel ask for memory.
9. `109-usb-controller-and-device-mode.md` — bring the chip onto
   the USB bus as a recognizable device. The heaviest single
   piece of work in the phase.
10. `110-usb-cdc-acm-debug.md` — turn that into a virtual serial
    port the laptop streams from. Most kernel text from here on
    flows through this channel.
11. `111-framebuffer-driver.md` — parent / index. Split into:
    - `111a-display-controller-and-bottom-screen.md` — bring up
      the shared controller and light the bottom screen.
    - `111b-top-screen-output.md` — add the second output path
      to the already-running controller. Required to close phase
      1 — phase 1 demonstrates the hardware, and the hardware has
      two screens, so both light up before the phase ends.
12. `112-draw-one-pixel.md` — earn the first visible signal on
    each screen.
13. `113-phase-1-demo.md` — wrap the whole thing in a one-command
    script that builds, flashes via chip ROM recovery, and
    streams the debug output.

## What changed from the original phase 1 plan

The original phase 1 routed debug through a UART. The Anbernic RG
DS has no accessible UART without opening the case and soldering,
so we route debug over USB instead. That makes phase 1 bigger —
USB device-mode bring-up is the single biggest piece of work —
but eliminates the need for an SD card reader or any path where
the stock OS touches the developer's laptop. The chip's ROM
recovery mode handles every install; USB CDC-ACM handles the
ongoing debug stream. USB mass storage (the "drop a file on the
device's exposed drive to update the kernel" flow) is deferred
to phase 7 where the rest of the USB transport work lives.

The framebuffer issues moved later in the numbering (from 109 to
111) so the story order matches the dependency order: USB-debug
is up before the framebuffer driver tries to report whether it
came up correctly.

## Completed issues

None yet.

## Open issues

All of 101 through 113.

## Phase demo

`issues/completed/demos/phase-1/run.sh` will exist once the phase
closes. It builds the kernel image, flashes it to the device via
the chip ROM recovery tool, streams the USB CDC-ACM debug output,
asks the developer to confirm a bright pixel at the center of each
screen, and reports the wall-clock time from build start to ready
— the iteration loop developers will live in during phase 2.
