# 056-emit-conductor — info

The conducting, in assembly. The last readable piece of a forward pass — the
layer loop, the head loop, and the pointer arithmetic that hands each kernel
exactly the memory it is owed — emitted as one routine. With it, a whole
thought is assembly end to end on x86-64. Checked by `050` against the same
recorded answer as everything else, bit for bit.

## What it exports

| Name | Meaning |
|---|---|
| `M.SLOTS` | the plan's layout: one row per eight-byte slot, order is layout |
| `M.LAYER_ORDER` | the nine per-layer tensors, in the order the table carries them |
| `M.offsets()` | slot name to byte offset, computed |
| `M.declare()` | teaches the FFI the plan and the conductor, then checks every FFI offset against the assembly's |
| `M.new_plan(kernels, model, cache, wide)` | a filled plan with fresh scratch, plus everything that must stay alive with it |
| `M.x86_64()` | the conductor as assembler text |

## The plan

The conductor takes one argument: a table holding the model's counts, the
two floating constants, the address of every kernel it may call, every fixed
tensor, the cache, the scratch vectors, and a per-layer table of nine tensor
pointers. It reaches nothing by name — on bare metal there are no names —
and asks only "what is at this offset of the plan," so the same instructions
run hosted and bare.

The layout is declared once as data. Assembly offsets are computed from it,
and `declare()` refuses to continue if any FFI field sits anywhere else —
the same rule as the blob header: one description, nothing counted by hand.

## Why kernels arrive as addresses

A call to an exported symbol is a note for a linker. Hosted, a linker exists
and would oblige; on the metal there is none, and the engine fills the table
by measuring from where it stands. Taking addresses through the plan keeps
the conductor honest about the machine it is really for.

## Two constants the conductor never computes

The attention scale (one over the square root of the head width, rounded
through single precision) and the normalisation epsilon arrive in the plan.
The conductor has no floating point in it at all — every number it touches
is a count or an address — which is what made it safe to move last: after
`050` passed, a disagreement could only ever have been here, and there is no
arithmetic here to disagree in.

## The head walk has no division

Query heads outnumber key heads, so the walk keeps two counters advancing
together — the head, and its place within its key head's group — and the key
head steps when the group completes.

## Result on 2026-08-02

6 of 6 in `050`: the conducted pass matches the recorded answer exactly and
conducts the wide kernel to the identical answer. What remains of the engine
on other architectures is `401`, held against the readable conductor (`049`)
that stays as the reference.
