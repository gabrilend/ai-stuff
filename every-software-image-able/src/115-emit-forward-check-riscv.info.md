# 115-emit-forward-check-riscv — info

A payload that runs a WHOLE FORWARD PASS on a bare RISC-V machine and says how many of its scores matched what the first architecture produced. The third architecture's half of what 109 does for the second.

The eleven pieces of arithmetic were already proved to agree one at a time (111, 112, 113). This runs them in the order a thought requires, driven by the conducting written in the same tongue, over a whole small model -- and compares every score against the first architecture's as an integer, so nothing rounds and "close" cannot happen.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `115-emit-forward-check-riscv.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/115-emit-forward-check-riscv.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.workspace(shape, steps, slot_count)` | Where everything writable lives, as offsets from the stack pointer. |
| `M.riscv64(options)` | described below |

### In more detail

**`M.workspace(shape, steps, slot_count)`**

Where everything writable lives, as offsets from the stack pointer.
Computed rather than written down, for the same reason 109's is: offsets
counted by hand produce numbers that look like numbers.

**`M.riscv64(options)`**

options: shape, tensors, words_of, prompt, recorded, scale_bits,
epsilon_bits, kernels (module), conductor (module), plan (module 056),
specification, float_bits, dir

## Why this is a different claim

A routine can be right alone and be handed the wrong thing by the routine before it. The first architecture learned exactly that: composing nine routines that each passed found a disagreement of four parts in a thousand million, at the second token only, and the defect was in the REFERENCE rather than the assembly.

## Why everything is in one counted program

This assembler leaves a relocation on a branch to a label in its own file, there is no linker to answer it, and the extracted bytes then encode a branch to the instruction's own address -- so every loop would spin forever, silently. The word emitter (054) counts every distance itself, and it has to see every instruction to do so.

## Where the writable memory is

On the stack, all of it. Firmware that honours section rights maps the payload's code read-only, so a buffer in the instructions faults on some machines and not others.

## Where it sits

**Checked by** `116-test-forward-riscv64`.

