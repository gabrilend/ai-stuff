# 046 — How numbers are written down

```meta
phase  | 6
issues | 606
```

| what | format | where |
|---|---|---|
| weights | 4-bit index into a 16-entry table, group of 128, one scale | core, slice, engine input |
| the scale | 16-bit float | beside every group |
| activations | 16-bit float | staging buffers, between layers |
| engine operands | 8-bit integer, per-tensor scale | inside the array |
| accumulators | 32-bit | inside the array |
| key and value cache | 8-bit | core |
| logits | 32-bit float | face five only |

## Why weights are four bits

**Not storage.** Sixty-four gibibytes would hold the reference model at eight
bits, barely. It is that a weight is read once per token and the reading is the
bottleneck, so halving the weight halves the machine's time to think.

Precision is being traded for speed at one for one, which is a much starker
bargain than it usually is, and the blueprint should say so rather than presenting
four bits as a quantisation choice.

## The exactness rule

Two implementations must agree bit for bit or `085` cannot debug anything.
`043` owns accumulation order; this owns width and rounding:

- every conversion between formats has one specified rounding mode
- every accumulator has a specified width, and it is **the narrowest that
  provably cannot overflow** rather than the widest available, which is a `077`
  calculation
- denormals, infinities and not-a-number are **refused rather than propagated**

That last is a real decision. Nothing in a transformer forward pass should
produce one, and a machine that quietly carries a not-a-number through eighty
layers has thrown away the only place the fault was findable. Refusing raises one
of `049`'s two traps.

## Symbols

```symbols
b1            | bit | given | 1    | one bit. A width carries the unit so that a format's size can be added to a capacity; an exponent needs a pure number. Dividing by this is how a width becomes a count, and it is the only place in the project where a unit quantity is declared for that purpose
w_weight      | bit | given | 4    | bits per weight index
n_group       | 1   | given | 128  | weights sharing one expansion table and one scale
w_scale       | bit | given | 16   | width of a group's scale
w_act         | bit | given | 16   | activations in the residual stream
w_operand     | bit | given | 8    | engine operands
w_kv          | bit | given | 8    | key and value cache entries
w_logit       | bit | given | 32   | logits, on face five only
n_round_mode  | 1   | given | 1    | rounding modes the machine has. One, so that no conversion anywhere can differ between two implementations
special_vals  | 1   | given | 0    | whether denormals, infinities and not-a-number are propagated. They are not; producing one raises a trap

w_weight_eff  | bit | derived | w_weight + w_scale / n_group    | bits per weight including the amortised scale, which is the number that decides how long a token takes
f_scale_cost  | 1 | derived | (w_scale / n_group) / w_weight_eff | what the scale costs as a share of the weight read, which is the whole of open question F1
w_weight_8    | bit | derived | w_operand + w_scale / n_group   | what eight-bit weights would cost, for the comparison
speed_ratio   | 1 | derived | w_weight_8 / w_weight_eff         | how much faster four bits makes the machine than eight, which is the trade being made
range_operand | 1 | derived | 2^(w_operand / b1 - 1)            | largest magnitude an engine operand can carry
n_lut_bits    | bit | derived | n_lut_entry * w_scale           | bits of expansion table one group carries, which the slice stores alongside the weights
```

## Constraints

```constraints
C-046-1 | 2^(w_weight / b1) == n_lut_entry | the index width and the table size must match exactly, which is trivially true and catches one being edited without the other
C-046-2 | w_weight_eff * n_param ~= C_weights | bits per weight including the amortised scale, times the reference model's parameter count, must equal the resident weight size in 078. Two routes to the size of the thing this machine exists to hold
C-046-3 | speed_ratio > 1.5             | four bits must make the machine at least half again faster than eight, or the accuracy is being spent for too little
C-046-4 | w_acc > 2 * w_operand         | the accumulator must be wider than the product of two operands, which is the weakest possible overflow check and is here because 045's real one depends on 077
C-046-5 | n_round_mode == 1             | one rounding mode. Asserted as a value, because a second one is the ordinary way bit-exactness between two implementations quietly stops holding
C-046-6 | special_vals == 0             | special values are refused rather than propagated. Asserted so that a blueprint assuming a not-a-number can flow through a layer fails outright
C-046-7 | w_kv <= w_act                 | the cache is no wider than the activations it stores, since it is a compressed record of them
```

## What is still open

**`009` entry F1 is quantified here and not closed.** The scale costs an eighth
of a bit per weight, about three per cent of the read that dominates everything.
Whether eight-bit scales would cost measurable accuracy is a `077` measurement,
and until it exists the three per cent is being paid for a reason nobody has
checked.

**The expansion table's fitting rule is not here.** Sixteen entries per group of
a hundred and twenty-eight is not uniform quantisation — the table can be fitted
to the distribution of the weights it covers, and how it is fitted changes the
error by more than the bit width does. `077` owns it and this blueprint reads a
result that does not exist.
