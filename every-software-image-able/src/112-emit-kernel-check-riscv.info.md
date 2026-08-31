# 112-emit-kernel-check-riscv — info

A payload that runs the third tongue's arithmetic on a bare machine and says how many of its answers matched what the first tongue produced. The other half of issue 401's third architecture.

The routines for this architecture cannot be tested on the machine that wrote them, because that machine does not speak this language. So the test is carried to a machine that does: the inputs, the routines, and the answers the first architecture gave, all baked into one program that boots, computes, compares, and reports.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `112-emit-kernel-check-riscv.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/112-emit-kernel-check-riscv.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.STACK_BYTES` | what the payload takes for its own working room |
| `M.riscv64(options)` | described below |

### In more detail

**`M.STACK_BYTES`**

Results at sp+512, per-routine scratch at sp+1024, the hexadecimal buffer
at sp+64. Nothing is written inside the payload itself: firmware that
honours section rights maps the code read-only, so a buffer in the
instructions faults on some machines and not others.

**`M.riscv64(options)`**

options: cases, recorded, norms, recorded_norm, jobs, number_at,
epsilon_bits, kernels (the module), specification, float_bits, dir

## Why the answers are carried rather than recomputed

A payload that computed its own expected answers would be comparing an implementation against itself, which passes whatever it does. The bit patterns here came off the first architecture, and they are compared as INTEGERS -- not as numbers, so nothing rounds and "close" is not a thing that can happen.

## Why this file looks nothing like 101

On the other two architectures a payload is assembler text and the assembler finishes the branch arithmetic. Here it does not: a branch to a label in the same file leaves a relocation, there is no linker to satisfy it, and the extracted bytes encode a branch to the instruction's own address. Every loop would be a silent infinite one. So the whole program -- prologue, routines, data, comparisons -- is laid into ONE counted program (054), which measures every distance itself. That is also why the routines cannot be pasted in as text: the emitter has to see every instruction to count.

## Where things live

s1 the code base, s3 the firmware's table, s4 its console, s5 matched, s6 compared, s7 and s8 the first disagreement, s9 whether one has been captured, s10 and s11 the normalisations. The routines that call the exponential use s0 through s3 and give them back, so nothing here is disturbed by a call.

## Where it sits

**Belongs to** `401`.

**Checked by** `113-test-kernels-riscv64`.

