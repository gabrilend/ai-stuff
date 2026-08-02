# 030, 031, 032 — the UEFI boards — info

Three emulated machines that start the way the design assumes: through UEFI
firmware rather than a BIOS or nothing at all. The field schema is in
`015-board-qemu-x86-64.info.md`; this file covers what the UEFI boards add and
where the three differ.

## Why these exist beside the first three

A machine that boots through UEFI is a different board from one that boots
through a BIOS. It hands over different things, looks for its payload
elsewhere, and offers a display where the other offers only text memory. Two
kinds of board, two sets of descriptions.

They buy two things the first three cannot:

**The framebuffer.** Issue `202` says firmware hands over an address and a
geometry so a machine can draw from its first instant with no driver. That
handover is UEFI's alone — a BIOS board has text memory, which is characters
rather than pixels, and a board with no firmware has nothing at all until a
driver exists.

**The selection.** Issue `402` says nothing detects a processor and dispatches,
because each firmware finds only its own payload. The label it reads is written
on the application's envelope (`029`), and the filename it looks for encodes the
same thing.

## Where the three differ, and none of it was guessable

| | Firmware arrives as | Boot file | Storage |
|---|---|---|---|
| x86-64 | two flash chips: code, and a writable copy of the variables | `EFI/BOOT/BOOTX64.EFI` | SATA |
| ARM64 | handed over whole | `EFI/BOOT/BOOTAA64.EFI` | NVMe |
| RISC-V | two flash chips again | `EFI/BOOT/BOOTRISCV64.EFI` | USB |

Handing the RISC-V firmware over whole makes it assert inside its own startup
before reaching anything of ours. Presenting the ARM one as flash does not work
either. Each of the three wanted something different and none of it followed
from the others — which is exactly the kind of knowledge a board description
exists to hold.

**The variable store is copied per machine**, never shared. The firmware writes
to it, and one run changing what the next one sees would make results depend on
history.

**The boot filesystem arrives on the board's own storage controller**, not a
fixed one. Attaching it as IDE worked on x86 and the ARM board has no IDE at
all.

## How the payload gets there

The emulator can serve a directory as a FAT filesystem, which saves building a
disk image for something that changes on every build. The launcher creates the
directory, places the application at the board's boot path, and attaches it.

## Proven on 2026-08-02

All three booted real firmware, which found and started an executable generated
by `029`, which walked the firmware's own table to reach the console and
printed `first light through firmware: <arch>`.
