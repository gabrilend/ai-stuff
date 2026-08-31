# 121-emit-sampler-check-riscv — info

A payload that draws on a bare RISC-V machine and says whether it chose the same words the first architecture chose. The third architecture's half of what 118 does for the second.

A score off in its last bit stays off in its last bit. A CHOICE that flips once joins the conversation, and everything after it is said in a different conversation. So this checks that across many hundreds of draws, under every setting the sampler has, both machines picked the same word every time and recorded the same chance for it, bit for bit.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `121-emit-sampler-check-riscv.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/121-emit-sampler-check-riscv.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.workspace(count, draws, stream_slots, plan_slots)` |  |
| `M.riscv64(options)` |  |

## Why the draws are chained

The carried stream advances with every draw -- position, state, how many have been taken from this number, whether it has wrapped. Independent draws would check the arithmetic and miss the bookkeeping, so one run passes through every setting from one file and both machines are required to finish looking at the same place in it.

## Where it sits

**Checked by** `122-test-sampler-riscv64`.

