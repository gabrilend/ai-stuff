---
name: bare-metal boot
phase: 11
status: pending
blockedBy: []
---

# 1101 — bare-metal boot

The RK3568 boots directly into our code, with no Linux kernel
underneath. The very first step of phase 11.

## current behavior

The device boots Linux, Linux starts the broker, the broker spawns
GSplus instances. Many layers between power-on and "Apple IIds is
running."

## intended behavior

- The device's bootloader (U-Boot or similar — depends on the
  RG DS's stock bootloader) loads our bare-metal binary from the
  microSD card.
- Our binary is a tiny ARM stub that:
  - Sets up the ARM CPU (MMU, caches, exception vectors).
  - Initializes essential hardware (UART for debug, panels enough
    to show "loading," interrupts).
  - Hands control to the Apple IIds runtime.
- No Linux kernel. No userspace. No GSplus.
- The bootloader is configurable: holding a specific button at
  power-on falls back to Linux (preserving the ability to debug,
  reflash, or run the staging-ground build).

## suggested implementation steps

1. Identify the RG DS's bootloader. Document how to interrupt it
   and select a boot target.
2. Set up the cross-compilation toolchain for bare-metal ARM
   (likely `aarch64-elf-gcc` or assembler directly).
3. Write the boot stub. Tiny, ARM assembly only. Sets up the
   stack, the MMU (initially identity-mapped), and exception
   vectors.
4. Write a "hello world" payload: blinks the screen, prints a
   message over UART.
5. Get this booting on the device. This may take weeks of
   trial-and-error around the bootloader, SD card layout, and
   panel initialization.
6. Add the fallback-to-Linux button combo.
7. Document everything in `docs/research/bare-metal-boot.md`.

## related documents

- `docs/004-roadmap.md` — phase 11 entry
- `notes/vision/000-vision.md` — the destination

## known design questions

- What's the SD card layout for dual-boot? A small partition for
  the bare-metal binary + the Linux partition for staging-ground.
  Bootloader selects between them based on the button combo.
- How do we update the bare-metal binary? For development:
  reflash the SD card from a host. For users (if ever): a
  bootloader-level update mechanism is a separate concern; defer.

## notes

- This is the issue that demystifies bare-metal. Everything after
  it is "we have a working bare-metal target; now we put more
  stuff on it."
