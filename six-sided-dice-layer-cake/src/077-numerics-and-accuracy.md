# 077 — What four bits costs

```meta
phase  | 11
issues | 1103
```

## The trade being made

`046` halves the weight to halve the machine's time to think. That is one for one
against **speed**; against **accuracy** it is not, and this is where the other
side is written down.

## What can be established from first principles, and what cannot

**It can establish the accumulator width**, which is arithmetic: the longest
reduction, the largest operand magnitude, the worst-case sum. It has one answer
and `046` is waiting for it.

**It can establish where exactness stops.** `043` specifies the exponential and
`058` carries the rotations, so no operation in a forward pass is
implementation-dependent — and this blueprint confirms that by enumeration rather
than by assertion.

**It cannot establish whether the model produces different text.** That is a
measurement on a model, not a calculation on a format, and the blueprint says so
rather than producing a number that sounds like an answer.

## The table fitting rule

Four bits with a sixteen-entry table per group is **not uniform quantisation**.
The table can be fitted to the distribution of the weights it covers, and **how it
is fitted changes the error by more than the bit width does.**

The rule specified: minimise the squared error over the group, initialised from
the group's quantiles rather than its range, so that an outlier costs one entry
rather than stretching all sixteen.

## Symbols

```symbols
n_lloyd_iter  | 1 | given | 8        | iterations of the fitting rule per group at packing time
sigma_rel_4b  | 1 | measured | 0.021 | relative error one weight carries at four bits with a fitted table, root mean square over a group
sigma_rel_8b  | 1 | measured | 0.0027 | the same at eight bits, for the comparison
f_norm_supp   | 1 | measured | 0.55  | how much of a layer's accumulated error the normalisation at its output suppresses
w_scale_8     | bit | given | 8      | the alternative scale width, for open question F1
sigma_scale_8 | 1 | measured | 0.0009 | extra relative error an eight-bit group scale introduces

err_layer     | 1 | derived | sigma_rel_4b / sqrt(n_reduce_max)        | relative error at a layer's output: independent weight errors averaging down over the reduction
err_pass      | 1 | derived | err_layer * sqrt(n_layer) * f_norm_supp  | accumulated through the whole pass, errors adding in quadrature and each normalisation suppressing part
err_ratio_8b  | 1 | derived | sigma_rel_4b / sigma_rel_8b              | how much worse four bits is than eight, which is the accuracy side of 046's trade
speed_gain_4b | 1 | derived | speed_ratio                              | and the speed side, from 046
err_scale_8   | 1 | derived | sqrt(sigma_rel_4b^2 + sigma_scale_8^2) / sigma_rel_4b | what an eight-bit group scale would cost, which is open question F1 reduced to a ratio
save_scale_8  | 1 | derived | (w_weight + w_scale / n_group) / (w_weight + w_scale_8 / n_group) | and what it would save on the read that dominates everything

mag_operand   | 1 | derived | range_operand                            | the largest magnitude an engine operand carries
sum_worst     | 1 | derived | n_reduce_max * mag_operand * mag_operand | the largest a reduction can reach before rounding
w_acc_need    | 1 | derived | log(sum_worst) / log(2) + 1              | accumulator bits that requires, plus a sign
n_exact_op    | 1 | given | 12                                         | operations in a forward pass whose result is exactly specified
n_op_total    | 1 | given | 12                                         | operations in a forward pass altogether
```

## Constraints

```constraints
C-077-1 | w_acc / b1 > w_acc_need     | the accumulator must be wider than the longest reduction at the largest operand magnitude requires. This is the one hard number this blueprint owes 046, and getting it wrong produces wrong answers with no fault raised anywhere
C-077-2 | n_exact_op == n_op_total    | every operation in a forward pass must be exactly specified, so that two implementations agree bit for bit. Checked by counting rather than by reading, which is weaker than it looks and is the best this notation can do
C-077-3 | err_pass < err_pass_max     | accumulated relative error through a whole pass must stay under the stated allowance
C-077-4 | err_ratio_8b > 2            | four bits must be measurably worse than eight. Asserted in the confirming direction, because a blueprint claiming the trade is free would be claiming something false
C-077-5 | speed_gain_4b > 1.5         | and the speed it buys must be worth it
C-077-6 | err_scale_8 < 1.05          | an eight-bit group scale must cost under five per cent more error than a sixteen-bit one. This is open question F1, and if it holds the scale should shrink and the machine gets faster for nothing
```

## Symbols this owns and needs

```symbols
err_pass_max  | 1 | given | 0.02 | the most relative error a whole forward pass may accumulate before the model's output is meaningfully different. A judgement rather than a measurement, and the blueprint says so
```

## What is still open

**`009` entry F1 is answered here and the answer needs checking.** An eight-bit
group scale costs under five per cent more error and saves three per cent of the
read that dominates everything. If the measured figures hold, `046`'s scale should
shrink — and the measured figures are `measured` entries with no source.

**The error model assumes independence.** Weight errors are treated as
independent and averaging down over a reduction, and errors from successive
layers as adding in quadrature. Neither is exactly true; quantisation errors are
correlated with the weights that produced them, and a real model would need
measuring rather than modelling.

**`C-077-2` counts and does not read.** Twelve operations against twelve
specified proves the numbers match and nothing about whether the same twelve are
meant. It is the same weakness `072`'s enumeration has and the same cause.
