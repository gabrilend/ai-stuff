# 144-assemble-a-machine — info

Everything a bare computer needs, emitted as one program: the work area divided, the engine set up, the tokenizer prepared, the sampler readied, and the driver's loop entered. Issue `502`, and it is what `107` built.

This writes out the actual instructions a machine runs when it is switched on with nothing else on the computer. Hand it a model and what the machine should be told, and it hands back the program, and the data that program carries.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `144-assemble-a-machine.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/144-assemble-a-machine.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.KERNELS` | the arithmetic the conducting calls, in the order it expects |
| `M.assemble(options)` | Returns { assembly, riding, work_bytes, riding_at, shape } or nil and why. |

### In more detail

**`M.KERNELS`**

Named here rather than where they are emitted, because the plan the
conducting reads is a table of addresses and the order IS the meaning.

**`M.assemble(options)`**

```
options: dir         the project root
         blob        the packed model, as bytes
         text        what the machine wakes holding, as token numbers
         max_tokens  how many words it may say before stopping
         settings    { temperature = n }
         randomness  the carried numbers, as an array of integers

Returns { assembly, riding, work_bytes, riding_at, shape } or nil and why.
```

## Why it is a file of its own, as of 2026-08-22

It lived inside `140`, which is a test. So the only way to obtain a whole machine was to run a test, and the image builder -- whose entire purpose is producing one -- could not reach it. The builder invented its own arrangement instead, and that arrangement was correct, carefully commented, checked by its own test, and described a machine nobody built.

## What it deliberately does not do

It does not assemble, wrap or write anything. It returns text and bytes. Turning text into instructions is clang's business, the executable envelope is `029`'s, the medium is `141`'s -- and keeping them apart is what lets a test read the assembly while a builder takes the image.

## And it is where the firmware is met

The name does not suggest it, but this emits the entry point firmware actually calls, so the two things that have to happen before anything else happen here: the firmware's name for this program is kept before the first call can destroy it, and the five-minute timer firmware arms before entering a program is turned off. Both would belong to the processor-selection payload if that were on the boot path. It is not, so they belong to whatever runs first, and this runs first.

## Worth knowing

A test that builds its own version of the thing is testing its own version. `140` calls this and checks what comes back; the builder calls the same thing. One dataflow, and the machine on it is the machine that ships.

## Where it sits

**Belongs to** `502`.

**Checked by** `140-test-the-driver`, `151-test-the-documentation-site`.

