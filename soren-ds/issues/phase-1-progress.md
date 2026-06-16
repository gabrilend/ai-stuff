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
9. `109-usb-controller-and-device-mode.md` — parent / index.
    Split into:
    - `109a-usb-phy-and-controller.md` — bring up the USB 2.0
      PHY and the DWC3 controller, in device mode. Closes when
      the laptop's `dmesg` shows raw USB activity on plug-in.
    - `109b-usb-device-enumeration.md` — descriptor tables,
      the setup-packet dispatcher, and endpoint-zero hardware
      configuration. Closes when the kernel builds with these
      in place and the controller's RUN bit is set.
    - `109c-usb-control-transfer-plumbing.md` — TRB rings, the
      setup-packet buffer, the event-ring decoder, and the
      polling loop that wires them together. Closes when
      `lsusb` reports our device with the right IDs.
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
    - `111a-display-controller-and-bottom-screen.md` — VOP2
      display controller bring-up.
    - `111b-dsi-bringup.md` — MIPI DSI controllers and D-PHYs.
    - `111c-panel-initialization.md` — JD9365DA-H3 panel init
      register sequence.
    - `111d-framebuffer-and-scanout.md` — framebuffers from the
      page allocator, VOP2 output paths pointed at them, scan-
      out enabled.
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
- A safety gate (110e) before the first eMMC write: copy the
  first 200 MB of the eMMC to a reserved region of the external
  microSD card, eject the card, analyze on the lab laptop via
  raw `dd` (no mount, no execution), find where the boot
  partition actually lives, before invoking 110b's writer on
  real hardware. This requires a microSD driver (110f) to
  exist first — SDMMC0 uses a different IP from the SDHCI we
  wrote for the eMMC.

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
- 108 — flat page allocator. `src/008-allocator.c` implements a
  4 KB-page allocator backed by a one-bit-per-page bitmap that
  it carves out of the bottom of 107's memory pool. The bitmap
  walk is O(n) on alloc, O(1) on free. A boot-time self-test
  runs from `kernel_main` and panics to a red LED on bookkeeping
  failure. Multi-page contiguous allocation and concurrency
  control are deferred to later issues that actually need them.
- 109a — USB PHY and controller bring-up. `src/009-usb.c` brings
  the USB 2.0 PHY out of suspend through the chip's GRF, soft-
  resets the DWC3 controller through its global control
  register, sets the port-capability direction to device mode,
  pins device speed to USB 2.0 high speed, and verifies the
  controller is alive by reading the documented Synopsys magic
  out of the identification register. `kernel_main` advances
  the LED stage to `STAGE_USB_CONTROLLER` on success or panics
  on identification mismatch. The closing evidence on real
  hardware (raw USB activity in the laptop's `dmesg`) gets
  observed when issue 110b puts our kernel on the eMMC; if the
  laptop sees nothing at that point this issue reopens.
- 109b — USB descriptors, dispatcher, and endpoint-zero
  configuration. `src/010-usb-enumeration.c` defines the device,
  configuration, and string descriptors in `.rodata`, the
  setup-packet dispatcher that maps standard USB requests to
  responses, and the DEPSTARTCFG / DEPCFG / DEPXFERCFG sequence
  that configures endpoint zero through the controller's
  command interface. The transfer machinery that turns
  dispatched responses into bytes the host actually sees lives
  in 109c.
- 109c — USB control transfer plumbing. The TRB struct, per-
  endpoint TRB allocations, the 8-byte setup-packet buffer, the
  event-ring decoder that walks 4-byte events and distinguishes
  endpoint events from device events, and the four-stage
  control-transfer state machine that wires the 109b dispatcher
  to the host. On bus reset the state machine resets and
  re-arms endpoint zero OUT; on SET_ADDRESS completion the
  device address is applied to the DCFG register. Closing
  evidence on hardware (`lsusb` reporting the device) lands when
  110b puts the kernel on the eMMC; reopens if anything in the
  TRB layout or event-decode bit positions is off.
- 110 — USB CDC-ACM debug stream. The configuration descriptor
  now declares CDC Control + CDC Data interfaces with their
  functional descriptors and endpoints; `src/011-cdc-acm.c`
  configures the bulk endpoints after the host selects our
  configuration and exposes a `debug_write` function the rest
  of the kernel calls to push text. The LED stage advances to
  `STAGE_USB_ENUMERATED` when CDC-ACM is live. Closing evidence
  (`/dev/ttyACM0` carrying kernel text on the host) lands when
  the kernel boots from the device.
- 110a — eMMC controller driver. `src/012-emmc.c` brings up the
  RK3568's SDHCI host, walks the JEDEC eMMC identification
  sequence (CMD0 through CMD7), and exposes single-block read
  and write through CMD17 and CMD24. Polled and blocking; each
  call is one transaction. Bring-up status is narrated through
  the CDC-ACM channel. Closing evidence (round-trip pattern
  test on real hardware) lands when 110b boots from the device.
- 110b — bootable eMMC overwrite. `src/013-boot-image.c` wraps
  the running kernel in an Android boot.img header (version 0)
  and writes header + kernel bytes to the eMMC's boot
  partition through 110a's block driver, then reads the first
  block back to verify the magic landed intact. The linker
  script gains an `__image_end` symbol so kernel_size in the
  header can be computed at runtime. The boot partition LBA
  is a hard-coded placeholder until first hardware test
  validates it.
- 110d — bootstrap button trigger. The button-held-at-boot
  flash trigger that calls into 110b's writer; documented as a
  recovery-net mechanism in case 110c's USB-C path is broken or
  unavailable. The code path is currently disabled in
  `kernel_main` pending 110e's LBA verification; the design and
  prototype work that this issue captures is preserved in git
  history.
- 110f — microSD controller driver. `src/015-sdmmc.c` brings up
  the RK3568's SDMMC0 controller (a Synopsys DW MSHC, distinct
  from the SDHCI we use for the eMMC), walks the SD spec's
  card-init sequence (CMD0, CMD8, ACMD41-loop, CMD2, CMD3,
  CMD9, CMD7), and exposes single-block read and write through
  CMD17 and CMD24. Polled and blocking. Used by 110e's
  eMMC-to-microSD backup. Closing evidence (a successful round
  trip on real hardware) lands when boot test #1 runs.
- 110g — SD-card debug log. `src/017-debug-log.c` adds a DRAM
  ring buffer plus periodic flush to a reserved 16 MB region of
  the microSD card. `debug_write` in 011-cdc-acm.c gains a call
  to the new `debug_log_append` so every diagnostic narration
  also lands in the log regardless of whether a USB host is
  attached. The phase 3 RAM transcript ring (issue 310) is
  marked as the eventual replacement; both should land together
  in that issue's commit.
- 103a — air-gapped SD card flash workflow. Two scripts live at
  `scripts/push-to-usb` and `scripts/lab-side/flash-sd`. The
  push side has been exercised end-to-end against the real USB
  drive and reformatted it to a clean FAT32 with the project
  label. The lab side will get its first real run when the
  build system produces an actual kernel image; if it surfaces
  bugs at that point the issue reopens.
- 103c — kernel image bootloader-recognition envelope. A
  sixty-four-byte header lives at the start of `output/kernel.img`,
  built by `src/000-image-header.s` and pinned at the load
  address by the linker script. The header carries two
  instructions of glue (a no-op and a branch into `_start` at
  byte 64), an image-size field the linker computes from the
  distance between the load address and the end of `.bss`, a
  flags word, and the four-byte `ARM\x64` magic at offset 56
  that u-boot's `booti` command grep's for to recognise an
  image worth loading. The vector table moved from
  `.text.vectors` to a freestanding `.vectors` output section
  so its 2 KB alignment requirement no longer propagates back
  to `.text` and shoves `_start` away from the recognition
  envelope. Without this header, ROCKNIX's u-boot on the SD
  card refuses to launch the kernel.
- 103b — bootable SD card image assembly. Two scripts work
  together. `scripts/extract-sd-image-parts` runs once: it
  downloads a pinned ROCKNIX nightly into `tmp/`, verifies
  the upstream-published SHA-256, decompresses the image,
  and carves three durable blobs into `libs/sd-image-parts/`
  with a `.sha256` next to each — the Rockchip idbloader
  from sector 64, the u-boot FIT from sector 16384, and the
  RG DS device tree blob from inside ROCKNIX's first
  partition. `scripts/build-bootable-sd` runs on every
  build: it allocates a 272 MiB image, writes an MBR
  partition table with one bootable FAT32 LBA partition
  starting at sector 32768, drops the idbloader and u-boot
  FIT into the unpartitioned pre-partition region at their
  fixed BootROM-expected offsets, builds a 256 MiB FAT32
  partition with `mkfs.fat` + `mtools`, populates it with
  the kernel as `/KERNEL`, the DTB as
  `/device_trees/rk3568-anbernic-rg-ds.dtb`, and a minimal
  `extlinux.conf` pointing u-boot at both, and dd's the
  partition into the output at sector 32768.
  `scripts/lab-side/flash-sd` was updated to look for
  `bootable-sd.img` specifically rather than "any single
  `.img` in `output/`" (two `.img` files now share that
  extension and the kernel image alone is not bootable).
  `scripts/push-to-usb` already rsync's the whole output
  directory, so the new artifact ships automatically.
  Closing evidence on real hardware lands when we flash a
  card for the first time.
- 106a — visible heartbeat during long operations. The LED
  layer gained two diagnostic signals on top of the existing
  static stage table. A brief hello flash (all three LEDs
  together for a fraction of a second, then all three dark,
  then the steady stage signal) runs as the first thing
  `kernel_main` does, so the developer can tell at a glance
  whether the kernel reached its first C function — a
  diagnostic that became essential after the first SD-card
  boot test showed all LEDs dark for ambiguous reasons. A
  breathing-amber heartbeat advances one step on each
  megabyte of progress through the eMMC-to-SD backup, using
  the PWM hardware's actual brightness control rather than
  on/off, so the multi-minute backup is visibly "still
  working" rather than indistinguishable from a hung kernel.
  Both signals depend on a small `delay_busy` busy-wait
  utility — phase 1 has no clock source yet, so timed pauses
  are produced by counting nops in a volatile-counter loop.
  The diagnostic-codes document is updated to describe the
  new patterns and the "no LEDs ever" interpretation now
  unambiguously points at boot-chain failures rather than
  kernel-runtime hangs.
- 103d — kernel load address matches what the SD-boot
  bootloader actually uses. The linker pin moved from
  `0x0028_0000` to `0x0200_0000`, the address ROCKNIX's
  u-boot drops `/KERNEL` at. The earlier value was inherited
  from Anbernic's Android conventions and held over the
  whole project before any hardware test had been run against
  the SD-card path; the first hardware test surfaced the
  mismatch as a kernel that loaded and was jumped to but
  read its own data from the wrong memory (the stack pointer
  pointed into u-boot's heap, the BSS-zero loop wrote into
  u-boot's heap, the vector base register pointed at memory
  that did not contain vectors, and the LED-flash diagnostic
  produced no visible signal because the call chain that
  would have driven the PWM never resolved its own state
  correctly). The boot-partition writer in
  `src/013-boot-image.c` carries the same constant into the
  Android boot.img envelope so Anbernic's u-boot lands the
  kernel at the same address once the eMMC takeover runs;
  the physical-memory-map doc names the new boundary and
  explains where the original value came from.

## Open issues

110c (USB-C runtime re-flash, moved back to open after the
prior session conflated it with the button trigger), 110e
(eMMC layout probe — code is in place and `kernel_main` runs
the backup automatically on boot; the issue closes when the
first hardware run produces a dump that lets us identify the
boot partition's real LBA), the four display sub-issues
(111a, 111b, 111c, 111d), 112, and 113.

103e (direct-GPIO LED probe) is open as a temporary
diagnostic. After the load-address fix from 103d, the first
SD boot test still produced no LED activity; the cause is
ambiguous between "the kernel still does not reach `_start`"
and "the kernel reaches `_start` but the PWM path to the LEDs
is blocked by something the bootloader does not configure
(pin-multiplexer routing or the PWM controller's clock gate)."
The probe drives the three LED pins through the GPIO
controller directly — bypassing the PWM controller entirely —
to answer that question. If the hardware run shows the wink
pattern the probe produces, the kernel reaches its entry
point and the next investigation focuses on the PWM path
(pin-mux, clock gate). If the hardware run still shows no LED
activity, the kernel is not reaching `_start` and the next
investigation moves further upstream (the bootloader, the
recognition envelope's parsing, the load address). The probe
and the GPIO-function override it sets come out of source the
moment the question is answered, either way.

## Phase demo

`issues/completed/demos/phase-1/run.sh` will exist once the phase
closes. It builds the kernel image, flashes it to the device over
USB-C using the protocol from 110c, streams the USB CDC-ACM debug
output, asks the developer to confirm a bright pixel at the
center of each screen, and reports the wall-clock time from build
start to ready — the iteration loop developers will live in
during phase 2.
