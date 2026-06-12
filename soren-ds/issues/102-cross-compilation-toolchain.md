# 102 — Cross-compilation toolchain

## Current behavior

There is no toolchain on the developer's machine that produces
executable code for the device's ARM chip. C source can be written
but cannot be turned into something the handheld can run.

## Intended behavior

A reproducible cross-compilation toolchain installed on the
developer's machine. The toolchain:

- Targets the exact ARM chip identified in 101.
- Compiles C source to a freestanding object file (no hosted libc,
  since the kernel is freestanding).
- Links objects into an image whose entry point and load address
  are specified by a linker script under our control.
- Produces output in the format the device's bootloader expects.

A script under `scripts/` verifies the toolchain is installed and
reports its version. The script follows the project convention of
a hard-coded `${DIR}` at the top, accepting an override as the
first argument, and using paths relative to `${DIR}` throughout.

## Suggested implementation steps

1. Decide between `gcc-arm-none-eabi` and `clang` with appropriate
   target flags. Document the choice and the reasoning.
2. Install the chosen toolchain. Record the installation method so
   it can be reproduced on another machine.
3. Compile the smallest possible freestanding C source (a function
   that returns 0) to confirm the pipeline works end to end.
4. Add `scripts/check-toolchain.sh` to verify the toolchain is
   present and report its version.

## Related documents

- `docs/002-roadmap.md` — phase 1.

## Blocked by

101.

## Blocks

103, every later phase 1 issue.
