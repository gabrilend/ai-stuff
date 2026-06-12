# 103 — Project build system

## Current behavior

Source files can be compiled one at a time with the toolchain from
102, but there is no system that walks the project tree, compiles
every source file in dependency order, links them into a single
image, and packages that image for the device's bootloader.

## Intended behavior

A build system rooted at the project directory that:

- Takes every C source file under `src/` and compiles it with the
  cross-compiler from 102.
- Links the compiled objects together using a linker script under
  our control. The linker script specifies the kernel's load
  address and the layout of code, data, and BSS sections.
- Produces a single kernel image in the format the device's
  bootloader accepts.
- Reports clean error messages on failure rather than silently
  falling back. (Per project policy, fallbacks are warnings,
  warnings are errors.)
- Can be invoked from any directory by passing the project root as
  an argument, or by running it from the project root.

The build system is itself a script (or a Makefile invoked by a
script) under `scripts/` following the `${DIR}` convention.

## Suggested implementation steps

1. Write a minimal linker script that places the kernel at the load
   address documented in 101. Section layout: `.text`, then
   `.rodata`, then `.data`, then `.bss`.
2. Write `scripts/build.sh` that walks `src/`, compiles every `.c`
   it finds, links them with the linker script, and emits the
   kernel image to `tmp/kernel.img`.
3. Test the build by compiling a placeholder `src/000-main.c`
   containing only an empty entry function. Confirm the build
   produces an image of plausible size.

## Related documents

- `docs/002-roadmap.md` — phase 1.

## Blocked by

102.

## Blocks

104.
