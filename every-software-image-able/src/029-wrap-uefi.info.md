# 029-wrap-uefi — info

Wraps a raw binary in the executable format UEFI firmware will load, so a
payload can be started by real firmware rather than dropped at an address by a
loader trick.

## Invocation

```
luajit src/029-wrap-uefi.lua --from RAW --to APP --arch NAME [--entry N]
                             [--append BLOB]
```

`--arch` is `x86_64`, `aarch64` or `riscv64`. `--entry` is the offset of the
entry point within the raw code, defaulting to zero. `--append` places a
payload a fixed distance past the code in the same section, which is how a
packed model rides inside the program that runs it (issue 102).

Two query flags answer layout questions so nobody keeps a second copy of the
answers: `--blob-offset` prints where an appended payload begins, measured
from the code; `--text-rva` prints how far into the loaded image the code
begins, with the headers below it. Their sum is the whole footprint of an
engine with no model aboard.

## Why this exists rather than a linker

There is no linker on this machine that produces this format. There does not
need to be one — the envelope is a fixed arrangement of numbers, and
generating it is less work than acquiring a tool that would.

## What the envelope is

A PE file, the format Windows uses and UEFI adopted. It opens with a stub from
an older era saying the program cannot run under DOS, kept only because the
format never dropped it. Then a header naming the machine it is for, then one
section holding all the code.

**The machine number is the whole of issue 402's answer.** Nothing detects a
processor and dispatches; each firmware simply declines to open an envelope
addressed to somebody else.

## The one thing not to change back

The executable is **not** marked as carrying no relocation table, although it
genuinely carries none. Firmware reads that mark as *load me at the stated
address or not at all*, and an address that is ordinary memory on one machine
is outside RAM on another — x86 accepted `0x400000` without comment and the
ARM board refused with `failed to find range 400000`.

Leaving the mark off lets firmware place the image wherever it likes. Nothing
needs fixing up afterwards because the code refers to itself relative to where
it stands, which is the same property that let it be built without a linker.

## Proven on 2026-08-02

All three architectures booted through real UEFI firmware and printed through
the firmware's own console: `first light through firmware: <arch>`.
