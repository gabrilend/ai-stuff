# 108-conductor-aarch64 — info

The conducting, in the second tongue. The layer loop, the head loop, and the
pointer arithmetic that hands each kernel exactly the memory it is owed,
written again in ARM's instructions. With it, a whole thought is assembly end
to end on a second architecture.

## What it exports

| Name | Meaning |
|---|---|
| `M.source(plan, options)` | the conducting as assembler text |

`plan` is the module that describes the plan's layout (`056`). It is passed in
rather than read off a path, so there is exactly one description of where every
slot sits and this file holds no second copy of it.

| Option | Effect |
|---|---|
| `name` | renames the routine and every label inside it, so more than one conducting can sit in one program |
| `miswire` | emits a deliberately wrong one — see below |

## What it does not contain

Floating point. Not one instruction of it. Every number this file touches is a
count or an address, which is why the first architecture moved its conducting
last and why a disagreement after this change cannot be an arithmetic
disagreement. The two floating constants — the attention scale and the
normalisation epsilon — arrive already computed, in the plan.

## Where the registers go

Ten of them survive kernel calls and hold what every call site needs.

| | |
|---|---|
| `x19` | the plan |
| `x20` | the position |
| `x21` | the row of turns for this position |
| `x22` | the cursor into the layer table |
| `x23` | the layer |
| `x24` | this position's slot in the cache, counted in numbers |
| `x25` | where the caller wants the scores written |
| `x26` | this layer's base slot in the cache, counted in numbers |
| `x27` | the head |
| `x28` | the key head |

and `[sp, #96]` holds how far through its group the head is, which is the
eleventh thing and the one there is no register left for.

`x9` and `x10` are the scratch pair, and nothing that must survive a call is
ever put in either. The convention lets a called routine destroy `x9` through
`x15`, and several kernels do.

## The one place the architectures genuinely differ

x86-64 has six registers that survive a call and had to keep four pieces of
loop state on the stack. This architecture has ten, so all but one live in
registers. That is a difference of convenience rather than of specification:
the order of operations is identical, and the order of operations is the only
thing the answer depends on. The one that stays on the stack does so to keep
the shape recognisable beside the first tongue, not because it must.

## The mis-wired one, and why it exists

`miswire` hands the feedforward's two projections to each other — the gate is
computed from the tensor the up projection wants and the other way round. Both
tensors are exactly the same shape, so nothing reads outside anything and
nothing faults. Every kernel still computes precisely what it is asked. The
answer is wrong, because the gate goes through a curve the other half does not.

That is this project's characteristic defect in its plainest clothes: a piece
that is right alone being handed the wrong thing by the piece before it. A test
that proves the pieces agree and cannot show itself failing has proved only
that nothing crashed — so the wrong one rides along in the same payload
(`109`) and is required to disagree.

## Related

`056-emit-conductor` — the same conducting for the first architecture, and the
description of the plan that both of them read.
`099-kernels-aarch64` — the ten routines this one calls.
`109-emit-forward-check`, `110-test-forward-aarch64` — what proves it.
