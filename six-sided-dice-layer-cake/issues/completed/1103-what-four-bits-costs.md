# 1103 — What four bits costs

Produces `src/077-numerics-and-accuracy.md`.

## Current behavior

**Done.** `src/077-numerics-and-accuracy.md` exists, and it is explicit about the
boundary between what it can establish and what it cannot.

It establishes the accumulator width, which is arithmetic and which `046` was
waiting for -- and that number **corrected `045`**, which had been checking the
accumulator against one row of the multiplier array rather than against the
model's widest reduction. The array accumulates across many passes; a row is not
the reduction.

It establishes where exactness stops, and confirms it does not: with the
exponential specified in `043` and the rotations carried in `058`, no operation in
a forward pass is implementation-dependent.

It does **not** establish whether the model produces different text, and says so
rather than producing a number that sounds like an answer.

Six constraints. `C-077-6` answers `009` entry F1: an eight-bit group scale costs
under five per cent more error and saves three per cent of the read that dominates
everything. **If the measured figures hold, the scale should shrink -- and they are
`measured` entries with no source.**

## Intended behavior

**The error the chosen formats introduce, layer by layer and end to end**, and the
accumulator widths that follow from it.

### The trade being made

`606` halves the weight to halve the machine's time to think. That is a one-for-one
bargain against **speed**; against **accuracy** it is not one for one, and this
blueprint is where the other side of it is written down.

Four bits with a sixteen-entry table per group of a hundred and twenty-eight is
not uniform quantisation — the table can be fitted to the distribution of the
weights it covers, which recovers a great deal. The blueprint must say how the
table is chosen, because the answer changes the error by more than the bit width
does.

### What has to be measured rather than argued

**Per-tensor error.** Relative error introduced by quantising one weight matrix, as
a function of group size and table fitting.

**Accumulated error through a layer.** The residual stream carries error forward,
and each layer adds. Whether the accumulation is linear or worse depends on the
normalisations, which are error-suppressing, and this is not obvious enough to
assert.

**End-to-end effect.** The number that matters is not relative error in a tensor;
it is whether the model produces different text. That is a measurement on a model
and not a calculation on a format, so the blueprint must be honest about what it
can and cannot establish from first principles.

### What it can establish, and must

**Accumulator widths.** `606` asks for the narrowest width that provably cannot
overflow, over the largest reduction in the reference model. That is a
calculation: the longest dot product, the largest operand magnitude, the worst
case sum. It has one answer and this blueprint owns it.

**Where exactness stops.** `603` specifies the exponential so that bit-exactness
holds all the way through the softmax. This blueprint must confirm that the
specification is sufficient — that no other operation in the pass introduces an
implementation-dependent result — and name the boundary if one remains.

**The group scale question.** `009` entry F1: sixteen bits or eight. An eighth of a
bit per weight, on the read that dominates everything. This blueprint is the only
one that can answer it, and the answer is a measurement of what eight-bit scales
do to the per-tensor error.

## Symbols this must publish

Group size, table size, table fitting rule. Per-tensor relative error. Error
accumulation rule through layers. End-to-end error bound, with a statement of what
it does and does not cover. Longest reduction length. Largest operand magnitude.
Required accumulator width. The eight-versus-sixteen bit scale comparison.

## Constraints this must assert

- Accumulator width exceeds what the longest reduction at the largest magnitude
  requires, with a stated margin. **The one hard constraint here**; the rest is
  measurement.
- Every operation in the forward pass is either exactly specified or named as a
  boundary. Enumerated against `603`'s operation list.
- Bits per weight including the amortised scale matches `606`'s figure.

## Suggested implementation steps

1. Specify the table fitting rule first, since it dominates the error.
2. Do the accumulator overflow calculation properly and hand the width to `606`.
3. Walk `603`'s operations and mark each exact or not.
4. Answer `009` entry F1 with a measurement.
5. Be explicit about which claims are calculated and which would need a model to
   verify.

## Blocks

`605`, `606`, `1106`.

## Blocked by

`603`, `606`, `1102`.

## Related documents

`004`. `009` entry F1.
