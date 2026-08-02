# 033-emit-blob-report — info

Generates a payload that finds the packed model riding inside its own image and
reads its header aloud. Issue 102 in the small: locating the weights with no
filesystem, no allocator and no operating system, then proving it by saying
what was found.

Used by the payload builder (`019`), not run directly.

## What it exports

| Name | Meaning |
|---|---|
| `field_offsets(format)` | where each header field sits, computed from the layout description |
| `x86_64(blob_offset, offsets)` | complete assembler text for the payload |

Only x86-64 so far. The other two need the same routine written again in their
own instructions, and the RISC-V one without a single symbol reference.

## How the model is found

Firmware may place the image anywhere, so no absolute address can be written
down in advance. But the distance from the code to what was appended to it is
fixed at build time (`029`), and a program can always work out where it is
standing. Where it is, plus how far it is, gives an answer correct wherever it
was put.

## Two things not to change back

**Measure from a local label, never an exported one.** `leaq _start(%rip)`
assembles to `leaq (%rip)` — the address of the next instruction — because a
reference to an exported symbol is a note for a linker and there is no linker
here. Everything measured from it was two dozen bytes out, and the payload
printed plausible nonsense rather than failing.

**Take field offsets from the format description, never by counting.**
Counting them by hand put two of them one field off, and the machine reported a
vocabulary of 176 and a size of zero in the same tidy format as the correct
values beside them.

## How it prints

There is nowhere to put data, so each string is laid inline in the instruction
stream with a jump over it — good data and terrible instructions, hence the
jump coming first. Numbers are converted to hexadecimal on the stack a nibble
at a time, since there is nothing to convert them with.

## Proven on 2026-08-02

Booted by real UEFI firmware, reporting magic `41495345` (`ESIA`), version 1, 4
layers, hidden 64, 4 heads, vocabulary 32, context 128, 5 tensors, 32 tokens,
25728 bytes — every value matching the host-side reader on the same blob.
