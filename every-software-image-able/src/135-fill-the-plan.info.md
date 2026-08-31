# 135-fill-the-plan — info

Telling the conducting where everything is, on a bare machine, in all three tongues. The third piece of the driver (issue 107).

The conducting reaches nothing by name -- on bare metal there are no names -- so it asks only "what is at this offset of the plan". Something has to write that plan, and hosted, a readable program does it with a page of assignments. This is that page, in the processor's own instructions, filled from what the previous two pieces found out.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `135-fill-the-plan.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/135-fill-the-plan.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.EPSILON_BITS` | the normalisation constant, as a pattern |
| `M.header_offsets(format) and M.plan_offsets(conductor)` |  |
| `M.x86_64(format, conductor, float_bits)` | plan rdi, blob rsi, tensors rdx, regions rcx, kernels r8, layer_table r9. |
| `M.aarch64(format, conductor, float_bits)` | plan x0, blob x1, tensors x2, regions x3, kernels x4, layer_table x5. |
| `M.riscv64(p, format, conductor, float_bits)` | plan a0, blob a1, tensors a2, regions a3, kernels a4, layer_table a5. |

### In more detail

**`M.EPSILON_BITS`**

Carried as bits rather than computed, for the same reason every other
constant in the assembly is: there is no way to say "one hundred
thousandth" in a processor's instructions, and a decimal that has to be
parsed back is a rounding this would then be measuring.

## What it ties together

The counts come out of the model's own header. The tensor addresses come from `131`, which walked the model. The workspace addresses come from `133`, which divided the memory. The kernel addresses come from the caller, which is the only thing that knows where it put its own routines. Nothing here is a constant except the two the specification fixes.

## Where being wrong is silent

and it is nearly everywhere in this routine. A slot written one place along is not an error: the conducting reads it, gets an address that is something else's, and the arithmetic proceeds. A layer table filled with the wrong stride gives every layer the layer before's weights and produces a perfectly well-formed answer to a question nobody asked.

## The one refusal

and it is worth more than it looks. Query heads are walked in groups, one group per key head, and the walk counts up rather than dividing -- so a model whose heads do not divide evenly among its key heads would walk off the end of the group and read a key head that does not exist. That cannot be discovered later: it is a wrong answer, not a fault. So it is refused here, where there is still something to say it to.

## The two floating numbers are the only arithmetic in the setup

The conducting deliberately has none -- every number it touches is a count or an address -- and the attention scale has to come from somewhere. It is computed once here, at startup, as one over the square root of the head width, ROUNDED THROUGH SINGLE PRECISION, because that rounding is part of the specification and not an accident of where it was worked out (`035`).

## Where it sits

**Belongs to** `107`.

**Checked by** `136-test-fill-the-plan`, `140-test-the-driver`.

