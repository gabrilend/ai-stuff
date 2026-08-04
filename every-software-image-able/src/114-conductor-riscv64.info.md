# 114, 115, 116 — a whole thought on a real RISC-V machine — info

The conducting written a third time, and a complete forward pass run on a
bare RISC-V machine with every score compared against the first
architecture's as an integer.

With this, **a whole thought runs end to end in assembly on all three
architectures, and all three produce the same scores over the same weights.**

## Running it

```
luajit src/116-test-forward-riscv64.lua
```

## What it exports

| File | Role |
|---|---|
| `114-conductor-riscv64` | the conducting, laid into a counted program |
| `115-emit-forward-check-riscv` | the payload: model, plan, three runs, comparisons |
| `116-test-forward-riscv64` | records the first tongue's scores and drives the board |

On `114`:

| Name | Meaning |
|---|---|
| `M.emit(p, plan, options)` | lay the conducting into a program being built |

`plan` is the module describing the plan's layout (`056`) — the same
description all three conductings read, so there is never a second copy.
`options.name` renames the routine and every label inside it;
`options.miswire` emits a deliberately wrong one.

## What it does not contain

Floating point. Not one instruction of it. Every number is a count or an
address, which is why a disagreement after this change cannot be an
arithmetic disagreement.

## Where the state lives

All of it in registers. This architecture has twelve that survive a call,
where x86 has six and ARM has ten — so unlike the first tongue nothing spills
to the stack, and unlike the second nothing needs a slot beside the frame.

| | |
|---|---|
| `s0` | the plan |
| `s1` | the position |
| `s2` | the row of turns for this position |
| `s3` | the cursor into the layer table |
| `s4` | the layer |
| `s5` | this position's slot in the cache, in numbers |
| `s6` | where the caller wants the scores written |
| `s7` | this layer's base slot in the cache, in numbers |
| `s8` | the head |
| `s9` | the key head |
| `s10` | how far through its group the head is |

That is a difference of convenience and not of specification. The order of
operations is identical on all three, and the order of operations is the only
thing the answer depends on.

## Why it emits rather than returning text

This assembler leaves a relocation on a branch to a label in its own file,
there is no linker to answer it, and the extracted bytes then encode a branch
to the instruction's own address — every loop a silent infinite one. The word
emitter (`054`) counts every distance itself, and has to see every instruction
to do so. `116` checks the finished object has no relocation left in it rather
than booting one and puzzling at the silence.

## What is reported

| Mark | Meaning |
|---|---|
| `matched` / `of` | scores identical to the first architecture, and compared |
| `wide` / `wof` | scores where the two matrix routines agreed, and compared |
| `got` / `want` | the first disagreement, kept whole |
| `bent` | scores the deliberately wrong conducting moved |

`bent` must **not** be zero. A zero there means every score survived a
conducting known to be wrong, which would mean the payload is comparing
something against itself.

## Reading the machine, carefully

Only the text after the payload's own header is searched, and every mark must
begin a line. This board's firmware prints `device is of 3 speed` while
enumerating USB, eleven hundred lines before the payload speaks, and a loose
search for "of" finds that instead — which once reported three values compared
where there had been two hundred and seventy-nine, every one agreeing.

## Result on 2026-08-03

11 of 11. All 192 scores across four steps match the first architecture bit
for bit; the two matrix routines agree on all 192; and the conducting bent on
purpose moved all 192.

## What is still not ported anywhere

The hands. That half is not a translation: x86 reaches devices through a
separate address space with its own instructions and the other two are
memory-mapped throughout, so one hand changes shape rather than detail and the
catalogue is genuinely not identical across machines. That is survivable only
because the machine reads its catalogue rather than being told it.

## Related

`056-emit-conductor`, `108-conductor-aarch64` — the same conducting elsewhere.
`111-kernels-riscv64` — the eleven routines this one calls.
`109`, `110` — the same claim on the second architecture.
