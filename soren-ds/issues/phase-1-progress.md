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
    - `103a-air-gapped-flash-workflow.md` — move the build's
      output onto a microSD card across an air gap, in two
      scripts: one on the main machine pushes to a dedicated USB
      drive, one on the lab laptop (carried over by that drive)
      writes the kernel image to the SD card. The early-phase-1
      iteration loop runs through here until the eMMC takeover
      pipeline lands.
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
11. `110a-emmc-controller-driver.md` — bring up the SDMMC2
    controller that owns the internal eMMC so the kernel can
    read and write blocks on it.
12. `110b-bootable-emmc-overwrite.md` — write the kernel image
    (wrapped in the Android boot.img envelope u-boot expects)
    to the eMMC boot partition so the device boots SoreOS
    standalone with no SD card present.
13. `110c-usb-c-flash-protocol.md` — SoreOS on eMMC accepts new
    kernel images over USB-C and writes them back to eMMC,
    closing the daily iteration loop without SD-swap.
14. `111-framebuffer-driver.md` — parent / index. Split into:
    - `111a-display-controller-and-bottom-screen.md` — bring up
      the shared controller and light the bottom screen.
    - `111b-top-screen-output.md` — add the second output path
      to the already-running controller. Required to close phase
      1 — phase 1 demonstrates the hardware, and the hardware has
      two screens, so both light up before the phase ends.
15. `112-draw-one-pixel.md` — earn the first visible signal on
    each screen.
16. `113-phase-1-demo.md` — wrap the whole thing in a one-command
    script that builds, flashes by USB-C through the protocol
    from 110c, and streams the debug output.

## What changed from the original phase 1 plan

The original phase 1 routed debug through a UART. The Anbernic RG
DS has no accessible UART without opening the case and soldering,
so we route debug over USB instead. That makes phase 1 bigger —
USB device-mode bring-up is the single biggest piece of work —
but eliminates the need for an SD card reader or any path where
the stock OS touches the developer's laptop. USB CDC-ACM handles
the ongoing debug stream.

The framebuffer issues moved later in the numbering (from 109 to
111) so the story order matches the dependency order: USB-debug
is up before the framebuffer driver tries to report whether it
came up correctly.

The install path moved out of chip ROM recovery (Maskrom) and
into a three-step pipeline added during issue 101 research:

- The earliest phase 1 issues (102 through 110) are iterated by
  writing the kernel image to an external microSD card on the
  developer's main machine and moving the card to the device. The
  Rockchip boot ROM picks SD over eMMC and runs our kernel; stock
  Android on eMMC is never invoked. No USB connection between the
  device and any host computer is needed during this stretch.
- Issue 110a brings up the SDMMC2 controller so the kernel can
  read and write the eMMC.
- Issue 110b writes a SoreOS image, wrapped in the Android
  boot.img format Anbernic's u-boot accepts, into the eMMC's boot
  partition. From that point on, the device boots SoreOS
  standalone — no SD card required.
- Issue 110c adds a flash-receive mode to SoreOS itself. The
  laptop ships a new image over USB-C through SoreOS's own CDC
  plumbing; SoreOS writes it to the eMMC and reboots. Both ends
  of the USB bus are code we wrote, so the daily loop never
  trusts closed-source Anbernic firmware on the wire.

Chip ROM Maskrom remains the deepest recovery path beneath this
pipeline (per `notes/safety/000-bricking-and-recovery.md`) but is
not part of the daily loop. The phase 1 demo runs the USB-C
flash loop from 110c, not Maskrom.

## Completed issues

- 101 — hardware specification research. Findings live in
  `docs/014-hardware-overview.md`. The research surfaced enough
  known unknowns to spawn the new sub-issues 110a/110b/110c
  described above, and confirmed that the SD-boot-then-eMMC-
  takeover install pipeline is viable on this device.
- 102 — cross-compilation toolchain. Binutils 2.44 and GCC
  16.1.0 are built from source by `scripts/build-deps` and
  installed at `libs/cross/`. The smoke test in
  `scripts/check-toolchain` confirms the pipeline produces a
  64-bit ARM aarch64 ELF.
- 103 — project build system. A Makefile at the project root
  walks `src/` for every `.c`, compiles each with the cross-
  toolchain, links with the linker script at `src/kernel.ld`,
  and emits a raw kernel binary at `output/kernel.img`.
  `scripts/build` is the project-root-aware wrapper.
- 104 — boot and reset vector. `src/001-boot.s` defines `_start`
  at the kernel load address: masks all asynchronous exceptions,
  sets the stack pointer to a linker-reserved 16 KB region,
  zeroes .bss between linker-defined symbols, and branches into
  `kernel_main` in `src/002-main.c`.
- 106 — LED earliest boot signal. A small PWM driver
  (`src/003-pwm.c`) brings up channels 5/6/7 of the RK3568's
  PWM1 controller; the LED abstraction (`src/004-led.c`) maps
  the three LEDs (green/amber/red, all driven via PWM per the
  upstream device tree) to a boot-stage enum. `kernel_main`
  calls `led_init` and `led_set_stage(STAGE_KERNEL_MAIN)` as the
  first signs of life the device shows. The pattern table lives
  in `docs/015-led-diagnostic-codes.md`.
- 105 — exception and interrupt vectors. `src/005-vectors.s`
  defines a 2 KB-aligned 16-entry vector table; every entry
  captures the exception type index and falls into a common
  panic stub that records the faulting PC and syndrome before
  calling into the C `panic_handler` (`src/006-panic.c`). The
  panic handler lights `STAGE_PANIC_GENERIC` (red solid) and
  parks the core. The boot code installs the table by writing
  its address into the system's vector base register before
  branching to C.
- 107 — flat memory layout. `src/007-memory.c` exposes
  `memory_pool_base`, `memory_pool_end`, and `memory_pool_size`
  to the rest of the kernel; the full chip address space the
  three values sit inside is catalogued in
  `docs/016-physical-memory-map.md`. The DRAM extent (3 GB
  starting at zero), the lower-layer-firmware reservation
  beneath the kernel image, and every peripheral register
  window the SoC exposes are all documented in one place. The
  boot-time dump the original sketch proposed is deferred to
  whenever 110 brings up a text channel; until then the LED
  stage signal is sufficient.
- 103a — air-gapped SD card flash workflow. Two scripts live at
  `scripts/push-to-usb` and `scripts/lab-side/flash-sd`. The
  push side has been exercised end-to-end against the real USB
  drive and reformatted it to a clean FAT32 with the project
  label. The lab side will get its first real run when the
  build system produces an actual kernel image; if it surfaces
  bugs at that point the issue reopens.

## Open issues

108, 109, 110, the three install-pipeline issues 110a, 110b,
110c, plus 111a, 111b, 112, and 113.

## Phase demo

`issues/completed/demos/phase-1/run.sh` will exist once the phase
closes. It builds the kernel image, flashes it to the device over
USB-C using the protocol from 110c, streams the USB CDC-ACM debug
output, asks the developer to confirm a bright pixel at the
center of each screen, and reports the wall-clock time from build
start to ready — the iteration loop developers will live in
during phase 2.
