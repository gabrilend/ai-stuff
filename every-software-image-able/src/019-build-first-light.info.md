# 019-build-first-light — info

Builds the first-light stubs: one tiny payload per architecture that boots on
its example board and says `first light: <arch>` over the console. They prove
the harness end to end and are scaffolding, never the seed.

## Invocation

```
luajit src/019-build-first-light.lua [--arch x86_64|aarch64|riscv64] [--dir PROJECT_ROOT]
```

No `--arch` builds all three. Artifacts land on the RAM artifact tier at
`tmp/shared-memory/first-light/<arch>.{s,o,bin}` — the generated assembly is
kept beside the binary so what ran is always readable.

## How it works, in one paragraph

The assembly is generated from the message string: each character becomes a
load-immediate plus a store to the board's console address, then the machine
sleeps forever. No data section, no relocations — which is what lets the
whole build be `clang -c` plus `llvm-objcopy -O binary`, with no linker on
the machine at all. The x86 variant is a BIOS boot sector and is checked to
be exactly 512 bytes; the other two are raw binaries for the boards' loader
paths.

One generator per architecture in a dispatch table (`emit`). Adding an
architecture is adding a row and a clang target triple.

## Proven results

All three stubs produced first light on their boards on 2026-08-02, on the
first attempt, via launcher 018. The empirical findings — the ARM board needs
its PC set by a second loader entry, the RISC-V reset vector jumps to DRAM
start with no firmware — are recorded in the board info files where they
belong.
