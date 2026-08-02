# 033, 055 — the blob report, and its comparison — info

`033` generates a payload that finds the packed model riding inside its own
image, reads its header aloud, reads the memory map the firmware leaves
behind, verifies its own body sits outside every usable range, and computes —
before touching anything — which memory strategy the machine can afford.
Issue `102` whole, on all three architectures.

`055` boots that payload on the three UEFI boards and holds every number the
machine speaks against what the host works out from the same blob.

Used by the payload builder (`019`), not run directly. The test runs alone:

```
luajit src/055-test-blob-report.lua [--seconds N]
```

## What the payload prints

| Line | Where it comes from |
|---|---|
| header fields | thirty-two bit loads at offsets computed from the layout description (`024`) |
| `total` | free + engine + weights |
| `engine` | the code and its envelope: text offset + blob offset, asked of `029` |
| `weights` | the blob's own size field, all sixty-four bits |
| `free` | conventional ranges in the firmware's map, summed |
| the outside check | no usable range may touch the image; the loader's own allocation is verified, not assumed |
| `cache`, `working` | `045`'s two formulas, re-implemented in each architecture's instructions |
| `rung` | the ratchet: fastest arrangement that fits, refusal last |

## How the model is found

Firmware may place the image anywhere, so no absolute address can be written
down in advance. But the distance from the code to what was appended to it is
fixed at build time (`029`), and a program can always work out where it is
standing. Where it is, plus how far it is, gives an answer correct wherever it
was put.

## Why the ratchet is computed twice

Two implementations of one specification, on purpose — the same reason the
assembly kernels have a reference (`043`/`044`). The host arithmetic in `045`
is what the image builder will trust; this payload is what the machine itself
will trust; `055` requires the two to agree at the same inputs, on every
board. The seam between the builder and the engine is exactly where a machine
fails at first light with the least possible information, so it is a test
instead of a discovery.

The weights term is the whole blob rather than the sum of its tensors,
because the blob is the unit that is copied or read in place — the tokenizer
tables ride along. `045.strategy` takes the same number through
`weights_bytes` so both sides answer the same question.

## The three tongues differ in shape

x86-64 and ARM finish their own label arithmetic, so those two are ordinary
assembly text with strings inline behind jumps. The RISC-V assembler leaves
every branch as a note for a linker that does not exist, so that payload is
laid out and encoded by `054`, with its strings pooled at the end and
addressed as the code base plus a counted offset.

Three calling conventions, one specification: arguments in rcx/rdx then
x0/x1 then a0/a1; values that must survive firmware calls live only in
registers each convention obliges the firmware to give back.

## Things learned that must not be re-learned

**Measure from a local label, never an exported one** (x86): a reference to
an exported symbol is a note for a linker, dropped silently, leaving the
address of the next instruction instead.

**Take field offsets from the format description, never by counting.**
Counting produced a vocabulary of 176 and a size of zero, in the same tidy
format as correct values.

**GetMemoryMap wants five arguments**, and the fifth rides differently per
architecture: on the stack above the scratch x86 calls are owed, in plain
registers elsewhere.

**The map buffer lives on the stack.** The image's own section is mapped
read-only by firmware that honours section rights (the RISC-V build does),
so a buffer in `.text` would be a crash that only happens on one board.

**An addi immediate stops at 2047**, so page-rounding by adding 4095 is
three instructions on RISC-V.

## Proven on 2026-08-02

All three architectures booted through real UEFI firmware: header values
matching the host reader, free memory plausible for the board, the image
verified outside every usable range, cache and working costs bit-identical
to `045`, and both implementations choosing the same rung. 27 of 27 in `055`.
