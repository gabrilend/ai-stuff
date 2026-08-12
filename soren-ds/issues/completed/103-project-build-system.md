# 103 — Project build system

## Current behavior

A Makefile at the project root walks `src/` for every `.c`,
compiles each with the cross-compiler from 102, links the
objects under the linker script at `src/kernel.ld`, and emits
a raw kernel binary at `output/kernel.img`. Intermediate object
files live under `tmp/build/kernel/` so the SSD never sees the
build tree. `scripts/build` is a thin wrapper that sets the
project-root variable so the Makefile is invokable from any
directory; the second argument is passed through as the make
target (defaults to `all`; `clean` removes the build outputs).

The placeholder `src/000-main.c` defines `_start` as a low-power
wait loop (`wfi`, then a branch back). The compiled image is
exactly the two-instruction body, eight bytes total, linked at
`0x00280000` — a reasonable placeholder for the RK3568 Android
boot.img kernel load address until issue 110b ties the image
to u-boot's actual expectations. `aarch64-elf-objdump -d`
confirms `_start` lives at the linker-script address and
contains exactly the instructions we wrote.

The Makefile fails loudly if `libs/cross/bin/aarch64-elf-gcc`
isn't installed — no silent fallback to the host toolchain.

The build re-creates its own work directory rather than assuming
one is there. `tmp/` in the project root is a symlink into
`/tmp`, and the system clears `/tmp` on every reboot, so the link
routinely outlives its target: the first build after any restart
finds it dangling. This is worth stating precisely because the
obvious repair does not work. `mkdir -p` on a path that runs
through a dangling symlink does *not* follow the link and create
the target — the symlink itself exists, so `mkdir` stops at
"File exists", and every object-file directory below it fails
with the same error. The path has to be resolved to its real
location first, which the Makefile does once at parse time and
hangs `tmp/build/generated` and `tmp/build/kernel[-debug]` off
the result. `scripts/build-bootable-sd`, `scripts/push-to-usb`,
and `scripts/extract-sd-image-parts` do the same thing for their
own use of `tmp/`, each immediately after the check that refuses
to run when `tmp/` is missing altogether. That check stays: a
missing `tmp/` means the RAM-backed convention was never set up
and should be an error, while a dangling one means the machine
merely rebooted and should be repaired in place.

## Intended behavior

A build system rooted at the project directory that:

- Takes every C source file under `src/` and compiles it with
  the cross-compiler from 102.
- Links the compiled objects together using a linker script
  under our control. The linker script specifies the kernel's
  load address and the layout of code, data, and BSS sections.
- Produces a single kernel image in the format the device's
  bootloader accepts (a raw binary; the Android boot.img
  wrapping that u-boot expects is added in 110b on top of
  this).
- Reports clean error messages on failure rather than silently
  falling back. (Per project policy, fallbacks are warnings,
  warnings are errors.)
- Can be invoked from any directory by passing the project root
  as an argument, or by running `make` from the project root.

A Makefile is the right tool from the start rather than a
shell script: incremental rebuilds are immediately useful once
src/ grows past a handful of files, and rewriting from shell to
make later costs more than starting in make today. The shell
script at `scripts/build` is a wrapper that sets the project
root for the Makefile so the rest of the workflow scripts can
call it the same way they call everything else.

## Suggested implementation steps

1. Write a minimal linker script at `src/kernel.ld` that places
   the kernel at the load address pinned for the chip. Section
   layout: `.text`, then `.rodata`, then `.data`, then `.bss`.
2. Write the Makefile at the project root. Use `DIR ?= $(CURDIR)`
   so it picks up the right project root whether invoked
   directly or by the wrapper. Compile flags include
   `-ffreestanding -nostdlib -nostartfiles -mcpu=cortex-a55`.
   Refuse to proceed when the cross-toolchain isn't installed.
3. Write `scripts/build` that invokes `make -C $DIR DIR=$DIR
   $TARGET`. Both arguments are optional; the defaults are the
   project root and the `all` target.
4. Write a placeholder `src/000-main.c` whose `_start` is a
   low-power-wait loop. Confirm the build produces a raw image
   whose disassembly matches the source.

## Related documents

- `docs/002-roadmap.md` — phase 1.

## Blocked by

102.

## Blocks

104.
