# 103d — Kernel load address matches what the SD-boot bootloader actually uses

## Current behavior

The linker script pins the kernel image at physical address
`0x0200_0000`. The bootloader on the SD card development path
(ROCKNIX's u-boot, built into the FIT image extracted into
`libs/sd-image-parts/`) loads `/KERNEL` to the address its
`kernel_addr_r` environment variable names, which on this build
is `0x0200_0000`. Because the linker and the bootloader agree,
every absolute address the linker resolved at link time — the
stack pointer's runtime value, the start and end of `.bss`, the
address that gets written into the exception vector base
register, the value the recognition envelope's `image_size`
field carries — names the same memory the bytes were actually
copied into. PC-relative branches between the kernel's own
functions worked already and continue to work; the difference
is that the kernel's pointers to its own data now point at the
kernel's own data instead of at whatever happened to live at
the linker's idea of those addresses.

The header's flexible-placement flag stays set. With the
linker's load address already on a 2 MB boundary, u-boot's
`booti` accepts the image where it loaded it rather than
relocating. The image runs from `0x0200_0000` end-to-end.

## Why this issue exists

The previous load address was `0x0028_0000`, the conventional
Rockchip Android boot.img kernel load address that Anbernic's
u-boot on eMMC uses. The first SD-boot hardware test produced
no LED activity. Investigation found that ROCKNIX's u-boot does
not use Anbernic's address; its compiled-in defaults name
`0x0200_0000` for the kernel and `0x1200_0000` for the device
tree. The kernel was being loaded and jumped into correctly,
but every literal-pool address it then read referenced a
different memory range than the one it was running from. The
stack pointer pointed into u-boot's heap, the BSS-zero loop
wrote zeros into u-boot's heap, the vector base register
pointed at memory that did not contain vectors. The kernel did
not crash visibly because its first observable signal — the
LED-flash diagnostic — depends only on MMIO writes to fixed
peripheral addresses, and those addresses are absolute physical
addresses unaffected by where the kernel itself lives. But the
PWM controller never received the writes either, because either
the wrong stack corrupted a register save earlier in the chain
or the PWM pinmux / clock state the LED layer assumes is in
fact not set by ROCKNIX's u-boot. Without the address fix it is
impossible to tell which.

The fix is the linker change. Diagnosing any further LED
silence after the change requires a kernel that runs from the
address its own pointers name.

## Why two different bootloaders disagree

Anbernic's u-boot is a Rockchip vendor build that follows
Android-on-Rockchip conventions. The conventional kernel load
address in that lineage is `0x0028_0000` — a small offset above
the secure firmware reservation, packing the kernel against the
bottom of usable DRAM. ROCKNIX's u-boot is built from the
mainline u-boot tree with the project's own configuration, and
mainline u-boot picks a higher load address for kernels —
`0x0200_0000` — because mainline ARM64 Linux expects the kernel
within the first 512 MB of DRAM and the higher offset leaves
plenty of room beneath it for early-boot scratch space, the
device tree, and the ramdisk. Both choices are valid; they
disagree because they are written by different people with
different defaults.

The project's eventual home is the eMMC, where Anbernic's
u-boot lives and where we will overwrite the boot partition
with our kernel wrapped in an Android boot.img envelope. That
envelope carries its own `kernel_addr` field that tells
Anbernic's u-boot where to load the kernel; we set it to match
the linker, so the same kernel binary runs from the same
address on both paths once the eMMC takeover lands. The
in-tree assembler that builds the boot.img header
(`src/013-boot-image.c`) reads its load address from the same
constant the linker is set to so they cannot drift apart
silently.

## Things this issue does not do

- *Make the kernel position-independent.* A position-independent
  kernel could run from any load address, sidestepping the
  agreement-between-linker-and-bootloader question entirely. It
  is a substantial project (every literal-pool reference, every
  symbol address used at runtime, has to be reconstructed from
  the current PC rather than baked in by the linker) and is not
  needed when one fixed load address works for both boot paths.
- *Investigate the LED pinmux and clock state.* If the address
  fix is not enough to make the kernel's hello flash visible on
  hardware, the next thing to look at is whether ROCKNIX's
  u-boot leaves the chip's general register file configured so
  the three LED pins are routed to PWM output, and whether the
  PWM1 controller block's clock is gated. The current PWM
  driver assumes both of these are already set by the
  bootloader; the diagnostic-codes document already notes the
  first SD-boot test showed all LEDs dark, which is consistent
  with that assumption being wrong. A separate issue picks this
  up if hardware testing after this fix shows the LEDs still
  silent.

## Implementation steps

1. Change the load address at the top of `src/kernel.ld` from
   `0x00280000` to `0x02000000`. Update the comment block
   describing the address so it names the SD-card path's
   bootloader and the eMMC path's bootloader as both targeting
   this address, with the boot.img envelope from
   `src/013-boot-image.c` carrying it across to Anbernic's
   u-boot.
2. Update the comment in `src/000-image-header.s` that
   illustrates the `flags` field — the parenthetical example
   that names `0x00280000` as the bootloader-configured kernel
   load needs to name the new address.
3. Update `KERNEL_LOAD_ADDR` in `src/013-boot-image.c` so the
   Android boot.img header it writes to the eMMC boot partition
   tells Anbernic's u-boot to load the kernel at the same
   address the linker pinned it to. Without this update the
   eMMC boot path would fail with the same symptom the SD-boot
   path was producing.
4. Update `docs/016-physical-memory-map.md` so the DRAM-region
   table names `0x0200_0000` as the kernel image's start, the
   memory between u-boot's region and the kernel as a gap, and
   the caveats section explains the split between the two
   u-boot conventions.
5. Build the kernel and confirm by disassembly that the literal
   pool in `_start` now contains four addresses whose top bits
   are `0x0200…` rather than `0x0028…`, and that the linker's
   recognition-envelope `image_size` value still matches
   `__bss_end - __image_start`.

## Related documents

- `docs/016-physical-memory-map.md` — the DRAM regions table
  this change updates.
- `notes/safety/000-bricking-and-recovery.md` — why getting the
  boot chain right matters and what happens when it fails.
- `docs/015-led-diagnostic-codes.md` — the "no LEDs ever"
  interpretation row, which until now ambiguously implicated
  either an upstream boot-chain failure or a kernel-runtime
  hang. After this fix the kernel actually runs end-to-end from
  the address u-boot drops it at, so that row's interpretation
  resolves: anything observed past this point is a
  kernel-runtime issue, not a load-address issue.

## Blocked by

103c (the recognition envelope this issue does not change,
which was a prerequisite for u-boot recognising the image at
all).

## Blocks

Everything from this point on, since without the linker and
the bootloader agreeing on where the kernel lives the kernel
cannot read its own data correctly. The remaining open phase 1
work (the eMMC layout probe, the USB-C runtime re-flash path,
the framebuffer bring-up, the first-pixel demo, and the phase
demo wrapper) all depend on a kernel that actually runs.

## Parent

103.
